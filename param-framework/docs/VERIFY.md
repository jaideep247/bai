# Verification items (not provable offline)

The offline gates (abaplint v758 with the `abaplint/deps` stubs, `tools/checks.py`,
serializer check, tool tests) prove syntax, typing against stubs and house rules only.
They do **not** prove activation, DDIC existence, RAP runtime behaviour or ABAP Unit
results. Work through this list in the development system (DV1) after the first abapGit
pull; record the outcome in `CHANGELOG.md`.

## VERIFY-ADT

| # | Item | Where | Check / fallback |
|---|---|---|---|
| A1 | abapGit TABL XML with foreign keys (DD05M / DD08V), full buffering, table logging, delivery class C | `src/zca_param_*.tabl.xml` | SE11: foreign keys AREA and NAME, technical settings *log data changes*, buffering *fully buffered*; else maintain in SE11 and re-serialize |
| A2 | DOMA / DTEL XML, value table of `ZCA_PARAM_AREA_ID`, fixed values | `src/*.doma.xml`, `*.dtel.xml` | SE11 shows fixed values of KIND / VTYPE / SIGN / OPTION |
| A3 | Authorization objects SUSC `ZCA`, AUTH `ZCA_PARAR`, SUSO `ZCA_PARAM` (fields, activities 01/02/03/06) | `src/zca.susc.xml`, `zca_parar.auth.xml`, `zca_param.suso.xml` | SU21; fallback: create in SU21 manually - object class `ZCA` (or an existing customer class), field `ZCA_PARAR` with data element `ZCA_PARAM_AREA_ID`, object `ZCA_PARAM` with fields `ZCA_PARAR`, `ACTVT`, permitted activities 01 02 03 06 |
| A4 | Message class `ZCA_PARAM` | `src/zca_param.msag.xml` | SE91 shows 001-025, 040-045, 047, 048 |
| A5 | `CL_ABAP_INTFDESCR->APPLIES_TO_CLASS( p_classname )` incl. inherited interfaces | `ZCL_CA_PARAM_VALIDATOR->CHECK_REPOSITORY` | unit test `class_with_interface` (CX_SY_ZERODIVIDE / IF_MESSAGE) |
| A6 | Invalid date converts to 0 days (`d` -> `i`) | `ZCL_CA_PARAM_VALIDATOR->IS_DATE` | unit test `date_impossible_day` |
| A7 | `matches( val pcre case = abap_false )`, `replace( pcre ... occ = 0 )`, `CX_SY_REGEX` for invalid PCRE | validator | unit tests `allowed_pcre_*`, `pcre_value_compiles`, `def_pattern_rules` |
| A8 | A `FOR TESTING` class as `GLOBAL FRIENDS` of a productive class | `ZCL_CA_PARAM_FACTORY` / `ZCL_CA_PARAM_INJECTOR` | activation; fallback: remove `FOR TESTING` from the injector (it stays `CREATE PRIVATE` with static methods only) |
| A9 | `cl_osql_test_environment` with the three customizing tables | `ZCL_CA_PARAM_DAO` tests | ABAP Unit |
| A10 | Business configuration API `CL_BCFG_CD_REUSE_API_FACTORY=>GET_CUST_OBJ_SERVICE_INSTANCE( iv_objectname iv_objecttype )`, constant `SIMPLE_TABLE`, method `IS_EDITABLE` | `ZCL_CA_PARAM_SYSTEM->READ_CLIENT` | open in ADT; fallback: set `cust_editable` from T000 only (then TRANSPORT = not production and automatic recording) |
| A11 | `MBC_CP_API=>RAP_TABLE_CTS( table_entity_relations )->RECORD_CHANGES( transport_request create update delete )` | `ZCL_CA_PARAM_SYSTEM->RECORD_CHANGES` | open in ADT; fallback: `TR_OBJECTS_CHECK` / `TR_OBJECTS_INSERT` with E071K `TABU` keys (VERIFY-SE37) |
| A12 | BDEF: `create ( features : global )` on the root, `draft action ( features : instance ) Edit`, `with additional save` on managed draft entities, `early numbering` of a grandchild (`earlynumbering_cba_value` in the Definition handler), validation trigger `delete` | `ZR_CA_PARAMAREA` | activation of BDEF and behaviour pool; fallback for `delete` triggers: drop them (deletions are then checked only by feature control and the request check of the root) |
| A13 | EML `READ ENTITIES ... IN LOCAL MODE` of the active area in `save_modified` | saver `lsc_zr_ca_paramarea` | manual app test: change only a value, save, check the request object list (SE01); fallback: take the request from `update-area` only and set it by a determination |
| A14 | `RAISE SHORTDUMP` on a recording failure rolls the save back | saver | negative test: release the request between Prepare and Activate |
| A15 | Table function `DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name )` with fields `value_low`, `text`, `language` | `ZI_CA_Param*VH` | activation, value help in the app; fallback: CDS views over `DD07L` / `DD07T` |
| A16 | DCL `pfcg_auth( ZCA_PARAM, ZCA_PARAR, ACTVT = '03' )` on draft-enabled projections | `ZC_CA_PARAM*.dcls` | user without 03 for an area does not see it |
| A17 | Service binding | ADT: *New Service Binding* `ZUI_CA_PARAM_O4`, type *OData V4 - UI*, service definition `ZUI_CA_PARAM`, *Publish*; preview entity `Area` | Fiori elements preview: list, object page, draft, create definition and value |
| A18 | RAP data elements `ABP_CREATION_USER`, `ABP_CREATION_TSTMPL`, `ABP_LASTCHANGE_USER`, `ABP_LASTCHANGE_TSTMPL`, `ABP_LOCINST_LASTCHANGE_TSTMPL`, include `SYCH_BDL_DRAFT_ADMIN_INC` | tables | activation |
| A19 | ABAP Unit of all six test classes (105 tests), coverage | SE80 / ADT | all green; coverage of `ZCL_CA_PARAM`, `ZCL_CA_PARAM_VALIDATOR` >= 90 % |
| A20 | ATC (default variant of DV1) | package `ZCA_PARAM` | no priority 1 / 2 findings |
| A21 | App rules end to end | TRANSPORT client: create area / definition / values with request; QA or production: change a released value, try a developer-owned one (045), try to create a definition (disabled / 044) | as `docs/DESIGN.md` section 8 |

## VERIFY-SE11

| # | Item | Expected |
|---|---|---|
| S1 | Domain of T000-CCCORACTIV | ' ' changes without automatic recording, 1 automatic recording, 2 no changes, 3 no transports (constants `GC_CHANGE_OPTION`) |
| S2 | T000-CCCATEGORY | P = production (`GC_ROLE_PRODUCTION`) |
| S3 | E070-TRSTATUS / TRFUNCTION | D modifiable, L modifiable protected; W customizing request, Q customizing task |
| S4 | Domain `XFELD`, data elements `SEOCLSNAME`, `TRKORR` | exist (standard) |

## Basis

| # | Item | Expected |
|---|---|---|
| B1 | Profile parameter `rec/client` | includes the clients where values change (table logging, SCU3) |
| B2 | Table buffer synchronization `rdisp/bufreftime` | known delay for value changes across application servers (`docs/OPERATIONS.md`) |
