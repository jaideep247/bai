*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_rule_base.clas.testclasses.abap
*& Purpose:
*& Tests for every EBS rule class (R01-R20, S01-S12), grouped by test level:
*& LTC_LINE_RULES (domain, no repository), LTC_LOOKUP_RULES (payment engine
*& reads through LTD_SAP_DAO) and LTC_STMT_RULES (statement checks, LTD_FEB_DAO).
*& Legacy parity rows (v4 BAI validators) are named in the comments.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.
    DATA mt_params TYPE zif_cd_ops_types=>tt_kv.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    rs_run-module = iv_module.
  ENDMETHOD.
  METHOD zif_cd_ops_store~save_findings.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~finish_run.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_param.
    rv_value = VALUE #( mt_params[ name = iv_name ]-value DEFAULT iv_default ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_last_run.
    CLEAR rs_run.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_runs_since.
    CLEAR rt_runs.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_findings.
    CLEAR rt_findings.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261105080000.0000000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261105'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '080000'.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_sap_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_sap_dao.
    DATA mt_items      TYPE zif_cd_ebs_sap_dao=>tt_return_item.
    DATA mt_payments   TYPE zif_cd_ebs_sap_dao=>tt_payment.
    DATA mt_retrievals TYPE zif_cd_ebs_sap_dao=>tt_retrieval.
    DATA mt_checks     TYPE zif_cd_ebs_sap_dao=>tt_check.
    DATA mt_fi_lines   TYPE zif_cd_ebs_sap_dao=>tt_fi_line.
    DATA mv_gl_balance TYPE zif_cd_ops_types=>ty_amount.
    DATA mt_docno_seen TYPE zif_cd_ebs_sap_dao=>tt_docno.
ENDCLASS.

CLASS ltd_sap_dao IMPLEMENTATION.
  METHOD zif_cd_ebs_sap_dao~get_return_items.
    mt_docno_seen = it_docno.
    LOOP AT mt_items INTO DATA(ls_item).
      IF line_exists( it_docno[ table_line = ls_item-selw1 ] ).
        INSERT ls_item INTO TABLE rt_items.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ebs_sap_dao~get_payments.
    mt_docno_seen = it_docno.
    LOOP AT mt_payments INTO DATA(ls_payment).
      IF line_exists( it_docno[ table_line = ls_payment-doc1r ] ).
        INSERT ls_payment INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ebs_sap_dao~get_retrievals.
    mt_docno_seen = it_docno.
    LOOP AT mt_retrievals INTO DATA(ls_retrieval).
      IF line_exists( it_docno[ table_line = ls_retrieval-augbl ] ).
        INSERT ls_retrieval INTO TABLE rt_retrievals.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ebs_sap_dao~get_checks.
    LOOP AT mt_checks INTO DATA(ls_check).
      IF line_exists( it_ztnum[ table_line = ls_check-ztnum ] ).
        INSERT ls_check INTO TABLE rt_checks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ebs_sap_dao~get_fi_lines.
    LOOP AT mt_fi_lines INTO DATA(ls_fi_line).
      IF line_exists( it_keys[ bukrs = ls_fi_line-bukrs belnr = ls_fi_line-belnr gjahr = ls_fi_line-gjahr ] ).
        INSERT ls_fi_line INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_ebs_sap_dao~get_gl_balance.
    rv_balance = mv_gl_balance.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_feb_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao.
    DATA ms_prior  TYPE zif_cd_ebs_feb_dao=>ty_header.
    DATA mv_exists TYPE abap_bool.
ENDCLASS.

CLASS ltd_feb_dao IMPLEMENTATION.
  METHOD zif_cd_ebs_feb_dao~get_headers.
    CLEAR rt_headers.
  ENDMETHOD.
  METHOD zif_cd_ebs_feb_dao~get_items.
    CLEAR rt_items.
  ENDMETHOD.
  METHOD zif_cd_ebs_feb_dao~get_prior_header.
    rs_header = ms_prior.
  ENDMETHOD.
  METHOD zif_cd_ebs_feb_dao~statement_exists.
    rv_exists = mv_exists.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_cfg_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao.
    DATA mt_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.
    DATA mt_reasons  TYPE zif_cd_ebs_types=>tt_reason_map.
ENDCLASS.

CLASS ltd_cfg_dao IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_btc_map.
    CLEAR rt_map.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_rules.
    CLEAR rt_rules.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_accounts.
    rt_accounts = mt_accounts.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_flow_patterns.
    CLEAR rt_patterns.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_reason_map.
    rt_reasons = mt_reasons.
  ENDMETHOD.
