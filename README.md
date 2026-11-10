# jaideep247/bai — Payment Engine Operations Suite

> **First principle:** one repository, one importable code base, one place for each document.
> **Analogy:** a well-run warehouse — the shelves (`ops-suite/src`) hold what ships, the archive room (`legacy/`) holds what it replaced, and the front desk (this page) tells you where everything is.

| Path | What it is |
|---|---|
| `ops-suite/` | **The product** — EBS validation (BAI2 + CAMT), file monitoring, health check and morning report, configurable alerting. Start with `ops-suite/README.md`. |
| `param-framework/` | **Global parameter framework `ZCA_PARAM`** — typed, validated, audited parameters for every SAP team (areas → definitions → values, read API `ZIF_CA_PARAM`, maintenance app). Prerequisite of the operations framework and the ops suite. Start with `param-framework/README.md`. |
| `ops-framework/` | **Operations framework `ZCA_OPS`** — reusable store of runs and findings, owned exceptions with SLA and the exceptions app, configurable alerting, run lock / abort boundary, configuration gate, retention purge with a target registry, control register with a daily sign-off per business date (2026-11-10); one area register (ZCA_PARAM areas) and one authorisation object `ZCA_OPS`. Extracted from the ops suite on 2026-11-10; installed after ZCA_PARAM and before the suite. Start with `ops-framework/README.md`. |
| `ops-suite/src/` | ABAP source in **abapGit** format (classes, interfaces, programs, tables, message class, packages) |
| `REQUIREMENTS_FSCD_OPERATIONS_SUITE.md` | The requirements the suite is built against |
| `tools/abaptools/` | **Shared offline tooling** of the three ABAP components (abapGit serializer, parameter seed and RAP generators, modernize, literal scan, class purpose table, house checks); each component's `tools/` keeps thin wrappers, tests in `tools/tests/` (`python3 -m unittest discover -s tools/tests`) |
| `tools/git-sync/` | Windows scheduled task that keeps a local clone in step with GitHub |
| `legacy/` | Superseded code and the 65 status documents of the first framework (reference only — do not transport) |

## Import into SAP with abapGit

0. First install the parameter framework (package `ZCA_PARAM`, release 1.1.0) from `param-framework/` — abapGit offline ZIP built with `git archive HEAD:param-framework --format=zip -o zca_param.zip` (see `param-framework/README.md`), then the operations framework (package `ZCA_OPS`) from `ops-framework/` — `git archive HEAD:ops-framework --format=zip -o zca_ops.zip` (see `ops-framework/README.md`). Order: ZCA_PARAM -> ZCA_OPS -> suite (user decision 2026-11-10: separate components, shipped together).
1. In DV1 create package `ZCD_OPS` (software component HOME/your component, transport layer of DV1).
2. abapGit → New Online → URL `https://github.com/jaideep247/bai.git`, branch `main`, package `ZCD_OPS`.
3. abapGit reads `/.abapgit.xml` (starting folder `/ops-suite/src/`, folder logic PREFIX) and creates sub-packages `ZCD_OPS_CORE`, `ZCD_OPS_EBS`, `ZCD_OPS_FMON`, `ZCD_OPS_HCK`.
4. Pull. Before the first pull complete step 0 of `ops-suite/docs/Implementation_Order.md` (SE11 checks of `VERIFY-DDIC` fields).

Not in abapGit scope (created in ADT from the sources in the repository): CDS views and access control in `ops-suite/cds/`, secondary indexes (commented in `ops-suite/ddic/*/*.tabl.ddl`), SM30 maintenance views, text elements of the three reports (`ops-suite/docs/text_elements/`).

## The two frameworks and how to ship them to another customer

The repository holds two reusable frameworks next to their first consumer:

| Component | Package | Needs | What it gives a consumer |
|---|---|---|---|
| `param-framework/` | `ZCA_PARAM` (release 1.1.0) | SAP standard only | typed, validated, audited parameters per area (areas -> definitions -> values), read API `ZIF_CA_PARAM`, maintenance app; the one area register `ZCA_PARAM_AREA` |
| `ops-framework/` | `ZCA_OPS` (release 1.0.0) | `ZCA_PARAM` 1.1.0 | store of runs and findings, owned exceptions with SLA and the exceptions app, configurable alerting (e-mail to SO23 lists, application log), run lock / abort, configuration gate, retention purge with a target registry; optional demo consumer `ZCA_OPS_DEMO` |

Both are self-contained: neither refers to the operations suite (`ops-suite/`), and the parameter framework
refers to neither of the others (check `packaging` of each component's `tools/checks.py`); the operations
framework depends on the parameter framework only. To ship them to another customer:

1. Copy the folders `param-framework/` and `ops-framework/` - they never need `ops-suite/`. Copy
   `tools/abaptools/` and `tools/tests/` along when the customer's developers will run the offline tools
   (serializer, generators, checks); nothing of `tools/` is imported into SAP.
2. Work through `ops-framework/docs/INSTALL.md` section 0 before the first pull: confirm reuse rights,
   look up the `ZCA` object names in the customer's `TADIR` (the prefix is not a registered namespace),
   add the customer's names to `config/customer_terms.txt` of both frameworks (check `customer_terms`).
3. Install with abapGit in the order **ZCA_PARAM -> ZCA_OPS** (`git archive HEAD:param-framework ...`,
   `git archive HEAD:ops-framework ...`; leave out `src/demo` for production), then configure and verify
   with the demo report as `ops-framework/docs/INSTALL.md` describes.
4. The customer's own checks and monitors are consumers: they use the frameworks' public API
   (`ops-framework/README.md`, *How a consumer uses it*) and never write the frameworks' tables.
