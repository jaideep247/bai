*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_trx_req_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the request side of the transactions dashboard on
*& cl_cds_test_environment doubles of ZCD_PAYM_REQ_LOG (fields as the
*& placeholders of ZI_CD_TrxReqLog - align them with SE11 together with the
*& view) and of the SAP side and outcome tables: the SUCCESS row rule (any
*& SUCCESS attempt, whatever COUNTER a later failed attempt has, also a
*& SUCCESS older than the request date window), errored and pending
*& requests, the member number never in the view; and the shared negative
*& fixtures (ZCL_CD_OPS_PAY_FIXTURE) with the outcome the evaluator gives
*& them: a retrieval is RETRIEVED (never RETURNED), a FIN in two sources is
*& AMBIGUOUS for both, a FIN paid in two company codes is two rows (the
*& company-code authorisation applies to the row's own items).
*& Not executed offline; created in ADT after SE11 confirmation.
*& Modification log:
*& 2026-11-06 | Initial version (transactions dashboard, request side).
*& 2026-11-07 | Canonical payment outcome and review defects: window after the SUCCESS rule,
*&            | retrieval not a return, ambiguous source, identity FIN + source + company code.
*& 2026-11-08 | Exceptions-only worklist: a clean final payment has no worklist row - its stage
*&            | is the evidence stage (PAID); the retrieval is shown, never RETURNED.
*&---------------------------------------------------------------------*
"! ZI_CD_TRXREQUEST / ZR_CD_TRXREQFLOW
CLASS ltc_request DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_fin,
        retry_after  TYPE c LENGTH 20 VALUE 'FIN0000000001',
        errored      TYPE c LENGTH 20 VALUE 'FIN0000000002',
        pending      TYPE c LENGTH 20 VALUE 'FIN0000000003',
        two_company  TYPE c LENGTH 20 VALUE 'FIN0000000004',
      END OF gc_fin.
    CONSTANTS gc_source TYPE c LENGTH 10 VALUE 'PCLM'.
    CONSTANTS:
      BEGIN OF gc_status,
        success  TYPE c LENGTH 20 VALUE 'SUCCESS',
        failed   TYPE c LENGTH 20 VALUE 'FAILED',
        received TYPE c LENGTH 20 VALUE 'RECEIVED',
      END OF gc_status.
    CONSTANTS:
      BEGIN OF gc_outcome,
        processed TYPE c LENGTH 10 VALUE 'PROCESSED',
        errored   TYPE c LENGTH 10 VALUE 'ERRORED',
        pending   TYPE c LENGTH 10 VALUE 'PENDING',
      END OF gc_outcome.
    CONSTANTS gc_member TYPE c LENGTH 20 VALUE '000123456789'.
    CONSTANTS gc_member_field TYPE string VALUE `ZZ_MEMBER_NO`.
    CONSTANTS gc_company2 TYPE c LENGTH 4 VALUE 'US02'.
    CONSTANTS gc_item2 TYPE c LENGTH 12 VALUE '100000000042'.
    CONSTANTS gc_item1 TYPE c LENGTH 12 VALUE '100000000041'.
    CONSTANTS gc_rtrv_status TYPE c LENGTH 20 VALUE 'RETRIEVED'.
    "! Stage of a paid request without worklist row (clean final payment)
    CONSTANTS gc_stage_paid TYPE c LENGTH 20 VALUE 'PAID'.

    TYPES:
      BEGIN OF ty_param,
        from       TYPE d,
        to         TYPE d,
        "! Day of the worklist rows of the fixture (written the day before)
        as_of_date TYPE d,
      END OF ty_param.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    DATA mt_log TYPE STANDARD TABLE OF zcd_paym_req_log WITH EMPTY KEY.
    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA ms_param TYPE ty_param.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS success_row_wins_over_counter FOR TESTING.
    METHODS errored_without_success_row FOR TESTING.
    METHODS pending_without_outcome FOR TESTING.
    METHODS member_number_not_exposed FOR TESTING.
    METHODS success_older_than_window FOR TESTING.
    METHODS retrieval_is_not_returned FOR TESTING.
    METHODS fin_two_sources_ambiguous FOR TESTING.
    METHODS one_row_per_company_code FOR TESTING.

    METHODS add_attempt
      IMPORTING
        iv_fin     TYPE csequence
        iv_counter TYPE i
        iv_status  TYPE csequence
        iv_date    TYPE d OPTIONAL
        iv_source  TYPE csequence DEFAULT gc_source.
    "! Rows of a fixture scenario: request log, open item, payment runs, the snapshot's outcome
    METHODS given_fixture
      IMPORTING
        iv_id              TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
      RETURNING
        VALUE(rs_scenario) TYPE zcl_cd_ops_pay_fixture=>ty_scenario.
    METHODS outcome_of
      IMPORTING
        iv_fin            TYPE csequence
      RETURNING
        VALUE(rv_outcome) TYPE string.
ENDCLASS.


CLASS ltc_request IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZI_CD_TRXREQUEST' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_TRXREQFLOW' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_t001 TYPE STANDARD TABLE OF t001 WITH EMPTY KEY.
    DATA ls_t001 TYPE t001.
    DATA lt_methods TYPE STANDARD TABLE OF tfk042z WITH EMPTY KEY.
    DATA ls_method TYPE tfk042z.
    go_env->clear_doubles( ).
    CLEAR mt_log.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    mo_fixture = NEW #( lv_today ).
    ms_param-from       = lv_today.
    ms_param-to         = lv_today.
    ms_param-as_of_date = lv_today.
    ls_t001-bukrs = zcl_cd_ops_pay_fixture=>gc_bukrs.
    ls_t001-land1 = zcl_cd_ops_pay_fixture=>gc_country.
    INSERT ls_t001 INTO TABLE lt_t001.
    ls_t001-bukrs = gc_company2.
    INSERT ls_t001 INTO TABLE lt_t001.
    ls_method-land1 = zcl_cd_ops_pay_fixture=>gc_country.
    ls_method-zlsch = zcl_cd_ops_pay_fixture=>gc_wire.
    INSERT ls_method INTO TABLE lt_methods.
    ls_method-zlsch = zcl_cd_ops_pay_fixture=>gc_ach.
    INSERT ls_method INTO TABLE lt_methods.
    go_env->insert_test_data( i_data = lt_t001 ).
    go_env->insert_test_data( i_data = lt_methods ).
    " SUCCESS at counter 1, a failed retry written later at counter 2: still processed
    add_attempt( iv_fin = gc_fin-retry_after iv_counter = 1 iv_status = gc_status-success ).
    add_attempt( iv_fin = gc_fin-retry_after iv_counter = 2 iv_status = gc_status-failed ).
    add_attempt( iv_fin = gc_fin-errored iv_counter = 1 iv_status = gc_status-failed ).
    add_attempt( iv_fin = gc_fin-pending iv_counter = 1 iv_status = gc_status-received ).
    go_env->insert_test_data( i_data = mt_log ).
    CLEAR mt_log.
  ENDMETHOD.


  METHOD add_attempt.
    DATA ls_row TYPE zcd_paym_req_log.
    " VERIFY-SE11: same placeholder fields as ZI_CD_TrxReqLog (FIN, request date)
    ls_row-zz_fin_trans_num = iv_fin.
    ls_row-source           = iv_source.
    ls_row-counter          = iv_counter.
    ls_row-zz_status        = iv_status.
    ls_row-zz_created_on    = COND #( WHEN iv_date IS INITIAL THEN cl_abap_context_info=>get_system_date( ) ELSE iv_date ).
    ls_row-zz_member_no     = gc_member.
    INSERT ls_row INTO TABLE mt_log.
  ENDMETHOD.


  METHOD given_fixture.
    DATA lv_from TYPE timestamp.
    rs_scenario = mo_fixture->scenario( iv_id ).
    LOOP AT rs_scenario-requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      add_attempt( iv_fin     = <ls_request>-fin
                   iv_counter = <ls_request>-counter
                   iv_status  = <ls_request>-status
                   iv_date    = <ls_request>-request_date
                   iv_source  = <ls_request>-source ).
    ENDLOOP.
    go_env->insert_test_data( i_data = mt_log ).
    CLEAR mt_log.
    go_env->insert_test_data( i_data = mo_fixture->dfkkop_rows( rs_scenario ) ).
    go_env->insert_test_data( i_data = mo_fixture->dpayh_rows( rs_scenario ) ).
    CONVERT DATE ms_param-as_of_date - 1 TIME zif_cd_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_from TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
    go_env->insert_test_data( i_data = mo_fixture->outcome_rows( is_scenario = rs_scenario iv_valid_from = lv_from ) ).
    " The request date window covers every attempt of the scenario
    LOOP AT rs_scenario-requests ASSIGNING <ls_request>.
      ms_param-from = nmin( val1 = ms_param-from val2 = <ls_request>-request_date ).
    ENDLOOP.
  ENDMETHOD.


  METHOD outcome_of.
    SELECT SINGLE requestoutcome FROM zi_cd_trxrequest WHERE finid = @iv_fin INTO @DATA(lv_outcome).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |Request { iv_fin } must be listed| ).
    rv_outcome = condense( lv_outcome ).
  ENDMETHOD.


  METHOD success_row_wins_over_counter.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = outcome_of( gc_fin-retry_after ) exp = gc_outcome-processed
                                            msg = 'A SUCCESS row counts, never the highest COUNTER' ).
        SELECT SINGLE attemptcount, successattempts FROM zi_cd_trxrequest
          WHERE finid = @gc_fin-retry_after INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The request must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-attemptcount exp = 2 msg = 'Both attempts are counted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-successattempts exp = 1 msg = 'One SUCCESS attempt' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD errored_without_success_row.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = outcome_of( gc_fin-errored ) exp = gc_outcome-errored
                                            msg = 'No SUCCESS row and a failure value: ERRORED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD pending_without_outcome.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = outcome_of( gc_fin-pending ) exp = gc_outcome-pending
                                            msg = 'Neither SUCCESS nor failure: PENDING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD member_number_not_exposed.
    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( 'ZR_CD_TRXREQFLOW' ) ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( lo_struct->components[ name = gc_member_field ] ) )
          msg = 'The member number is never an element of the request funnel' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Review defect: the 30-day window ran before the SUCCESS rule and erased an older SUCCESS. A
  " request selected by today's failed retry is still PROCESSED (SUCCESS 40 days ago)
  METHOD success_older_than_window.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        " Only today is chosen: the request is selected by its failed retry of today
        ms_param-from = ms_param-to.
        SELECT requestoutcome, requeststage
          FROM zr_cd_trxreqflow( p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @ls_scenario-fin
          ORDER BY sourcesystem
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'The request is listed' ).
        cl_abap_unit_assert=>assert_equals( act = condense( lt_rows[ 1 ]-requestoutcome ) exp = gc_outcome-processed
                                            msg = 'SUCCESS 40 days ago still counts: PROCESSED' ).
        cl_abap_unit_assert=>assert_equals( act = condense( lt_rows[ 1 ]-requeststage ) exp = condense( gc_stage_paid )
                                            msg = 'Cleared: no worklist row, stage PAID' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Review defect: RETURNED when IsReturned > 0 OR RetrievalCount > 0. A retrieval (logged in
  " ZCD_ACH_RTRV_LOG) is shown, never a return; RETRIEVED is final, so no worklist row
  METHOD retrieval_is_not_returned.
    DATA lt_rtrv TYPE STANDARD TABLE OF zcd_ach_rtrv_log WITH EMPTY KEY.
    DATA ls_rtrv TYPE zcd_ach_rtrv_log.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-retrieval ).
        ls_rtrv-augbl           = ls_scenario-augbl.
        ls_rtrv-zz_rtrvl_status = gc_rtrv_status.
        INSERT ls_rtrv INTO TABLE lt_rtrv.
        go_env->insert_test_data( i_data = lt_rtrv ).
        SELECT requeststage, retrievalstatus, exceptioncount
          FROM zr_cd_trxreqflow( p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @ls_scenario-fin
          ORDER BY sourcesystem
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One request row' ).
        cl_abap_unit_assert=>assert_differs( act = condense( lt_rows[ 1 ]-requeststage )
                                             exp = CONV string( zif_cd_ops_payout_types=>gc_outcome-returned )
                                             msg = 'Never RETURNED' ).
        cl_abap_unit_assert=>assert_equals( act = condense( lt_rows[ 1 ]-retrievalstatus ) exp = condense( gc_rtrv_status )
                                            msg = 'The retrieval is shown' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-exceptioncount exp = 0
                                            msg = 'RETRIEVED is final: no worklist exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A FIN with SUCCESS rows in two sources: both requests AMBIGUOUS - never one picked
  METHOD fin_two_sources_ambiguous.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources ).
        SELECT sourcesystem, requeststage, sourcecount
          FROM zr_cd_trxreqflow( p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @ls_scenario-fin
          ORDER BY sourcesystem
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One row per source' ).
        LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
          cl_abap_unit_assert=>assert_equals( act = condense( <ls_row>-requeststage ) exp = CONV string( ls_scenario-expected )
                                              msg = |{ <ls_row>-sourcesystem }: AMBIGUOUS| ).
          cl_abap_unit_assert=>assert_equals( act = <ls_row>-sourcecount exp = 2 msg = 'Two sources' ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Review defect: grouped by FIN only with MAX( CompanyCode ) - a FIN with items in two company
  " codes is now two rows, each with its own company code (the DCL key of the row)
  METHOD one_row_per_company_code.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    DATA ls_item TYPE dfkkop.
    TRY.
        add_attempt( iv_fin = gc_fin-two_company iv_counter = 1 iv_status = gc_status-success ).
        go_env->insert_test_data( i_data = mt_log ).
        ls_item-opbel            = gc_item1.
        ls_item-bukrs            = zcl_cd_ops_pay_fixture=>gc_bukrs.
        ls_item-budat            = ms_param-to.
        ls_item-pymet            = zcl_cd_ops_pay_fixture=>gc_wire.
        ls_item-zz_fin_trans_num = gc_fin-two_company.
        INSERT ls_item INTO TABLE lt_items.
        ls_item-opbel = gc_item2.
        ls_item-bukrs = gc_company2.
        INSERT ls_item INTO TABLE lt_items.
        go_env->insert_test_data( i_data = lt_items ).
        SELECT companycode
          FROM zr_cd_trxreqflow( p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @gc_fin-two_company
          ORDER BY companycode
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One row per company code' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-companycode exp = gc_company2 msg = 'US02 row of its own' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