ENDCLASS.


"! Shared arrange/act helpers for the three rule test classes
CLASS ltc_rule_fixture DEFINITION ABSTRACT FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PROTECTED SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'S0001',
        bukrs    TYPE c LENGTH 4 VALUE 'US01',
        hbkid    TYPE c LENGTH 5 VALUE 'JPMC1',
        hktid    TYPE c LENGTH 5 VALUE 'DISB1',
        account  TYPE zif_cd_ebs_types=>ty_text35 VALUE '000123456789',
        usd      TYPE zif_cd_ops_types=>ty_currency VALUE 'USD',
        ref      TYPE zif_cd_ebs_types=>ty_text35 VALUE '12345',
        docno    TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000012345',
        today    TYPE d VALUE '20261105',
        amount   TYPE zif_cd_ops_types=>ty_amount VALUE '250.00',
      END OF gc_test.

    DATA mo_store    TYPE REF TO ltd_store.
    DATA mo_sap_dao  TYPE REF TO ltd_sap_dao.
    DATA mo_feb_dao  TYPE REF TO ltd_feb_dao.
    DATA mo_cfg_dao  TYPE REF TO ltd_cfg_dao.
    DATA mt_lines    TYPE zif_cd_ebs_types=>tt_line.
    DATA mt_stmts    TYPE zif_cd_ebs_types=>tt_statement.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

    METHODS prepare_fixture.
    METHODS clear_fixture.

    METHODS rule
      IMPORTING
        iv_rule_id     TYPE zif_cd_ops_types=>ty_rule_id
        iv_param1      TYPE clike OPTIONAL
        iv_param2      TYPE clike OPTIONAL
        iv_tolerance   TYPE zif_cd_ops_types=>ty_amount OPTIONAL
        iv_window_days TYPE i OPTIONAL
      RETURNING
        VALUE(rs_rule) TYPE zif_cd_ebs_types=>ty_rule_cfg.

    METHODS add_statement
      IMPORTING
        iv_opening TYPE zif_cd_ops_types=>ty_amount OPTIONAL
        iv_closing TYPE zif_cd_ops_types=>ty_amount OPTIONAL
        iv_source  TYPE zif_cd_ebs_types=>ty_source DEFAULT zif_cd_ebs_types=>gc_source-feb.

    METHODS add_line
      IMPORTING
        iv_cdi        TYPE zif_cd_ebs_types=>ty_cdi DEFAULT zif_cd_ebs_types=>gc_cdi-credit
        iv_exp_cdi    TYPE zif_cd_ebs_types=>ty_cdi OPTIONAL
        iv_amount     TYPE zif_cd_ops_types=>ty_amount DEFAULT gc_test-amount
        iv_reference  TYPE zif_cd_ebs_types=>ty_text35 DEFAULT gc_test-ref
        iv_belnr      TYPE zif_cd_ebs_types=>ty_line-belnr OPTIONAL
        iv_category   TYPE zif_cd_ebs_types=>ty_category DEFAULT 'D02'
        iv_value_date TYPE d DEFAULT gc_test-today.

    METHODS run
      IMPORTING
        iv_class TYPE zif_cd_ops_types=>ty_class_name
        is_rule  TYPE zif_cd_ebs_types=>ty_rule_cfg.

    METHODS assert_one_code
      IMPORTING
        iv_check_code TYPE zif_cd_ops_types=>ty_check_code
        iv_msg        TYPE string.

ENDCLASS.


