*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_trx_dash_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the transactions dashboard on cl_cds_test_environment
*& doubles of the base tables (DFKKOP, T001, TFK042Z, DPAYH, DFKKCR, FEBEP,
*& DFKKRP, DFKKRK, DFKKNRP, ZCD_PAY_OUTCOME): the flow bucket is the
*& canonical payment outcome (never derived from a bank / encashment line or
*& a returns lot here), not evaluated / offset / posted / reversed without
*& one, proposal runs ignored, the 400-day retention and the FIN filter,
*& the date kinds posting / payment run / value date, the "as of" instant
*& between two versions, direction from TFK042Z-XEINZ, KPI counts incl.
*& distinct FIN numbers per company code (authorisation key passed through,
*& never summed across company codes), the errored / stuck list, returns by
*& DFKKRP-RLGRD and NOCs by DFKKNRP-FLGRD, no partner or member element;
*& and the shared negative fixtures (ZCL_CD_OPS_PAY_FIXTURE) with the
*& outcome the evaluator gives them: retrieval without return, bank line
*& without clearing, two DPAYH runs (one row, values of the latest run),
*& FIN in two sources (one row, AMBIGUOUS). Does not prove live SAP
*& runtime behavior.
*& VERIFY-ADT: create( i_select_base_dependencies = abap_true ) doubles the
*& standard tables behind the view stack on 7.58; $session.system_date is not
*& doubled (test data is built relative to today).
*& Modification log:
*& 2026-11-06 | Initial version (transactions dashboard).
*& 2026-11-06 | Modern-syntax sweep: test helper LTD_ROWS.
*& 2026-11-07 | Canonical payment outcome: buckets from ZCD_PAY_OUTCOME, date kind and as-of
*&            | parameters, shared fixtures and the review defects (settled from a bank line,
*&            | independent MAX of the payment run, ambiguous source, company code of the KPI).
*&---------------------------------------------------------------------*
"! Test data builders: one row per call, filled field by field (house rule)
CLASS ltd_rows DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS gc_company TYPE c LENGTH 4 VALUE 'US01'.
    CONSTANTS gc_company2 TYPE c LENGTH 4 VALUE 'US02'.
    CONSTANTS gc_currency TYPE c LENGTH 5 VALUE 'USD'.
    CONSTANTS gc_method_disb TYPE c LENGTH 1 VALUE 'K'.
    CONSTANTS gc_method_coll TYPE c LENGTH 1 VALUE 'D'.
    CONSTANTS gc_method_chq TYPE c LENGTH 1 VALUE 'C'.

    CLASS-METHODS days_ago
      IMPORTING
        iv_days        TYPE i
      RETURNING
        VALUE(rv_date) TYPE d.

    CLASS-METHODS item
      IMPORTING
        iv_opbel       TYPE clike
        iv_fin         TYPE clike
        iv_augbl       TYPE clike OPTIONAL
        iv_method      TYPE clike DEFAULT gc_method_disb
        iv_days_ago    TYPE i DEFAULT 0
        iv_company     TYPE clike DEFAULT gc_company
      RETURNING
        VALUE(rs_item) TYPE dfkkop.

    "! A current outcome version (written by the snapshot) of an item's payment
    CLASS-METHODS outcome
      IMPORTING
        iv_fin         TYPE clike
        iv_augbl       TYPE clike
        iv_outcome     TYPE zif_cd_ops_payout_types=>ty_outcome
      RETURNING
        VALUE(rs_row)  TYPE zcd_pay_outcome.

    "! Company codes US01 / US02, payment methods (K disbursement, C cheque, D collection, and the
    "! fixture methods E wire / G ACH)
    CLASS-METHODS insert_config
      IMPORTING
        io_env TYPE REF TO if_cds_test_environment.
ENDCLASS.


