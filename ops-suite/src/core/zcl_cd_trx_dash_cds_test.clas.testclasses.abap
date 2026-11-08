*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_trx_dash_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the transactions dashboard on cl_cds_test_environment
*& doubles of the base tables (ZCD_PAY_OUTCOME, DPAYH, T001, TFK042Z,
*& DFKKOP, DFKKRP, DFKKNRP): the rows are the current rows of the payment
*& worklist only (a closed version is never shown, a clean payment has no
*& row), kind PAYMENT / REQUEST and the worklist date (run date / due date),
*& the date kinds WORKLIST / RUN / VALUE / DUE, proposal runs not joined,
*& direction from TFK042Z-XEINZ, open / exception counts and criticality,
*& KPI counts incl. distinct FIN numbers per company code (authorisation
*& key passed through, never summed across company codes), the errored /
*& stuck list = the exceptions, returns by DFKKRP-RLGRD and NOCs by
*& DFKKNRP-FLGRD, no partner or member element; and the shared negative
*& fixtures (ZCL_CD_OPS_PAY_FIXTURE) with the worklist rows the snapshot
*& writes for them: retrieval (final, no row), bank line without clearing
*& (INCONSISTENT exception), FIN in two sources (one AMBIGUOUS row per
*& source). Does not prove live SAP runtime behavior.
*& VERIFY-ADT: create( i_select_base_dependencies = abap_true ) doubles the
*& standard tables behind the view stack on 7.58; $session.system_date is not
*& doubled (test data is built relative to today).
*& Modification log:
*& 2026-11-06 | Initial version (transactions dashboard).
*& 2026-11-06 | Modern-syntax sweep: test helper LTD_ROWS.
*& 2026-11-07 | Canonical payment outcome: buckets from ZCD_PAY_OUTCOME, date kind and as-of
*&            | parameters, shared fixtures and the review defects (settled from a bank line,
*&            | independent MAX of the payment run, ambiguous source, company code of the KPI).
*& 2026-11-08 | Exceptions-only worklist: rows, measures and date kinds of the worklist; the
*&            | 400-day item driver, the POSTING date kind and the "as of" history are gone.
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
    CONSTANTS gc_run_id TYPE c LENGTH 6 VALUE 'DISB01'.
    CONSTANTS gc_status TYPE c LENGTH 10 VALUE 'CONFIRMED'.
    CONSTANTS gc_amount TYPE p LENGTH 13 DECIMALS 2 VALUE '-125.00'.

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
      RETURNING
        VALUE(rs_item) TYPE dfkkop.

    "! A current worklist row of a payment (run of iv_run_days_ago days ago)
    CLASS-METHODS payment
      IMPORTING
        iv_fin          TYPE clike
        iv_augbl        TYPE clike
        iv_outcome      TYPE zif_cd_ops_payout_types=>ty_outcome
        iv_finding      TYPE clike OPTIONAL
        iv_severity     TYPE clike OPTIONAL
        iv_run_days_ago TYPE i DEFAULT 0
        iv_company      TYPE clike DEFAULT gc_company
      RETURNING
        VALUE(rs_row)   TYPE zcd_pay_outcome.

    "! A current worklist row of a payment request (no payment document) due on iv_due
    CLASS-METHODS request
      IMPORTING
        iv_fin        TYPE clike
        iv_outcome    TYPE zif_cd_ops_payout_types=>ty_outcome
        iv_due        TYPE d
        iv_finding    TYPE clike OPTIONAL
        iv_stage      TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_row) TYPE zcd_pay_outcome.

    "! The payment run row (DPAYH) of a worklist row of a payment
    CLASS-METHODS run_of
      IMPORTING
        is_row        TYPE zcd_pay_outcome
        iv_method     TYPE clike DEFAULT gc_method_disb
      RETURNING
        VALUE(rs_run) TYPE dpayh.

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
    rs_item-bukrs            = gc_company.
    rs_item-budat            = days_ago( iv_days_ago ).
    rs_item-waers            = gc_currency.
    rs_item-pymet            = iv_method.
    rs_item-augbl            = iv_augbl.
    rs_item-zz_fin_trans_num = iv_fin.
  ENDMETHOD.


  METHOD payment.
    DATA lv_from TYPE timestamp.
    CONVERT DATE days_ago( 1 ) TIME zif_cd_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_from TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
    rs_row-fin_id     = iv_fin.
    rs_row-source     = zcl_cd_ops_pay_fixture=>gc_source-pclm.
    rs_row-bukrs      = iv_company.
    rs_row-augbl      = iv_augbl.
    rs_row-laufd      = days_ago( iv_run_days_ago ).
    rs_row-laufi      = gc_run_id.
    rs_row-valid_from = lv_from.
    rs_row-valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open.
    rs_row-outcome    = iv_outcome.
    rs_row-finding    = iv_finding.
    rs_row-severity   = iv_severity.
  ENDMETHOD.


  METHOD request.
    DATA lv_from TYPE timestamp.
    CONVERT DATE days_ago( 1 ) TIME zif_cd_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_from TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
    rs_row-fin_id        = iv_fin.
    rs_row-source        = zcl_cd_ops_pay_fixture=>gc_source-pclm.
    rs_row-valid_from    = lv_from.
    rs_row-valid_to      = zif_cd_ops_payout_types=>gc_valid_to_open.
    rs_row-outcome       = iv_outcome.
    rs_row-finding       = iv_finding.
    rs_row-evidence_kind = iv_stage.
    rs_row-due_date      = iv_due.
    IF iv_finding IS NOT INITIAL.
      rs_row-severity = zif_cd_ops_types=>gc_severity-error.
    ENDIF.
  ENDMETHOD.


  METHOD run_of.
    rs_run-laufd             = is_row-laufd.
    rs_run-laufi             = is_row-laufi.
    rs_run-doc1r             = is_row-augbl.
    rs_run-pymet             = iv_method.
    rs_run-valut             = is_row-laufd + 1.
    rs_run-waers             = gc_currency.
    rs_run-rwbtr             = gc_amount.
    rs_run-zz_payment_status = gc_status.
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
      BEGIN OF gc_pay,
        open      TYPE c LENGTH 12 VALUE '200000000001',
        second    TYPE c LENGTH 12 VALUE '200000000011',
        late      TYPE c LENGTH 12 VALUE '200000000002',
        closed    TYPE c LENGTH 12 VALUE '200000000003',
        collect   TYPE c LENGTH 12 VALUE '200000000004',
        proposal  TYPE c LENGTH 12 VALUE '200000000005',
        returned  TYPE c LENGTH 12 VALUE '200000000006',
        noc       TYPE c LENGTH 12 VALUE '200000000012',
      END OF gc_pay.
    CONSTANTS:
      BEGIN OF gc_doc,
        returned TYPE c LENGTH 12 VALUE '100000000006',
        noc      TYPE c LENGTH 12 VALUE '100000000012',
      END OF gc_doc.
    CONSTANTS:
      BEGIN OF gc_fin,
        open       TYPE c LENGTH 20 VALUE 'FIN0000000101',
        late       TYPE c LENGTH 20 VALUE 'FIN0000000102',
        closed     TYPE c LENGTH 20 VALUE 'FIN0000000103',
        collect    TYPE c LENGTH 20 VALUE 'FIN0000000104',
        proposal   TYPE c LENGTH 20 VALUE 'FIN0000000105',
        req_open   TYPE c LENGTH 20 VALUE 'FIN0000000106',
        req_unpaid TYPE c LENGTH 20 VALUE 'FIN0000000107',
        lots       TYPE c LENGTH 20 VALUE 'FIN0000000108',
      END OF gc_fin.
    CONSTANTS gc_return_doc TYPE c LENGTH 12 VALUE '600000000006'.
    CONSTANTS gc_return_reason TYPE c LENGTH 3 VALUE 'R01'.
    CONSTANTS gc_noc_lot TYPE c LENGTH 12 VALUE 'NOC000000012'.
    CONSTANTS gc_noc_item TYPE n LENGTH 6 VALUE '000001'.
    CONSTANTS gc_noc_infof TYPE c LENGTH 50 VALUE '00200000000012'.
    CONSTANTS gc_noc_reason TYPE c LENGTH 3 VALUE 'C01'.
    CONSTANTS gc_days_late TYPE i VALUE 6.
    CONSTANTS gc_days_unpaid TYPE i VALUE 2.
    CONSTANTS gc_days_window TYPE i VALUE 60.
    CONSTANTS:
      BEGIN OF gc_kind,
        worklist TYPE c LENGTH 10 VALUE 'WORKLIST',
        run      TYPE c LENGTH 10 VALUE 'RUN',
        value    TYPE c LENGTH 10 VALUE 'VALUE',
        due      TYPE c LENGTH 10 VALUE 'DUE',
      END OF gc_kind.
    CONSTANTS:
      BEGIN OF gc_work,
        payment TYPE c LENGTH 7 VALUE 'PAYMENT',
        request TYPE c LENGTH 7 VALUE 'REQUEST',
      END OF gc_work.
    CONSTANTS:
      BEGIN OF gc_direction,
        disbursement TYPE c LENGTH 12 VALUE 'DISBURSEMENT',
        collection   TYPE c LENGTH 12 VALUE 'COLLECTION',
      END OF gc_direction.
    CONSTANTS:
      BEGIN OF gc_lot,
        return TYPE c LENGTH 6 VALUE 'RETURN',
        noc    TYPE c LENGTH 6 VALUE 'NOC',
      END OF gc_lot.
    CONSTANTS:
      BEGIN OF gc_criticality,
        red    TYPE i VALUE 1,
        yellow TYPE i VALUE 2,
        none   TYPE i VALUE 0,
      END OF gc_criticality.

    "! Parameters of ZR_CD_TrxFlow for the next select (date kind, day(s))
    TYPES:
      BEGIN OF ty_param,
        kind TYPE c LENGTH 10,
        from TYPE d,
        to   TYPE d,
      END OF ty_param.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA ms_param TYPE ty_param.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS current_rows_only          FOR TESTING.
    METHODS kind_and_worklist_date     FOR TESTING.
    METHODS date_kinds_select_rows     FOR TESTING.
    METHODS proposal_run_not_joined    FOR TESTING.
    METHODS direction_from_tfk042z     FOR TESTING.
    METHODS open_and_exception_counts  FOR TESTING.
    METHODS kpi_counts_distinct_fin    FOR TESTING.
    METHODS kpi_never_mixes_company    FOR TESTING.
    METHODS problems_are_exceptions    FOR TESTING.
    METHODS reasons_from_lot_items     FOR TESTING.
    METHODS no_partner_or_member_exposed FOR TESTING.
    " shared fixtures (same data and outcome as the evaluator, A_INFLIGHT and the trace)
    METHODS fixture_retrieval_no_row   FOR TESTING.
    METHODS fixture_line_inconsistent  FOR TESTING.
    METHODS fixture_two_sources_rows   FOR TESTING.

    "! Rows of a fixture scenario with the worklist rows the snapshot wrote for it
    METHODS given_fixture
      IMPORTING
        iv_id              TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
      RETURNING
        VALUE(rs_scenario) TYPE zcl_cd_ops_pay_fixture=>ty_scenario.

    "! Parameters of the following selects (default: worklist date over the test window)
    METHODS use_params
      IMPORTING
        iv_kind TYPE clike DEFAULT gc_kind-worklist
        iv_from TYPE d OPTIONAL
        iv_to   TYPE d OPTIONAL.

    METHODS rows_of
      IMPORTING
        iv_fin         TYPE clike
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
    DATA lt_rows TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA lt_items TYPE STANDARD TABLE OF dfkkop WITH EMPTY KEY.
    DATA lt_returns TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA lt_nocs TYPE STANDARD TABLE OF dfkknrp WITH EMPTY KEY.
    DATA ls_return TYPE dfkkrp.
    DATA ls_noc TYPE dfkknrp.

    go_env->clear_doubles( ).
    use_params( ).
    mo_fixture = NEW #( ltd_rows=>days_ago( 0 ) ).
    ltd_rows=>insert_config( go_env ).

    " Open payment of today, in flight
    DATA(ls_open) = ltd_rows=>payment( iv_fin = gc_fin-open iv_augbl = gc_pay-open
                                       iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
    INSERT ls_open INTO TABLE lt_rows.
    INSERT ltd_rows=>run_of( ls_open ) INTO TABLE lt_runs.
    " Late payment (beyond RED): exception of the shared ageing
    DATA(ls_late) = ltd_rows=>payment( iv_fin          = gc_fin-late
                                       iv_augbl        = gc_pay-late
                                       iv_outcome      = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                       iv_finding      = zif_cd_hck_runtime_types=>gc_code-payment_not_clear
                                       iv_severity     = zif_cd_ops_types=>gc_severity-error
                                       iv_run_days_ago = gc_days_late ).
    INSERT ls_late INTO TABLE lt_rows.
    INSERT ltd_rows=>run_of( ls_late ) INTO TABLE lt_runs.
    " Closed exception history (finished): never a current row
    DATA(ls_closed) = ltd_rows=>payment( iv_fin = gc_fin-closed iv_augbl = gc_pay-closed
                                         iv_outcome = zif_cd_ops_payout_types=>gc_outcome-cleared
                                         iv_finding = zif_cd_hck_runtime_types=>gc_code-payment_not_clear ).
    ls_closed-valid_to = ls_closed-valid_from.
    INSERT ls_closed INTO TABLE lt_rows.
    INSERT ltd_rows=>run_of( ls_closed ) INTO TABLE lt_runs.
    " Collection in the second company code
    DATA(ls_collect) = ltd_rows=>payment( iv_fin = gc_fin-collect iv_augbl = gc_pay-collect
                                          iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                          iv_company = ltd_rows=>gc_company2 ).
    INSERT ls_collect INTO TABLE lt_rows.
    INSERT ltd_rows=>run_of( is_row = ls_collect iv_method = ltd_rows=>gc_method_coll ) INTO TABLE lt_runs.
    " Payment whose only DPAYH row is a proposal run
    DATA(ls_proposal) = ltd_rows=>payment( iv_fin = gc_fin-proposal iv_augbl = gc_pay-proposal
                                           iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
    INSERT ls_proposal INTO TABLE lt_rows.
    DATA(ls_proposal_run) = ltd_rows=>run_of( ls_proposal ).
    ls_proposal_run-xvorl = abap_true.
    INSERT ls_proposal_run INTO TABLE lt_runs.
    " Requests: open (due tomorrow) and not paid on its due date (payment block)
    INSERT ltd_rows=>request( iv_fin = gc_fin-req_open iv_outcome = zif_cd_ops_payout_types=>gc_outcome-req_open
                              iv_due = ltd_rows=>days_ago( -1 ) ) INTO TABLE lt_rows.
    INSERT ltd_rows=>request( iv_fin     = gc_fin-req_unpaid
                              iv_outcome = zif_cd_ops_payout_types=>gc_outcome-req_not_paid
                              iv_due     = ltd_rows=>days_ago( gc_days_unpaid )
                              iv_finding = zif_cd_ops_payout_types=>gc_code-request_not_paid
                              iv_stage   = zif_cd_ops_payout_types=>gc_req_stage-payment_block ) INTO TABLE lt_rows.

    " Returns / NOC lots of two paid items (evidence window)
    INSERT ltd_rows=>item( iv_opbel = gc_doc-returned iv_fin = gc_fin-lots iv_augbl = gc_pay-returned ) INTO TABLE lt_items.
    INSERT ltd_rows=>item( iv_opbel = gc_doc-noc iv_fin = gc_fin-lots iv_augbl = gc_pay-noc ) INTO TABLE lt_items.
    ls_return-selw1 = gc_pay-returned.
    ls_return-opbel = gc_return_doc.
    ls_return-rlgrd = gc_return_reason.
    INSERT ls_return INTO TABLE lt_returns.
    ls_noc-keyn1 = gc_noc_lot.
    ls_noc-posna = gc_noc_item.
    ls_noc-infof = gc_noc_infof.
    ls_noc-flgrd = gc_noc_reason.
    INSERT ls_noc INTO TABLE lt_nocs.

    go_env->insert_test_data( i_data = lt_rows ).
    go_env->insert_test_data( i_data = lt_runs ).
    go_env->insert_test_data( i_data = lt_items ).
    go_env->insert_test_data( i_data = lt_returns ).
    go_env->insert_test_data( i_data = lt_nocs ).
  ENDMETHOD.


  METHOD given_fixture.
    DATA lv_from TYPE timestamp.
    rs_scenario = mo_fixture->scenario( iv_id ).
    go_env->insert_test_data( i_data = mo_fixture->dfkkop_rows( rs_scenario ) ).
    go_env->insert_test_data( i_data = mo_fixture->dpayh_rows( rs_scenario ) ).
    CONVERT DATE ltd_rows=>days_ago( 1 ) TIME zif_cd_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_from TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.
    DATA(lt_rows) = mo_fixture->outcome_rows( is_scenario = rs_scenario iv_valid_from = lv_from ).
    IF lt_rows IS NOT INITIAL.
      go_env->insert_test_data( i_data = lt_rows ).
    ENDIF.
  ENDMETHOD.


  METHOD use_params.
    ms_param-kind = iv_kind.
    ms_param-from = COND #( WHEN iv_from IS INITIAL THEN ltd_rows=>days_ago( gc_days_window ) ELSE iv_from ).
    ms_param-to   = COND #( WHEN iv_to IS INITIAL THEN ltd_rows=>days_ago( -1 ) ELSE iv_to ).
  ENDMETHOD.


  METHOD rows_of.
    SELECT COUNT(*)
      FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
      WHERE finid = @iv_fin
      INTO @rv_rows.
  ENDMETHOD.


  " Only the current rows of the worklist: a closed exception version is history, never a row
  METHOD current_rows_only.
    TRY.
        SELECT finid FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          ORDER BY finid
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 6
                                            msg = 'Open, late, collection, proposal-run payment and two requests' ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_fin-closed ) exp = 0 msg = 'Closed version not shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A payment's worklist date is its run date, a request's its due date (kind REQUEST: no document)
  METHOD kind_and_worklist_date.
    TRY.
        SELECT finid, workkind, worklistdate, duedate, direction
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @gc_fin-late OR finid = @gc_fin-req_unpaid
          ORDER BY finid
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Payment and request' ).
        DATA(ls_payment) = lt_rows[ finid = gc_fin-late ].
        cl_abap_unit_assert=>assert_equals( act = ls_payment-workkind exp = gc_work-payment msg = 'Payment' ).
        cl_abap_unit_assert=>assert_equals( act = ls_payment-worklistdate exp = ltd_rows=>days_ago( gc_days_late )
                                            msg = 'Run date of the payment' ).
        DATA(ls_request) = lt_rows[ finid = gc_fin-req_unpaid ].
        cl_abap_unit_assert=>assert_equals( act = ls_request-workkind exp = gc_work-request msg = 'Request' ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-worklistdate exp = ltd_rows=>days_ago( gc_days_unpaid )
                                            msg = 'Due date of the request' ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-direction exp = gc_direction-disbursement
                                            msg = 'A payment request is a disbursement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " RUN selects payments by run date, VALUE by the run's value date, DUE requests by due date
  METHOD date_kinds_select_rows.
    DATA(lv_run) = ltd_rows=>days_ago( gc_days_late ).
    DATA(lv_value) = ltd_rows=>days_ago( gc_days_late - 1 ).
    DATA(lv_due) = ltd_rows=>days_ago( gc_days_unpaid ).
    TRY.
        use_params( iv_kind = gc_kind-run iv_from = lv_run iv_to = lv_run ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_fin-late ) exp = 1 msg = 'Run date' ).
        use_params( iv_kind = gc_kind-run iv_from = lv_value iv_to = lv_value ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_fin-late ) exp = 0 msg = 'Other run date' ).
        use_params( iv_kind = gc_kind-value iv_from = lv_value iv_to = lv_value ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_fin-late ) exp = 1 msg = 'Value date of the run' ).
        use_params( iv_kind = gc_kind-due iv_from = lv_due iv_to = lv_due ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_fin-req_unpaid ) exp = 1 msg = 'Due date' ).
        use_params( iv_kind = gc_kind-run iv_from = lv_due iv_to = lv_due ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( gc_fin-req_unpaid ) exp = 0
                                            msg = 'A request has no run date' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A proposal run (DPAYH-XVORL) is not the payment: the row stays, without run values
  METHOD proposal_run_not_joined.
    TRY.
        SELECT finid, paymentstatus, amount
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @gc_fin-proposal
          ORDER BY finid
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'The worklist row is shown' ).
        cl_abap_unit_assert=>assert_initial( act = lt_rows[ 1 ]-paymentstatus msg = 'No values of the proposal run' ).
        cl_abap_unit_assert=>assert_initial( act = lt_rows[ 1 ]-amount msg = 'No amount of the proposal run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD direction_from_tfk042z.
    TRY.
        SELECT finid, direction
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @gc_fin-collect OR finid = @gc_fin-open
          ORDER BY finid
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ finid = gc_fin-collect ]-direction exp = gc_direction-collection
                                            msg = 'XEINZ = X: collection' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ finid = gc_fin-open ]-direction exp = gc_direction-disbursement
                                            msg = 'Disbursement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Open rows count as open, exceptions (a finding) as exceptions; criticality red for severity E
  METHOD open_and_exception_counts.
    TRY.
        SELECT finid, opencount, exceptioncount, latecount, requestnotpaidcount, requestopencount, flowcriticality
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          ORDER BY finid
          INTO TABLE @DATA(lt_rows).
        DATA(ls_open) = lt_rows[ finid = gc_fin-open ].
        cl_abap_unit_assert=>assert_equals( act = ls_open-opencount exp = 1 msg = 'Open' ).
        cl_abap_unit_assert=>assert_equals( act = ls_open-exceptioncount exp = 0 msg = 'No exception' ).
        cl_abap_unit_assert=>assert_equals( act = CONV i( ls_open-flowcriticality ) exp = gc_criticality-none msg = 'Neutral' ).
        DATA(ls_late) = lt_rows[ finid = gc_fin-late ].
        cl_abap_unit_assert=>assert_equals( act = ls_late-exceptioncount exp = 1 msg = 'Late is an exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_late-latecount exp = 1 msg = 'Counted late' ).
        cl_abap_unit_assert=>assert_equals( act = CONV i( ls_late-flowcriticality ) exp = gc_criticality-red msg = 'Red' ).
        DATA(ls_unpaid) = lt_rows[ finid = gc_fin-req_unpaid ].
        cl_abap_unit_assert=>assert_equals( act = ls_unpaid-requestnotpaidcount exp = 1 msg = 'Request not paid' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ finid = gc_fin-req_open ]-requestopencount exp = 1
                                            msg = 'Request open' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A FIN paid in two payments today: two entries, one FIN number
  METHOD kpi_counts_distinct_fin.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    TRY.
        DATA(ls_second) = ltd_rows=>payment( iv_fin = gc_fin-open iv_augbl = gc_pay-second
                                             iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        INSERT ls_second INTO TABLE lt_rows.
        INSERT ltd_rows=>run_of( ls_second ) INTO TABLE lt_runs.
        go_env->insert_test_data( i_data = lt_rows ).
        go_env->insert_test_data( i_data = lt_runs ).
        DATA(lv_today) = ltd_rows=>days_ago( 0 ).
        SELECT SINGLE entrycount, fincount, opencount, exceptioncount, inflightcount
          FROM zr_cd_trxkpi
          WHERE worklistdate = @lv_today AND companycode = @ltd_rows=>gc_company
            AND direction = @gc_direction-disbursement
          INTO @DATA(ls_kpi).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'KPI row of today' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-entrycount exp = 2 msg = 'Two payments today' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-fincount exp = 1 msg = 'One FIN number' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-opencount exp = 2 msg = 'Both open' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-exceptioncount exp = 0 msg = 'No exception today' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-inflightcount exp = 2 msg = 'In flight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The company code is a key of the KPI: US02's collection is never summed into US01
  METHOD kpi_never_mixes_company.
    TRY.
        DATA(lv_today) = ltd_rows=>days_ago( 0 ).
        SELECT companycode, direction, entrycount FROM zr_cd_trxkpi
          WHERE worklistdate = @lv_today
          ORDER BY companycode, direction
          INTO TABLE @DATA(lt_kpi).
        cl_abap_unit_assert=>assert_equals( act = lt_kpi[ companycode = ltd_rows=>gc_company2 ]-entrycount exp = 1
                                            msg = 'US02: its collection' ).
        cl_abap_unit_assert=>assert_equals( act = lt_kpi[ companycode = ltd_rows=>gc_company2 ]-direction
                                            exp = gc_direction-collection msg = 'US02: collection' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_kpi[ companycode = ltd_rows=>gc_company
                                                                               direction   = gc_direction-collection ] ) )
                                           msg = 'No collection in US01' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The errored / stuck list is the worklist's exceptions: the late payment and the unpaid request
  METHOD problems_are_exceptions.
    TRY.
        SELECT finid, problemtype, problemcriticality, evidencekind FROM zr_cd_trxproblem
          ORDER BY finid
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Two exceptions' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ finid = gc_fin-late ]-problemtype
                                            exp = zif_cd_hck_runtime_types=>gc_code-payment_not_clear msg = 'Late' ).
        DATA(ls_request) = lt_rows[ finid = gc_fin-req_unpaid ].
        cl_abap_unit_assert=>assert_equals( act = ls_request-problemtype
                                            exp = zif_cd_ops_payout_types=>gc_code-request_not_paid msg = 'Not paid' ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-evidencekind
                                            exp = zif_cd_ops_payout_types=>gc_req_stage-payment_block msg = 'Stage' ).
        cl_abap_unit_assert=>assert_equals( act = CONV i( ls_request-problemcriticality ) exp = gc_criticality-red
                                            msg = 'Severity E: red' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ finid = gc_fin-open ] ) )
                                           msg = 'An open payment is not a problem' ).
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


  " Shared fixture: a retrieval is final (RETRIEVED, never RETURNED) - the payment leaves the worklist
  METHOD fixture_retrieval_no_row.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-retrieval ).
        cl_abap_unit_assert=>assert_equals( act = rows_of( ls_scenario-fin ) exp = 0
                                            msg = 'A clean final payment has no worklist row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture: the wire on the statement without DPAYH status CLEARED is an INCONSISTENT exception
  METHOD fixture_line_inconsistent.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-bank_line ).
        SELECT outcome, isexception
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @ls_scenario-fin
          ORDER BY finid
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One worklist row' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = ls_scenario-expected msg = 'INCONSISTENT' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isexception exp = abap_true msg = 'An exception' ).
        SELECT COUNT(*) FROM zr_cd_trxproblem WHERE finid = @ls_scenario-fin INTO @DATA(lv_listed).
        cl_abap_unit_assert=>assert_equals( act = lv_listed exp = 1 msg = 'On the errored / stuck list' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Shared fixture: a FIN in two sources has one AMBIGUOUS row per source - never one source picked
  METHOD fixture_two_sources_rows.
    TRY.
        DATA(ls_scenario) = given_fixture( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources ).
        SELECT sourcesystem, outcome, finding
          FROM zr_cd_trxflow( p_datekind = @ms_param-kind, p_datefrom = @ms_param-from, p_dateto = @ms_param-to )
          WHERE finid = @ls_scenario-fin
          ORDER BY sourcesystem
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'One row per source' ).
        LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
          cl_abap_unit_assert=>assert_equals( act = <ls_row>-outcome exp = ls_scenario-expected msg = 'AMBIGUOUS' ).
          cl_abap_unit_assert=>assert_equals( act = <ls_row>-finding exp = zif_cd_ops_payout_types=>gc_code-source_ambiguous
                                              msg = 'With the finding' ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
