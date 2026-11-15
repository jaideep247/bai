# Table definitions of the payment engine landscape

Evidence for the field references of the product layers and of this overlay: what SE11 shows in the landscape.
No business data - dictionary metadata only.

| Folder | Source | Tables |
|---|---|---|
| `landscape_2026-11-15` | definitions pasted from the landscape (annotations left out of `DFKKOP` / `DFKKOPK`) | `DFKKKO`, `DFKKOP`, `DFKKOPK` |

Add a folder per export (`tools/abaptools/ddic_export.py export`, table lists
`ops-framework/config/ddic/standard_tables.txt` and `config/ddic/customer_tables.txt`), then run
`python3 tools/abaptools/ddic_export.py compare --exports ops-suite/ddic/<folder> --repo .` from the repository root
and move every field it shows as existing from evidence V to C.
