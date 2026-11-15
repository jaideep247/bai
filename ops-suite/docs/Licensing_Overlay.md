# Licensing - the licence of the ops suite (first customer)

Release: 2026-11-15 (build J). Product: `ops-framework/docs/LICENSING.md`. This document holds only what is this
landscape's own: which licensable modules of the framework the suite uses, how its licence is issued and installed in
DV1 / QA1 / PS4, and the decisions to take. **The licence is a configuration fact of the customer, not code:** nothing
of the suite's source changes, and no licence file, installation number or key is kept in this repository.

> **First principle:** the vendor writes onto the licence which modules this customer bought; the suite's own
> engines (EBS validation, file monitoring, health check, payment snapshot) run on the framework's core and need none.
>
> **Analogy:** the hotel card of the guest - the floors written on it are the modules below; the guest's own luggage
> (the suite's own programs) needs no card at all.

## 1. Modules the suite uses

| Module | Used by the suite for | Evidence in this folder | Needed from |
|---|---|---|---|
| `CORE` | every run of the suite's engines (`start_run` of EBS, FMON, HCK, payment snapshot), exceptions, alerts, the check runner of its areas, its plug-in pack of extensions | `src/`, `config/extensions` | always included |
| `JOBS` | SAP job monitor of area `CD_JOBS` (checks `JOB_FAILURES`, `JOB_STATES`; business process `SAP_JOBS` active) | `config/check_registry.csv`, `config/process_register.csv` | first install |
| `ONBOARD` | no-code aggregate checks of the collections request lifecycle (`CD_COLL`), approved tables | `config/check_aggregates.csv`, `config/approved_tables.csv` | first install |
| `CONTROL` | control register and daily review of the suite's areas | `config/control_register.csv`, `config/control_checks.csv` | first install |
| `RESPONSE` | correlation rules, runbook links, escalation of the suite's alert rules | `config/correlation_rules.csv`, `config/alert_rules.csv` | first install |
| `LINKS` | the customer layer `CD` of the link registry (custom tables and fields, own links) | `config/links` | first install |
| `CATALOGUE_FICA` | the business process `GL_CLEAR_BRK` monitors `FICA_GL_TRANSFER`; FI-CA catalogue processes of the activation proposal | `config/catalogue/overlay.json`, `docs/Process_Catalogue_Overlay.md` | when the catalogue activation is approved |
| `CATALOGUE_FSCD` | FS-CD catalogue processes of the activation proposal (payment plan, premium, broker, claims as decided) | `docs/catalogue/activation.md` | when the catalogue activation is approved |
| `BREAKS` | clearing-account break analysis of area `CD_HCK` (check `GL_BREAKS`), pilot pack | `config/breaks`, `docs/Break_Analysis_Overlay.md` | before the break accounts are activated |
| `FLOW` | account flows `DISB` / `COLL` of area `CD_HCK` | `config/flows`, `docs/Account_Flow_Overlay.md` | before the flows are activated |
| `PAYMODEL` | the suite's generated payment model (`config/payment_model`, `src/paym`) | `tools/payment_model.py` | contract (no runtime gate, D-L1) |
| `CATALOGUE_FSRI` | not used: "Is FS-RI integrated?" is an open question of the activation proposal (`overlay.json`) | - | only if the answer is yes |

The suite's own business process `BASE_REQ_LIFE` monitors its own catalogue process `CD_COLL_REQ_LIFE` (customer layer
`CD`, no module): it needs `ONBOARD` for its aggregate rows only.

## 2. How the licence is issued and installed

The vendor issues **one licence file per system** (the installation number and SID differ per system; a single file
may list all three systems when they share the installation number - the vendor decides):

| System | SID | Client | Installation number | Licence file | Enforcement |
|---|---|---|---|---|---|
| Development | ‹DV1 SID› | ‹client› | ‹installation number of DV1› | issued by the vendor, kept in the vendor's register | `W` |
| Quality | ‹QA1 SID› | ‹client› | ‹installation number of QA1› | as above | `W`, `X` for the V167 tests |
| Production | ‹PS4 SID› | ‹client› | ‹installation number of PS4› | as above | `W` until the decision D-J2 |

1. The customer's Basis team sends the installation number(s) and SIDs (SLICENSE / system status) to the vendor.
2. The vendor issues the file with `tools/licensing/issue_license.py` (modules of section 1 with the contract's dates,
   grace days of the contract) and checks it with `verify_license.py` for each system's identity.
3. Basis prepares each system: SSF application and PSE, the vendor's certificate in its certificate list (STRUST),
   parameter `LIC_SSF_PROFILE` (framework INSTALL 6h).
4. The licence administrator (role `Z_CA_OPS_LICENSE`) installs the file per system with `ZCA_OPS_LICENSE_INSTALL` -
   test mode first, then for real. The licence is never transported; a renewal is a new file installed the same way.
5. The morning run of `CA_OPS` (check `LICENSE`) and the dashboard `ZUI_CA_OPS_LIC` show the modules; the suite's alert
   rule for licence findings is a copy of `ops-framework/config/licensing/alert_rules_license.csv` with the suite's
   operations list (to be added when the list is named).

## 3. Decisions

| ID | Question | Proposal |
|---|---|---|
| D-J1 | Which modules does the first customer's contract include? | the modules of section 1 needed "from first install"; `BREAKS`, `FLOW`, `CATALOGUE_*` before their activation |
| D-J2 | When does production switch `LIC_ENFORCE` to `X`? | not before V162 / V163 / V166 / V167 / V169 are closed and one renewal has been rehearsed in QA1 |
| D-J3 | One licence file for all three systems or one per system? | one per system (installation numbers usually differ; a lost QA1 file never touches production) |

## 4. VERIFY

| ID | Where | What to confirm |
|---|---|---|
| V169 | DV1 / QA1 / PS4 | The installation number(s) and SIDs of the three systems sent to the vendor; the vendor's file installed in each (test mode, then for real), the dashboard showing the modules of D-J1 as `LICENSED`, the `LICENSE` exception of `CA_OPS` resolved; in QA1 under `X` a module outside the licence refused and the suite's own engines (EBS, FMON, HCK, payment snapshot - CORE) unaffected |
