#!/usr/bin/env python3
"""Table definitions from an SAP landscape, and a check of the repository's field references against them.

First principle: no SAP field is relied on until it is seen in the landscape. This tool fetches what SE11 shows -
the definition, the fields with keys and data elements, and the indexes - for a list of tables, and then tells which
fields the repository still marks as VERIFY (link registry, process catalogue) exist, are missing, or may sit in an
include whose fields were not exported.

Run it on a machine that reaches the system (it uses the ABAP Development Tools HTTP interface of the system, the same
one Eclipse ADT uses). Only dictionary metadata is read; no business table is selected.

    python ddic_export.py export --tables ops-framework/config/ddic/standard_tables.txt --out ops-suite/ddic/<label>
    python ddic_export.py compare --exports ops-suite/ddic/<label> --repo .

The logon comes from --url / --client / --user or from the environment, with the same names as the test tool's
qualification harness: SAP_URL or ZCA_TT_A4H_URL, SAP_CLIENT or ZCA_TT_A4H_CLIENT, SAP_USER or ZCA_TT_A4H_USER,
SAP_PASSWORD or ZCA_TT_A4H_PASSWORD (else asked for), and SAP_TLS_PIN or ZCA_TT_A4H_TLS_PIN (SHA-256 fingerprint of a
self-signed test system's certificate: that certificate only is accepted). On Windows, ddic_export.ps1 reads variables
set with setx. Standard library only.

Per table the export writes <TABLE>.acds (definition, if the system offers it), <TABLE>.fields.csv (DD03L, active
version: every field incl. includes and appends) and <TABLE>.indexes.csv (DD17S); manifest.json lists what was found.
Either the definition or the field list is enough for the comparison; the field list is preferred (it has the fields
of includes and appends - e.g. customer fields on a standard table).
"""
from __future__ import annotations

import argparse
import base64
import csv
import getpass
import hashlib
import http.client
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

NAME_RE = re.compile(r"^[A-Z][A-Z0-9_/]{0,29}$")

FIELD_SQL = ("SELECT FIELDNAME, POSITION, KEYFLAG, ROLLNAME, DATATYPE, LENG, DECIMALS, PRECFIELD "
             "FROM DD03L WHERE TABNAME = '{t}' AND AS4LOCAL = 'A' ORDER BY POSITION")
INDEX_SQL = ("SELECT INDEXNAME, POSITION, FIELDNAME FROM DD17S "
             "WHERE SQLTAB = '{t}' AND AS4LOCAL = 'A' ORDER BY INDEXNAME, POSITION")


# ---------------------------------------------------------------- table lists

def load_table_list(path: str | Path) -> list[str]:
    """One table per line; '#' starts a comment; names are validated (they are put into SQL text)."""
    names: list[str] = []
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip().upper()
        if not line:
            continue
        if not NAME_RE.match(line):
            raise ValueError(f"{path}: not a table name: {raw!r}")
        if line not in names:
            names.append(line)
    return names


# ---------------------------------------------------------------- ADT client

def env(*names: str) -> str:
    for n in names:
        if os.environ.get(n):
            return os.environ[n]
    return ""


class PinnedHandler(urllib.request.HTTPSHandler):
    """Accepts exactly the certificate with the pinned SHA-256 fingerprint (self-signed test systems)."""

    def __init__(self, pin: str, ctx: ssl.SSLContext):
        super().__init__(context=ctx)
        self.pin = pin

    def https_open(self, req):
        pin = self.pin

        class Conn(http.client.HTTPSConnection):
            def connect(self):
                super().connect()
                seen = hashlib.sha256(self.sock.getpeercert(binary_form=True)).hexdigest()
                if seen != pin:
                    self.sock.close()
                    raise ssl.SSLError(f"certificate fingerprint {seen} is not the pinned one")
        return self.do_open(Conn, req, context=self._context)


