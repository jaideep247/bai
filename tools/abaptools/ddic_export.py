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

`compare` checks two kinds of reference against each export folder (--exports, repeatable): the link registry and
process catalogue specs, and the code - ABAP SQL, TYPE <table>-<field>, structures typed with a table and CDS views
(section "code references", file:line; the scanner and its limits are described at code_references). It exits
non-zero when a referenced field is MISSING from a complete export, unless an --open list (CSV TABLE, FIELD, VERIFY,
NOTE) names it with its VERIFY item.

    python ddic_export.py compare --exports ops-suite/ddic/a4h --open ops-suite/ddic/open_fields.csv --repo .
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
        elif PLACEHOLDER in r["field"]:
            state = "placeholder (not compared)"
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


# ---------------------------------------------------------------- code references (ABAP SQL, CDS)
#
# The repository's code is read as text: ABAP SQL (FROM / JOIN with aliases, alias~field, unqualified fields of a
# query with exactly one data source and no join), TYPE <table>-<field>, components of variables typed with a table
# (TYPE <table>; the row of TABLE OF <table> taken by LOOP AT / READ TABLE ... INTO DATA( ) / ASSIGNING
# FIELD-SYMBOL( )), and CDS view entities (select from / join / association with aliases, Alias.field, unqualified
# fields of a branch with exactly one data source and no join). A field is only judged when its table is certain: an
# alias or a variable that may stand for more than one table is reported "unresolved", never MISSING. What the scanner
# does not see (dynamic SQL, VALUE #( ) rows, variables typed through a local type, fields read through a CDS entity)
# is not reported at all - an empty list is no proof.

CODE_SKIP_DIRS = {"legacy", ".git", "node_modules", "__pycache__", "lint_stubs"}
CUSTOMER_FIELD = re.compile(r"^(ZZ|YY)")

SQL_TOKEN = re.compile(r"""
    (?P<id>[@+]?(?:<[a-z0-9_]+>|[a-z_/][a-z0-9_/]*)(?:(?:~|-|=>|->)(?:[a-z_/][a-z0-9_/]*))*)
  | (?P<num>\d+)
  | (?P<op><>|<=|>=|=|<|>)
  | (?P<other>\S)
""", re.X)

SQL_KEYWORDS = set("""
select single distinct from fields where and or not is null initial in between like escape exists as case when then
else end group by order having into appending corresponding of table up to rows offset ascending descending primary
key inner left right outer cross join on union all intersect except for entries client specified using bypassing
buffer connection data final packing size extended result new cast count sum min max avg abs coalesce lines
hierarchy hints
""".split())
SQL_FUNCTIONS = {"cast", "count", "sum", "min", "max", "avg", "abs", "coalesce"}
SQL_COMPARE = {"=", "<>", "<", ">", "<=", ">=", "eq", "ne", "lt", "gt", "le", "ge", "in", "between", "like", "is",
               "not"}
SQL_CLAUSE_END = {"group", "order", "having", "into", "appending", "up", "offset", "union", "intersect", "except",
                  "bypassing", "connection", "where", "fields", "for"}

CDS_KEYWORDS = set("""
key as case when then else end cast and or not is null initial between like escape distinct preserving type abap
select from where group by having union all on inner left right outer cross join to one many exact association
composition parent redirected virtual define view entity root with parameters exists
""".split())


def _plain(tok: str) -> bool:
    return bool(re.fullmatch(r"[a-z_][a-z0-9_]*", tok))


def _blank(out: list[str], start: int, end: int) -> None:
    for k in range(start, min(end, len(out))):
        if out[k] != "\n":
            out[k] = " "


def clean_abap(text: str) -> str:
    """ABAP source in lower case with comments and the contents of literals and string templates blanked (positions
    and line breaks kept)."""
    out = list(text)
    i, n = 0, len(text)
    line_start = True
    while i < n:
        c = text[i]
        if c == "\n":
            line_start = True
            i += 1
            continue
        if (line_start and c == "*") or c == '"':
            j = text.find("\n", i)
            j = n if j < 0 else j
            _blank(out, i, j)
            i = j
            continue
        line_start = False
        if c in "'`|":
            j = i + 1
            while j < n and text[j] != "\n":
                if c == "|" and text[j] == "\\":
                    j += 2
                    continue
                if text[j] == c:
                    if c != "|" and j + 1 < n and text[j + 1] == c:
                        j += 2
                        continue
                    break
                j += 1
            _blank(out, i, j + 1)
            i = j + 1
            continue
        i += 1
    return "".join(out).lower()


