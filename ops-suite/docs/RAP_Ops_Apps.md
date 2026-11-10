# RAP operations apps — exceptions, suppressions, manual status, PRISM

> **First principle:** when operations step in, the system records who did what, why, on which evidence — and where a whole check is waved through, a second person agrees. The apps write only the suite's own records, never FS-CD / FI data.
> **Analogy:** the bank-branch override desk — the clerk can request an override, a supervisor signs it, and the override slip stays in the drawer for the auditor.

Implements design §6 (`RAP_Apps_Design.md`, decision D-4). Status: written and statically checked offline (abaplint: CDS, BDEF and ABAP parsed; 0 issues). **Not activated in SAP** — first DV1 import is the test.

## 1. The four apps

| App | Service definition (binding to create) | Root | Table | Area (ZCD_OPS) | Who |
|---|---|---|---|---|---|
| Owned exceptions | `ZUI_CA_OPS_EXC` (`ZUI_CD_OPS_EXC_O4`) | `ZR_CA_OpsException` + history child `ZR_CA_OpsExcHist` | ZCA_OPS_FINDING (rank ≥ 2, not superseded), ZCA_OPS_EXC_HIST | per finding (EBS / FMON / HCK / CORE) | Operations, owners; approvers |
| Health check suppressions | `ZUI_CD_HCK_SUP` (`ZUI_CD_HCK_SUP_O4`) | `ZR_CD_HckSuppress` | ZCD_HCK_SUPPRESS | HCK | RTB; RTB lead for > 7 days |
| Monitored files — manual status | `ZUI_CD_FMON_MAN` (`ZUI_CD_FMON_MAN_O4`) | `ZR_CD_FmonFile` | ZCD_FMON_FILE (+ event in ZCD_FMON_EVENT) | FMON | Operations |
| PRISM requests handled manually | `ZUI_CD_FMON_PRQ` (`ZUI_CD_FMON_PRQ_O4`) | `ZR_CD_FmonPrqWa` | ZCD_FMON_PRQ_WA | FMON | Disbursement operations |

All four: RAP **managed**, **no draft** (each action is one complete change), operations tables delivery class A (no transport, no change policy, no table log — the history is in the tables themselves), authorisation through `ZCL_CA_OPS_AUTH` (object `ZCD_OPS`, design §1), every decision in a pure policy class with unit tests, behaviour pools thin.

## 2. What each app does

### 2.1 Owned exceptions (design 6.1)
| Action | Allowed when | Effect | Authorisation |
|---|---|---|---|
| Assign | Disposition O or A; owner given | Owner set, disposition A | 02 for the finding's area |
| Resolve | O or A; reason given | Disposition R, resolved by / at, resolution | 02 |
| Request waiver | O or A; no request pending; reason; end date not in the past | Requester, time, reason, end date stored; disposition unchanged | 02 |
| Approve waiver | Request pending; approver ≠ requester (**four-eyes**) | Disposition W until the end date | 85 |

Every action writes one row in ZCA_OPS_EXC_HIST (action, from / to disposition, owner, reason, user, time). A waiver request survives a re-run (carry-forward keeps requester, reason and end date); a valid waiver is not reopened by re-runs (phase 1). Buttons are switched off where an action is not allowed (the requester never sees an active *Approve*). **ETag (2026-11-10):** every action sets `LastChangedAt`; an action on a version the batch store changed after the screen was loaded is refused (refresh and act again), and the store never overwrites a user's action (guarded writes, `RAP_Apps_Design.md` §3).

### 2.2 Health check suppressions (design 6.3)
- **Create** (02): check ID, optional object-key pattern (PCRE, complete key, case ignored: `HCK_C04/.*/US01`; refused with 418 when it does not compile) and company code, period, reason. Up to `HCK_SUPPRESS_MAX_DAYS` (default 7) the suppression is active at once; longer waits for a **second user** (85, *Approve*). *End now* stops it from the next run.
- **Engine:** matching findings of the day become information "Suppressed until … by …" — listed on the report, not alerted, not scored; the check is not red or amber because of them. Expired and pending suppressions are ignored automatically.

### 2.3 Monitored files — manual status (design 6.4)
- **Set status manually** (02): stage, reason (mandatory), evidence. Allowed only where the file state machine itself would move the file (`ZCL_CD_FMON_STATUS=>MANUAL_ALLOWED`) — no going back, no overwriting a final ACK or FULLY_PROCESSED.
- On save one event with source `MANUAL` (reason in INFO, evidence in SRC_KEY) is written through `ZIF_CD_FMON_DAO~INSERT_EVENT`; if the event cannot be written the save is aborted (no change without audit trail). The next FMON run reconciles the file's exceptions.
- Files not yet in the registry (an expected file that never arrived) cannot be set by hand — the missing-file exception is worked in the exceptions app.