CLASS ltd_rows IMPLEMENTATION.

  METHOD days_ago.
    rv_date = cl_abap_context_info=>get_system_date( ) - iv_days.
  ENDMETHOD.


  METHOD item.
    rs_item-opbel            = iv_opbel.
    rs_item-bukrs            = iv_company.
    rs_item-budat            = days_ago( iv_days_ago ).
    rs_item-waers            = gc_currency.
    rs_item-pymet            = iv_method.
    rs_item-augbl            = iv_augbl.
    rs_item-zz_fin_trans_num = iv_fin.
  ENDMETHOD.


  METHOD outcome.
    DATA lv_from TYPE timestamp.
    CONVERT DATE days_ago( 1 ) TIME zif_cd_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_from TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
    rs_row-fin_id     = iv_fin.
    rs_row-source     = zcl_cd_ops_pay_fixture=>gc_source-pclm.
    rs_row-bukrs      = gc_company.
    rs_row-augbl      = iv_augbl.
    rs_row-laufd      = days_ago( 0 ).
    rs_row-valid_from = lv_from.
    rs_row-valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open.
    rs_row-outcome    = iv_outcome.
  ENDMETHOD.


  METHOD insert_config.
    DATA lt_t001 TYPE STANDARD TABLE OF t001 WITH EMPTY KEY.
    DATA lt_methods TYPE STANDARD TABLE OF tfk042z WITH EMPTY KEY.
    DATA ls_t001 TYPE t001.
    DATA ls_method TYPE tfk042z.

    ls_t001-bukrs = gc_company.
    ls_t001-land1 = zcl_cd_ops_pay_fixture=>gc_country.
    ls_t001-waers = gc_currency.
    INSERT ls_t001 INTO TABLE lt_t001.
    ls_t001-bukrs = gc_company2.
    INSERT ls_t001 INTO TABLE lt_t001.
    ls_method-land1 = zcl_cd_ops_pay_fixture=>gc_country.
    ls_method-zlsch = gc_method_disb.
    INSERT ls_method INTO TABLE lt_methods.
    ls_method-zlsch = gc_method_chq.
    INSERT ls_method INTO TABLE lt_methods.
    ls_method-zlsch = zcl_cd_ops_pay_fixture=>gc_wire.
    INSERT ls_method INTO TABLE lt_methods.
    ls_method-zlsch = zcl_cd_ops_pay_fixture=>gc_ach.
    INSERT ls_method INTO TABLE lt_methods.
    ls_method-zlsch = gc_method_coll.
    ls_method-xeinz = abap_true.
    INSERT ls_method INTO TABLE lt_methods.
    io_env->insert_test_data( i_data = lt_t001 ).
    io_env->insert_test_data( i_data = lt_methods ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_TRXFLOW / ZR_CD_TRXKPI / ZR_CD_TRXPROBLEM / ZR_CD_TRXRETNOC
CLASS ltc_flow DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_doc,
        posted    TYPE c LENGTH 12 VALUE '100000000001',
        offset    TYPE c LENGTH 12 VALUE '100000000002',
        paid      TYPE c LENGTH 12 VALUE '100000000003',
        settled   TYPE c LENGTH 12 VALUE '100000000004',
        cheque    TYPE c LENGTH 12 VALUE '100000000005',
        returned  TYPE c LENGTH 12 VALUE '100000000006',
        reversed  TYPE c LENGTH 12 VALUE '100000000007',
        proposal  TYPE c LENGTH 12 VALUE '100000000008',
        no_fin    TYPE c LENGTH 12 VALUE '100000000009',
        too_old   TYPE c LENGTH 12 VALUE '100000000010',
        collect   TYPE c LENGTH 12 VALUE '100000000011',
        noc       TYPE c LENGTH 12 VALUE '100000000012',
        overdue   TYPE c LENGTH 12 VALUE '100000000013',
        other_cc  TYPE c LENGTH 12 VALUE '100000000014',
      END OF gc_doc.
    CONSTANTS:
      BEGIN OF gc_pay,
        offset   TYPE c LENGTH 12 VALUE '200000000002',
        paid     TYPE c LENGTH 12 VALUE '200000000003',
        settled  TYPE c LENGTH 12 VALUE '200000000004',
        cheque   TYPE c LENGTH 12 VALUE '200000000005',
        returned TYPE c LENGTH 12 VALUE '200000000006',
        reversed TYPE c LENGTH 12 VALUE '200000000007',
        proposal TYPE c LENGTH 12 VALUE '200000000008',
        noc      TYPE c LENGTH 12 VALUE '200000000012',
      END OF gc_pay.
    CONSTANTS gc_fin TYPE c LENGTH 20 VALUE 'FIN0000000100'.
    CONSTANTS gc_fin_shared TYPE c LENGTH 20 VALUE 'FIN0000000200'.
    CONSTANTS gc_cheque_no TYPE c LENGTH 13 VALUE 'CHK0000000005'.
    CONSTANTS gc_run_id TYPE c LENGTH 6 VALUE 'DISB01'.
    CONSTANTS gc_status TYPE c LENGTH 10 VALUE 'SENT'.
    CONSTANTS gc_reversal TYPE c LENGTH 2 VALUE '05'.
    CONSTANTS gc_return_doc TYPE c LENGTH 12 VALUE '600000000006'.
    CONSTANTS gc_return_reason TYPE c LENGTH 3 VALUE 'R01'.
    CONSTANTS gc_noc_lot TYPE c LENGTH 12 VALUE 'NOC000000012'.
    CONSTANTS gc_noc_item TYPE n LENGTH 6 VALUE '000001'.
    CONSTANTS gc_noc_infof TYPE c LENGTH 50 VALUE '00200000000012'.
    CONSTANTS gc_noc_reason TYPE c LENGTH 3 VALUE 'C01'.
    CONSTANTS gc_esnum TYPE n LENGTH 5 VALUE '00001'.
    CONSTANTS gc_kukey TYPE n LENGTH 8 VALUE '00009001'.
    CONSTANTS gc_days_retained TYPE i VALUE 40.
    CONSTANTS gc_days_expired TYPE i VALUE 401.
    CONSTANTS gc_days_overdue TYPE i VALUE 3.
    CONSTANTS:
      BEGIN OF gc_kind,
        posting TYPE c LENGTH 10 VALUE 'POSTING',
        run     TYPE c LENGTH 10 VALUE 'RUN',
        value   TYPE c LENGTH 10 VALUE 'VALUE',
      END OF gc_kind.
    CONSTANTS:
      BEGIN OF gc_bucket,
        posted        TYPE c LENGTH 20 VALUE 'POSTED',
        offset        TYPE c LENGTH 20 VALUE 'OFFSET',
        not_evaluated TYPE c LENGTH 20 VALUE 'NOT_EVALUATED',
        settled       TYPE c LENGTH 20 VALUE 'SETTLED',
        reversed      TYPE c LENGTH 20 VALUE 'REVERSED',
      END OF gc_bucket.
    CONSTANTS:
      BEGIN OF gc_direction,
        disbursement TYPE c LENGTH 12 VALUE 'DISBURSEMENT',
        collection   TYPE c LENGTH 12 VALUE 'COLLECTION',
      END OF gc_direction.
    CONSTANTS:
      BEGIN OF gc_problem,
        overdue TYPE c LENGTH 20 VALUE 'OPEN_OVERDUE',
      END OF gc_problem.
    CONSTANTS:
      BEGIN OF gc_lot,
        return TYPE c LENGTH 6 VALUE 'RETURN',
        noc    TYPE c LENGTH 6 VALUE 'NOC',
      END OF gc_lot.

    "! Parameters of ZR_CD_TrxFlow for the next select (date kind, day(s), as of)
    TYPES:
      BEGIN OF ty_param,
        kind       TYPE c LENGTH 10,
        from       TYPE d,
        to         TYPE d,
        as_of_date TYPE d,
        as_of_time TYPE t,
      END OF ty_param.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA ms_param TYPE ty_param.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS bucket_is_canonical_outcome FOR TESTING.
    METHODS bank_line_alone_not_settled FOR TESTING.
    METHODS proposal_run_is_not_payment FOR TESTING.
    METHODS retention_and_fin_bound    FOR TESTING.
    METHODS direction_from_tfk042z     FOR TESTING.
    METHODS kpi_counts_distinct_fin    FOR TESTING.
    METHODS kpi_never_mixes_company    FOR TESTING.
    METHODS problems_list_errored_stuck FOR TESTING.
    METHODS reasons_from_lot_items     FOR TESTING.
    METHODS no_partner_or_member_exposed FOR TESTING.
    " shared fixtures (same data and outcome as the evaluator, A_INFLIGHT and the trace)
    METHODS fixture_retrieval_not_return FOR TESTING.
    METHODS fixture_line_inconsistent  FOR TESTING.
    METHODS fixture_two_runs_one_row   FOR TESTING.
    METHODS fixture_two_sources_one_row FOR TESTING.
    METHODS as_of_between_versions     FOR TESTING.
    METHODS date_kind_run_and_value    FOR TESTING.

    "! Rows of a fixture scenario with the outcome the snapshot wrote for it
    METHODS given_fixture
      IMPORTING
        iv_id              TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
        iv_with_outcome    TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_scenario) TYPE zcl_cd_ops_pay_fixture=>ty_scenario.

    "! Parameters of the following selects (default: posting date over the retention, as of now)
    METHODS use_params
      IMPORTING
        iv_kind       TYPE clike DEFAULT gc_kind-posting
        iv_from       TYPE d OPTIONAL
        iv_to         TYPE d OPTIONAL
        iv_as_of_date TYPE d OPTIONAL.

    METHODS bucket_of
      IMPORTING
        iv_opbel         TYPE clike
      RETURNING
        VALUE(rv_bucket) TYPE string.

    METHODS rows_of
      IMPORTING
        iv_opbel       TYPE clike
      RETURNING
        VALUE(rv_rows) TYPE i.