CLASS ltc_rule_fixture IMPLEMENTATION.

  METHOD prepare_fixture.
    DATA ls_account TYPE zif_cd_ebs_types=>ty_account_cfg.
    mo_store   = NEW #( ).
    mo_sap_dao = NEW #( ).
    mo_feb_dao = NEW #( ).
    mo_cfg_dao = NEW #( ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_ebs_injector=>inject_sap_dao( mo_sap_dao ).
    zcl_cd_ebs_injector=>inject_feb_dao( mo_feb_dao ).
    zcl_cd_ebs_injector=>inject_cfg_dao( mo_cfg_dao ).
    ls_account-bukrs      = gc_test-bukrs.
    ls_account-hbkid      = gc_test-hbkid.
    ls_account-hktid      = gc_test-hktid.
    ls_account-account_no = gc_test-account.
    ls_account-currency   = gc_test-usd.
    ls_account-gl_account = '0011001000'.
    ls_account-active     = abap_true.
    INSERT ls_account INTO TABLE mo_cfg_dao->mt_accounts.
    CLEAR: mt_lines, mt_stmts, mt_findings.
  ENDMETHOD.


  METHOD clear_fixture.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR: mo_store, mo_sap_dao, mo_feb_dao, mo_cfg_dao.
  ENDMETHOD.


  METHOD rule.
    rs_rule-rule_id     = iv_rule_id.
    rs_rule-severity    = zif_cd_ops_types=>gc_severity-error.
    rs_rule-action      = zif_cd_ops_types=>gc_action-exception.
    rs_rule-param1      = iv_param1.
    rs_rule-param2      = iv_param2.
    rs_rule-tolerance   = iv_tolerance.
    rs_rule-window_days = iv_window_days.
    rs_rule-active      = abap_true.
  ENDMETHOD.


  METHOD add_statement.
    DATA ls_stmt TYPE zif_cd_ebs_types=>ty_statement.
    ls_stmt-stmt_key       = gc_test-stmt_key.
    ls_stmt-source         = iv_source.
    ls_stmt-bukrs          = gc_test-bukrs.
    ls_stmt-hbkid          = gc_test-hbkid.
    ls_stmt-hktid          = gc_test-hktid.
    ls_stmt-account_no     = gc_test-account.
    ls_stmt-currency       = gc_test-usd.
    ls_stmt-stmt_no        = '00042'.
    ls_stmt-stmt_date      = gc_test-today.
    ls_stmt-has_opening    = xsdbool( iv_opening IS SUPPLIED ).
    ls_stmt-opening_bal    = iv_opening.
    ls_stmt-has_closing    = xsdbool( iv_closing IS SUPPLIED ).
    ls_stmt-closing_bal    = iv_closing.
    ls_stmt-declared_count = -1.
    ls_stmt-bank_key       = 'JPMC'.
    ls_stmt-flow_default   = zif_cd_ebs_types=>gc_flow-disbursement.
    INSERT ls_stmt INTO TABLE mt_stmts.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE zif_cd_ebs_types=>ty_line.
    ls_line-stmt_key     = gc_test-stmt_key.
    ls_line-line_no      = lines( mt_lines ) + 1.
    ls_line-scheme       = zif_cd_ebs_types=>gc_scheme-bai2.
    ls_line-btc_code     = '168'.
    ls_line-cdi          = iv_cdi.
    ls_line-exp_cdi      = iv_exp_cdi.
    ls_line-amount       = iv_amount.
    ls_line-currency     = gc_test-usd.
    ls_line-reference    = iv_reference.
    ls_line-belnr        = iv_belnr.
    ls_line-gjahr        = '2026'.
    ls_line-category     = iv_category.
    ls_line-rule_group   = iv_category.
    ls_line-booking_date = gc_test-today.
    ls_line-value_date   = iv_value_date.
    ls_line-flow_type    = zif_cd_ebs_types=>gc_flow-disbursement.
    INSERT ls_line INTO TABLE mt_lines.
  ENDMETHOD.


  METHOD run.
    TRY.
        DATA(lo_rule) = CAST zif_cd_ebs_rule( zcl_cd_ops_factory=>get_plugin( iv_class ) ).
        mt_findings = lo_rule->execute( is_rule       = is_rule
                                        it_statements = mt_stmts
                                        it_lines      = mt_lines ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Rule { iv_class } raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD assert_one_code.
    cl_abap_unit_assert=>assert_equals( act = lines( mt_findings ) exp = 1 msg = iv_msg ).
    cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-check_code exp = iv_check_code msg = iv_msg ).
  ENDMETHOD.

ENDCLASS.


"! Domain level: line rules that need no repository
CLASS ltc_line_rules DEFINITION FINAL FOR TESTING
  INHERITING FROM ltc_rule_fixture
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS r01_debit_on_credit_code     FOR TESTING.
    METHODS r01_reversal_may_flip_sign   FOR TESTING.
    METHODS r02_amount_above_max_fails   FOR TESTING.
    METHODS r03_foreign_currency_fails   FOR TESTING.
    METHODS r04_missing_reference_fails  FOR TESTING.
    METHODS r04_alnum_format_enforced    FOR TESTING.
    METHODS r05_unknown_reason_fails     FOR TESTING.
    METHODS r05_mapped_reason_passes     FOR TESTING.
    METHODS r09_second_identical_entry   FOR TESTING.
    METHODS r10_value_date_out_of_window FOR TESTING.
    METHODS r15_posting_rule_mismatch    FOR TESTING.
    METHODS r20_posted_line_fails        FOR TESTING.
