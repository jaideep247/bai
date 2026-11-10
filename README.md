# jaideep247/bai — Payment Engine Operations Suite

> **First principle:** one repository, one importable code base, one place for each document.
> **Analogy:** a well-run warehouse — the shelves (`ops-suite/src`) hold what ships, the archive room (`legacy/`) holds what it replaced, and the front desk (this page) tells you where everything is.

| Path | What it is |
|---|---|
| `ops-suite/` | **The product** — EBS validation (BAI2 + CAMT), file monitoring, health check and morning report, configurable alerting. Start with `ops-suite/README.md`. |
| `param-framework/` | **Global parameter framework `ZCA_PARAM`** — typed, validated, audited parameters for every SAP team (areas → definitions → values, read API `ZIF_CA_PARAM`, maintenance app). Prerequisite of the operations framework and the ops suite. Start with `param-framework/README.md`. |
| `ops-framework/` | **Operations framework `ZCA_OPS`** — reusable store of runs and findings, owned exceptions with SLA and the exceptions app, configurable alerting, run lock / abort boundary, configuration gate, retention purge with a target registry; one area register (ZCA_PARAM areas) and one authorisation object `ZCA_OPS`. Extracted from the ops suite on 2026-11-10; installed after ZCA_PARAM and before the suite. Start with `ops-framework/README.md`. |
| `ops-suite/src/` | ABAP source in **abapGit** format (classes, interfaces, programs, tables, message class, packages) |
| `REQUIREMENTS_FSCD_OPERATIONS_SUITE.md` | The requirements the suite is built against |
| `tools/git-sync/` | Windows scheduled task that keeps a local clone in step with GitHub |
| `legacy/` | Superseded code and the 65 status documents of the first framework (reference only — do not transport) |

## Import into SAP with abapGit

0. First install the parameter framework (package `ZCA_PARAM`, release 1.1.0) from `param-framework/` — abapGit offline ZIP built with `git archive HEAD:param-framework --format=zip -o zca_param.zip` (see `param-framework/README.md`), then the operations framework (package `ZCA_OPS`) from `ops-framework/` — `git archive HEAD:ops-framework --format=zip -o zca_ops.zip` (see `ops-framework/README.md`). Order: ZCA_PARAM -> ZCA_OPS -> suite (user decision 2026-11-10: separate components, shipped together).
1. In DV1 create package `ZCD_OPS` (software component HOME/your component, transport layer of DV1).
2. abapGit → New Online → URL `https://github.com/jaideep247/bai.git`, branch `main`, package `ZCD_OPS`.
3. abapGit reads `/.abapgit.xml` (starting folder `/ops-suite/src/`, folder logic PREFIX) and creates sub-packages `ZCD_OPS_CORE`, `ZCD_OPS_EBS`, `ZCD_OPS_FMON`, `ZCD_OPS_HCK`.
4. Pull. Before the first pull complete step 0 of `ops-suite/docs/Implementation_Order.md` (SE11 checks of `VERIFY-DDIC` fields).

Not in abapGit scope (created in ADT from the sources in the repository): CDS views and access control in `ops-suite/cds/`, secondary indexes (commented in `ops-suite/ddic/*/*.tabl.ddl`), SM30 maintenance views, text elements of the three reports (`ops-suite/docs/text_elements/`).
