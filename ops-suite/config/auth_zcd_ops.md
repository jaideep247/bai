# Authorisation object ZCD_OPS — definition sheet (SU20 / SU21 / roles)

> **First principle:** one object guards every operations action, so a role says in one place who may run, change, release or approve.
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
| 01 | Create configuration entry (DV1, transport) | Configuration apps |
| 02 | Change (existing configuration, exception assign / resolve) | Configuration and operations apps |
| 03 | Display | All apps, ALV reports |
| 06 | Delete configuration entry (DV1, transport) | Configuration apps |
| 16 | Execute | `ZCD_EBS_VALIDATE` (EBS), `ZCD_FMON_MONITOR` (FMON), `ZCD_MORNING_REPORT` (HCK), `ZCD_OPS_PURGE` (CORE) |
| 43 | Release | EBS blocked-line release request |
| 85 | Approve (second person) | Waiver approval, EBS release approval |

`BUKRS`: company code of the object where it has one (bank account, statement, check threshold row); payment engine area-wide checks pass it as `DUMMY`.

## 3. Roles (PFCG) — proposal

| Role | ZCD_MODULE | ACTVT | BUKRS |
|---|---|---|---|
| `Z_CD_OPS_DISPLAY` | * | 03 | * |
| `Z_CD_OPS_BATCH` (Control-M job user) | EBS, FMON, HCK, CORE | 16 | * |
| `Z_CD_OPS_OPERATOR` (RTB operations) | EBS, FMON, HCK | 02, 03, 43 | own company codes |
| `Z_CD_OPS_APPROVER` (team lead, not the operator) | EBS, FMON, HCK | 03, 85 | own company codes |
| `Z_CD_OPS_CONFIG` (configuration owner) | per payment engine area | 01, 02, 03, 06 | * |

Segregation of duties: the same user must not hold 43 and 85 for the same payment engine area and company code; the apps additionally refuse an approval by the requester (four-eyes).

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