ENDCLASS.


CLASS ltc_flow IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_CD_TRXFLOW' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_TRXKPI' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_TRXPROBLEM' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_TRXRETNOC' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA lt_cheques TYPE STANDARD TABLE OF dfkkcr WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA lt_returns TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA lt_nocs TYPE STANDARD TABLE OF dfkknrp WITH EMPTY KEY.
    DATA lt_outcomes TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA ls_run TYPE dpayh.
    DATA ls_cheque TYPE dfkkcr.
    DATA ls_line TYPE febep.
    DATA ls_return TYPE dfkkrp.
    DATA ls_noc TYPE dfkknrp.

    go_env->clear_doubles( ).
    use_params( ).
    mo_fixture = NEW #( ltd_rows=>days_ago( 0 ) ).
    ltd_rows=>insert_config( go_env ).

    INSERT ltd_rows=>item( iv_opbel = gc_doc-posted iv_fin = gc_fin ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-offset iv_fin = gc_fin iv_augbl = gc_pay-offset ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-paid iv_fin = gc_fin_shared iv_augbl = gc_pay-paid ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-settled iv_fin = gc_fin_shared iv_augbl = gc_pay-settled ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel  = gc_doc-cheque iv_fin = gc_fin iv_augbl = gc_pay-cheque
                           iv_method = ltd_rows=>gc_method_chq ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-returned iv_fin = gc_fin iv_augbl = gc_pay-returned ) INTO TABLE lt_items.
    DATA(ls_reversed) = ltd_rows=>item( iv_opbel = gc_doc-reversed iv_fin = gc_fin iv_augbl = gc_pay-reversed ).
    ls_reversed-augrd = gc_reversal.
    INSERT ls_reversed INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-proposal iv_fin = gc_fin iv_augbl = gc_pay-proposal ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-no_fin iv_fin = space ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-too_old iv_fin = gc_fin iv_days_ago = gc_days_expired ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-collect iv_fin = gc_fin iv_method = ltd_rows=>gc_method_coll
                           iv_days_ago = gc_days_overdue ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-noc iv_fin = gc_fin iv_augbl = gc_pay-noc ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-overdue iv_fin = gc_fin iv_days_ago = gc_days_overdue ) INTO TABLE lt_items.

    ls_run-laufd = ltd_rows=>days_ago( 0 ).
    ls_run-laufi = gc_run_id.
    ls_run-zz_payment_status = gc_status.
    ls_run-doc1r = gc_pay-paid.
    INSERT ls_run INTO TABLE lt_runs.
    ls_run-doc1r = gc_pay-settled.
    INSERT ls_run INTO TABLE lt_runs.
    ls_run-doc1r = gc_pay-returned.
    INSERT ls_run INTO TABLE lt_runs.
    ls_run-doc1r = gc_pay-proposal.
    ls_run-xvorl = abap_true.
    INSERT ls_run INTO TABLE lt_runs.

    ls_cheque-doc1r = gc_pay-cheque.
    ls_cheque-ztnum = gc_cheque_no.
    INSERT ls_cheque INTO TABLE lt_cheques.

    " A bank line on the paid item's payment and on the cheque: evidence shown, never a bucket
    ls_line-kukey = gc_kukey.
    ls_line-esnum = gc_esnum.
    ls_line-budat = ltd_rows=>days_ago( 0 ).
    ls_line-chect = gc_pay-paid.
    INSERT ls_line INTO TABLE lt_lines.
    ls_line-esnum = gc_esnum + 1.
    ls_line-chect = gc_cheque_no.
    INSERT ls_line INTO TABLE lt_lines.

    ls_return-selw1 = gc_pay-returned.
    ls_return-opbel = gc_return_doc.
    ls_return-rlgrd = gc_return_reason.
    INSERT ls_return INTO TABLE lt_returns.
    ls_noc-keyn1 = gc_noc_lot.
    ls_noc-posna = gc_noc_item.
    ls_noc-infof = gc_noc_infof.
    ls_noc-flgrd = gc_noc_reason.
    INSERT ls_noc INTO TABLE lt_nocs.

    " The canonical outcome the snapshot wrote: settled payment CLEARED, returned payment RETURNED
    INSERT ltd_rows=>outcome( iv_fin = gc_fin_shared iv_augbl = gc_pay-settled
                              iv_outcome = zif_cd_ops_payout_types=>gc_outcome-cleared ) INTO TABLE lt_outcomes.
    INSERT ltd_rows=>outcome( iv_fin = gc_fin iv_augbl = gc_pay-returned
                              iv_outcome = zif_cd_ops_payout_types=>gc_outcome-returned ) INTO TABLE lt_outcomes.

    go_env->insert_test_data( i_data = lt_items ).
    go_env->insert_test_data( i_data = lt_runs ).
    go_env->insert_test_data( i_data = lt_cheques ).
    go_env->insert_test_data( i_data = lt_lines ).
    go_env->insert_test_data( i_data = lt_returns ).
    go_env->insert_test_data( i_data = lt_nocs ).
    go_env->insert_test_data( i_data = lt_outcomes ).
  ENDMETHOD.


  METHOD given_fixture.
    rs_scenario = mo_fixture->scenario( iv_id ).
    go_env->insert_test_data( i_data = mo_fixture->dfkkop_rows( rs_scenario ) ).
    go_env->insert_test_data( i_data = mo_fixture->dpayh_rows( rs_scenario ) ).
    go_env->insert_test_data( i_data = mo_fixture->febep_rows( rs_scenario ) ).
    IF iv_with_outcome = abap_true.
      DATA lv_from TYPE timestamp.
      CONVERT DATE ltd_rows=>days_ago( 1 ) TIME zif_cd_ops_types=>gc_time-day_start
        INTO TIME STAMP lv_from TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
      go_env->insert_test_data( i_data = mo_fixture->outcome_rows( is_scenario = rs_scenario iv_valid_from = lv_from ) ).
    ENDIF.
  ENDMETHOD.


  METHOD use_params.
    ms_param-kind       = iv_kind.
    ms_param-from       = COND #( WHEN iv_from IS INITIAL THEN ltd_rows=>days_ago( gc_days_expired ) ELSE iv_from ).
    ms_param-to         = COND #( WHEN iv_to IS INITIAL THEN ltd_rows=>days_ago( 0 ) ELSE iv_to ).
    ms_param-as_of_date = COND #( WHEN iv_as_of_date IS INITIAL THEN ltd_rows=>days_ago( 0 ) ELSE iv_as_of_date ).
    " End of the day: no version starts in the future, so the version valid then is the current one
    ms_param-as_of_time = zif_cd_ops_types=>gc_time-day_end.
  ENDMETHOD.


  METHOD bucket_of.
    SELECT SINGLE flowbucket
      FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to,
                          p_asofdate = @ms_param-as_of_date, p_asoftime = @ms_param-as_of_time )
      WHERE documentno = @iv_opbel
      INTO @DATA(lv_bucket).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |Item { iv_opbel } must be on the dashboard| ).
    rv_bucket = condense( lv_bucket ).
  ENDMETHOD.


  METHOD rows_of.
    SELECT COUNT(*)
      FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to,
                          p_asofdate = @ms_param-as_of_date, p_asoftime = @ms_param-as_of_time )
      WHERE documentno = @iv_opbel
      INTO @rv_rows.
  ENDMETHOD.


  " Rule: the bucket is the canonical outcome when one is valid; without one: not evaluated
  " (payment run / cheque), offset, posted, reversed (clearing reason 05)
  METHOD bucket_is_canonical_outcome.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-posted ) exp = gc_bucket-posted
                                            msg = 'No clearing document: POSTED (open)' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-offset ) exp = gc_bucket-offset
                                            msg = 'Cleared without payment run: OFFSET' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-settled )
                                            exp = CONV string( zif_cd_ops_payout_types=>gc_outcome-cleared )
                                            msg = 'Outcome CLEARED written by the snapshot' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-returned )
                                            exp = CONV string( zif_cd_ops_payout_types=>gc_outcome-returned )
                                            msg = 'Outcome RETURNED' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-cheque ) exp = gc_bucket-not_evaluated
                                            msg = 'Cheque without outcome: NOT_EVALUATED' ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-reversed ) exp = gc_bucket-reversed
                                            msg = 'Clearing reason 05: REVERSED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Review defect: SETTLED came from any bank or encashment line. A bank line alone is evidence,
  " not a verdict - without an outcome the payment is NOT_EVALUATED, never SETTLED or CLEARED
  METHOD bank_line_alone_not_settled.
    TRY.
        DATA(lv_bucket) = bucket_of( gc_doc-paid ).
        cl_abap_unit_assert=>assert_equals( act = lv_bucket exp = gc_bucket-not_evaluated
                                            msg = 'Bank line without outcome: NOT_EVALUATED' ).
        cl_abap_unit_assert=>assert_differs( act = lv_bucket exp = gc_bucket-settled msg = 'Never SETTLED from a line' ).
        cl_abap_unit_assert=>assert_differs( act = bucket_of( gc_doc-cheque ) exp = gc_bucket-settled
                                             msg = 'An encashment line is no verdict either' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD proposal_run_is_not_payment.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = bucket_of( gc_doc-proposal ) exp = gc_bucket-offset
                                            msg = 'A proposal run (XVORL) is never payment evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: items without FIN are no transactions; any day of the 400-day retention can be chosen,
  " an item posted 401 days ago is outside
  METHOD retention_and_fin_bound.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    TRY.
        INSERT ltd_rows=>item( iv_opbel = gc_doc-other_cc iv_fin = gc_fin iv_days_ago = gc_days_retained ) INTO TABLE lt_items.
        go_env->insert_test_data( i_data = lt_items ).
        DATA(lv_day) = ltd_rows=>days_ago( gc_days_retained ).
        use_params( iv_from = lv_day iv_to = lv_day ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_doc-other_cc ) exp = 1 msg = 'A day 40 days ago can be chosen' ).
        use_params( iv_from = ltd_rows=>days_ago( 0 ) iv_to = ltd_rows=>days_ago( 0 ) ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_doc-no_fin ) exp = 0
                                            msg = 'Items without FIN are not transactions' ).
        use_params( iv_from = ltd_rows=>days_ago( gc_days_expired ) iv_to = ltd_rows=>days_ago( gc_days_expired ) ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_doc-too_old ) exp = 0 msg = 'Outside the 400-day retention' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD direction_from_tfk042z.
    TRY.
        SELECT documentno, direction
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to,
                              p_asofdate = @ms_param-as_of_date, p_asoftime = @ms_param-as_of_time )
          WHERE documentno = @gc_doc-collect OR documentno = @gc_doc-posted
          ORDER BY documentno
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_rows[ documentno = gc_doc-collect ]-direction OPTIONAL )
                                            exp = gc_direction-collection msg = 'TFK042Z-XEINZ = X is a collection' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_rows[ documentno = gc_doc-posted ]-direction OPTIONAL )
                                            exp = gc_direction-disbursement msg = 'XEINZ blank is a disbursement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD kpi_counts_distinct_fin.
    TRY.
        SELECT SINGLE itemcount, fincount, paidreachedcount, clearedcount, returnedcount, reversedcount,
                      notevaluatedcount
          FROM zr_cd_trxkpi
          WHERE postingdate = @( ltd_rows=>days_ago( 0 ) )
            AND companycode = @ltd_rows=>gc_company
            AND direction   = @gc_direction-disbursement
          INTO @DATA(ls_kpi).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'A KPI row for today, US01, disbursements' ).
        " Today, disbursement: posted, offset, paid, settled, cheque, returned, reversed, proposal, noc
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-itemcount exp = 9 msg = 'Nine transactions today' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-fincount exp = 2
                                            msg = 'Two FIN numbers - the shared FIN counts once' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-paidreachedcount exp = 4
                                            msg = 'Paid: paid, settled, returned (runs) and the cheque' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-clearedcount exp = 1 msg = 'Cleared: the canonical outcome only' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-returnedcount exp = 1 msg = 'One returned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-reversedcount exp = 1 msg = 'One reversed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-notevaluatedcount exp = 2
                                            msg = 'Paid and cheque without an outcome' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Authorisation before aggregation: the KPI company code is a GROUP BY key of the base rows, so
  " an item of another company code is never summed into a row of US01 (the DCL filters that key)
  METHOD kpi_never_mixes_company.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    TRY.
        INSERT ltd_rows=>item( iv_opbel = gc_doc-other_cc iv_fin = gc_fin iv_company = ltd_rows=>gc_company2 )
          INTO TABLE lt_items.
        go_env->insert_test_data( i_data = lt_items ).
        SELECT companycode, itemcount, fincount
          FROM zr_cd_trxkpi
          WHERE postingdate = @( ltd_rows=>days_ago( 0 ) )
            AND direction   = @gc_direction-disbursement
          ORDER BY companycode
          INTO TABLE @DATA(lt_kpi).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_kpi ) exp = 2 msg = 'One row per company code' ).
        cl_abap_unit_assert=>assert_equals( act = lt_kpi[ companycode = ltd_rows=>gc_company ]-itemcount exp = 9
                                            msg = 'US01 counts only its own items' ).
        cl_abap_unit_assert=>assert_equals( act = lt_kpi[ companycode = ltd_rows=>gc_company2 ]-itemcount exp = 1
                                            msg = 'The US02 item stays in the US02 row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD problems_list_errored_stuck.
    TRY.
        SELECT documentno, problemtype FROM zr_cd_trxproblem ORDER BY documentno INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3
                                            msg = 'Returned, reversed and the overdue open disbursement' ).
        cl_abap_unit_assert=>assert_equals(
          act = condense( VALUE #( lt_rows[ documentno = gc_doc-returned ]-problemtype OPTIONAL ) )
          exp = CONV string( zif_cd_ops_payout_types=>gc_outcome-returned )
          msg = 'The returned payment (canonical outcome) is listed' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_rows[ documentno = gc_doc-overdue ]-problemtype OPTIONAL ) exp = gc_problem-overdue
          msg = 'An open disbursement posted 3 days ago is overdue' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ documentno = gc_doc-collect ] ) )
                                           msg = 'An open collection is not overdue' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ documentno = gc_doc-posted ] ) )
                                           msg = 'An item posted today is not overdue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD reasons_from_lot_items.
    TRY.
        SELECT documentno, lotkind, reason FROM zr_cd_trxretnoc ORDER BY documentno INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One return, one NOC' ).
        DATA(ls_return) = VALUE #( lt_rows[ lotkind = gc_lot-return ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_return-documentno exp = gc_doc-returned
                                            msg = 'Return linked by DFKKRP-SELW1 = AUGBL' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_return-reason ) exp = gc_return_reason
                                            msg = 'Return reason from DFKKRP-RLGRD' ).
        DATA(ls_noc) = VALUE #( lt_rows[ lotkind = gc_lot-noc ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_noc-documentno exp = gc_doc-noc
                                            msg = 'NOC linked by INFOF (leading zeros) = AUGBL' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_noc-reason ) exp = gc_noc_reason
                                            msg = 'NOC reason from DFKKNRP-FLGRD' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_partner_or_member_exposed.
    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( 'ZR_CD_TRXFLOW' ) ).
        DATA(lt_names) = VALUE string_table( FOR ls_comp IN lo_struct->components ( CONV #( ls_comp-name ) ) ).
        LOOP AT VALUE string_table( ( `GPART` ) ( `VKONT` ) ( `ZZ_MEMBER_NO` ) ( `BANKN` ) ( `IBAN` ) )
             INTO DATA(lv_forbidden).
          cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_names[ table_line = lv_forbidden ] ) )
                                             msg = |{ lv_forbidden } must never be an element of the dashboard| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture: a retrieval is shown RETRIEVED, never RETURNED (same outcome as the evaluator)
  METHOD fixture_retrieval_not_return.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-retrieval ).
        DATA(lv_bucket) = bucket_of( ls_scenario-opbel ).
        cl_abap_unit_assert=>assert_equals( act = lv_bucket exp = CONV string( ls_scenario-expected )
                                            msg = 'RETRIEVED' ).
        cl_abap_unit_assert=>assert_differs( act = lv_bucket exp = CONV string( zif_cd_ops_payout_types=>gc_outcome-returned )
                                             msg = 'Never RETURNED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture: the wire on the statement without DPAYH status CLEARED is INCONSISTENT
  METHOD fixture_line_inconsistent.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-bank_line ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( ls_scenario-opbel ) exp = CONV string( ls_scenario-expected )
                                            msg = 'INCONSISTENT, not settled' ).
        SELECT COUNT(*) FROM zr_cd_trxproblem WHERE documentno = @ls_scenario-opbel INTO @DATA(lv_listed).
        cl_abap_unit_assert=>assert_equals( act = lv_listed exp = 1 msg = 'On the errored / stuck list' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Review defect: MAX( laufd ), MAX( laufi ), MAX( status ) mixed two runs. One row; run date, run
  " ID, value date and status all of the latest run
  METHOD fixture_two_runs_one_row.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        SELECT lastrundate, lastrunid, valuedate, paymentstatus, flowbucket
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to,
                              p_asofdate = @ms_param-as_of_date, p_asoftime = @ms_param-as_of_time )
          WHERE documentno = @ls_scenario-opbel
          ORDER BY documentno
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row for two runs' ).
        DATA(lt_runs) = ls_scenario-runs.
        SORT lt_runs BY laufd DESCENDING laufi DESCENDING.
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-lastrundate exp = lt_runs[ 1 ]-laufd msg = 'Latest run date' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-lastrunid exp = lt_runs[ 1 ]-laufi msg = 'Its run ID' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-valuedate exp = lt_runs[ 1 ]-valut msg = 'Its value date' ).
        cl_abap_unit_assert=>assert_equals( act = condense( lt_rows[ 1 ]-paymentstatus ) exp = condense( lt_runs[ 1 ]-status )
                                            msg = 'Its status' ).
        cl_abap_unit_assert=>assert_equals( act = condense( lt_rows[ 1 ]-flowbucket ) exp = CONV string( ls_scenario-expected )
                                            msg = 'CLEARED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture: a FIN in two sources has two versions (one per source), the item shows one
  " row, AMBIGUOUS, with two sources - never one source picked, never two rows
  METHOD fixture_two_sources_one_row.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources ).
        SELECT flowbucket, outcomesourcecount, outcomefinding
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to,
                              p_asofdate = @ms_param-as_of_date, p_asoftime = @ms_param-as_of_time )
          WHERE documentno = @ls_scenario-opbel
          ORDER BY documentno
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row for the item' ).
        cl_abap_unit_assert=>assert_equals( act = condense( lt_rows[ 1 ]-flowbucket ) exp = CONV string( ls_scenario-expected )
                                            msg = 'AMBIGUOUS' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcomesourcecount exp = 2 msg = 'Two sources' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcomefinding exp = zif_cd_ops_payout_types=>gc_code-source_ambiguous
                                            msg = 'With the finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " "As of": between the two versions the earlier outcome is shown, now the current one
  METHOD as_of_between_versions.
    DATA lv_first TYPE timestamp.
    DATA lv_second TYPE timestamp.
    TRY.
        DATA(ls_scenario) = given_fixture( iv_id           = zcl_cd_ops_pay_fixture=>gc_scenario-two_runs
                                           iv_with_outcome = abap_false ).
        CONVERT DATE ltd_rows=>days_ago( 3 ) TIME zif_cd_ops_types=>gc_time-day_start
          INTO TIME STAMP lv_first TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
        CONVERT DATE ltd_rows=>days_ago( 1 ) TIME zif_cd_ops_types=>gc_time-day_start
          INTO TIME STAMP lv_second TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
        go_env->insert_test_data( i_data = mo_fixture->history( iv_first = lv_first iv_second = lv_second ) ).
        use_params( iv_as_of_date = ltd_rows=>days_ago( 2 ) ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( ls_scenario-opbel )
                                            exp = CONV string( zif_cd_ops_payout_types=>gc_outcome-in_flight )
                                            msg = 'Two days ago: the first version' ).
        use_params( ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( ls_scenario-opbel ) exp = CONV string( ls_scenario-expected )
                                            msg = 'Now: the current version' ).
        use_params( iv_as_of_date = ltd_rows=>days_ago( 5 ) ).
        cl_abap_unit_assert=>assert_equals( act = bucket_of( ls_scenario-opbel ) exp = gc_bucket-not_evaluated
                                            msg = 'Before the first version (go-live): not evaluated' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Date kinds: the payment run date is the latest run's (an older run's date finds nothing), the
  " value date is that run's value date
  METHOD date_kind_run_and_value.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        DATA(lt_runs) = ls_scenario-runs.
        SORT lt_runs BY laufd DESCENDING laufi DESCENDING.
        DATA(ls_latest) = lt_runs[ 1 ].
        DATA(ls_older) = lt_runs[ 2 ].
        use_params( iv_kind = gc_kind-run iv_from = ls_latest-laufd iv_to = ls_latest-laufd ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( ls_scenario-opbel ) exp = 1 msg = 'Run date of the latest run' ).
        use_params( iv_kind = gc_kind-run iv_from = ls_older-laufd iv_to = ls_older-laufd ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( ls_scenario-opbel ) exp = 0
                                            msg = 'The older run does not select the payment' ).
        use_params( iv_kind = gc_kind-value iv_from = ls_latest-valut iv_to = ls_latest-valut ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( ls_scenario-opbel ) exp = 1 msg = 'Value date of the latest run' ).
        use_params( iv_kind = gc_kind-posting iv_from = ls_latest-laufd iv_to = ls_latest-laufd ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( ls_scenario-opbel ) exp = 0 msg = 'Posting date is another day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