def clean_cds(text: str) -> str:
    """CDS source in lower case with // and /* */ comments and the contents of literals blanked."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
        elif text[i] == "'":
            j = i + 1
            while j < n and text[j] != "\n":
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            j = min(j + 1, n)
        else:
            i += 1
            continue
        _blank(out, i, j)
        i = j
    return "".join(out).lower()


class _Lines:
    def __init__(self, text: str):
        self.starts = [0] + [m.end() for m in re.finditer("\n", text)]

    def line(self, pos: int) -> int:
        lo, hi = 0, len(self.starts)
        while lo + 1 < hi:
            mid = (lo + hi) // 2
            if self.starts[mid] <= pos:
                lo = mid
            else:
                hi = mid
        return lo + 1


def abap_statements(clean: str) -> list[tuple[int, str]]:
    """(start offset, text) of each statement of a cleaned source: a period followed by white space ends it."""
    out, start = [], 0
    for m in list(re.finditer(r"\.(?=\s|$)", clean)) + [None]:
        stop = m.start() if m else len(clean)
        body = clean[start:stop]
        if body.strip():
            out.append((start + len(body) - len(body.lstrip()), body.strip()))
        if m:
            start = m.end()
    return out


def _ref(table: str, field: str, pos: int, lines: _Lines, path: str, kind: str,
         candidates: set[str] | None = None) -> dict:
    return {"table": table.upper(), "field": field.upper(), "where": f"{path}:{lines.line(pos)}", "kind": kind,
            "candidates": sorted(c.upper() for c in candidates) if candidates else [], "pos": pos, "item": False}


def _resolve(names: set[str], field: str, pos: int, lines: _Lines, path: str, kind: str,
             tables: set[str]) -> list[dict]:
    """A reference through an alias / a variable: certain when it stands for one table, else unresolved."""
    exported = sorted(n for n in names if n.upper() in tables)
    if not exported:
        return []
    if len(names) == 1:
        return [_ref(exported[0], field, pos, lines, path, kind)]
    return [_ref(exported[0], field, pos, lines, path, kind, names)]


def _depths(words: list[str]) -> list[int]:
    depth, d = [], 0
    for t in words:
        if t == "(":
            depth.append(d)
            d += 1
        elif t == ")":
            d -= 1
            depth.append(d)
        else:
            depth.append(d)
    return depth


def _host_expressions(words: list[str]) -> set[int]:
    """Token indexes of host expressions @( ... ) - never fields of a data source."""
    host: set[int] = set()
    for i, t in enumerate(words):
        if t == "@" and i + 1 < len(words) and words[i + 1] == "(":
            j, lvl = i + 1, 0
            while j < len(words):
                lvl += {"(": 1, ")": -1}.get(words[j], 0)
                if lvl == 0:
                    break
                j += 1
            host.update(range(i, j + 1))
    return host


def scan_sql(stmt: str, base: int, lines: _Lines, path: str, tables: set[str]) -> list[dict]:
    """Field references of one cleaned ABAP SQL statement (SELECT, WITH, OPEN CURSOR) to the given tables."""
    toks = [(m.group(0), base + m.start()) for m in SQL_TOKEN.finditer(stmt)]
    words = [t for t, _ in toks]
    depth = _depths(words)
    host = _host_expressions(words)
    # queries: a SELECT up to the end of its parenthesis level or a set operator on its level
    queries = []
    for i, t in enumerate(words):
        if t != "select" or i in host:
            continue
        lvl, j = depth[i], i + 1
        while j < len(words) and depth[j] >= lvl and not (depth[j] == lvl and words[j] in ("union", "intersect",
                                                                                           "except")):
            j += 1
        queries.append({"start": i, "end": j, "depth": lvl})
    owner: dict[int, int] = {}
    for n, q in sorted(enumerate(queries), key=lambda x: x[1]["end"] - x[1]["start"], reverse=True):
        for k in range(q["start"], q["end"]):
            owner[k] = n
    aliases: dict[str, set[str]] = {}
    for n, q in enumerate(queries):
        own = [k for k in range(q["start"], q["end"]) if owner.get(k) == n and k not in host]
        q["own"], q["sources"], q["join"] = own, [], False
        for at, k in enumerate(own):
            if words[k] == "join":
                q["join"] = True
            if words[k] not in ("from", "join"):
                continue
            nxt = [m for m in own[at + 1:] if words[m] != "("]
            if not nxt or not _plain(words[nxt[0]].lstrip("+")):
                continue
            name = words[nxt[0]]
            alias = words[nxt[2]] if len(nxt) > 2 and words[nxt[1]] == "as" and _plain(words[nxt[2]]) else name
            q["sources"].append(name)
            aliases.setdefault(alias, set()).add(name)
    # whole items of a field list without a result name (a field renamed there needs AS to keep its name)
    items: set[int] = set()
    for n, q in enumerate(queries):
        lst = [words[k] for k in q["own"]]
        for i in range(1, len(lst)):
            k = q["own"][i]
            if depth[k] == q["depth"] and lst[i] in ("from", "into", "appending"):
                break
            if depth[k] == q["depth"] and lst[i - 1] in ("select", "single", "distinct", ",") \
                    and (i + 1 >= len(lst) or lst[i + 1] in (",", "from", "into", "appending")):
                items.add(k)
    refs: list[dict] = []
    for k, (w, pos) in enumerate(toks):
        if "~" not in w or k in host:
            continue
        a, f = w.lstrip("@").split("~", 1)
        f = re.split(r"-|=>|->", f)[0]
        if a in aliases and _plain(f):
            for r in _resolve(aliases[a], f, pos + w.index("~") + 1, lines, path, "sql", tables):
                refs.append({**r, "item": k in items})
    for q in queries:
        if len(q["sources"]) != 1 or q["join"] or q["sources"][0].upper() not in tables:
            continue
        table, own = q["sources"][0], q["own"]
        lst = [words[k] for k in own]

        def at_end(i: int, stop: set[str]) -> bool:
            return lst[i] in stop and depth[own[i]] == q["depth"]

        names = {lst[i + 1] for i in range(len(lst) - 1) if lst[i] == "as"}   # result names (ORDER BY etc.)

        def take(i: int, result_names: bool = False) -> None:
            w = lst[i]
            if not _plain(w) or w in SQL_KEYWORDS or (i > 0 and lst[i - 1] in ("as", "@")) \
                    or (i + 1 < len(lst) and lst[i + 1] == "(") or (result_names and w in names):
                return
            if i > 1 and lst[i - 1] == "(" and (not _plain(lst[i - 2]) or lst[i - 2] in SQL_KEYWORDS - SQL_FUNCTIONS):
                return                         # ( lv_fields ): a dynamic token
            refs.append({**_ref(table, w, toks[own[i]][1], lines, path, "sql"), "item": own[i] in items})

        i = 1                                  # field list: SELECT ... FROM / INTO
        while i < len(lst) and not at_end(i, {"from", "into", "appending"}):
            take(i)
            i += 1
        fields_at = [i for i, w in enumerate(lst) if w == "fields" and lst[i - 1] != "corresponding"]
        if fields_at:                          # FROM ... FIELDS ... next clause
            i = fields_at[0] + 1
            while i < len(lst) and not at_end(i, SQL_CLAUSE_END):
                take(i)
                i += 1
        for kw in ("where", "having"):         # left-hand side of a comparison
            if kw not in lst:
                continue
            i = lst.index(kw) + 1
            while i < len(lst) and not at_end(i, SQL_CLAUSE_END - {"for"}):
                if i + 1 < len(lst) and lst[i + 1] in SQL_COMPARE and lst[i] not in SQL_COMPARE:
                    take(i, result_names=kw == "having")
                i += 1
        for i in range(len(lst) - 1):          # GROUP BY / ORDER BY lists
            if lst[i] in ("group", "order") and lst[i + 1] == "by":
                j = i + 2
                while j < len(lst) and not at_end(j, SQL_CLAUSE_END):
                    take(j, result_names=True)
                    j += 1
    return refs


_TYPE_TAIL = (r"\s+type\s+(?:(?:standard|sorted|hashed|any)\s+)?(table\s+of\s+|range\s+of\s+|ref\s+to\s+|line\s+of\s+)?"
              r"([a-z_/][a-z0-9_/]*)(?![a-z0-9_/=>-])")
DECL_TYPE = re.compile(r"^(<[a-z0-9_]+>|[a-z_][a-z0-9_]*)" + _TYPE_TAIL)
DECL_OTHER = re.compile(r"^(<[a-z0-9_]+>|[a-z_][a-z0-9_]*)\s+(like|type)\b")
PARAM_TYPE = re.compile(r"(?:value|reference)?\(?\b([a-z_][a-z0-9_]*)\)?" + _TYPE_TAIL)
INLINE = re.compile(r"(?:data|final|field-symbol)\((<[a-z0-9_]+>|[a-z_][a-z0-9_]*)\)")
TYPE_FIELD = re.compile(r"\btype\s+(?:(?:standard|sorted|hashed|any)\s+)?(?:table\s+of\s+|range\s+of\s+|line\s+of\s+)?"
                        r"([a-z_][a-z0-9_]*)-([a-z0-9_]+)\b")
COMPONENT = re.compile(r"(?<![a-z0-9_~>=/-])(?:me->)?(<[a-z0-9_]+>|[a-z_][a-z0-9_]*)-([a-z_][a-z0-9_]*)")
VALUE_TYPED = re.compile(r"\bvalue\s+([a-z_][a-z0-9_/]*)\(")
VALUE_TO_VAR = re.compile(r"^(?P<var><[a-z0-9_]+>|[a-z_][a-z0-9_]*)\s*=\s*value\s+#\s*(?P<open>\()")
VALUE_INTO_VAR = re.compile(r"^(?:insert|append)\s+value\s+#\s*(?P<open>\().*\)\s+(?:into\s+table|to)\s+"
                            r"(?P<var><[a-z0-9_]+>|[a-z_][a-z0-9_]*)$", re.S)
LOOP_ROW = re.compile(r"^(?:loop\s+at|read\s+table)\s+([a-z_][a-z0-9_]*)\s.*?\b(?:into\s+data|assigning\s+field-symbol)"
                      r"\((<[a-z0-9_]+>|[a-z_][a-z0-9_]*)\)", re.S)


def _value_components(stmt: str, open_at: int, level: int) -> list[tuple[str, int]]:
    """(component, offset) of the 'comp =' of a VALUE #( ... ) / VALUE t( ... ) on parenthesis level `level` (1: a
    structure, 2: the rows of a table). A FOR / LET expression on the first level is not followed (nothing returned)."""
    depth, out, i = 0, [], open_at
    while i < len(stmt):
        c = stmt[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                break
        elif depth and (i == 0 or not (stmt[i - 1].isalnum() or stmt[i - 1] in "_<>-~@")):
            m = re.match(r"(<[a-z0-9_]+>|[a-z_][a-z0-9_]*)(\s*=(?![=>]))?", stmt[i:])
            if m:
                if depth == 1 and m.group(1) in ("for", "let", "reduce"):
                    return []
                if depth == level and m.group(2) and _plain(m.group(1)):
                    out.append((m.group(1), i))
                i += len(m.group(1))
                continue
        i += 1
    return out


def _kind(how: str | None) -> str:
    return {"table of": "table", "": "row"}.get(re.sub(r"\s+", " ", (how or "").strip()), "other")


def _split_chain(body: str) -> list[str]:
    parts, lvl, cur = [], 0, []
    for c in body:
        lvl += {"(": 1, ")": -1}.get(c, 0)
        if c == "," and lvl == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
    parts.append("".join(cur).strip())
    return [p for p in parts if p]


def _declarations(stmt: str) -> list[tuple[str, tuple]]:
    """(name, (kind, type)) of a DATA / STATICS / CLASS-DATA / FIELD-SYMBOLS statement; kind row, table or other
    (components of BEGIN OF ... END OF are left out)."""
    m = re.match(r"^(data|statics|class-data|field-symbols)\b\s*(:)?\s*", stmt)
    if not m:
        return []
    body = stmt[m.end():]
    out, nested = [], 0
    for part in (_split_chain(body) if m.group(2) else [body]):
        part = re.sub(r"\s+", " ", part)
        if part.startswith("begin of"):
            nested += 1
        elif part.startswith("end of"):
            nested -= 1
        elif not nested:
            dm = DECL_TYPE.match(part)
            if dm:
                out.append((dm.group(1), (_kind(dm.group(2)), dm.group(3))))
            elif DECL_OTHER.match(part):
                out.append((DECL_OTHER.match(part).group(1), ("other", None)))
    return out


def _method_params(stmt: str) -> list[tuple[str, list[tuple[str, tuple]]]]:
    """(method, [(parameter, (kind, type))]) of a METHODS / CLASS-METHODS statement."""
    m = re.match(r"^(class-methods|methods)\b\s*(:)?\s*", stmt)
    if not m:
        return []
    out = []
    for part in (_split_chain(stmt[m.end():]) if m.group(2) else [stmt[m.end():]]):
        part = re.sub(r"\s+", " ", part)
        name = part.split(" ", 1)[0]
        out.append((name, [(pm.group(1), (_kind(pm.group(2)), pm.group(3))) for pm in PARAM_TYPE.finditer(part)]))
    return out


def scan_abap(text: str, path: str, tables: set[str]) -> list[dict]:
    """Field references of one ABAP source to the given (exported) tables."""
    tables = {t.upper() for t in tables}
    clean = clean_abap(text)
    lines = _Lines(text)
    refs: list[dict] = []
    for m in TYPE_FIELD.finditer(clean):
        if m.group(1).upper() in tables:
            refs.append(_ref(m.group(1), m.group(2), m.start(2), lines, path, "type"))
    stmts = abap_statements(clean)
    attrs: dict[str | None, dict[str, set]] = {}
    params: dict[tuple, dict[str, set]] = {}
    cls, section = None, None
    for _pos, s in stmts:                      # class attributes and method parameters
        cm = re.match(r"^class\s+([a-z0-9_/]+)\s+(definition|implementation)\b", s)
        if cm:
            cls, section = cm.group(1), cm.group(2)
        elif s.startswith("endclass"):
            cls, section = None, None
        elif section == "definition":
            for name, typ in _declarations(s):
                attrs.setdefault(cls, {}).setdefault(name, set()).add(typ)
            for meth, plist in _method_params(s):
                for name, typ in plist:
                    params.setdefault((cls, meth), {}).setdefault(name, set()).add(typ)
    cls, scope, meth = None, None, None
    for pos, s in stmts:                       # SQL statements and method bodies
        cm = re.match(r"^class\s+([a-z0-9_/]+)\s+(definition|implementation)\b", s)
        if cm:
            cls = cm.group(1)
            continue
        mm = re.match(r"^(method|form|function)\s+([a-z0-9_~/]+)", s)
        if mm:
            scope, meth = {}, mm.group(2)
            continue
        if re.match(r"^(endmethod|endform|endfunction)\b", s):
            scope, meth = None, None
            continue
        first = s.split(None, 1)[0]
        if first in ("select", "with", "open") and re.search(r"\bselect\b", s):
            refs += scan_sql(s, pos, lines, path, tables)
        if scope is None:
            continue
        mine = params.get((cls, meth), {})

        def types_of(name: str) -> set:
            return scope.get(name) or mine.get(name) or attrs.get(cls, {}).get(name) or set()

        for name, typ in _declarations(s):
            scope.setdefault(name, set()).add(typ)
        done = set()
        lm = LOOP_ROW.match(s)
        if lm:
            src = types_of(lm.group(1))
            row = {("row", t) for _k, t in src} if src and all(k == "table" for k, _t in src) else {("other", None)}
            scope.setdefault(lm.group(2), set()).update(row)
            done.add(lm.group(2))
        for im in INLINE.finditer(s):
            if im.group(1) not in done:
                scope.setdefault(im.group(1), set()).add(("other", None))
        for vm in VALUE_TYPED.finditer(s):     # VALUE <table>( comp = ... )
            if vm.group(1).upper() in tables:
                for comp, at in _value_components(s, vm.end() - 1, 1):
                    refs.append(_ref(vm.group(1), comp, pos + at, lines, path, "component"))
        vm = VALUE_TO_VAR.match(s) or VALUE_INTO_VAR.match(s)
        if vm:                                 # var = VALUE #( ... ) / INSERT VALUE #( ... ) INTO TABLE var
            typs = types_of(vm.group("var"))
            kinds = {k for k, _t in typs}
            rows = {t for _k, t in typs if t and t.upper() in tables}
            level = (2 if vm.re is VALUE_TO_VAR else 1) if kinds == {"table"} else \
                1 if kinds == {"row"} and vm.re is VALUE_TO_VAR else 0
            if rows and level:
                for comp, at in _value_components(s, vm.start("open"), level):
                    if len(typs) == 1:
                        refs.append(_ref(next(iter(rows)), comp, pos + at, lines, path, "component"))
                    else:
                        refs += _resolve({t or "?" for _k, t in typs}, comp, pos + at, lines, path, "component",
                                         tables)
        if re.match(r"^(data|statics|field-symbols|types|constants)\b", s):
            continue
        for cm2 in COMPONENT.finditer(s):
            name, field = cm2.group(1), cm2.group(2)
            typs = types_of(name)
            rows = {t for k, t in typs if k == "row" and t and t.upper() in tables}
            if not rows:
                continue
            if len(typs) == 1:
                refs.append(_ref(next(iter(rows)), field, pos + cm2.start(2), lines, path, "component"))
            else:
                refs += _resolve({t or "?" for _k, t in typs}, field, pos + cm2.start(2), lines, path, "component",
                                 tables)
    return refs


CDS_SOURCE = re.compile(r"\b(select\s+(?:distinct\s+)?from|join)\s+([a-z0-9_/]+)(?:\s+as\s+([a-z0-9_]+))?")
CDS_ASSOC = re.compile(r"\b(?:association|composition)\b[^{}]*?\bto\s+(?:parent\s+)?([a-z0-9_/]+)\s+as\s+([a-z0-9_]+)")
CDS_QUALIFIED = re.compile(r"(?<![\w.$#@])([a-z_][a-z0-9_]*)\s*\.\s*([a-z_][a-z0-9_]*)")
CDS_WORD = re.compile(r"[a-z_][a-z0-9_]*")


def _strip_annotations(text: str) -> str:
    """Annotations (@Name: value, value in [ ] / { } included) blanked."""
    out = list(text)
    for m in re.finditer(r"@[a-z_<][\w.<]*", text):
        j = m.end()
        while j < len(text) and text[j] in " \t\r\n":
            j += 1
        end = m.end()
        if j < len(text) and text[j] == ":":
            j += 1
            while j < len(text) and text[j] in " \t":
                j += 1
            if j < len(text) and text[j] in "[{":
                lvl, k = 0, j
                while k < len(text):
                    lvl += {"[": 1, "{": 1, "]": -1, "}": -1}.get(text[k], 0)
                    if lvl == 0:
                        break
                    k += 1
                end = k + 1
            else:
                vm = re.match(r"[^,\n]*", text[j:])
                end = j + len(vm.group(0))
        _blank(out, m.start(), end)
    return "".join(out)


def _braces(text: str, start: int) -> int:
    lvl, k = 0, start
    while k < len(text):
        lvl += {"{": 1, "}": -1}.get(text[k], 0)
        if lvl == 0:
            return k
        k += 1
    return len(text)


def scan_cds(text: str, path: str, tables: set[str]) -> list[dict]:
    """Field references of one CDS view source to the given (exported) tables."""
    tables = {t.upper() for t in tables}
    clean = clean_cds(text)
    lines = _Lines(text)
    refs: list[dict] = []
    if not re.search(r"\bdefine\s+(?:root\s+)?view\b", clean) or re.search(r"\bas\s+projection\s+on\b", clean):
        return refs
    cuts = [0] + [m.start() for m in re.finditer(r"\b(?:union|except|intersect)\b", clean)] + [len(clean)]
    for lo, hi in zip(cuts, cuts[1:]):
        branch = clean[lo:hi]
        aliases: dict[str, set[str]] = {}
        sources, join = [], False
        for m in CDS_SOURCE.finditer(branch):
            name, alias = m.group(2), m.group(3) or m.group(2)
            aliases.setdefault(alias, set()).add(name)
            sources.append((name, m))
            join |= m.group(1) == "join"
        for m in CDS_ASSOC.finditer(branch):
            aliases.setdefault(m.group(2), set()).add(m.group(1))
        for m in CDS_QUALIFIED.finditer(branch):
            if m.group(1) in aliases and not m.group(2).startswith("_"):
                refs += _resolve(aliases[m.group(1)], m.group(2), lo + m.start(2), lines, path, "cds", tables)
        if len(sources) != 1 or join or sources[0][0].upper() not in tables:
            continue
        table, sm = sources[0]
        start = branch.find("{", sm.end())
        if start < 0:
            continue
        end = _braces(branch, start)
        segments = [(start + 1, branch[start + 1:end])]
        rest = re.search(r"\b(?:where|group\s+by|having)\b", branch[end + 1:])
        if rest:
            segments.append((end + 1 + rest.end(), branch[end + 1 + rest.end():]))
        for off, seg in segments:
            seg = _strip_annotations(seg)
            for m in CDS_WORD.finditer(seg):
                w = m.group(0)
                before, after = seg[:m.start()].rstrip(), seg[m.end():].lstrip()
                if w in CDS_KEYWORDS or w.startswith("_") or before.endswith((".", "$", "#", "@")) \
                        or after.startswith((".", "(", ":", "=>")) or re.search(r"\bas$", before) \
                        or seg[max(0, m.start() - 1):m.start()].isdigit():
                    continue
                refs.append(_ref(table, w, lo + off + m.start(), lines, path, "cds"))
    return refs


def code_references(repo: str | Path, tables: set[str]) -> list[dict]:
    """Field references of the repository's ABAP (.abap) and CDS (.asddls) sources to the given tables (the legacy
    sources and lint stubs are not product code and are left out)."""
    repo = Path(repo)
    refs: list[dict] = []
    for p in sorted(repo.rglob("*")):
        if p.suffix not in (".abap", ".asddls") or not p.is_file():
            continue
        rel = p.relative_to(repo)
        if set(rel.parts[:-1]) & CODE_SKIP_DIRS:
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        scan = scan_abap if p.suffix == ".abap" else scan_cds
        refs += scan(text, rel.as_posix(), tables)
    return refs


def compare_code(exports: dict[str, dict], refs: list[dict]) -> list[dict]:
    out = []
    for r in refs:
        info = exports.get(r["table"])
        if info is None:
            continue
        if r["candidates"]:
            state = "unresolved (" + " | ".join(r["candidates"]) + ")"
        elif r["field"] in info["fields"]:
            state = "exists"
        elif CUSTOMER_FIELD.match(r["field"]):
            state = "customer field (not in this export)"
        elif info["complete"]:
            state = "MISSING"
        else:
            state = "not in definition (may be in an include: " + ", ".join(info["includes"]) + ")"
        out.append({**r, "state": state})
    return out


def load_open_fields(path: str | Path) -> dict[tuple[str, str], str]:
    """Fields that an export shows missing but that stay read until a decision (TABLE, FIELD, VERIFY, NOTE): the
    owner of the evidence lists them with their VERIFY item, so that the comparison names them instead of failing."""
    with Path(path).open(encoding="utf-8") as fh:
        return {(r["TABLE"].strip().upper(), r["FIELD"].strip().upper()): r["VERIFY"].strip()
                for r in csv.DictReader(fh) if r.get("TABLE") and r.get("FIELD") and r.get("VERIFY", "").strip()}


def apply_open(rows: list[dict], open_fields: dict[tuple[str, str], str]) -> list[dict]:
    """MISSING rows of a listed field become 'missing, open <VERIFY>' (reported, not a failure)."""
    out = []
    for r in rows:
        item = open_fields.get((r["table"], r["field"]))
        out.append({**r, "state": f"missing, open {item}"} if r["state"] == "MISSING" and item else r)
    return out


def report_code(rows: list[dict], show_all: bool = False) -> str:
    """Markdown table of the code references (MISSING first, then unresolved); references to fields that exist and
    customer fields are counted, and listed with show_all."""
    lines = ["| Table | Field | State | Where | Kind |", "|---|---|---|---|---|"]
    seen = set()
    for r in sorted(rows, key=lambda x: (x["state"] != "MISSING", not x["state"].startswith("missing, open"),
                                         not x["state"].startswith("unresolved"),
                                         x["table"], x["field"], x["where"])):
        if not show_all and (r["state"] == "exists" or r["state"].startswith("customer field")):
            continue
        key = (r["table"], r["field"], r["where"])
        if key not in seen:
            seen.add(key)
            lines.append(f"| {r['table']} | {r['field']} | {r['state']} | {r['where']} | {r['kind']} |")
    counts: dict[str, int] = {}
    for r in rows:
        k = re.split(r" \(| V\d| [A-Z]+\d", r["state"])[0]
        counts[k] = counts.get(k, 0) + 1
    lines.append("")
    lines.append(f"{len(rows)} code references to exported tables: "
                 + (", ".join(f"{v} {k}" for k, v in sorted(counts.items())) or "none") + ".")
    return "\n".join(lines)


def export_folders(parent: str | Path) -> list[Path]:
    """The export folders under a parent folder (those with a field list or a definition)."""
    return [p for p in sorted(Path(parent).iterdir())
            if p.is_dir() and (any(p.glob("*.fields.csv")) or any(p.glob("*.acds")))]


def check_folders(repo: str | Path, folders: list[str | Path], open_files: tuple = ()) -> tuple[list[str], dict]:
    """(failures, counts) of the link registry, process catalogue and code references against every export folder:
    a failure is a MISSING field that no open-fields list names (for a portable check)."""
    open_fields: dict[tuple[str, str], str] = {}
    for f in open_files:
        if Path(f).exists():
            open_fields.update(load_open_fields(f))
    refs = repo_references(repo)
    failures, counts = [], {}
    for folder in folders:
        exports = load_exports(folder)
        rows = apply_open(compare(exports, refs), open_fields)
        rows += apply_open(compare_code(exports, code_references(repo, set(exports))), open_fields)
        for r in rows:
            state = r["state"].split(" (")[0]
            state = "missing, open" if state.startswith("missing, open") else state
            if state not in ("table not exported", "placeholder"):
                counts[state] = counts.get(state, 0) + 1
            if r["state"] == "MISSING":
                failures.append(f"{Path(folder).name}: {r['table']}-{r['field']} {r['where']}")
    return sorted(set(failures)), counts


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
    cp.add_argument("--exports", required=True, action="append", help="export folder (repeatable)")
    cp.add_argument("--repo", default=".")
    cp.add_argument("--all", action="store_true", help="also list confirmed fields that exist")
    cp.add_argument("--open", action="append", default=[],
                    help="CSV of fields that stay read until a VERIFY item is decided (TABLE, FIELD, VERIFY, NOTE)")
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
    failed = False
    refs = repo_references(args.repo)
    open_fields: dict[tuple[str, str], str] = {}
    for f in args.open:
        open_fields.update(load_open_fields(f))
    for folder in args.exports:
        exports = load_exports(folder)
        rows = apply_open(compare(exports, refs), open_fields)
        code = apply_open(compare_code(exports, code_references(args.repo, set(exports))), open_fields)
        print(f"# {folder}\n\n## Link registry and process catalogue\n")
        print(report(rows, only_open=not args.all))
        print("\n## Code references\n")
        print(report_code(code, show_all=args.all))
        print()
        failed |= any(r["state"] == "MISSING" for r in rows + code)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
