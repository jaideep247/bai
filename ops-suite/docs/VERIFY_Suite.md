# What the offline checks cannot prove - the suite's own items

> **First principle:** an item that names a customer's table, field, middleware, bank or scheduler belongs to that customer's delivery, not to the reusable product; the product's list keeps only what every customer must confirm.
> **Analogy:** the car maker's inspection sheet covers the car; the fleet owner's sheet covers its own fittings - the company logo, the radio, the toll tag.

The rows below were moved on 2026-11-11 from the framework's list `ops-framework/docs/VERIFY.md` (customer-neutral product: the framework names no customer object). **IDs are unchanged and never reused**; the framework keeps V01-V43, V46-V54, V57-V66, V70-V79, V94-V99 and V110-V114. Nothing activated; every row is open. Confirm each item in DV1 / QA1 and record the evidence in the release pack (`Release_Readiness.md`).

## 1. Where the suite's VERIFY items are

| IDs | Topic | Where |
|---|---|---|
| V44, V45 | Company-code isolation (FMON design guard), control proposal P1 | `Release_Readiness.md` |
| V55, V56 | Process onboarding check in the morning report; the example process before activation | `Release_Readiness.md` |
| V67-V69 | SAP job monitor: mass activity workers, payment run, Control-M rows | `Release_Readiness.md` |
| V80, V81 | Operations response features: runbook rows, overview page cards | `Release_Readiness.md` |
| **V82-V93** | **Service health, process flow, missing-volume checks, payment model mapping (build B)** | **this document, §2** |
| V100-V109 | Ledger drill-down, group reconciliation, document changes (build C) | `USAA_Known_Tables.md` §4 |

## 2. Build B (2026-11-11) - service health, process flow, missing-volume checks, payment model mapping

The framework's payment model product layer (contract, templates, generator) is verified by the framework's V94-V99; the rows here are the suite's mapping (`config/payment_model/mapping.json`), its helper views and its own checks.

| ID | Kind | Item |
|---|---|---|
| V82 | VERIFY-SE11 | `ZCD_PAYM_REQ_LOG`: FIN-number field, received date / time stamp, company code, currency and amount fields - names for the pending request / attempt adapters of the payment model (the suite's `config/payment_model/mapping.json`, sections `request`, `request_attempt`); then status `active` and regenerate |
| V83 | VERIFY-SE11 | `ZCD_PAYM_REQ_LOG` transaction field (the field exists - user 2026-11-11; name and values / texts): mapping `TransactionType`, dimension texts `TRANSACTION` in `ZCA_OPS_PMDIM`, volume rows grouped by it |
| V84 | VERIFY-SE11 | Business request lifecycle status (PENDING / SCHEDULED / SRCPOSTED / source reject): table and field (control_seed.md section 2a P2) - mapping `RequestStatus` stays blank until named |
| V85 | VERIFY-SE11 | Received date (DATS) and time (TIMS) of `ZCD_PAYM_REQ_LOG` for `B_VOL_PRQ` (inactive) and its hour bands; index for the day read (with pre-check 0.8) |
| V86 | VERIFY (Control-M) | Payment run ID convention per day-part (LAUFI) for the day-part rows of `B_VOL_PAYRUN` |
| V87 | VERIFY-SE11 | DPAYH-HKTID (house bank account ID) - mapping `HouseBankAccount` blank until confirmed; FEBKO-HBKID / HKTID for `B_VOL_STMT` |
| V88 | VERIFY-SE11 / PlanViz | DFKKOP secondary index on AUGBL (payment -> requests of the payment page) and the index of pre-check 0.8 on ZZ_FIN_TRANS_NUM (request -> payments); DFKKOP-BUKRS |
| V89 | VERIFY-SE11 / business | Feeder business reference field (claim / policy / invoice) of the request log, its sensitivity (masked by default) and the feeder URL templates (`ZCA_OPS_FEEDER`) |
| V90 | VERIFY-SE11 | Timeline hops of a request: link request -> PRISM file / message (FMON event), `ZCD_SPE_EXCP_LOG` fields of the status sent back - union view `ZI_CD_PaymHops` before the `request_event` section can be active |
| V91 | VERIFY-ADT | Service health CDS (`ZI_CD_SvcRule` UNION ALL, `ZI_CD_SvcFind` OR in the ON condition, `ZI_CD_SvcSlice` CROSS JOIN + UNION, `ZR_CD_SvcHealth` arithmetic in CASE) and process flow CDS (`>=` / `<` in ON conditions, `dats_days_between` with the session date); ABAP Unit `ZCL_CD_OPS_SVC_CDS_TEST` (4 methods) |
| V92 | ABAP Unit | Seasonal baseline: `ZCL_CD_HCK_THRESHOLD` (`weekday_season_steps_weeks`, `day_season_steps_days`, `season_needs_a_day_series`), `ZCL_CD_HCK_DAO` (`season_latest_point_per_day`: range on DIM2 inside a CTE with ROW_NUMBER, 7.58), `ZCL_CD_HCK_ENGINE` (`volume_below_same_weekday`) |
| V93 | VERIFY-ADT / PlanViz | Payment model of the suite: `ZI_CD_PayMethodCls` over TFK033D with the parameter tables (`ZI_CD_PostAreaCfg`, MAX of CASE), `ZI_CD_PaymFact` on a 2 million payment day (DPAYH key range LAUFD + worklist by AUGBL), `ZR_CD_PaymCube` / `ZR_CD_PaymTrend` response time < 5 s; ABAP Unit `ZCL_CD_PAYM_CDS_TEST` |

The suite-specific parts of the framework's product rows: the custom process-flow card of V97 is the suite's `ui/cards/processflow`; the intents of V98 are the suite's `ZCDPaymentTrace-display` and `ZCDJobFailure-display` (job app of build J, placeholder until merged); the binding of V99 is `ZUI_CD_PAYM_O4`.
