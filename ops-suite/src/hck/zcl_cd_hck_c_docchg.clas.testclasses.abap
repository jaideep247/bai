*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_docchg.clas.testclasses.abap
*& Purpose:
*& Unit tests of the document-change risk check A_DOC_CHANGE: a payment
*& reversed after it left SAP (status in the list, bank line, cashed cheque)
*& is an E finding with company code and amount; reversed before it left SAP
*& is silent; the latest payment run decides; the reversal's reconciliation
*& key without G/L transfer is an E finding; a bank line referencing the
*& reversed payment is an E finding of the reset / reversal bucket; PARAM4
*& replaces the status list; a capped read is a warning and evidence PARTIAL.
*& The document-change DAO, the payment trace repository and the HCK DAO are
*& doubles from the injectors; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
*&---------------------------------------------------------------------*
CLASS ltd_docchg_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_docchg_dao.
    DATA mt_rows TYPE zif_cd_hck_docchg_types=>tt_reversal.
ENDCLASS.

CLASS ltd_docchg_dao IMPLEMENTATION.
  METHOD zif_cd_hck_docchg_dao~get_reversed_payments.
    LOOP AT mt_rows INTO DATA(ls_row) TO iv_max_rows.
      INSERT ls_row INTO TABLE rt_reversals.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ).
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    LOOP AT mt_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      IF line_exists( it_docno[ table_line = <ls_check>-doc1r ] ).
        INSERT <ls_check> INTO TABLE rt_checks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_hck_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_gaps TYPE zif_cd_hck_types=>tt_fikey_gap.
    DATA mv_awtyp TYPE awtyp.
ENDCLASS.

CLASS ltd_hck_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_fikeys_without_gl.
    mv_awtyp = iv_awtyp.
    LOOP AT mt_gaps INTO DATA(ls_gap) TO iv_max_rows.
      INSERT ls_gap INTO TABLE rt_gaps.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_docchg DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        report_date TYPE d VALUE '20261111',
        reversed_on TYPE d VALUE '20261109',
        run_date    TYPE d VALUE '20261105',
        older_run   TYPE d VALUE '20261104',
        pay_doc     TYPE zif_cd_hck_docchg_types=>ty_docno VALUE '000012345678',
        pay_short   TYPE zif_cd_ops_trace_types=>ty_ref VALUE '12345678',
        rev_doc     TYPE zif_cd_hck_docchg_types=>ty_docno VALUE '000099990001',
        fikey       TYPE zif_cd_hck_types=>ty_fikey VALUE 'RK20261109',
        bukrs       TYPE c LENGTH 4 VALUE 'ZT01',
        usd         TYPE c LENGTH 5 VALUE 'USD',
        issued      TYPE zif_cd_hck_docchg_types=>ty_pay_status VALUE 'ISSUED',
        stopped     TYPE zif_cd_hck_docchg_types=>ty_pay_status VALUE 'STOPPED',
        cleared     TYPE c LENGTH 10 VALUE 'CLEARED',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_docchg_dao.
    DATA mo_trace TYPE REF TO ltd_trace_dao.
    DATA mo_hck TYPE REF TO ltd_hck_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.

    METHODS left_sap_by_status_is_error FOR TESTING.
    METHODS before_issue_is_silent FOR TESTING.
    METHODS latest_run_decides FOR TESTING.
    METHODS bank_line_found_both_ways FOR TESTING.
    METHODS cashed_cheque_is_left_sap FOR TESTING.
    METHODS reversal_without_gl_transfer FOR TESTING.
    METHODS param4_replaces_statuses FOR TESTING.
    METHODS capped_read_is_partial FOR TESTING.

    METHODS given_reversal
      IMPORTING
        iv_status TYPE zif_cd_hck_docchg_types=>ty_pay_status
        iv_run    TYPE d DEFAULT gc-run_date
        iv_doc    TYPE zif_cd_hck_docchg_types=>ty_docno DEFAULT gc-pay_doc.
    METHODS run_check
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.
    METHODS count_code
      IMPORTING
        is_result       TYPE zif_cd_hck_types=>ty_check_result
        iv_code         TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rv_count) TYPE i.
ENDCLASS.


