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
