# RAP applications and operations controls — design (2026-11-06)

> **First principle:** operations change the suite's behaviour only through audited, authorised apps — never through SE16, never without a reason, never without a trail.
> **Analogy:** a bank vault's logbook — anyone allowed in can open a drawer, but every opening is signed, timed and, for the big drawers, countersigned.

Decisions taken with the business owner (2026-11-06):

| # | Decision |
|---|---|
| D-1 | `ops-suite` is the final product: EBS validation, file monitoring, morning report. Legacy and `jaideep247/src` are references only |
| D-2 | **One configuration app per payment engine area** (EBS, FMON, HCK, Alerting) |
| D-3 | **New configuration entries via transport** (created in DV1, recorded on a customizing request); **existing entries editable directly in production** (no transport; change-logged, authorised) |
| D-4 | Operations apps: exception disposition, HCK check suppression, FMON manual file status, PRISM payment-request API handling (**record "handled manually with reference" only — no reprocessing**) |
| D-5 | Also in this build: retention purge (G1), authorisation object `ZCD_OPS` (G3), run lock, exception carry-forward |
| D-6 | **Wording: "payment engine", never "module" or FI-CA / FS-CD.** EBS validation, file monitoring and the morning report are **payment engine areas**. Applied everywhere: business text and app titles ("Payment engine – file monitoring"), and technical names — column `MODULE` → `PE_AREA`, authorisation field `ZCD_MODULE` → `ZCD_PE_AREA` (data element `ZCD_PE_AREA`, "Payment engine area"), constants `gc_module` → `gc_pe_area`, parameters `iv_module` → `iv_pe_area`. **Done 2026-11-06 (phase 4)** as one mechanical rename after phases 1–3, verified by lint and tests; CDS element `PaymentEngineArea`, label "Payment engine area" |

Platform: S/4HANA 2023 on-premise (SAP_BASIS 7.58), classic track for engines; **RAP managed BOs with draft** for the apps, OData V4 UI service, Fiori elements. House rules (`DEVELOPMENT_STANDARDS.md`) apply to every class.

## 1. Authorisation object `ZCD_OPS` (G3)

| Field | Data element | Values |
|---|---|---|
| `ACTVT` | standard | 03 display, 02 change, 01 create, 06 delete, 16 execute (run reports / purge), 85 approve / waive (second person) |
| `ZCD_PE_AREA` (was `ZCD_MODULE`, D-6) | `ZCD_PE_AREA` (CHAR 4), "Payment engine area" | `EBS`, `FMON`, `HCK`, `CORE` (alerting, parameters, purge) |
| `BUKRS` | standard | Company code; `*` for payment engine area-wide objects |

- One wrapper `ZCL_CA_OPS_AUTH` (`ZIF_CA_OPS_AUTH`, injectable through `ZCL_CD_OPS_INJECTOR`) — engines and RAP handlers never write `AUTHORITY-CHECK` themselves.
- Reports `ZCD_EBS_VALIDATE`, `ZCD_FMON_MONITOR`, `ZCD_MORNING_REPORT`, `ZCA_OPS_RETENTION` check `16` for their payment engine area at start.
- RAP: `authorization master ( global )` → activity per operation; instance authorisation by `BUKRS` where the entity has one.
- SU21 / SU20 objects are delivered as a definition sheet (`config/auth_zcd_ops.md`) — created once by Basis/security.

## 2. Run lock

- Table `ZCA_OPS_LOCK` (key PE_AREA, VARIANT; delivery class L) used only as the lock argument of standard lock object `E_TABLE` (`ENQUEUE_E_TABLE` / `DEQUEUE_E_TABLE`, `_SCOPE = '1'` so the lock survives the per-package `COMMIT WORK`). Isolated in `ZCL_CA_OPS_LOCK` (`ZIF_CA_OPS_LOCK`, injectable; `VERIFY-SE37` on the FM interface).
- EBS, FMON and HCK take the lock for payment engine area + variant before `start_run`; a held lock → no run, finding-free result with message, alert rule `RUN_LOCKED` (severity E) through the router, report message. Test mode does not lock.
- Released at the end of the run (also on exception via `CLEANUP`).

## 3. Exception carry-forward

