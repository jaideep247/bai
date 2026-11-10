# Authorisation object ZCD_OPS — definition sheet (SU20 / SU21 / roles)

> **First principle:** one object guards every operations action, so a role says in one place who may run, change or approve.
> **Analogy:** one keycard system for the whole building — the card says which floors (payment engine areas) and which doors (activities), not a different key per room.

Created once per landscape by security / Basis (DV1, transported to QA1 / PS4). The code checks it only through `ZCL_CD_OPS_AUTH` (`ZIF_CD_OPS_AUTH`).

## 1. Authorisation field (SU20)

| Field | Data element | Domain | Type | Values |
|---|---|---|---|---|
| `ZCD_PE_AREA` | `ZCD_PE_AREA` (create in SE11: short text "Operations suite payment engine area", domain `ZCD_PE_AREA`) | `ZCD_PE_AREA`, CHAR 4, fixed values below | CHAR 4 | `EBS` EBS validation · `FMON` file monitoring · `HCK` health check / morning report · `CORE` alerting, parameters, purge |

The data element is not delivered as abapGit XML (the repository serializer does not generate DTEL/DOMA); create it in SE11 before SU20.

## 2. Authorisation object (SU21)

| Object | Class | Fields | Text |
|---|---|---|---|
| `ZCD_OPS` | create class `ZCD` (or the landscape's custom class) | `ACTVT`, `ZCD_PE_AREA`, `BUKRS` | Payment engine operations suite |

Permitted activities (SU21 → Activities):

| ACTVT | Meaning in the suite | Used by |
|---|---|---|
| 01 | Create configuration entry (new row of a child entity, DV1 only, transport); **FMON: record a PRISM status event** | Configuration apps (create of a child row; editing the singleton); PRISM status API `ZCL_CD_FMON_PRISM_API` (`ZCD_PE_AREA` = FMON, `BUKRS` DUMMY) |
| 02 | Change (existing configuration row, exception assign / resolve) | Configuration apps (change of a child row; editing the singleton) and operations apps |
| 03 | Display | All apps, ALV reports |
| 06 | Delete configuration entry (row of a child entity, DV1 only, transport) | Configuration apps (delete of a child row; editing the singleton) |
| 16 | Execute | `ZCD_EBS_VALIDATE` (EBS), `ZCD_FMON_MONITOR` (FMON), `ZCD_MORNING_REPORT` (HCK), `ZCD_OPS_PURGE` (CORE) |
| 85 | Approve (second person) | Waiver approval, HCK suppression approval |

Configuration apps (user decision 2026-11-08): each activity is checked on its own per child entity and payment engine area of the app (EBS / FMON / HCK / CORE) — 01 create, 02 change, 06 delete; editing the singleton (Edit) needs at least one of the three; display needs only `S_SERVICE` (§3b). The client policy is unchanged: new rows and deletions only where the client records customizing changes (DV1).

`BUKRS`: company code of the object where it has one (bank account, statement, check threshold row); payment engine area-wide checks pass it as `DUMMY`.

## 3. Roles (PFCG) — proposal

| Role | ZCD_PE_AREA | ACTVT | BUKRS |
|---|---|---|---|
| `Z_CD_OPS_DISPLAY` | * | 03 | * |
| `Z_CD_OPS_BATCH` (Control-M job user) | EBS, FMON, HCK, CORE | 16 | * |
| `Z_CD_OPS_OPERATOR` (RTB operations) | EBS, FMON, HCK | 02, 03 | own company codes |
| `Z_CD_OPS_APPROVER` (team lead, not the operator) | EBS, FMON, HCK | 03, 85 | own company codes |
| `Z_CD_OPS_CONFIG` (configuration owner) | per payment engine area | 01, 02, 03, 06 (create, change, display, delete of configuration rows; each checked on its own) | * |
| `Z_CD_OPS_PRISM` (PRISM technical user `PRISM_FMON`, type B) | FMON | 01 | DUMMY — plus `S_ICF` ICF_FIELD `SERVICE`, ICF_VALUE `ZCD_PRISM` (the SICF node's authorisation value) |

Segregation of duties: the operator (02) and the approver (85) of a payment engine area and company code are different users; the apps additionally refuse an approval by the requester (four-eyes).

**PRISM status API (2026-11-06, `docs/PRISM_Status_API.md` §9).** The API checks `ZCD_OPS` ACTVT **01** for FMON (it *creates* an evidence record in the suite's own store). Activity 01 / FMON is also in `Z_CD_OPS_CONFIG`; the endpoint is therefore additionally restricted by the SICF authorisation value `ZCD_PRISM` (`S_ICF`), which only `Z_CD_OPS_PRISM` carries — a configuration owner cannot post PRISM events. The role is created in DV1 and assigned in PS4 only at switch S-PRISM (`Implementation_Order.md` step 1e). The bgPF unit runs under the calling user and needs no further authorisation (suite tables only; VERIFY in QA1).

## 3a. Dashboards (read-only, decision 2026-11-06)

| Dashboard (service) | ZCD_PE_AREA | BUKRS | ACTVT | DCL |
|---|---|---|---|---|
| File monitoring (`ZUI_CD_FMON_FLOW`) | FMON | — | 03 | `ZC_CD_FMONFLOW` |
| EBS validation (`ZUI_CD_EBS_DASH`) | EBS | — (area-wide, as the EBS run) | 03 | `ZC_CD_EBSDASH` |
| Health checks (`ZUI_CD_HCK_DASH`) | HCK | — | 03 | `ZC_CD_HCKDASH` |
| Transactions (`ZUI_CD_TRX_DASH`, `cds/ZUI_CD_TRX_REQ`) | **CORE** | **company code of the open item** (payment run rows: area only) | 03 | `ZC_CD_TRXDASH`, `ZC_CD_TRXREQ` |
| Production-support overview (`ZUI_CD_OPS_OVERVIEW`) | the area of each card / row | as the area dashboard | 03 | the area DCLs + `ZC_CD_OPSOVERVIEW` |

**Why CORE for transactions (no new value):** the transactions dashboard shows the same evidence as the 360° payment trace (request, open item, payment run, bank line, return), which is guarded by CORE 03 plus the company code of each item (`Payment_Trace.md` §6). One area keeps one rule for "may see payment evidence"; a new value (e.g. TRX) would need a domain change and a second grant for the same data. CORE 03 already covers the read-only alert / parameter apps — a user who should see neither gets no CORE. Company code is mapped in the DCL, so `Z_CD_OPS_OPERATOR` (own company codes) sees only its own transactions.

Roles: `Z_CD_OPS_DISPLAY` (ZCD_PE_AREA *, 03, BUKRS *) covers all dashboards. Business roles per launchpad page (`Dashboard_Production_Support.md` §5) add the catalogs and `S_SERVICE` for the bindings; they grant no activity other than 03.

## 3b. Every entry point and the ZCD_OPS check it makes (audit mapping, 2026-11-08)

Every `AUTHORITY-CHECK` on `ZCD_OPS` is in one class, `ZCL_CD_OPS_AUTH` (`ZIF_CD_OPS_AUTH`, factory `GET_AUTH`). The engines (`ZCL_CD_EBS_ENGINE`, `ZCL_CD_FMON_ENGINE`, `ZCL_CD_HCK_ENGINE`, …) are called only from the entry points below, which check before the engine is created. The suite has no RFC-enabled function module and no other external entry point.

**Batch programs and reports**

| Entry point | ZCD_PE_AREA | ACTVT | When |
|---|---|---|---|
| `ZCD_EBS_VALIDATE` (job / SE38) | EBS | 16 | At start, before the run; a bank file on the application server is a file name only, resolved in logical path `ZCD_OPS_EBS_IN` (FILE) and checked with `S_DATASET` activity READ (`ZCL_CD_OPS_FILE_PATH`, 2026-11-10) |
| `ZCD_FMON_MONITOR` (job `ZCD_FMON_MONITOR_ALL` step 1) | FMON | 16 | At start |
| `ZCD_OPS_PAY_SNAPSHOT` (job `ZCD_FMON_MONITOR_ALL` step 2) | CORE | 16 | At start |
| `ZCD_MORNING_REPORT` | HCK | 16 | At start; the CSV export takes a file name only, resolved in logical path `ZCD_OPS_HCK_OUT` (FILE) and checked with `S_DATASET` activity WRITE (`ZCL_CD_OPS_FILE_PATH`, 2026-11-10) |
| `ZCD_OPS_PURGE` | CORE | 16 | At start |
| `ZCD_OPS_PAYMENT_TRACE` | CORE | 03, plus company code per item | At start; a step on an item of a company code without 03 is shown as not authorised |
| `ZCD_OPS_PATTERN_CHECK` | each area | 03 | Per area read |
| `ZCD_OPS_PATTERN_MIGRATE` | each area | 02 | Per area, before anything is written (DV1, customizing request) |
| HCK checks reading a configured table (aggregates, value queries, queue and reference sources, drift hash) | — | `S_TABU_NAM` 03 | Before every dynamic read (`ZCL_CD_HCK_DAO=>GET_TABLE_FIELDS`, `ZIF_CD_OPS_AUTH=>MAY_READ_TABLE`, 2026-11-10), in addition to the approved-table list; refused = message 813 |
| EBS lookup rule R21 (`ZCD_EBS_LOOKUP`) | — | `S_TABU_NAM` 03 | Per lookup table at run time (`ZCL_CD_EBS_SAP_DAO=>GET_LOOKUP_ROWS`), after the field-level approval in `ZCD_OPS_TABWL` (area EBS, purpose LOOKUP; message 812); the approval is also checked when the lookup is saved |
| FMON dynamic reader (`ZCD_FMON_SRC` / `_LOTCFG` tables) | — | `S_TABU_NAM` 03 | Per table (`ZCL_CD_FMON_DDIC=>MAY_READ`, now the shared `ZIF_CD_OPS_AUTH=>MAY_READ_TABLE`) |
| PRISM status API (`POST /sap/zcd_ops/prism_status`, `ZCL_CD_FMON_PRISM_API`) | FMON | 01 | Per call, before the event is stored; the bgPF unit it queues runs only for that stored event |

**RAP services (Fiori apps)**

| Service | Behaviour pool | Operation | ZCD_PE_AREA | ACTVT |
|---|---|---|---|---|
| `ZUI_CD_EBS_CFG`, `ZUI_CD_FMON_CFG`, `ZUI_CD_HCK_CFG`, `ZUI_CD_OPS_CFG` (configuration apps) | `ZBP_R_CD_EBSCFGALL`, `…FMONCFGALL`, `…HCKCFGALL`, `…OPSCFGALL` | Edit / update of the singleton (global authorisation of the root, `ZCL_CD_OPS_CFG_GATE=>MAY_EDIT`) | EBS / FMON / HCK / CORE | at least one of 01, 02, 06 |
| same | same | Create of a child row (global authorisation of the root, create-by-association `%assoc`) | same | 01 |
| same | same | Change of a child row (global authorisation of the child entity, authorisation master) | same | 02 |
| same | same | Delete of a child row (global authorisation of the child entity) | same | 06 |
| same | same | Create and delete offered at all (global feature control) | — | Only in a client that records customizing changes (DV1), D-3; not an activity check |
| `ZUI_CD_OPS_EXC` (exceptions) | `ZBP_R_CD_OPSEXCEPTION` | Assign, resolve (instance authorisation) | Area of the exception | 02 |
| same | same | Approve a waiver (second person; the requester is refused) | Area of the exception | 85 |
| `ZUI_CD_HCK_SUP` (suppressions) | `ZBP_R_CD_HCKSUPPRESS` | Create, end suppression | HCK | 02 |
| same | same | Approve suppression (second person) | HCK | 85 |
| `ZUI_CD_FMON_MAN` (file manual status) | `ZBP_R_CD_FMONFILE` | Action set manual status | FMON | 02 |
| `ZUI_CD_FMON_PRQ` (PRISM request handled manually) | `ZBP_R_CD_FMONPRQWA` | Create (records the reference and resolves the exception) | FMON | 02 |
| Dashboards (`ZUI_CD_*_DASH`, `ZUI_CD_FMON_FLOW`, `ZUI_CD_TRX_REQ`, `ZUI_CD_OPS_OVERVIEW`) | — (read-only) | Read through the DCLs of §3a | per §3a | 03 |

The four configuration apps are generated (`tools/rap_generate.py`): every child entity is its own global authorisation master (VERIFY-ADT: child entity as authorisation master with draft on 7.58), so a user with 02 only can change but not add or delete rows, 01 only can add but not change, 06 can delete. Tests: the generated permission tests of each behaviour pool (02 only, 01 only, 06 only, no activity) and `ZCL_CD_OPS_CFG_GATE` (`edit_with_delete_only`, `no_activity_no_edit`).

## 3c. Read access of the operations apps (DCL, 2026-11-10)

The operations apps were readable with `S_SERVICE` alone (`#NOT_REQUIRED`). Their projections now carry `@AccessControl.authorizationCheck: #CHECK` and a DCL on `ZCD_OPS` activity 03, like the dashboards. Actions keep their own instance checks in the behaviour pools (unchanged).

| Projection (service) | DCL | Condition |
|---|---|---|
| `ZC_CD_OpsException` (`ZUI_CD_OPS_EXC`) | `ZC_CD_OPSEXCEPTION` | `( PaymentEngineArea ) = aspect pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' )` |
| `ZC_CD_OpsExcHist` (same service) | `ZC_CD_OPSEXCEPTION` | area of the exception (path `_Exception.PaymentEngineArea`) |
| `ZC_CD_FmonFile` (`ZUI_CD_FMON_MAN`) | `ZC_CD_FMONFILE` | fixed `ZCD_PE_AREA = 'FMON'`, ACTVT 03 (no area element in the view) |
| `ZC_CD_FmonPrqWa` (`ZUI_CD_FMON_PRQ`) | `ZC_CD_FMONPRQWA` | fixed `ZCD_PE_AREA = 'FMON'`, ACTVT 03 |
| `ZC_CD_HckSuppress` (`ZUI_CD_HCK_SUP`) | `ZC_CD_HCKSUPPRESS` | fixed `ZCD_PE_AREA = 'HCK'`, ACTVT 03 |

VERIFY-ADT: `pfcg_auth` with an empty element list and fixed field values, and the path to the parent entity, on 7.58. Roles: `Z_CD_OPS_DISPLAY` (03, all areas) already covers them; `Z_CD_OPS_OPERATOR` / `_APPROVER` carry 03 for their areas.

**Field names checked offline.** The kernel check of `ZCL_CD_OPS_AUTH` used the field name `ZCD_MODULE`, which SU21 does not know - every check failed. It now uses `ZCD_PE_AREA` (§1). The portable check `auth_fields_defined` (`tools/auth_checks.py`) fails when an `AUTHORITY-CHECK` on `ZCD_OPS` or a `pfcg_auth( ZCD_OPS, … )` names a field that §1 / §2 do not define.

**S_DATASET (2026-11-10).** The application-server files of the suite are reached only through logical paths of transaction FILE: `ZCD_OPS_EBS_IN` (EBS bank file, READ) and `ZCD_OPS_HCK_OUT` (morning report CSV, WRITE), each with a logical file name of the same name for `FILE_VALIDATE_NAME`. The user enters a file name only (no `/`, `\` or `..`, message 808). Roles running these programs need `S_DATASET` with the program name, activity `33` (read) / `34` (write) - and `06` (delete) for the export, whose temporary file is deleted - for the physical path of the logical path.