### 2.4 PRISM requests handled manually (design 6.5, record only)
- **Create** = handled manually (02): PRISM request reference, source, handling reference (payment document, ticket), reason — all mandatory except source. Status H.
- On save the open FMON exception whose object key is the request reference (upper case) is **resolved** (history action MANUAL, reference = handling reference). SAP re-sends nothing and re-posts nothing.
- **All or nothing (2026-11-10):** the open exceptions are read in the early save (`CHECK_BEFORE_SAVE`; a read failure refuses the save with message 788) and resolved in the late save only while each is still as read; a write failure or an exception changed meanwhile ends the save with nothing saved (short dump with message 787 - reload and record again). Before, the record was saved and the failure was only a warning.

## 3. Tests

| Object | Level | Tests (written before the code) |
|---|---|---|
| `ZCL_CA_OPS_EXC_POLICY` | Domain | 9 — owner required, open/assigned assignable, reason required, closed refused, waiver end not in past, one request at a time, approve needs request, requester cannot approve, second user approves |
| `ZCL_CA_OPS_EXC_DAO` | OSQL | 2 — only open / assigned found; resolve sets R with user, reason and one history row |
| `ZCL_CA_OPS_STORE` | OSQL | +1 — `pending_waiver_is_carried` |
| `ZCL_CD_HCK_SUPPRESSION` | Domain | 8 — match → info, pattern, company code, other check, expiry, pending, long period needs approval, creator cannot approve |
| `ZCL_CD_HCK_DAO` | OSQL | +1 — `only_active_suppressions` |
| `ZCL_CD_HCK_ENGINE` | Application | +1 — `suppressed_red_is_not_red` |
| `ZCL_CD_FMON_STATUS` | Domain | +4 — `success_wins_over_later_fail`, `success_after_fail_wins` (PRISM SUCCESS rule, characterisation of existing behaviour), `manual_forward_is_allowed`, `manual_backward_is_refused` |
| `ZCL_CD_FMON_OPS_POLICY` | Domain | 5 — manual needs reason, backward refused, forward allowed, handled needs reference, complete accepted |
| Behaviour pools, CDS, BDEF, SRVD | — | Not unit tested (thin); covered by the policy tests above and the QA1 cases below |

## 4. DV1 steps (after the abapGit pull)

1. **VERIFY-ADT:** `internal create` on the history association (`ZR_CA_OpsException`); `READ ENTITIES` of the own BO in `save_modified` (PRISM saver); `RAISE SHORTDUMP` with a `ZCX_CD_OPS_ERROR` instance (manual-status saver).
2. Activate: tables (ZCA_OPS_EXC_HIST, ZCD_HCK_SUPPRESS, ZCD_FMON_PRQ_WA, ZCA_OPS_FINDING with the waiver-request fields) → abstract entities `ZA_CD_*` → `ZR_CD_*` → `ZC_CD_*` → DDLX → BDEF `ZR_` → behaviour pools → BDEF `ZC_` → service definitions.
3. Create and **publish** the OData V4 – UI service bindings `ZUI_CD_OPS_EXC_O4`, `ZUI_CD_HCK_SUP_O4`, `ZUI_CD_FMON_MAN_O4`, `ZUI_CD_FMON_PRQ_O4`; FLP tiles per business role.
4. Roles: ZCD_OPS 02 per area for operations; **85 only for approvers who are not requesters** (segregation of duties); `S_SERVICE` for the four services.
5. Read access: the CDS views carry `#NOT_REQUIRED`; restrict reading per area with a DCL on `ZR_CA_OpsException` (`pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' )`) if the business roles are not already separated by service — decision for security.

## 5. QA1 cases

| ID | Case | Expected |
|---|---|---|
| OPS-01 | Assign, resolve an exception | History rows ASSIGN, RESOLVE; disposition A then R |
| OPS-02 | Request a waiver, approve with the same user | *Approve* disabled; via API message 063 |
| OPS-03 | Approve the waiver with a second user, re-run the payment engine area | Disposition W; the re-run keeps W until the end date |
| OPS-04 | Suppress a red check for 3 days | Active at once; check green with info finding; no alert |
| OPS-05 | Suppress for 14 days | Status R until a second user approves |
| OPS-06 | Set an outbound file SENT → ACK_RECEIVED by hand | Event source MANUAL; next run resolves the missing-ACK exception |
| OPS-07 | Set ACK_RECEIVED → SENT by hand | Refused (230) |
| OPS-08 | Record a PRISM request handled manually | Record H; FMON exception of the request resolved (MANUAL) |