class AdtClient:
    def __init__(self, url: str, client: str, user: str, password: str, ca_file: str | None = None,
                 timeout: int = 60, pin: str = ""):
        self.base = url.rstrip("/")
        self.client = client
        self.timeout = timeout
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        self.auth = f"Basic {token}"
        ctx = ssl.create_default_context(cafile=ca_file) if ca_file else ssl.create_default_context()
        handler: urllib.request.HTTPSHandler = urllib.request.HTTPSHandler(context=ctx)
        pin = pin.replace(":", "").lower()
        if pin:
            ctx.check_hostname, ctx.verify_mode = False, ssl.CERT_NONE
            handler = PinnedHandler(pin, ctx)
        if url.lower().startswith("http://"):
            print("WARNING: plain HTTP sends the logon unencrypted; use the HTTPS port", file=sys.stderr)
        cookies = urllib.request.HTTPCookieProcessor()
        self.opener = urllib.request.build_opener(cookies, handler)
        self.csrf: str | None = None

    def _url(self, path: str, **params: str) -> str:
        params = {"sap-client": self.client, **params}
        return f"{self.base}{path}?{urllib.parse.urlencode(params)}"

    def _send(self, req: urllib.request.Request) -> tuple[int, str]:
        req.add_header("Authorization", self.auth)
        req.add_header("sap-client", self.client)
        try:
            with self.opener.open(req, timeout=self.timeout) as resp:
                if resp.headers.get("x-csrf-token") and resp.headers.get("x-csrf-token") != "Required":
                    self.csrf = resp.headers.get("x-csrf-token")
                return resp.status, resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as err:
            return err.code, err.read().decode("utf-8", errors="replace")

    def table_source(self, table: str) -> tuple[int, str]:
        req = urllib.request.Request(self._url(f"/sap/bc/adt/ddic/tables/{table.lower()}/source/main"),
                                     headers={"Accept": "text/plain", "x-csrf-token": "fetch"})
        return self._send(req)

    def sql(self, statement: str, rows: int = 2000) -> tuple[int, str]:
        if self.csrf is None:
            self._send(urllib.request.Request(self._url("/sap/bc/adt/discovery"),
                                              headers={"x-csrf-token": "fetch"}))
        req = urllib.request.Request(self._url("/sap/bc/adt/datapreview/freestyle", rowNumber=str(rows)),
                                     data=statement.encode("utf-8"), method="POST",
                                     headers={"Content-Type": "text/plain", "Accept": "application/xml, */*",
                                              "x-csrf-token": self.csrf or "fetch"})
        return self._send(req)


def parse_preview(xml_text: str) -> list[dict[str, str]]:
    """Rows of an ADT data preview answer. The answer is column-oriented: each column element holds a metadata element
    (attribute 'name') and a dataSet element with one data element per row. Namespaces are ignored on purpose."""
    root = ET.fromstring(xml_text)
    cols: list[tuple[str, list[str]]] = []
    for col in root.iter():
        if _local(col.tag) != "columns":
            continue
        name, values = None, []
        for child in col:
            tag = _local(child.tag)
            if tag == "metadata":
                name = next((v for k, v in child.attrib.items() if _local(k) == "name"), None)
            elif tag == "dataSet":
                values = [(d.text or "") for d in child if _local(d.tag) == "data"]
        if name:
            cols.append((name.upper(), values))
    if not cols:
        return []
    count = max(len(v) for _, v in cols)
    return [{n: (v[i] if i < len(v) else "") for n, v in cols} for i in range(count)]


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1].rsplit(":", 1)[-1]