- New fields on `ZCA_OPS_FINDING`: `FIRST_SEEN_AT` (timestampl), `OCCURRENCES` (int4), `SUPERSEDED_BY` (sysuuid_x16, run that replaced it).
- `save_findings`: for a finding of rank ≥ 2, look up the open exception (disposition O or A) for the same PE_AREA + OBJECT_TYPE + OBJECT_KEY + CHECK_CODE from an earlier run. Found → the new row inherits `DISPOSITION`, `OWNER`, `DUE_DATE`, `FIRST_SEEN_AT`, `OCCURRENCES + 1`; the old row gets disposition `S` (superseded) and `SUPERSEDED_BY`.
- New store method `reconcile( is_run, it_scope )`: `it_scope` = object keys the run actually evaluated. Open exceptions of the payment engine area for keys in scope that were **not** found again → disposition `R`, `RESOLUTION = 'Passed on re-run <run id>'`, resolved by the run user. Each engine passes its scope (EBS: lines validated; FMON: files evaluated; HCK: checks executed).
- Waived (W) exceptions are not reopened by re-runs while the waiver is valid (see §6.1).
- **Change stamp (2026-11-10, concurrency review).** New field `LAST_CHANGED_AT` (timestampl) on `ZCA_OPS_FINDING`, set by every write: the store (insert, supersede, resolve), the exception repository (`ZCL_CA_OPS_EXC_DAO`) and the actions of the exceptions BO (its ETag, §6.1). The store's supersede and resolve and the repository's resolve write a row only while its disposition and stamp are the ones read (one keyed UPDATE each, sy-dbcnt compared): a row a user changed in between is read again and carried forward / resolved once more from what the user left; a second change during that attempt keeps the user's change, the new row of the run stays information and an information finding `EXC_CHANGED_DEFERRED` (786) leaves the exception for the next run. A waiver, assignment or resolution is never overwritten.

## 4. Retention purge (G1)

- Report `ZCA_OPS_RETENTION` (test mode default ON, counts per table), class `ZCL_CA_OPS_PURGE` + DAO.
- Parameters `RETENTION_DAYS_<TABLE>` in ZCA_PARAM, area `CD_OPS` (defaults: runs/findings 400, alert log 180, FMON events 400, HCK metrics 400).
- **Never purged:** open exceptions (O, A), waivers still valid, findings of a run that has open exceptions, suppression / manual-status records younger than their retention (audit evidence).
- Deletes in packages with commit per package; scheduled monthly by Control-M.

## 5. Configuration apps (D-2, D-3)

Pattern: SAP **business-configuration maintenance** shape — a **singleton root** per payment engine area (`SingletonID = 1`), every customizing table a **child entity** of it, draft on the whole, lock on the root, total ETag = max of the children's `LAST_CHANGED_AT`.

| App (service) | Root | Children (tables) |
|---|---|---|
| EBS rules & mapping `ZUI_CD_EBS_CFG_O4` | `ZR_CD_EbsCfgAll` | ZCD_BTC_RULE, ZCD_EBS_RULE_DEF, ZCD_EBS_ACCT, ZCD_EBS_FLOW_PAT, ZCD_EBS_LOOKUP (the BTC map and the reasons are FI-CA customer posting areas ZBTM / ZRSN since 2026-11-08) |
| File monitoring setup `ZUI_CD_FMON_CFG_O4` | `ZR_CD_FmonCfgAll` | ZCD_FMON_IFACE, ZCD_FMON_SLA, ZCD_FMON_SRC, ZCD_FMON_SRCMAP, ZCD_FMON_CHK, ZCD_FMON_LOTCFG, ZCD_FMON_CAL |
| Health check setup `ZUI_CD_HCK_CFG_O4` | `ZR_CD_HckCfgAll` | ZCD_HCK_DEF, ZCD_HCK_THRESH, ZCD_HCK_AGG (expected groups A103 as a list field, 2026-11-08), ZCD_JOB_CYCLE, ZCD_JOB_STEP |
| Alerting & approved tables `ZUI_CD_OPS_CFG_O4` | `ZR_CD_OpsCfgAll` | ZCA_OPS_ALRULE, ZCA_OPS_ALCHN, ZCD_OPS_TABWL (approved tables of every reader, 2026-11-08) (parameters - also the monitor freshness `MON_STALE_AFTER_MIN_<area>`, was ZCD_OPS_MONCFG: framework app `ZUI_CA_PARAM_O4`) |

- Every customizing table gets `LAST_CHANGED_BY` (`abp_lastchange_user`), `LAST_CHANGED_AT` (`abp_lastchange_tstmpl`), `LOCAL_LAST_CHANGED_AT` (`abp_locinst_lastchange_tstmpl`). Engines and DAOs ignore them.
- **Change policy** `ZCL_CA_OPS_CFG_POLICY` (pure, unit tested), input = client settings read from T000 (`CCCORACTIV`, `CCCATEGORY`) through an injectable reader:

| Client setting | Create | Update existing | Delete | Transport |
|---|---|---|---|---|
| Customizing client, automatic recording (DV1) | yes | yes | yes | required — request selected on the root, every change recorded |
| Changes not allowed / production (QA1, PS4) | **no** (message: "new entries via transport from DV1") | **yes** — direct, change-logged (table log flag set), `ZCD_OPS` 02 | **no** | none |

