# Verification items (not provable offline)

The offline gates (abaplint v758 with the `abaplint/deps` stubs, `tools/checks.py`,
serializer check, tool tests) prove syntax, typing against stubs and house rules only.
They do **not** prove activation, DDIC existence, the SM30 maintenance or ABAP Unit
results. Work through this list in the development system (DV1) after the first abapGit
pull; record the outcome in `CHANGELOG.md`.

## VERIFY-ADT

| # | Item | Where | Check / fallback |
|---|---|---|---|
| A1 | abapGit TABL XML with foreign keys (DD05M / DD08V), full buffering, table logging, delivery class C | `src/zca_param_*.tabl.xml` | SE11: foreign keys AREA and NAME, technical settings *log data changes*, buffering *fully buffered*; else maintain in SE11 and re-serialize |
| A2 | DOMA / DTEL XML, value table of `ZCA_PARAM_AREA_ID`, fixed values | `src/*.doma.xml`, `*.dtel.xml` | SE11 shows fixed values of KIND / VTYPE / SIGN / OPTION |
| A3 | Authorization objects SUSC `ZCA`, AUTH `ZCA_PARAR`, SUSO `ZCA_PARAM` (fields, activities 01/02/03/06) | `src/zca.susc.xml`, `zca_parar.auth.xml`, `zca_param.suso.xml` | SU21; fallback: create in SU21 manually - object class `ZCA` (or an existing customer class), field `ZCA_PARAR` with data element `ZCA_PARAM_AREA_ID`, object `ZCA_PARAM` with fields `ZCA_PARAR`, `ACTVT`, permitted activities 01 02 03 06 |
| A4 | Message class `ZCA_PARAM` | `src/zca_param.msag.xml` | SE91 shows 001-029 (040-048 deleted with the RAP app) |
| A5 | `CL_ABAP_INTFDESCR->APPLIES_TO_CLASS( p_classname )` incl. inherited interfaces | `ZCL_CA_PARAM_VALIDATOR->CHECK_REPOSITORY` | unit test `class_with_interface` (CX_SY_ZERODIVIDE / IF_MESSAGE) |
| A6 | Invalid date converts to 0 days (`d` -> `i`) | `ZCL_CA_PARAM_VALIDATOR->IS_DATE` | unit test `date_impossible_day` |
| A7 | `matches( val pcre case = abap_false )`, `replace( pcre ... occ = 0 )`, `CX_SY_REGEX` for invalid PCRE | validator | unit tests `allowed_pcre_*`, `pcre_value_compiles`, `def_pattern_rules` |
| A8 | A `FOR TESTING` class as `GLOBAL FRIENDS` of a productive class | `ZCL_CA_PARAM_FACTORY` / `ZCL_CA_PARAM_INJECTOR` | activation; fallback: remove `FOR TESTING` from the injector (it stays `CREATE PRIVATE` with static methods only) |
| A9 | `cl_osql_test_environment` with the three customizing tables | `ZCL_CA_PARAM_DAO` tests | ABAP Unit |
| A19 | ABAP Unit of all test classes (`ltc_context` included), coverage | SE80 / ADT | all green; coverage of `ZCL_CA_PARAM`, `ZCL_CA_PARAM_VALIDATOR` >= 90 % |
| A20 | ATC (default variant of DV1) | package `ZCA_PARAM` | no priority 1 / 2 findings |
| A22 | Table conversion of `ZCA_PARAM_VAL` (key `CTX1`-`CTX4` added) and `ZCA_PARAM_DEF` / `_AREA` (fields removed) | SE14 | *Activate and adjust database*, data kept; existing rows get blank context = general rows |
| A23 | SM30 / SM34 after the conversion | table maintenance of the three tables, view cluster `ZCA_PARAM_VC` | regenerate the maintenance dialogs (new key fields), field dependence DEF -> VAL, event 01 forms assigned (`sm30/lzca_param_maintf01.abap`) |
| A24 | Save checks | SM34 | an invalid row, a second row of a single value in one context, a context value without dimension (026) are refused |
| A25 | Context reads end to end | test report or ABAP Unit | general row, one source-specific row: `get_effective_context` shows the source context for that source and the general one for another |

## VERIFY-SE11

| # | Item | Expected |
|---|---|---|
| S4 | Domain `XFELD`, data element `SEOCLSNAME` | exist (standard) |

## Basis

| # | Item | Expected |
|---|---|---|
| B1 | Profile parameter `rec/client` | includes the clients where values change (table logging, SCU3) |
| B2 | Table buffer synchronization `rdisp/bufreftime` | known delay for value changes across application servers (`docs/OPERATIONS.md`) |