def export(client: AdtClient, tables: list[str], out: Path, log=print) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    manifest: dict = {"tables": {}}
    for t in tables:
        entry: dict = {}
        status, body = client.table_source(t)
        if status == 200 and body.strip():
            (out / f"{t}.acds").write_text(body, encoding="utf-8")
            entry["source"] = "ok"
        else:
            entry["source"] = f"http {status}"
        for kind, sql, header in (("fields", FIELD_SQL, ["FIELDNAME", "POSITION", "KEYFLAG", "ROLLNAME", "DATATYPE",
                                                          "LENG", "DECIMALS", "PRECFIELD"]),
                                  ("indexes", INDEX_SQL, ["INDEXNAME", "POSITION", "FIELDNAME"])):
            status, body = client.sql(sql.format(t=t))
            if status != 200:
                entry[kind] = f"http {status}"
                continue
            try:
                rows = parse_preview(body)
            except ET.ParseError:
                entry[kind] = "answer not readable"
                continue
            with (out / f"{t}.{kind}.csv").open("w", newline="", encoding="utf-8") as fh:
                w = csv.DictWriter(fh, fieldnames=header, extrasaction="ignore")
                w.writeheader()
                w.writerows(rows)
            entry[kind] = len(rows)
        fields = entry.get("fields")
        entry["found"] = entry["source"] == "ok" or (isinstance(fields, int) and fields > 0)
        manifest["tables"][t] = entry
        log(f"{t:<24} definition {entry['source']:<10} fields {entry.get('fields')!s:<8} "
            f"indexes {entry.get('indexes')}")
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


# ---------------------------------------------------------------- reading exports

DDL_FIELD = re.compile(r"^\s*(key\s+)?([a-z0-9_/]+)\s*:\s*([a-z0-9_/]+)", re.I)
DDL_INCLUDE = re.compile(r"^\s*include\s+([a-z0-9_/]+)", re.I)


def parse_definition(text: str) -> tuple[set[str], set[str], list[str]]:
    """Fields, key fields and includes of a table definition (as SE11 / ADT show it in source form)."""
    fields, keys, includes = set(), set(), []
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith(("@", "//", "define ", "}", "with ", "where ", "and ")):
            continue
        m = DDL_INCLUDE.match(s)
        if m:
            includes.append(m.group(1).upper())
            continue
        m = DDL_FIELD.match(s)
        if m:
            name = m.group(2).upper()
            fields.add(name)
            if m.group(1):
                keys.add(name)
    return fields, keys, includes


def load_exports(folder: str | Path) -> dict[str, dict]:
    """Per table: fields (set), complete (True when the field list has includes / appends resolved), includes."""
    folder = Path(folder)
    known: dict[str, dict] = {}
    for p in sorted(folder.glob("*.fields.csv")):
        t = p.name[: -len(".fields.csv")].upper()
        with p.open(encoding="utf-8") as fh:
            names = {r["FIELDNAME"].upper() for r in csv.DictReader(fh) if r.get("FIELDNAME")}
        names = {n for n in names if not n.startswith(".")}
        if names:
            known[t] = {"fields": names, "complete": True, "includes": []}
    for p in sorted(folder.glob("*.acds")):
        t = p.stem.upper()
        if t in known:
            continue
        fields, _keys, includes = parse_definition(p.read_text(encoding="utf-8"))
        known[t] = {"fields": fields, "complete": not includes, "includes": includes}
    return known


# ---------------------------------------------------------------- repository references

PLACEHOLDER = "‹"   # the angle quote that marks a value not named yet


def repo_references(repo: str | Path) -> list[dict]:
    """(table, field, evidence, where) of the link registry layers and the process catalogue packages."""
    repo = Path(repo)
    refs: list[dict] = []
    for spec in sorted(repo.glob("*/config/links/**/*.json")):
        data = json.loads(spec.read_text(encoding="utf-8"))
        for obj in data.get("objects", []):
            table = str(obj.get("source", "")).upper()
            if not table or table.startswith(("I_", "C_", "E_")):
                continue
            for f in obj.get("fields", []):
                refs.append({"table": table, "field": f["name"].upper(), "evidence": f.get("evidence", "C"),
                             "where": f"{spec.relative_to(repo)} {obj.get('id')}"})
    for spec in sorted(repo.glob("*/config/catalogue/**/*.json")):
        data = json.loads(spec.read_text(encoding="utf-8"))
        for proc in data.get("processes", []):
            for mon in proc.get("monitors", []):
                for agg in mon.get("aggregates", []):
                    table = str(agg.get("table", "")).upper()
                    if not table or PLACEHOLDER in table:
                        continue
                    for key in ("date_field", "bukrs_field", "status_field", "cond_field"):
                        val = str(agg.get(key) or "")
                        if not val or PLACEHOLDER in val:
                            continue
                        refs.append({"table": table, "field": val.upper(), "evidence": "V" if agg.get("verify")
                                     else "C", "where": f"{spec.relative_to(repo)} {mon.get('check')}/{agg.get('id')}"})
    return refs