CLASS ltc_docchg IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_trace = NEW #( ).
    mo_hck = NEW #( ).
    zcl_cd_hck_injector=>inject_docchg_dao( mo_dao ).
    zcl_cd_hck_injector=>inject_dao( mo_hck ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    CLEAR ms_def.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD given_reversal.
    DATA ls_row TYPE zif_cd_hck_docchg_types=>ty_reversal.
    ls_row-payment_doc  = iv_doc.
    ls_row-reversal_doc = gc-rev_doc.
    ls_row-fikey        = gc-fikey.
    ls_row-reversed_on  = gc-reversed_on.
    ls_row-laufd        = iv_run.
    ls_row-bukrs        = gc-bukrs.
    ls_row-status       = iv_status.
    ls_row-amount       = -250.
    ls_row-currency     = gc-usd.
    INSERT ls_row INTO TABLE mo_dao->mt_rows.
  ENDMETHOD.


  METHOD run_check.
    DATA ls_context TYPE zif_cd_hck_types=>ty_context.
    ls_context-report_date = gc-report_date.
    rs_result = NEW zcl_cd_hck_c_docchg( )->zif_cd_hck_check~execute( is_def        = ms_def
                                                                      it_thresholds = VALUE #( )
                                                                      is_context    = ls_context ).
  ENDMETHOD.


  METHOD count_code.
    LOOP AT is_result-findings TRANSPORTING NO FIELDS WHERE check_code = iv_code.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD left_sap_by_status_is_error.
    TRY.
        given_reversal( gc-issued ).
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_cd_hck_docchg_types=>gc_code-left_sap )
                                            exp = 1 msg = 'A payment reversed after its file was sent is a finding' ).
        DATA(ls_finding) = ls_result-findings[ check_code = zif_cd_hck_docchg_types=>gc_code-left_sap ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Possible double payment is an error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = gc-bukrs msg = 'Company code of the payment' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = CONV zif_ca_ops_types=>ty_amount( 250 )
                                            msg = 'Absolute payment amount with its currency' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-action exp = zif_ca_ops_types=>gc_action-exception
                                            msg = 'An owned exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD before_issue_is_silent.
    TRY.
        given_reversal( space ).
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings
                                             msg = 'Reversed before it left SAP: no evidence, no finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ metric = zif_cd_hck_docchg_types=>gc_metric-reversals ]-value
                                            exp = 1 msg = 'The reversal is still counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD latest_run_decides.
    TRY.
        " rows as the DAO orders them: the latest run first - stopped (a stop and reissue), then the older issue
        given_reversal( iv_status = gc-stopped iv_run = gc-run_date ).
        given_reversal( iv_status = gc-issued iv_run = gc-older_run ).
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_cd_hck_docchg_types=>gc_code-left_sap )
                                            exp = 0 msg = 'The status of the latest run decides' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ metric = zif_cd_hck_docchg_types=>gc_metric-reversals ]-value
                                            exp = 1 msg = 'One reversed payment, not one per run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD bank_line_found_both_ways.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    TRY.
        given_reversal( space ).
        " the statement carries the payment document without leading zeros
        ls_line-kukey = '00000042'.
        ls_line-esnum = '00003'.
        ls_line-chect = gc-pay_short.
        ls_line-budat = gc-reversed_on.
        ls_line-bukrs = gc-bukrs.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_cd_hck_docchg_types=>gc_code-bank_line )
                                            exp = 1 msg = 'The bank line of the reversed payment is a finding' ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_cd_hck_docchg_types=>gc_code-left_sap )
                                            exp = 1 msg = 'A bank line proves the payment left SAP' ).
        DATA(ls_finding) = ls_result-findings[ check_code = zif_cd_hck_docchg_types=>gc_code-bank_line ].
        cl_abap_unit_assert=>assert_equals( act = CONV string( ls_finding-reference ) exp = CONV string( gc-pay_doc )
                                            msg = 'The line names the OLD payment document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD cashed_cheque_is_left_sap.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    TRY.
        given_reversal( space ).
        ls_check-doc1r = gc-pay_doc.
        ls_check-state = zif_cd_hck_docchg_types=>gc_cheque_cashed.
        INSERT ls_check INTO TABLE mo_trace->mt_checks.
        DATA(ls_result) = run_check( ).
        DATA(ls_finding) = ls_result-findings[ check_code = zif_cd_hck_docchg_types=>gc_code-left_sap ].
        cl_abap_unit_assert=>assert_char_cp( act = ls_finding-message
                                             exp = |*{ zif_cd_hck_docchg_types=>gc_evidence-cheque_cashed }*|
                                             msg = 'The cashed cheque is the evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD reversal_without_gl_transfer.
    TRY.
        given_reversal( space ).
        INSERT VALUE #( fikey = gc-fikey bukrs = gc-bukrs ) INTO TABLE mo_hck->mt_gaps.
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_cd_hck_docchg_types=>gc_code-gl_not_rev )
                                            exp = 1 msg = 'The reversal key without G/L transfer is a finding' ).
        cl_abap_unit_assert=>assert_equals( act = mo_hck->mv_awtyp exp = zcl_cd_hck_c_gl_transfer=>gc_default_awtyp
                                            msg = 'The G/L transfer rule of A_GL_TRANSFER is reused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD param4_replaces_statuses.
    TRY.
        given_reversal( gc-issued ).
        ms_def-param4 = gc-cleared.
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_cd_hck_docchg_types=>gc_code-left_sap )
                                            exp = 0 msg = 'Only the statuses of PARAM4 count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD capped_read_is_partial.
    TRY.
        given_reversal( iv_status = space iv_doc = '000000000001' ).
        given_reversal( iv_status = space iv_doc = '000000000002' ).
        ms_def-param3 = '1'.
        DATA(ls_result) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( is_result = ls_result
                                                              iv_code   = zif_cd_hck_docchg_types=>gc_code-capped )
                                            exp = 1 msg = 'A capped read is reported' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-evidence exp = zif_cd_hck_types=>gc_completion-partial
                                            msg = 'Evidence PARTIAL, never complete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
