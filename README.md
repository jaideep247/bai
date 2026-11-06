# jaideep247/bai — Payment Engine Operations Suite

> **First principle:** one repository, one importable code base, one place for each document.
> **Analogy:** a well-run warehouse — the shelves (`ops-suite/src`) hold what ships, the archive room (`legacy/`) holds what it replaced, and the front desk (this page) tells you where everything is.

| Path | What it is |
|---|---|
| `ops-suite/` | **The product** — EBS validation (BAI2 + CAMT), file monitoring, health check and morning report, configurable alerting. Start with `ops-suite/README.md`. |
| `ops-suite/src/` | ABAP source in **abapGit** format (classes, interfaces, programs, tables, message class, packages) |
| `REQUIREMENTS_FSCD_OPERATIONS_SUITE.md` | The requirements the suite is built against |
| `tools/git-sync/` | Windows scheduled task that keeps a local clone in step with GitHub |
| `legacy/` | Superseded code and the 65 status documents of the first framework (reference only — do not transport) |

## Import into SAP with abapGit

1. In DV1 create package `ZCD_OPS` (software component HOME/your component, transport layer of DV1).
2. abapGit → New Online → URL `https://github.com/jaideep247/bai.git`, branch `main`, package `ZCD_OPS`.
3. abapGit reads `/.abapgit.xml` (starting folder `/ops-suite/src/`, folder logic PREFIX) and creates sub-packages `ZCD_OPS_CORE`, `ZCD_OPS_EBS`, `ZCD_OPS_FMON`, `ZCD_OPS_HCK`.
4. Pull. Before the first pull complete step 0 of `ops-suite/docs/Implementation_Order.md` (SE11 checks of `VERIFY-DDIC` fields).

Not in abapGit scope (created in ADT from the sources in the repository): CDS views and access control in `ops-suite/cds/`, secondary indexes (commented in `ops-suite/ddic/*/*.tabl.ddl`), SM30 maintenance views, text elements of the three reports (`ops-suite/docs/text_elements/`).
