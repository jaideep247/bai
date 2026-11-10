# Authorisation object ZCA_OPS — definition sheet (SU20 / SU21 / roles)

> **First principle:** one object guards every operations action of every consumer, so a role says in one place who may run, change or approve in which area.
> **Analogy:** one keycard system for the whole building — the card says which floors (areas) and which doors (activities), not a different key per room.

The object is part of the operations framework (`config/authorizations.json`, serialized to `src/zca_ops.suso.xml`). Its object class `ZCA` and its area field `ZCA_PARAR` belong to the parameter framework ZCA_PARAM (`param-framework/config/authorizations.json`) — install ZCA_PARAM first. Code checks it only through `ZCL_CA_OPS_AUTH` (`ZIF_CA_OPS_AUTH`, factory `ZCL_CA_OPS_FACTORY=>GET_AUTH`); CDS read access through `pfcg_auth( ZCA_OPS, … )` in a DCL. It replaces the first consumer's object `ZCD_OPS` and its field `ZCD_PE_AREA` (user decision 2026-11-10: one authorisation object).

## 1. Authorisation fields (SU20)

| Field | Data element | Owner | Values |
|---|---|---|---|
| `ZCA_PARAR` | `ZCA_PARAM_AREA_ID` (CHAR 16) | parameter framework ZCA_PARAM | an area of `ZCA_PARAM_AREA` (one area register: the area of a run, finding, alert rule, lock and configuration app is a parameter area); `CA_OPS` = the framework's own objects (alerting, purge targets, retention purge) |
| `ACTVT` | `ACTIV_AUTH` | SAP | see §2 |
| `BUKRS` | `BUKRS` | SAP | company code of an object that has one; area-wide checks pass `DUMMY` |

## 2. Authorisation object (SU21)

| Object | Class | Fields | Text |
|---|---|---|---|
| `ZCA_OPS` | `ZCA` | `ZCA_PARAR`, `ACTVT`, `BUKRS` | Operations framework: runs, findings, alerts per area |

Permitted activities (SU21 → Activities) — the same activities the first consumer used on `ZCD_OPS`:

| ACTVT | Meaning | Framework entry points |
|---|---|---|
| 01 | Create a configuration row (DV1 only, transport) | configuration apps (create of a child row; editing the singleton) |
| 02 | Change (configuration row; assign / resolve an exception) | configuration apps, exceptions app `ZUI_CA_OPS_EXC` |
| 03 | Display | every app and DCL, ALV reports |
| 06 | Delete a configuration row (DV1 only, transport) | configuration apps |
| 16 | Execute | `ZCA_OPS_RETENTION` (area `CA_OPS`); a consumer's batch programs (its area) |
| 85 | Approve (second person) | waiver approval in the exceptions app |

Configuration apps (generated, `ops-suite/tools/rap_generate.py`): each activity is checked on its own per child entity and the area of the app — 01 create, 02 change, 06 delete; editing the singleton needs at least one of them. The framework's app `ZUI_CA_OPS_CFG` (alert rules, alert channels, purge targets) checks area `CA_OPS`.

## 3. Roles (PFCG) — proposal

| Role | ZCA_PARAR | ACTVT | BUKRS |
|---|---|---|---|
| `Z_CA_OPS_DISPLAY` | * | 03 | * |
| `Z_CA_OPS_BATCH` (job user) | `CA_OPS` + the consumer areas it runs | 16 | * |
| `Z_CA_OPS_CONFIG` (configuration owner of the framework) | `CA_OPS` | 01, 02, 03, 06 | * |

A consumer adds its own roles with its areas (the payment engine suite: `ops-suite/config/auth_zcd_ops.md`). Segregation of duties: the operator (02) and the approver (85) of an area are different users; the exceptions app also refuses an approval by the requester (four-eyes).

## 3a. Read access (DCL)

| Projection (service) | DCL | Condition |
|---|---|---|
| `ZC_CA_OpsException` (`ZUI_CA_OPS_EXC`) | `ZC_CA_OPSEXCEPTION` | `( Area ) = aspect pfcg_auth( ZCA_OPS, ZCA_PARAR, ACTVT = '03' )` |
| `ZC_CA_OpsExcHist` (same service) | `ZC_CA_OPSEXCEPTION` | area of the exception (path `_Exception.Area`) |

VERIFY-ADT: `pfcg_auth` on a projection view and on a path to the parent (7.58).

## 3b. Checks offline

`ops-suite/tools/auth_checks.py` (portable check `auth_fields_defined`) reads §1 and §2 of this sheet and fails when an `AUTHORITY-CHECK` on `ZCA_OPS` (`zif_ca_ops_auth=>gc_object`) or a `pfcg_auth( ZCA_OPS, … )` in the framework or the suite names a field the sheet does not define. A wrong field name makes every kernel check fail (sy-subrc 12) and every DCL deny.

**S_DATASET.** `ZCL_CA_OPS_FILE_PATH=>PHYSICAL` resolves application server files only through a logical path of transaction FILE named by the consumer and checks `S_DATASET` (`AUTHORITY_CHECK_DATASET`, READ / WRITE). **S_TABU_NAM.** `ZIF_CA_OPS_AUTH=>MAY_READ_TABLE` checks display (03) of every table a consumer reads by a configured name.