ENDCLASS.


CLASS ltc_line_rules IMPLEMENTATION.

  METHOD setup.
    prepare_fixture( ).
  ENDMETHOD.


  METHOD teardown.
    clear_fixture( ).
  ENDMETHOD.


  " R01: a debit on a code that expects credits is a sign error
  METHOD r01_debit_on_credit_code.
    add_statement( ).
    add_line( iv_cdi = zif_cd_ebs_types=>gc_cdi-debit iv_exp_cdi = zif_cd_ebs_types=>gc_cdi-credit ).
    run( iv_class = 'ZCL_CD_EBS_R_R01_SIGN' is_rule = rule( 'R01' ) ).
    assert_one_code( iv_check_code = 'SIGN_MISMATCH' iv_msg = 'Debit on a credit code must fail R01' ).
  ENDMETHOD.


  " R01: a reversal entry carries the opposite sign legitimately
  METHOD r01_reversal_may_flip_sign.
    add_statement( ).
    add_line( iv_cdi = zif_cd_ebs_types=>gc_cdi-debit iv_exp_cdi = zif_cd_ebs_types=>gc_cdi-credit ).
    mt_lines[ 1 ]-reversal = abap_true.
    run( iv_class = 'ZCL_CD_EBS_R_R01_SIGN' is_rule = rule( 'R01' ) ).
    cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'Reversal with flipped sign must pass R01' ).
  ENDMETHOD.


  " R02: amount above the configured maximum (param2) fails
  METHOD r02_amount_above_max_fails.
    add_statement( ).
    add_line( iv_amount = '1000.01' ).
    run( iv_class = 'ZCL_CD_EBS_R_R02_BOUNDS' is_rule = rule( iv_rule_id = 'R02' iv_param1 = '0.01'
                                                             iv_param2 = '1000.00' ) ).
    assert_one_code( iv_check_code = 'AMOUNT_ABOVE_MAX' iv_msg = 'Amount above max must fail R02' ).
  ENDMETHOD.


  " R03: line currency must equal the statement currency
  METHOD r03_foreign_currency_fails.
    add_statement( ).
    add_line( ).
    mt_lines[ 1 ]-currency = 'CAD'.
    run( iv_class = 'ZCL_CD_EBS_R_R03_CURRENCY' is_rule = rule( 'R03' ) ).
    assert_one_code( iv_check_code = 'CURRENCY_MISMATCH' iv_msg = 'Foreign currency must fail R03' ).
  ENDMETHOD.


  " R04 (legacy CHECT_EMPTY): a required reference must be present
  METHOD r04_missing_reference_fails.
    add_statement( ).
    add_line( iv_reference = space ).
    run( iv_class = 'ZCL_CD_EBS_R_R04_REFERENCE' is_rule = rule( 'R04' ) ).
    assert_one_code( iv_check_code = 'REF_MISSING' iv_msg = 'Missing reference must fail R04' ).
  ENDMETHOD.


  " R04 (legacy CHECT_FORMAT): with param2 ALNUM only letters and digits are allowed
  METHOD r04_alnum_format_enforced.
    add_statement( ).
    add_line( iv_reference = '12-345' ).
    run( iv_class = 'ZCL_CD_EBS_R_R04_REFERENCE' is_rule = rule( iv_rule_id = 'R04' iv_param2 = 'ALNUM' ) ).
    assert_one_code( iv_check_code = 'REF_FORMAT' iv_msg = 'Non-alphanumeric reference must fail R04' ).
  ENDMETHOD.


  " R05: a return reason not mapped to an FI-CA reason fails
  METHOD r05_unknown_reason_fails.
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    ls_reason-reason      = 'R01'.
    ls_reason-fica_reason = '001'.
    INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
    add_statement( ).
    add_line( ).
    mt_lines[ 1 ]-return_reason = 'R99'.
    run( iv_class = 'ZCL_CD_EBS_R_R05_REASON' is_rule = rule( 'R05' ) ).
    assert_one_code( iv_check_code = 'REASON_UNMAPPED' iv_msg = 'Unmapped reason must fail R05' ).
  ENDMETHOD.


  " R05: a mapped NACHA reason passes
  METHOD r05_mapped_reason_passes.
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    ls_reason-reason      = 'R01'.
    ls_reason-fica_reason = '001'.
    INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
    add_statement( ).
    add_line( ).
    mt_lines[ 1 ]-return_reason = 'R01'.
    run( iv_class = 'ZCL_CD_EBS_R_R05_REASON' is_rule = rule( 'R05' ) ).
    cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'Mapped reason must pass R05' ).
  ENDMETHOD.


  " R09: the second identical entry (reference, amount, sign, value date) is a duplicate
  METHOD r09_second_identical_entry.
    add_statement( ).
    add_line( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R09_DUPLICATE' is_rule = rule( 'R09' ) ).
    assert_one_code( iv_check_code = 'DUPLICATE_ENTRY' iv_msg = 'Second identical entry must fail R09' ).
    cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-object_key exp = |{ gc_test-stmt_key }/2|
                                        msg = 'The duplicate is the second line, not the first' ).
  ENDMETHOD.


  " R10: value date more than window_days from booking date fails
  METHOD r10_value_date_out_of_window.
    add_statement( ).
    add_line( iv_value_date = '20261115' ).
    run( iv_class = 'ZCL_CD_EBS_R_R10_VALUE_DATE' is_rule = rule( iv_rule_id = 'R10' iv_window_days = 5 ) ).
    assert_one_code( iv_check_code = 'VALUE_DATE_WINDOW' iv_msg = 'Value date 10 days out must fail R10' ).
  ENDMETHOD.


  " R15: the posting rule used must be the one the BTC map prescribes
  METHOD r15_posting_rule_mismatch.
    add_statement( ).
    add_line( ).
    mt_lines[ 1 ]-map_posting  = 'Z168'.
    mt_lines[ 1 ]-posting_rule = 'Z999'.
    run( iv_class = 'ZCL_CD_EBS_R_R15_POSTING_RULE' is_rule = rule( 'R15' ) ).
    assert_one_code( iv_check_code = 'POSTING_RULE_MISMATCH' iv_msg = 'Wrong posting rule must fail R15' ).
  ENDMETHOD.


  " R20 (legacy 275/575 BELNR_NOT_EMPTY): this code must not have been posted
  METHOD r20_posted_line_fails.
    add_statement( ).
    add_line( iv_belnr = '1400000001' ).
    run( iv_class = 'ZCL_CD_EBS_R_R20_NOT_POSTED' is_rule = rule( 'R20' ) ).
    assert_one_code( iv_check_code = 'POSTED_UNEXPECTEDLY' iv_msg = 'Posted 275/575 line must fail R20' ).
  ENDMETHOD.