def compare(exports: dict[str, dict], refs: list[dict]) -> list[dict]:
    out = []
    for r in refs:
        info = exports.get(r["table"])
        if info is None:
            state = "table not exported"
        elif r["field"] in info["fields"]:
            state = "exists"
        elif info["complete"]:
            state = "MISSING"
        else:
            state = "not in definition (may be in an include: " + ", ".join(info["includes"]) + ")"
        out.append({**r, "state": state})
    return out


def report(rows: list[dict], only_open: bool = True) -> str:
    """Markdown table of the references to exported tables (missing first); references to tables that were not
    exported and fields still written as placeholders are counted below the table, not listed."""
    lines = ["| Table | Field | Evidence in repo | State | Where |", "|---|---|---|---|---|"]
    seen = set()
    skipped = sum(1 for r in rows if r["state"] == "table not exported" or PLACEHOLDER in r["field"])
    for r in sorted(rows, key=lambda x: (x["state"] != "MISSING", x["table"], x["field"])):
        if r["state"] == "table not exported" or PLACEHOLDER in r["field"]:
            continue
        if only_open and r["evidence"] == "C" and r["state"] == "exists":
            continue
        key = (r["table"], r["field"], r["where"])
        if key in seen:
            continue
        seen.add(key)
        lines.append(f"| {r['table']} | {r['field']} | {r['evidence']} | {r['state']} | {r['where']} |")
    lines.append("")
    lines.append(f"{skipped} references not compared (table not exported, or field still a placeholder).")
    return "\n".join(lines)


# ---------------------------------------------------------------- command line

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    ex = sub.add_parser("export", help="fetch definitions, fields and indexes from a system")
    ex.add_argument("--url", help="https://<host>:<port> (else SAP_URL / ZCA_TT_A4H_URL)")
    ex.add_argument("--client", help="client (else SAP_CLIENT / ZCA_TT_A4H_CLIENT)")
    ex.add_argument("--user", help="user (else SAP_USER / ZCA_TT_A4H_USER)")
    ex.add_argument("--tables", action="append", required=True, help="table list file (repeatable)")
    ex.add_argument("--out", required=True)
    ex.add_argument("--ca-file", help="CA bundle of the system's certificate")
    cp = sub.add_parser("compare", help="check the repository's field references against exports")
    cp.add_argument("--exports", required=True)
    cp.add_argument("--repo", default=".")
    cp.add_argument("--all", action="store_true", help="also list confirmed fields that exist")
    args = ap.parse_args(argv)

    if args.cmd == "export":
        tables: list[str] = []
        for f in args.tables:
            tables += [t for t in load_table_list(f) if t not in tables]
        url = args.url or env("SAP_URL", "ZCA_TT_A4H_URL")
        sap_client = args.client or env("SAP_CLIENT", "ZCA_TT_A4H_CLIENT")
        user = args.user or env("SAP_USER", "ZCA_TT_A4H_USER")
        if not (url and sap_client and user):
            ap.error("logon incomplete: give --url, --client and --user or set the environment variables")
        password = env("SAP_PASSWORD", "ZCA_TT_A4H_PASSWORD") or getpass.getpass(f"Password of {user}: ")
        client = AdtClient(url, sap_client, user, password, args.ca_file,
                           pin=env("SAP_TLS_PIN", "ZCA_TT_A4H_TLS_PIN"))
        manifest = export(client, tables, Path(args.out))
        missing = [t for t, e in manifest["tables"].items() if not e.get("found")]
        print(f"{len(tables) - len(missing)} of {len(tables)} tables read; not found: {', '.join(missing) or '-'}")
        return 0
    rows = compare(load_exports(args.exports), repo_references(args.repo))
    print(report(rows, only_open=not args.all))
    return 1 if any(r["state"] == "MISSING" for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
