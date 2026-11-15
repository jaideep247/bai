# Table definitions of the payment engine landscape

Evidence for the field references of the product layers and of this overlay: what SE11 shows in the landscape.
No business data - dictionary metadata only.

| Folder | Source | Tables |
|---|---|---|
| `landscape_2026-11-15` | definitions pasted from the landscape (annotations left out of `DFKKOP` / `DFKKOPK`) | `DFKKKO`, `DFKKOP`, `DFKKOPK` |
| `a4h` | reference system A4H (S/4HANA 2025 with FI-CA, client 100) - `ddic_export.py export` of `ops-framework/config/ddic/standard_tables.txt`: definition, DD03L fields (includes and appends resolved), DD17S indexes, `manifest.json`. The product targets S/4HANA 2023: a field seen here is used and noted as *seen on the reference system*; a field missing here is treated as wrong. Customer fields (ZZ*) are not on this system | 46 SAP standard tables (`manifest.json`) |

`open_fields.csv` lists the fields the suite's code still reads although an export shows them missing (TABLE, FIELD,
VERIFY, NOTE) - each waits for a decision under its VERIFY item (`docs/VERIFY_Suite.md` §4). The comparison names
them instead of failing.

Add a folder per export (`tools/abaptools/ddic_export.py export`, table lists
`ops-framework/config/ddic/standard_tables.txt` and `config/ddic/customer_tables.txt`), then run
`python3 tools/abaptools/ddic_export.py compare --exports ops-suite/ddic/<folder> --open ops-suite/ddic/open_fields.csv --repo .`
from the repository root and move every field it shows as existing from evidence V to C. The comparison covers the
link registry and process catalogue specs and the code (ABAP SQL, typed structures, CDS; section "code
references" with file:line); it exits non-zero on a missing field. `tools/portable_checks.py` runs it over every
export folder of `ddic/` (check `ddic_fields`).