ENDCLASS.


"! Application level: payment engine lookups through LTD_SAP_DAO
CLASS ltc_lookup_rules DEFINITION FINAL FOR TESTING
  INHERITING FROM ltc_rule_fixture
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS keys_padded_to_doc_length    FOR TESTING.
    METHODS r07_missing_payment_fails    FOR TESTING.
    METHODS r07_not_returned_fails       FOR TESTING.
    METHODS r07c_cancelled_check_fails   FOR TESTING.
    METHODS r07l_retrieval_not_af_fails  FOR TESTING.
    METHODS r07r_lot_status_not_5_fails  FOR TESTING.
    METHODS r08_check_amount_mismatch    FOR TESTING.
    METHODS r08_within_tolerance_passes  FOR TESTING.
    METHODS r12_code_total_mismatch      FOR TESTING.
    METHODS r19_uncleared_doc_fails      FOR TESTING.
    METHODS r19_missing_doc_fails        FOR TESTING.
ENDCLASS.


CLASS ltc_lookup_rules IMPLEMENTATION.

  METHOD setup.
    prepare_fixture( ).
  ENDMETHOD.


  METHOD teardown.
    clear_fixture( ).
  ENDMETHOD.


  " CHECT 12345 is looked up as the 12-digit document number 000000012345
  METHOD keys_padded_to_doc_length.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( 'R07' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->mt_docno_seen[ 1 ] exp = gc_test-docno
                                        msg = 'Reference must be normalised to the document key' ).
  ENDMETHOD.


  " R07 (legacy 195D DPAYH_NOT_FOUND): the payment document must exist in DPAYH
  METHOD r07_missing_payment_fails.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( 'R07' ) ).
    assert_one_code( iv_check_code = 'PAYMENT_NOT_FOUND' iv_msg = 'Missing DPAYH must fail R07' ).
  ENDMETHOD.


  " R07 (legacy 168D DPAYH_NOT_RETURNED): with param1 RETURNED the payment status must match
  METHOD r07_not_returned_fails.
    DATA ls_payment TYPE zif_cd_ebs_sap_dao=>ty_payment.
    ls_payment-doc1r  = gc_test-docno.
    ls_payment-status = 'PAID'.
    INSERT ls_payment INTO TABLE mo_sap_dao->mt_payments.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( iv_rule_id = 'R07' iv_param1 = 'RETURNED' ) ).
    assert_one_code( iv_check_code = 'PAYMENT_STATUS' iv_msg = 'Non-returned payment must fail R07' ).
  ENDMETHOD.


  " R07C (legacy 255D DFKKCR_CANCELLED_99): a cancelled check in the register fails
  METHOD r07c_cancelled_check_fails.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    ls_check-ztnum    = gc_test-ref.
    ls_check-crstatus = '99'.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R07C_CHECK' is_rule = rule( 'R07C' ) ).
    assert_one_code( iv_check_code = 'CHECK_STATUS' iv_msg = 'Cancelled check must fail R07C' ).
  ENDMETHOD.


  " R07L (legacy 468D RETR_STATUS_NOT_AF): the ACH retrieval must be in status AF
  METHOD r07l_retrieval_not_af_fails.
    DATA ls_retrieval TYPE zif_cd_ebs_sap_dao=>ty_retrieval.
    ls_retrieval-augbl  = gc_test-docno.
    ls_retrieval-status = 'RQ'.
    INSERT ls_retrieval INTO TABLE mo_sap_dao->mt_retrievals.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R07L_RETRIEVAL' is_rule = rule( 'R07L' ) ).
    assert_one_code( iv_check_code = 'RETRIEVAL_STATUS' iv_msg = 'Retrieval not AF must fail R07L' ).
  ENDMETHOD.


  " R07R (legacy 166D STARS_NOT_5): the returns lot must be in status 5
  METHOD r07r_lot_status_not_5_fails.
    DATA ls_item TYPE zif_cd_ebs_sap_dao=>ty_return_item.
    ls_item-selw1     = gc_test-docno.
    ls_item-opbel     = '000000099999'.
    ls_item-lot_stars = '2'.
    INSERT ls_item INTO TABLE mo_sap_dao->mt_items.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R07R_RETURN_LOT' is_rule = rule( 'R07R' ) ).
    assert_one_code( iv_check_code = 'RETURN_LOT_STATUS' iv_msg = 'Lot status 2 must fail R07R' ).
  ENDMETHOD.


  " R08 (legacy 581D AMOUNT_MISMATCH): check register amount must equal the bank amount
  METHOD r08_check_amount_mismatch.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    ls_check-ztnum  = gc_test-ref.
    ls_check-amount = '249.00'.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
    assert_one_code( iv_check_code = 'CHECK_AMOUNT_MISMATCH' iv_msg = 'Amount off by 1.00 must fail R08' ).
  ENDMETHOD.


  " R08: a difference inside the configured tolerance passes
  METHOD r08_within_tolerance_passes.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    ls_check-ztnum  = gc_test-ref.
    ls_check-amount = '249.99'.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( iv_rule_id = 'R08' iv_tolerance = '0.01' ) ).
    cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'Difference 0.01 within tolerance must pass' ).
  ENDMETHOD.


  " R12 (legacy 581D TOTAL_SUM_MISMATCH): code total per statement must equal the register total
  METHOD r12_code_total_mismatch.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    ls_check-ztnum  = gc_test-ref.
    ls_check-amount = gc_test-amount.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    add_statement( ).
    add_line( ).
    add_line( iv_reference = '67890' ).
    run( iv_class = 'ZCL_CD_EBS_R_R12_CODE_TOTAL' is_rule = rule( 'R12' ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( mt_findings ) exp = 2
                                        msg = 'Sum and count must both be reported' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( mt_findings[ check_code = 'CODE_TOTAL_MISMATCH' ] )
                 AND line_exists( mt_findings[ check_code = 'CODE_COUNT_MISMATCH' ] ) )
      msg = 'Both total and count mismatch must be reported for the statement' ).
  ENDMETHOD.


  " R19 (legacy 166C AUGBL_INITIAL): with param1 CLEARED the bank posting must be cleared
  METHOD r19_uncleared_doc_fails.
    DATA ls_fi_line TYPE zif_cd_ebs_sap_dao=>ty_fi_line.
    ls_fi_line-bukrs = gc_test-bukrs.
    ls_fi_line-belnr = '1400000001'.
    ls_fi_line-gjahr = '2026'.
    ls_fi_line-buzei = '001'.
    INSERT ls_fi_line INTO TABLE mo_sap_dao->mt_fi_lines.
    add_statement( ).
    add_line( iv_belnr = '1400000001' ).
    run( iv_class = 'ZCL_CD_EBS_R_R19_FI_DOCUMENT' is_rule = rule( iv_rule_id = 'R19' iv_param1 = 'CLEARED' ) ).
    assert_one_code( iv_check_code = 'FI_DOC_NOT_CLEARED' iv_msg = 'Uncleared posting must fail R19' ).
  ENDMETHOD.


  " R19 (legacy 466D BSEG_NOT_FOUND): the posted FI document must exist
  METHOD r19_missing_doc_fails.
    add_statement( ).
    add_line( iv_belnr = '1400000001' ).
    run( iv_class = 'ZCL_CD_EBS_R_R19_FI_DOCUMENT' is_rule = rule( 'R19' ) ).
    assert_one_code( iv_check_code = 'FI_DOC_NOT_FOUND' iv_msg = 'Missing FI document must fail R19' ).
  ENDMETHOD.

