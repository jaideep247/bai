# RAP operations apps — exceptions, releases, suppressions, manual status, PRISM

> **First principle:** when operations step in, the system records who did what, why, on which evidence — and where money or a whole check is waved through, a second person agrees.
> **Analogy:** the bank-branch override desk — the clerk can request an override, a supervisor signs it, and the override slip stays in the drawer for the auditor.

Implements design §6 (`RAP_Apps_Design.md`, decision D-4). Status: written and statically checked offline (abaplint: CDS, BDEF and ABAP parsed; 0 issues). **Not activated in SAP** — first DV1 import is the test.

## 1. The five apps

| App | Service definition (binding to create) | Root | Table | Area (ZCD_OPS) | Who |
|---|---|---|---|---|---|
| Owned exceptions | `ZUI_CD_OPS_EXC` (`ZUI_CD_OPS_EXC_O4`) | `ZR_CD_OpsException` + history child `ZR_CD_OpsExcHist` | ZCD_OPS_FINDING (rank ≥ 2, not superseded), ZCD_OPS_EXC_HIST | per finding (EBS / FMON / HCK / CORE) | Operations, owners; approvers |
| Blocked line releases | `ZUI_CD_EBS_REL` (`ZUI_CD_EBS_REL_O4`) | `ZR_CD_EbsRelease` | ZCD_EBS_RELEASE | EBS | Payment engine RTB (request), Treasury lead (approve) |
| Health check suppressions | `ZUI_CD_HCK_SUP` (`ZUI_CD_HCK_SUP_O4`) | `ZR_CD_HckSuppress` | ZCD_HCK_SUPPRESS | HCK | RTB; RTB lead for > 7 days |
| Monitored files — manual status | `ZUI_CD_FMON_MAN` (`ZUI_CD_FMON_MAN_O4`) | `ZR_CD_FmonFile` | ZCD_FMON_FILE (+ event in ZCD_FMON_EVENT) | FMON | Operations |
| PRISM requests handled manually | `ZUI_CD_FMON_PRQ` (`ZUI_CD_FMON_PRQ_O4`) | `ZR_CD_FmonPrqWa` | ZCD_FMON_PRQ_WA | FMON | Disbursement operations |

All five: RAP **managed**, **no draft** (each action is one complete change), operations tables delivery class A (no transport, no change policy, no table log — the history is in the tables themselves), authorisation through `ZCL_CD_OPS_AUTH` (object `ZCD_OPS`, design §1), every decision in a pure policy class with unit tests, behaviour pools thin.

## 2. What each app does

### 2.1 Owned exceptions (design 6.1)
| Action | Allowed when | Effect | Authorisation |
|---|---|---|---|
| Assign | Disposition O or A; owner given | Owner set, disposition A | 02 for the finding's area |
| Resolve | O or A; reason given | Disposition R, resolved by / at, resolution | 02 |
| Request waiver | O or A; no request pending; reason; end date not in the past | Requester, time, reason, end date stored; disposition unchanged | 02 |
| Approve waiver | Request pending; approver ≠ requester (**four-eyes**) | Disposition W until the end date | 85 |

Every action writes one row in ZCD_OPS_EXC_HIST (action, from / to disposition, owner, reason, user, time). A waiver request survives a re-run (carry-forward keeps requester, reason and end date); a valid waiver is not reopened by re-runs (phase 1). Buttons are switched off where an action is not allowed (the requester never sees an active *Approve*).

### 2.2 Blocked line releases (design 6.2)
- **Create** = request (line key `<statement key>/<line no>` and check code from the exception, reason, evidence; ZCD_OPS 43). Status R.
- **Approve** by a second user (85) → status A; the open exception of that line and check code is **resolved** (history action RELEASE, reference = release ID). **Reject** → X.
- **Posting gate** (`ZCL_CD_EBS_ENGINE->validate_for_posting`, enforce mode): an approved release turns exactly its block finding into information — still recorded, no longer blocking. A different block finding on the same line still blocks; run-level findings (PLUGIN_ERROR, VALIDATION_ERROR) are never releasable; if the release lookup fails, the gate stays closed.

### 2.3 Health check suppressions (design 6.3)
- **Create** (02): check ID, optional object-key pattern (`HCK_C04/*/US01`) and company code, period, reason. Up to `HCK_SUPPRESS_MAX_DAYS` (default 7) the suppression is active at once; longer waits for a **second user** (85, *Approve*). *End now* stops it from the next run.
- **Engine:** matching findings of the day become information "Suppressed until … by …" — listed on the report, not alerted, not scored; the check is not red or amber because of them. Expired and pending suppressions are ignored automatically.

### 2.4 Monitored files — manual status (design 6.4)
- **Set status manually** (02): stage, reason (mandatory), evidence. Allowed only where the file state machine itself would move the file (`ZCL_CD_FMON_STATUS=>MANUAL_ALLOWED`) — no going back, no overwriting a final ACK or FULLY_PROCESSED.
- On save one event with source `MANUAL` (reason in INFO, evidence in SRC_KEY) is written through `ZIF_CD_FMON_DAO~INSERT_EVENT`; if the event cannot be written the save is aborted (no change without audit trail). The next FMON run reconciles the file's exceptions.
- Files not yet in the registry (an expected file that never arrived) cannot be set by hand — the missing-file exception is worked in the exceptions app.