- Transport recording isolated in `ZCL_CA_OPS_CFG_TRANSPORT` over SAP's business-configuration CTS API (`mbc_cp_api`, `VERIFY-ADT` — confirm class and method names in DV1 before activation); called from `save_modified` (`with additional save`).
- Validations per table (in the handler, using the engines' existing pure checks): rule / check / adapter class exists and implements its interface; table and field names exist in the DDIC (FMON sources, HCK aggregates); BTC map row has a rule group with at least one active rule; thresholds amber < red; quiet-hours window valid; cron-free (Control-M owns schedules).

## 6. Operations apps (D-4)

All transactional (delivery class A), no transport, `ZCD_OPS` authorised, every action with a mandatory reason and a history row. They write only suite records (read-only towards FS-CD / FI data, user decision 2026-11-07); the blocked-line release of the first design (6.2) is not part of the suite.

### 6.1 Exceptions — `ZUI_CD_OPS_EXC_O4` (root `ZR_CA_OpsException` on ZCA_OPS_FINDING, rank ≥ 2, not superseded)
- Actions: **Assign** (owner) → A; **Resolve** (reason) → R; **Request waiver** (reason, valid to) → pending; **Approve waiver** — different user than the requester (four-eyes), `ZCD_OPS` 85 → W.
- ETag `LastChangedAt` (2026-11-10): `etag master` in `ZR_CA_OpsException`, `use etag` in the projection; no draft, so no total ETag. An action on a version the batch store changed after the screen was loaded is refused - refresh and act again (§3).
- Child `ZCA_OPS_EXC_HIST` (finding key, seq, action, from/to disposition, reason, user, timestamp) written for every action.

### 6.3 HCK suppression — `ZUI_CD_HCK_SUP_O4` (root on new `ZCD_HCK_SUPPRESS`)
- Check ID + object-key pattern + company code, valid from / to, reason, approver (four-eyes for > 7 days).
- Engine: matching findings become severity I with "suppressed until <date> by <user>" — still visible, not alerted, not scored; expired suppressions are ignored automatically (test first).

### 6.4 FMON manual file status — `ZUI_CD_FMON_MAN_O4` (root on ZCD_FMON_FILE, read-only fields)
- Action **Set status manually** (target stage, reason, evidence reference) — allowed only where the FMON state machine allows the transition; writes an event with source `MANUAL` through `ZIF_CD_FMON_DAO~INSERT_EVENT` in `save_modified`; the board shows the stage with origin MANUAL.

### 6.5 PRISM payment-request API calls
- Payment requests reach SAP as API calls from PRISM (log `ZCD_PAYM_REQ_LOG`; rule: status `ZZ_STATUS = SUCCESS`, never the highest COUNTER).
- Monitoring: an FMON interface of type API over the log through the generic adapter (configuration, no code) — stuck / failed requests become FMON findings and therefore exceptions (§6.1).
- Operations app `ZUI_CD_FMON_PRQ_O4` (decision 2026-11-06: **record only, no reprocessing**): new table `ZCD_FMON_PRQ_WA` keyed by the PRISM request reference (CHAR 70, as delivered by PRISM) + sequence. Action **Handled manually** (reference — e.g. payment document or ticket — mandatory, reason mandatory) → status H; the open FMON exception for that request is resolved with the reference (§6.1 history row). Nothing is re-sent or re-posted by SAP.
- Still needed for the monitoring side: the SE11 structure of `ZCD_PAYM_REQ_LOG` (request reference, status and timestamp fields) to configure the FMON API interface; until then the reference is entered by hand from PRISM.

### 6.6 Status — built (phase 3, 2026-11-06)
All four apps built as designed (`RAP_Ops_Apps.md`). Deviations:
- **No draft** for any operations BO — every action is one complete change; draft would add a second, unaudited state.
- **Suppression company code** is matched inside the finding's object key (HCK object keys carry the company code as dimension); a separate column on the finding does not exist.
- **Manual status** only for files already in the registry; an expected file that never arrived is worked as an exception.
- **History of PRISM handling** is written by `ZCL_CA_OPS_EXC_DAO` in the other BO's saver (EML of a second BO is not allowed in the save sequence). Since 2026-11-10 the open exceptions are read in `CHECK_BEFORE_SAVE` (a read failure refuses the save, message 788) and resolved in `SAVE_MODIFIED` all or nothing: each exception only while it is as read, the history only when every exception was written; a failure there ends the save (`RAISE SHORTDUMP`, as the manual file status) - before, it was a warning and a half-written closure could be committed.
- **Read authorisation** per area: CDS views `#NOT_REQUIRED`, actions instance- / globally authorised; a DCL is a DV1 decision (`RAP_Ops_Apps.md` §4 step 5).

## 7. Delivery and verification

- RAP sources in abapGit format under `src/<pe_area>/` (DDLS, DDLX, BDEF, SRVD, draft TABL, behaviour pools); service bindings created and published in ADT after import (`Implementation_Order.md`).
- Pure classes (policy, suppression matching, carry-forward, purge selection) test first; RAP handlers thin; DAO SQL with `cl_osql_test_environment`.
- abaplint + ATC-equivalent + portable checks green before each commit; nothing here is executed in SAP until DV1.