ENDCLASS.


"! Statement checks S01-S12 and R18
CLASS ltc_stmt_rules DEFINITION FINAL FOR TESTING
  INHERITING FROM ltc_rule_fixture
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS s01_opening_ne_prior_closing FOR TESTING.
    METHODS s01_deviation_within_toler   FOR TESTING.
    METHODS s02_arithmetic_break_fails   FOR TESTING.
    METHODS s02_balanced_statement_ok    FOR TESTING.
    METHODS s03_number_gap_detected      FOR TESTING.
    METHODS s04_unconfigured_account     FOR TESTING.
    METHODS s05_future_date_fails        FOR TESTING.
    METHODS s07_already_imported_fails   FOR TESTING.
    METHODS s09_unmapped_lines_reported  FOR TESTING.
    METHODS s10_unposted_entry_reported  FOR TESTING.
    METHODS s12_count_mismatch_reported  FOR TESTING.
    METHODS r18_gl_ne_closing_fails      FOR TESTING.
ENDCLASS.


CLASS ltc_stmt_rules IMPLEMENTATION.

  METHOD setup.
    prepare_fixture( ).
  ENDMETHOD.


  METHOD teardown.
    clear_fixture( ).
  ENDMETHOD.


  " S01: opening balance must equal the prior statement's closing balance
  METHOD s01_opening_ne_prior_closing.
    mo_feb_dao->ms_prior-aznum = '00041'.
    mo_feb_dao->ms_prior-azdat = '20261104'.
    mo_feb_dao->ms_prior-esbtr = '1000.00'.
    mo_feb_dao->ms_prior-esvoz = 'H'.
    add_statement( iv_opening = '900.00' iv_closing = '900.00' ).
    run( iv_class = 'ZCL_CD_EBS_R_S01_CONTINUITY' is_rule = rule( 'S01' ) ).
    assert_one_code( iv_check_code = 'OPENING_NE_PRIOR_CLOSING' iv_msg = 'Break in balance chain must fail S01' ).
  ENDMETHOD.


  " S01 / acceptance test 4: a deviation up to the configured 0.01 tolerance passes
  METHOD s01_deviation_within_toler.
    mo_feb_dao->ms_prior-aznum = '00041'.
    mo_feb_dao->ms_prior-azdat = '20261104'.
    mo_feb_dao->ms_prior-esbtr = '1000.00'.
    mo_feb_dao->ms_prior-esvoz = 'H'.
    add_statement( iv_opening = '1000.01' iv_closing = '1000.01' ).
    run( iv_class = 'ZCL_CD_EBS_R_S01_CONTINUITY' is_rule = rule( iv_rule_id = 'S01' iv_tolerance = '0.01' ) ).
    cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'Deviation 0.01 within tolerance must pass S01' ).
  ENDMETHOD.


  " S02: opening + credits - debits must equal closing
  METHOD s02_arithmetic_break_fails.
    add_statement( iv_opening = '1000.00' iv_closing = '1300.00' ).
    add_line( iv_cdi = zif_cd_ebs_types=>gc_cdi-credit iv_amount = '250.00' ).
    run( iv_class = 'ZCL_CD_EBS_R_S02_BALANCE' is_rule = rule( 'S02' ) ).
    assert_one_code( iv_check_code = 'BALANCE_ARITHMETIC' iv_msg = '1000 + 250 <> 1300 must fail S02' ).
  ENDMETHOD.


  " S02: a statement that adds up passes
  METHOD s02_balanced_statement_ok.
    add_statement( iv_opening = '1000.00' iv_closing = '1150.00' ).
    add_line( iv_cdi = zif_cd_ebs_types=>gc_cdi-credit iv_amount = '250.00' ).
    add_line( iv_cdi = zif_cd_ebs_types=>gc_cdi-debit iv_amount = '100.00' iv_reference = '67890' ).
    run( iv_class = 'ZCL_CD_EBS_R_S02_BALANCE' is_rule = rule( 'S02' ) ).
    cl_abap_unit_assert=>assert_initial( act = mt_findings msg = '1000 + 250 - 100 = 1150 must pass S02' ).
  ENDMETHOD.


  " S03: statement 42 after prior 40 leaves a gap
  METHOD s03_number_gap_detected.
    mo_feb_dao->ms_prior-aznum = '00040'.
    mo_feb_dao->ms_prior-azdat = '20261104'.
    add_statement( ).
    run( iv_class = 'ZCL_CD_EBS_R_S03_SEQUENCE' is_rule = rule( 'S03' ) ).
    assert_one_code( iv_check_code = 'STMT_NO_GAP' iv_msg = 'Statement 42 after 40 must report a gap' ).
  ENDMETHOD.


  " S04: a statement for an account not in ZCD_EBS_ACCT fails
  METHOD s04_unconfigured_account.
    CLEAR mo_cfg_dao->mt_accounts.
    add_statement( ).
    run( iv_class = 'ZCL_CD_EBS_R_S04_ACCOUNT' is_rule = rule( 'S04' ) ).
    assert_one_code( iv_check_code = 'ACCOUNT_NOT_CONFIGURED' iv_msg = 'Unknown account must fail S04' ).
  ENDMETHOD.


  " S05: a statement dated in the future fails
  METHOD s05_future_date_fails.
    add_statement( ).
    mt_stmts[ 1 ]-stmt_date = '20261106'.
    run( iv_class = 'ZCL_CD_EBS_R_S05_DATE' is_rule = rule( 'S05' ) ).
    assert_one_code( iv_check_code = 'STMT_DATE_FUTURE' iv_msg = 'Future statement date must fail S05' ).
  ENDMETHOD.


  " S07: a file statement already imported into FEBKO is a duplicate
  METHOD s07_already_imported_fails.
    mo_feb_dao->mv_exists = abap_true.
    add_statement( iv_source = zif_cd_ebs_types=>gc_source-file ).
    run( iv_class = 'ZCL_CD_EBS_R_S07_DUPLICATE' is_rule = rule( 'S07' ) ).
    assert_one_code( iv_check_code = 'STMT_ALREADY_IMPORTED' iv_msg = 'Re-delivered statement must fail S07' ).
  ENDMETHOD.


  " S09: BTC coverage - one finding per statement with unmapped lines
  METHOD s09_unmapped_lines_reported.
    add_statement( ).
    add_line( iv_category = zif_cd_ebs_types=>gc_category_unmapped ).
    add_line( iv_reference = '67890' ).
    run( iv_class = 'ZCL_CD_EBS_R_S09_COVERAGE' is_rule = rule( 'S09' ) ).
    assert_one_code( iv_check_code = 'BTC_COVERAGE' iv_msg = 'Statement with an unmapped line must fail S09' ).
  ENDMETHOD.


  " S10: an imported entry that is neither posted nor blocked is unaccounted for
  METHOD s10_unposted_entry_reported.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_S10_COMPLETE' is_rule = rule( 'S10' ) ).
    assert_one_code( iv_check_code = 'ENTRIES_NOT_ACCOUNTED' iv_msg = 'Unposted, unblocked entry must fail S10' ).
  ENDMETHOD.


  " S12: FEBKO entry count must equal the entries read
  METHOD s12_count_mismatch_reported.
    add_statement( ).
    mt_stmts[ 1 ]-declared_count = 2.
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_S12_COUNT' is_rule = rule( 'S12' ) ).
    assert_one_code( iv_check_code = 'ENTRY_COUNT' iv_msg = 'Declared 2, read 1 must fail S12' ).
  ENDMETHOD.


  " R18: after posting, the bank G/L balance must equal the statement closing balance
  METHOD r18_gl_ne_closing_fails.
    mo_sap_dao->mv_gl_balance = '1100.00'.
    add_statement( iv_opening = '1000.00' iv_closing = '1150.00' ).
    run( iv_class = 'ZCL_CD_EBS_R_R18_GL_BALANCE' is_rule = rule( 'R18' ) ).
    assert_one_code( iv_check_code = 'GL_NE_CLOSING' iv_msg = 'G/L 1100 vs closing 1150 must fail R18' ).
  ENDMETHOD.

ENDCLASS.
