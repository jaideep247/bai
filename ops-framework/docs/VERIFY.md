# What the offline checks cannot prove (ZCA_OPS)

> **First principle:** a clean lint is evidence about syntax, not about a running system.
> **Analogy:** a building plan approved by the inspector is not yet a house you can live in.

Nothing of ZCA_OPS has been activated or run in an SAP system. Each item is confirmed in DV1 / QA1 and
recorded in the release pack.

| ID | Where | What to confirm |
|---|---|---|
| V01 | VERIFY-ADT | Activation of the whole package `ZCA_OPS` / `ZCA_OPS_UI` after ZCA_PARAM 1.1.0 (dependency order of the pull) |
| V02 | VERIFY-SE11 | Tables `ZCA_OPS_RUN`, `_FINDING`, `_EXC_HIST`, `_LOCK`, `_ALRULE`, `_ALCHN`, `_ALLOG`, `_PURGE` and drafts `ZCA_D_*`; field `AREA` with data element `ZCA_PARAM_AREA_ID` (CHAR 16); secondary indexes noted in the DDL comments (MOD, OPN, OBJ, RUL, INT unique, FND) created by hand |
| V03 | VERIFY-SU21 | Object `ZCA_OPS` in class `ZCA` with fields `ZCA_PARAR`, `ACTVT`, `BUKRS` and activities 01 02 03 06 16 85 (`src/zca_ops.suso.xml`) |
| V04 | VERIFY-ADT | DCL `ZC_CA_OPSEXCEPTION` (`pfcg_auth( ZCA_OPS, ZCA_PARAR, ACTVT = '03' )`, path `_Exception.Area`) |
| V05 | VERIFY-ADT | Configuration app `ZUI_CA_OPS_CFG`: child entities as global authorisation masters with draft, `%assoc` in the permission result, validations on save incl. the area (435) and parameter (434) checks, transport recording |
| V06 | ABAP Unit | All test classes of `src/` (HARMLESS, SHORT); OSQL / CDS test doubles in the DAO tests |
| V07 | ATC | Default check variant of the landscape |
| V08 | Runtime | `CHECK_VERSION`: with ZCA_PARAM 1.0.0 every `start_run` is refused with 044; with 1.1.0 it passes |
| V09 | Runtime | `ENQUEUE_E_TABLE` / `DEQUEUE_E_TABLE` with table `ZCA_OPS_LOCK` (key MANDT, AREA 16, VARIANT 30) |
| V10 | SLG0 | Object `ZCA_OPS` / sub-object `ALERT` (APPLOG channel default destination) |
| V11 | Runtime | `ZCA_OPS_RETENTION` in test mode lists RUN, ALERT_LOG and every active row of `ZCA_OPS_PURGE`; a registry class that is no purge target stops the run before anything is deleted (032) |
| V12 | VERIFY-ADT | Optional sub-package `ZCA_OPS_DEMO` (folder `src/demo`) created by the abapGit import and activated after `ZCA_OPS`; an import without `src/demo` leaves the framework complete (nothing outside the demo refers to it) |
| V13 | VERIFY-SE11 | `TBTCO` fields read by `ZCL_CA_OPS_DEMO_DAO`: `AUTHCKMAN` (client of the job), `STATUS` (`F` finished, `A` cancelled, `S` released), `ENDDATE` / `ENDTIME`, `SDLSTRTDT` / `SDLSTRTTM` (planned start, server time); COUNT only, read only |
| V14 | Runtime | Demo (`docs/INSTALL.md` section 7): test mode writes nothing and sends nothing; test mode off with *Sample* stores a run of area `CA_DEMO` with an open error and warning exception (exceptions app), one SLG1 entry `ZCA_OPS` / `ALERT` by rule `DEMO_LOG` and its `ZCA_OPS_ALLOG` row; a second run without *Sample* resolves the exceptions it no longer raises; without ZCA_OPS 16 for `CA_DEMO` the report stops with 041 |
| V15 | ABAP Unit | `ZCL_CA_OPS_DEMO` (local doubles injected through `ZCL_CA_OPS_INJECTOR`) and `ZCL_CA_OPS_DEMO_DAO` (OSQL double of `TBTCO`, incl. the client filter) |
| V16 | Runtime | Messages 900-903 of `ZCA_OPS` (texts and variables of the demo findings and of its result message) |
| V17 | VERIFY-ADT | `CL_SMTG_EMAIL_API` exists; static `GET_INSTANCE` (`IV_TEMPLATE_ID`, returning `RO_INSTANCE`) - constants of `ZCL_CA_OPS_MAIL_TPL_SMTG` |
| V18 | VERIFY-ADT | `RENDER_W_DATA` (`IV_LANGUAGE`, data parameter assumed `IR_DATA`, `EV_SUBJECT` / `EV_BODY_HTML` / `EV_BODY_TEXT`); components mapped to placeholders by name |
| V19 | VERIFY-ADT | `RENDER` with `IT_DATA_KEY` (`NAME` / `VALUE`, key `ALERT_ID` of `ZI_CA_OPS_ALERTMAILCTX`) |
| V20 | VERIFY-ADT | Exception classes of the API; `GET_INSTANCE` raises for an unknown / inactive template |
| V21 | VERIFY-SE11 | Data element and length of the SMTG template ID (CHAR 30 assumed in `ZCA_OPS_ALRULE` / `_ALCHN` / `_ALLOG`) and its allowed characters |
| V22 | VERIFY-ADT | abapGit support of object type SMTG in DV1 (else templates stay documented sources, `templates/`) |
| V23 | VERIFY-ADT | Placeholder syntax `{{NAME}}`, case of the element names in the template editor; `ZI_CA_OPS_ALERTMAILCTX` with `cast( ' ' as abap.char(n) )` elements accepted as data source |
| V24 | Runtime | A token (letters and digits) survives rendering unchanged and is replaced by the table |
| V25 | Runtime | QA1: alert e-mails rendered from templates (`ZCA_OPS_ALLOG-RENDERER` = `SMTG`); a deleted template gives the built-in layout and `RENDER_INFO` 071; `ALERT_MAIL_RENDERER` = `BUILTIN` gives 075 |
| V26 | VERIFY-SE11 | Tables `ZCA_OPS_CONTROL`, `_CTLT`, `_CTLCHK` (C), `ZCA_OPS_REVIEW` (A), field `ZCA_OPS_FINDING-REASON_CODE`, domain / data element `ZCA_OPS_CTL_STATUS` (fixed values H / W / A); optionally `ZCA_OPS_CTLT` declared the text table of `ZCA_OPS_CONTROL` (foreign key, TEXT_KEY) for SE63 |
| V27 | VERIFY-ADT | `I_CalendarDate` available and filled for the years in use; `tstmp_to_dats` / `tstmp_to_tims` with a time zone element; CROSS JOIN and a left outer join with an ON condition of literals only (`ZI_CA_OpsCtlTz`, `ZI_CA_OpsBusDay`, `ZI_CA_OpsCtlDay`); MAX on RAW 16 (`ZI_CA_OpsCtlEvid`); `DDCDS_CUSTOMER_DOMAIN_VALUE_T` for the status texts |
| V28 | VERIFY-ADT | Review BO `ZR_CA_OpsCtlReview`: managed without persistent table (`with unmanaged save`, `lock master unmanaged`, `etag master LastChangedAt`) over a root view with joins; action `markReviewed` with parameter `ZA_CA_CtlReview`; internal update of read-only fields in local mode |
| V29 | VERIFY-SE37 | `SUSR_USER_CHECK_EXISTENCE` (parameter `USER_NAME`, exception `USER_NAME_NOT_EXISTS`) behind `ZIF_CA_OPS_AUTH=>USER_EXISTS`; `ENQUEUE_E_TABLE` with table `ZCA_OPS_REVIEW` and scope 2 |
| V30 | Runtime | Two users sign off the same control and date: the second gets 079 (lock) or HTTP 412 (ETag) and sees the first sign-off after refresh; one row in `ZCA_OPS_REVIEW` |
| V31 | Runtime | Status of a control equals the worst live finding of the date in the exceptions app; a finding after the sign-off makes it await review again; past the cut-off (local time of `CONTROL_TIME_ZONE`) it shows as overdue |
| V32 | Runtime | `ZCA_OPS_RETENTION` test mode lists target REVIEW with `RETENTION_DAYS_REVIEW` |
| V33 | Runtime | Exceptions app: action *Classify* accepts the values of `EXC_REASON_CODES` only (068), writes history CLASSIFY, the reason code survives the next run of the check (carry-forward) |
| V34 | Runtime (DV1, before the QA1 pilot) | Alert audit log with the unique index `INT` active: (a) ordinary logging - one run whose rules produce two or more routing decisions without a dispatch (throttled, quiet hours, repeat, failed by `SEND`) writes one `ZCA_OPS_ALLOG` row per decision, each with `INTENT_KEY` = its alert ID and `ATTEMPT` 0; (b) simultaneous dispatch - two sessions dispatch the same run (same intent) at the same moment: exactly one row reaches status S, the other session logs no second send; (c) a refused row raises 081 and the run records `ALERT_FAILED` |