### 2.5 PRISM requests handled manually (design 6.5, record only)
- **Create** = handled manually (02): PRISM request reference, source, handling reference (payment document, ticket), reason — all mandatory except source. Status H.
- On save the open FMON exception whose object key is the request reference (upper case) is **resolved** (history action MANUAL, reference = handling reference). SAP re-sends nothing and re-posts nothing.

## 3. Tests

| Object | Level | Tests (written before the code) |
|---|---|---|
| `ZCL_CD_OPS_EXC_POLICY` | Domain | 9 — owner required, open/assigned assignable, reason required, closed refused, waiver end not in past, one request at a time, approve needs request, requester cannot approve, second user approves |
| `ZCL_CD_OPS_EXC_DAO` | OSQL | 2 — only open / assigned found; resolve sets R with user, reason and one history row |
| `ZCL_CD_OPS_STORE` | OSQL | +1 — `pending_waiver_is_carried` |
| `ZCL_CD_EBS_RELEASE_POLICY` | Domain | 6 — released block becomes info, other check code still blocks, run finding never released, requester cannot approve, second user approves, request needs line / check / reason |
| `ZCL_CD_EBS_RELEASE_DAO` | OSQL | 1 — only approved releases of the requested lines |
| `ZCL_CD_EBS_ENGINE` | Application | +3 — `approved_release_unblocks`, `other_block_still_blocks`, `rule_failure_not_releasable` |
| `ZCL_CD_HCK_SUPPRESSION` | Domain | 8 — match → info, pattern, company code, other check, expiry, pending, long period needs approval, creator cannot approve |
| `ZCL_CD_HCK_DAO` | OSQL | +1 — `only_active_suppressions` |
| `ZCL_CD_HCK_ENGINE` | Application | +1 — `suppressed_red_is_not_red` |
| `ZCL_CD_FMON_STATUS` | Domain | +4 — `success_wins_over_later_fail`, `success_after_fail_wins` (PRISM SUCCESS rule, characterisation of existing behaviour), `manual_forward_is_allowed`, `manual_backward_is_refused` |
| `ZCL_CD_FMON_OPS_POLICY` | Domain | 5 — manual needs reason, backward refused, forward allowed, handled needs reference, complete accepted |
| Behaviour pools, CDS, BDEF, SRVD | — | Not unit tested (thin); covered by the policy tests above and the QA1 cases below |

## 4. DV1 steps (after the abapGit pull)

1. **VERIFY-ADT:** `internal create` on the history association (`ZR_CD_OpsException`); `READ ENTITIES` of the own BO in `save_modified` (release and PRISM savers); `RAISE SHORTDUMP` with a `ZCX_CD_OPS_ERROR` instance (manual-status saver).
2. Activate: tables (ZCD_OPS_EXC_HIST, ZCD_EBS_RELEASE, ZCD_HCK_SUPPRESS, ZCD_FMON_PRQ_WA, ZCD_OPS_FINDING with the waiver-request fields) → abstract entities `ZA_CD_*` → `ZR_CD_*` → `ZC_CD_*` → DDLX → BDEF `ZR_` → behaviour pools → BDEF `ZC_` → service definitions.
3. Create and **publish** the OData V4 – UI service bindings `ZUI_CD_OPS_EXC_O4`, `ZUI_CD_EBS_REL_O4`, `ZUI_CD_HCK_SUP_O4`, `ZUI_CD_FMON_MAN_O4`, `ZUI_CD_FMON_PRQ_O4`; FLP tiles per business role.
4. Roles: ZCD_OPS 02 per area for operations; 43 (EBS) for release requesters; **85 only for approvers who are not requesters** (segregation of duties); `S_SERVICE` for the five services.
5. Read access: the CDS views carry `#NOT_REQUIRED`; restrict reading per area with a DCL on `ZR_CD_OpsException` (`pfcg_auth( ZCD_OPS, ZCD_MODULE, ACTVT = '03' )`) if the business roles are not already separated by service — decision for security.

## 5. QA1 cases

| ID | Case | Expected |
|---|---|---|
| OPS-01 | Assign, resolve an exception | History rows ASSIGN, RESOLVE; disposition A then R |
| OPS-02 | Request a waiver, approve with the same user | *Approve* disabled; via API message 063 |
| OPS-03 | Approve the waiver with a second user, re-run the module | Disposition W; the re-run keeps W until the end date |
| OPS-04 | Request a release for an R14 block, approve with a second user, run validate_for_posting in enforce mode | Not blocked; finding information; exception resolved with RELEASE |
| OPS-05 | Same line with a second, different block | Still blocked |
| OPS-06 | Suppress a red check for 3 days | Active at once; check green with info finding; no alert |
| OPS-07 | Suppress for 14 days | Status R until a second user approves |
| OPS-08 | Set an outbound file SENT → ACK_RECEIVED by hand | Event source MANUAL; next run resolves the missing-ACK exception |
| OPS-09 | Set ACK_RECEIVED → SENT by hand | Refused (230) |
| OPS-10 | Record a PRISM request handled manually | Record H; FMON exception of the request resolved (MANUAL) |
