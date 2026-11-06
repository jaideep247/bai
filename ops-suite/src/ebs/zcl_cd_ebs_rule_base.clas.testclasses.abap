*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_rule_base.clas.testclasses.abap
*& Purpose:
*& Tests for every EBS rule class (R01-R19, S01-S12), grouped by test level:
*& LTC_LINE_RULES (domain, no repository), LTC_LOOKUP_RULES (payment engine
*& reads through LTD_SAP_DAO) and LTC_STMT_RULES (statement checks, LTD_FEB_DAO).
*& Legacy parity rows (v4 BAI validators) are named in the comments.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | 275/575 not validated (business decision): R20 removed, sweep test.
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-06 | Audit A11: 166 disbursement retrieval-log chain (R07L PARAM2 AP, PARAM3 LOT).
*& 2026-11-06 | Audit A25 / A33: canonical account identity, missing currencies.
*& 2026-11-06 | Audit A07 / A08: company code in the register match, leading zeros, R12 populations.
*& 2026-11-06 | Audit A14: cross-statement duplicate look-back (R22).
*& 2026-11-06 | Audit A26 / A32 / A34: sweeps not posted, imported entry without posting rule, sign and gross totals.
*&---------------------------------------------------------------------*
CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.
    DATA mt_params TYPE zif_cd_ops_types=>tt_kv.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    rs_run-pe_area = iv_pe_area.
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
    DATA mt_ztnum_seen TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    DATA mt_lookup_rows TYPE zif_cd_ebs_sap_dao=>tt_lookup_row.
    DATA ms_lookup_used TYPE zif_cd_ebs_types=>ty_lookup_cfg.
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
    mt_ztnum_seen = it_ztnum.
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
  METHOD zif_cd_ebs_sap_dao~get_lookup_rows.
    ms_lookup_used = is_lookup.
    LOOP AT mt_lookup_rows INTO DATA(ls_row).
      IF line_exists( it_keys[ table_line = ls_row-lookup_key ] ).
        INSERT ls_row INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_feb_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao.
    DATA ms_prior  TYPE zif_cd_ebs_feb_dao=>ty_header.
    DATA mv_exists TYPE abap_bool.
    DATA mt_recent TYPE zif_cd_ebs_feb_dao=>tt_item.
    DATA mv_from   TYPE d.
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
  METHOD zif_cd_ebs_feb_dao~get_recent_items.
    mv_from  = iv_from.
    rt_items = mt_recent.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_cfg_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao.
    DATA mt_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.
    DATA mt_reasons  TYPE zif_cd_ebs_types=>tt_reason_map.
    DATA mt_lookups  TYPE zif_cd_ebs_types=>tt_lookup_cfg.
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
  METHOD zif_cd_ebs_cfg_dao~get_lookups.
    rt_lookups = mt_lookups.
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
        iv_param3      TYPE clike OPTIONAL
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
    rs_rule-param3      = iv_param3.
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
    METHODS r15_imported_without_rule    FOR TESTING.
    METHODS r03_missing_currency         FOR TESTING.
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
ENDCLASS.


CLASS ltc_line_rules IMPLEMENTATION.

  METHOD setup.
    prepare_fixture( ).
  ENDMETHOD.


  METHOD teardown.
    clear_fixture( ).
  ENDMETHOD.


  " R01: a debit on a code that expects credits is a sign error
  " A33: a line without currency cannot be compared - reported instead of skipped
  METHOD r03_missing_currency.
    TRY.
        add_statement( ).
        add_line( ).
        CLEAR mt_lines[ 1 ]-currency.
        run( iv_class = 'ZCL_CD_EBS_R_R03_CURRENCY' is_rule = rule( 'R03' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-currency_missing
                         iv_msg        = 'A line without currency must be reported by R03' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A32: an imported entry without posting rule (FEBEP-VGINT) is reported - FF_5 could not
  " interpret it; a parsed file (not yet imported) has no posting rule yet and is not reported
  METHOD r15_imported_without_rule.
    TRY.
        add_statement( ).
        add_line( ).
        mt_lines[ 1 ]-map_posting = '0001'.
        run( iv_class = 'ZCL_CD_EBS_R_R15_POSTING_RULE' is_rule = rule( 'R15' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-posting_rule_unresolved
                         iv_msg        = 'An imported entry without posting rule must be reported' ).
        CLEAR mt_findings.
        mt_stmts[ 1 ]-source = zif_cd_ebs_types=>gc_source-file.
        run( iv_class = 'ZCL_CD_EBS_R_R15_POSTING_RULE' is_rule = rule( 'R15' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'A parsed file has no posting rule yet - not reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


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


  " R05: a return reason not mapped to an payment engine reason fails
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
    METHODS r08_other_house_bank_ignored FOR TESTING.
    METHODS r12_code_total_mismatch      FOR TESTING.
    METHODS r19_uncleared_doc_fails      FOR TESTING.
    METHODS r19_missing_doc_fails        FOR TESTING.
    METHODS r07_any_run_with_status_ok   FOR TESTING.
    METHODS r07l_any_af_attempt_passes   FOR TESTING.
    METHODS r07l_ap_passes_without_lot   FOR TESTING.
    METHODS r07l_af_with_lot_passes      FOR TESTING.
    METHODS r07l_af_without_lot_fails    FOR TESTING.
    METHODS r07l_chain_no_retrieval      FOR TESTING.
    METHODS r07l_chain_other_status      FOR TESTING.
    METHODS run_166d_chain
      IMPORTING
        iv_status TYPE zif_cd_ebs_sap_dao=>ty_retrieval-status OPTIONAL
        iv_lot    TYPE abap_bool DEFAULT abap_false.
    METHODS r07r_any_done_lot_passes     FOR TESTING.
    METHODS r07c_any_cancelled_row_fails FOR TESTING.
    METHODS r08_unknown_bank_ambiguous   FOR TESTING.
    METHODS r08_unknown_bank_single_ok   FOR TESTING.
    METHODS r08_other_company_ignored    FOR TESTING.
    METHODS r08_leading_zeros_match      FOR TESTING.
    METHODS r08_bank_zeros_register_none FOR TESTING.
    METHODS r12_equal_total_other_count  FOR TESTING.
    METHODS r12_register_row_not_reused  FOR TESTING.
    METHODS r21_missing_record_reported  FOR TESTING.
    METHODS r21_any_allowed_status_ok    FOR TESTING.
    METHODS r21_status_not_allowed       FOR TESTING.
    METHODS r21_unknown_lookup_raises    FOR TESTING.
    METHODS add_lookup
      IMPORTING
        iv_allowed TYPE clike DEFAULT 'OK'.
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


  " Review 3.2: ZTNUM is unique only per house bank; a register row of another bank must not be summed
  METHOD r08_other_house_bank_ignored.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    ls_check-ztnum  = gc_test-ref.
    ls_check-hbkid  = gc_test-hbkid.
    ls_check-hktid  = gc_test-hktid.
    ls_check-amount = gc_test-amount.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    ls_check-hbkid  = 'BOFA1'.
    ls_check-hktid  = 'COLL1'.
    ls_check-amount = '999.00'.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
    cl_abap_unit_assert=>assert_initial( act = mt_findings
                                         msg = 'Same check number at another house bank must be ignored' ).
  ENDMETHOD.


  " Several DPAYH runs for one document (review 2026-11-06): any productive run with an
  " allowed status satisfies R07 - the first row returned is not authoritative
  METHOD r07_any_run_with_status_ok.
    DATA ls_payment TYPE zif_cd_ebs_sap_dao=>ty_payment.
    TRY.
        ls_payment-doc1r  = gc_test-docno.
        ls_payment-laufi  = 'RUN2'.
        ls_payment-status = 'PAID'.
        INSERT ls_payment INTO TABLE mo_sap_dao->mt_payments.
        ls_payment-laufi  = 'RUN1'.
        ls_payment-status = 'RETURNED'.
        INSERT ls_payment INTO TABLE mo_sap_dao->mt_payments.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( iv_rule_id = 'R07' iv_param1 = 'RETURNED' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'A RETURNED run among several must satisfy R07' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Retrieval log with several attempts: an AF attempt satisfies R07L even when a
  " failed attempt was written after it (same pattern as ZCD_PAYM_REQ_LOG SUCCESS)
  METHOD r07l_any_af_attempt_passes.
    DATA ls_retrieval TYPE zif_cd_ebs_sap_dao=>ty_retrieval.
    TRY.
        ls_retrieval-augbl  = gc_test-docno.
        ls_retrieval-status = 'ER'.
        INSERT ls_retrieval INTO TABLE mo_sap_dao->mt_retrievals.
        ls_retrieval-status = 'AF'.
        INSERT ls_retrieval INTO TABLE mo_sap_dao->mt_retrievals.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07L_RETRIEVAL' is_rule = rule( iv_rule_id = 'R07L' iv_param1 = 'AF' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'An AF attempt among several must satisfy R07L' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A11 (business decision): 166 disbursement - retrieval-log chain. R07L with PARAM1 AF,
  " PARAM2 AP (passes alone) and PARAM3 LOT (AF needs a returns-lot entry by SELW1)
  METHOD run_166d_chain.
    DATA ls_retrieval TYPE zif_cd_ebs_sap_dao=>ty_retrieval.
    DATA ls_item      TYPE zif_cd_ebs_sap_dao=>ty_return_item.
    IF iv_status IS NOT INITIAL.
      ls_retrieval-augbl  = gc_test-docno.
      ls_retrieval-status = iv_status.
      INSERT ls_retrieval INTO TABLE mo_sap_dao->mt_retrievals.
    ENDIF.
    IF iv_lot = abap_true.
      ls_item-selw1     = gc_test-docno.
      ls_item-opbel     = '000000000001'.
      ls_item-lot_stars = '1'.
      INSERT ls_item INTO TABLE mo_sap_dao->mt_items.
    ENDIF.
    add_statement( ).
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R07L_RETRIEVAL'
         is_rule  = rule( iv_rule_id = 'R07L' iv_param1 = 'AF' iv_param2 = 'AP' iv_param3 = 'LOT' ) ).
  ENDMETHOD.


  " A11: retrieval status AP passes on its own - no returns lot needed
  METHOD r07l_ap_passes_without_lot.
    TRY.
        run_166d_chain( iv_status = 'AP' ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'AP must pass without a returns lot' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A11: retrieval status AF plus a returns-lot entry passes
  METHOD r07l_af_with_lot_passes.
    TRY.
        run_166d_chain( iv_status = 'AF' iv_lot = abap_true ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'AF with a returns lot must pass' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A11: AF without a returns-lot entry fails
  METHOD r07l_af_without_lot_fails.
    TRY.
        run_166d_chain( iv_status = 'AF' ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-return_item_not_found
                         iv_msg        = 'AF without a returns lot must fail' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A11: no retrieval at all fails, even when a returns lot exists
  METHOD r07l_chain_no_retrieval.
    TRY.
        run_166d_chain( iv_lot = abap_true ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-retrieval_not_found
                         iv_msg        = 'A missing retrieval must fail the chain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A11: a retrieval in another status (neither AP nor AF) fails
  METHOD r07l_chain_other_status.
    TRY.
        run_166d_chain( iv_status = 'ER' iv_lot = abap_true ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-retrieval_status
                         iv_msg        = 'A retrieval neither AP nor AF must fail the chain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Payment in two returns lots: a lot with the required status satisfies R07R
  METHOD r07r_any_done_lot_passes.
    DATA ls_item TYPE zif_cd_ebs_sap_dao=>ty_return_item.
    TRY.
        ls_item-selw1     = gc_test-docno.
        ls_item-opbel     = '000000000001'.
        ls_item-lot_stars = '1'.
        INSERT ls_item INTO TABLE mo_sap_dao->mt_items.
        ls_item-opbel     = '000000000002'.
        ls_item-lot_stars = '5'.
        INSERT ls_item INTO TABLE mo_sap_dao->mt_items.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07R_RETURN_LOT' is_rule = rule( iv_rule_id = 'R07R' iv_param1 = '5' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'A lot with status 5 among several must satisfy R07R' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fail closed: a cancelled register row fails R07C even when it is not the first row
  METHOD r07c_any_cancelled_row_fails.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum    = gc_test-ref.
        ls_check-crstatus = '01'.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        ls_check-crstatus = '99'.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07C_CHECK' is_rule = rule( 'R07C' ) ).
        assert_one_code( iv_check_code = 'CHECK_STATUS' iv_msg = 'A cancelled row must fail R07C' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Statement account without house bank (not in ZCD_EBS_ACCT) and the check number in
  " two house bank accounts: no account isolation is possible - reported, never matched
  METHOD r08_unknown_bank_ambiguous.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum  = gc_test-ref.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-amount = gc_test-amount.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        ls_check-hbkid  = 'BOFA1'.
        ls_check-hktid  = 'COLL1'.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        CLEAR: mt_stmts[ 1 ]-hbkid, mt_stmts[ 1 ]-hktid.
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        assert_one_code( iv_check_code = 'HOUSE_BANK_AMBIGUOUS'
                         iv_msg        = 'Unknown house bank with two candidate accounts must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Statement without house bank but the check number in one account only: unambiguous
  METHOD r08_unknown_bank_single_ok.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum  = gc_test-ref.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-amount = gc_test-amount.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        CLEAR: mt_stmts[ 1 ]-hbkid, mt_stmts[ 1 ]-hktid.
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'One candidate account is unambiguous and must match' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Generic lookup R21 (new BAI codes need configuration only): PARAM1 names a ZCD_EBS_LOOKUP
  " row - table, key field, key kind, status field, allowed values
  METHOD add_lookup.
    DATA ls_lookup TYPE zif_cd_ebs_types=>ty_lookup_cfg.
    ls_lookup-lookup_id      = 'TESTLKP'.
    ls_lookup-table_name     = 'ZCD_TEST_LOG'.
    ls_lookup-key_field      = 'DOCNO'.
    ls_lookup-key_kind       = zif_cd_ebs_types=>gc_lookup_key-docno.
    ls_lookup-status_field   = 'STATUS'.
    ls_lookup-allowed_values = iv_allowed.
    ls_lookup-active         = abap_true.
    INSERT ls_lookup INTO TABLE mo_cfg_dao->mt_lookups.
  ENDMETHOD.


  " R21: a line whose key is not in the configured table is reported (default check code)
  METHOD r21_missing_record_reported.
    TRY.
        add_lookup( ).
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R21_LOOKUP' is_rule = rule( iv_rule_id = 'R21' iv_param1 = 'TESTLKP' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-lookup_not_found
                         iv_msg        = 'A key missing in the lookup table must fail R21' ).
        cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->ms_lookup_used-table_name exp = 'ZCD_TEST_LOG'
                                            msg = 'The configured table must be read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " R21: like R07, any matching row with an allowed status satisfies the rule
  METHOD r21_any_allowed_status_ok.
    DATA ls_row TYPE zif_cd_ebs_sap_dao=>ty_lookup_row.
    TRY.
        add_lookup( ).
        ls_row-lookup_key = gc_test-docno.
        ls_row-status     = 'ER'.
        INSERT ls_row INTO TABLE mo_sap_dao->mt_lookup_rows.
        ls_row-status     = 'OK'.
        INSERT ls_row INTO TABLE mo_sap_dao->mt_lookup_rows.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R21_LOOKUP' is_rule = rule( iv_rule_id = 'R21' iv_param1 = 'TESTLKP' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'An allowed status among several rows must satisfy R21' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " R21: found, but no row has an allowed status
  METHOD r21_status_not_allowed.
    DATA ls_row TYPE zif_cd_ebs_sap_dao=>ty_lookup_row.
    TRY.
        add_lookup( 'OK,DONE' ).
        ls_row-lookup_key = gc_test-docno.
        ls_row-status     = 'ER'.
        INSERT ls_row INTO TABLE mo_sap_dao->mt_lookup_rows.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R21_LOOKUP' is_rule = rule( iv_rule_id = 'R21' iv_param1 = 'TESTLKP' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-lookup_status
                         iv_msg        = 'A status outside the allowed values must fail R21' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " R21: an unknown or inactive lookup ID is a configuration error - raised, so the engine
  " records PLUGIN_ERROR with action BLOCK (fail closed), never a silent pass
  METHOD r21_unknown_lookup_raises.
    DATA lx_expected TYPE REF TO zcx_cd_ops_error.
    add_statement( ).
    add_line( ).
    TRY.
        DATA(lo_rule) = CAST zif_cd_ebs_rule( zcl_cd_ops_factory=>get_plugin( 'ZCL_CD_EBS_R_R21_LOOKUP' ) ).
        lo_rule->execute( is_rule       = rule( iv_rule_id = 'R21' iv_param1 = 'NOSUCH' )
                          it_statements = mt_stmts
                          it_lines      = mt_lines ).
      CATCH zcx_cd_ops_error INTO lx_expected.
        cl_abap_unit_assert=>assert_bound( act = lx_expected msg = 'Unknown lookup must raise' ).
      CATCH cx_root INTO DATA(lx_other).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_other->get_text( ) }| ).
    ENDTRY.
    cl_abap_unit_assert=>assert_bound( act = lx_expected msg = 'An unknown lookup ID must raise ZCX_CD_OPS_ERROR' ).
  ENDMETHOD.


  " A07: the same house bank ID in another company code is another account - its register
  " row (company code from DFKKCR) is ignored
  METHOD r08_other_company_ignored.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum  = gc_test-ref.
        ls_check-bukrs  = gc_test-bukrs.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-amount = gc_test-amount.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        ls_check-bukrs  = 'CA01'.
        ls_check-amount = '999.00'.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'A register row of another company code must be ignored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Leading zeros: the bank strips them, the register keeps them (EBS_KEYLEN_ZTNUM = 13)
  METHOD r08_leading_zeros_match.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        INSERT VALUE #( name = 'EBS_KEYLEN_ZTNUM' value = '13' ) INTO TABLE mo_store->mt_params.
        ls_check-ztnum  = '0000000012345'.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-amount = gc_test-amount.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = '12345 and 0000000012345 must be the same check' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Leading zeros the other way round: the bank sends them, the register does not
  METHOD r08_bank_zeros_register_none.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum  = gc_test-ref.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-amount = gc_test-amount.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( iv_reference = '0000000012345' ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = '0000000012345 from the bank must match register 12345' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A08: equal totals with unequal counts fail - one bank entry against two register rows
  METHOD r12_equal_total_other_count.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum  = gc_test-ref.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-doc1r  = '000000000001'.
        ls_check-amount = '125.00'.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        ls_check-doc1r  = '000000000002'.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R12_CODE_TOTAL' is_rule = rule( 'R12' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-code_count_mismatch
                         iv_msg        = 'One bank entry against two register rows must fail on count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A08: a repeated bank reference must not reuse the same register row
  METHOD r12_register_row_not_reused.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum  = gc_test-ref.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-amount = gc_test-amount.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R12_CODE_TOTAL' is_rule = rule( 'R12' ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mt_findings ) exp = 2
                                            msg = 'Two bank entries on one register row: total and count fail' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
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
    METHODS s01_nearest_package_prior    FOR TESTING.
    METHODS s01_other_account_not_prior  FOR TESTING.
    METHODS s07_two_accounts_same_number FOR TESTING.
    METHODS r22_entry_in_earlier_stmt    FOR TESTING.
    METHODS s10_unposted_sweep_ok        FOR TESTING.
    METHODS s02_unknown_cdi_reported     FOR TESTING.
    METHODS s02_gross_totals_compared    FOR TESTING.
    METHODS r22_own_statement_ignored    FOR TESTING.
    METHODS r22_other_amount_not_dup     FOR TESTING.
    METHODS r22_window_from_rule         FOR TESTING.
    METHODS add_history_item
      IMPORTING
        iv_kukey  TYPE zif_cd_ebs_types=>ty_kukey
        iv_amount TYPE zif_cd_ops_types=>ty_amount DEFAULT gc_test-amount.
    METHODS run_r22.
    METHODS r18_gl_by_house_bank         FOR TESTING.
    METHODS s04_house_bank_preferred     FOR TESTING.
    METHODS s04_missing_currency         FOR TESTING.
    METHODS add_second_account_statement
      IMPORTING
        iv_opening TYPE zif_cd_ops_types=>ty_amount OPTIONAL
        iv_closing TYPE zif_cd_ops_types=>ty_amount OPTIONAL.
    METHODS s01_newer_stored_prior_wins  FOR TESTING.
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
    METHODS r18_unmapped_gl_reported     FOR TESTING.
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
  " Audit A15: the nearest earlier statement of the account (date, then number) is the
  " predecessor - not the last one in table order
  " Second statement of the same date and number on another house bank account; both
  " imported (FEBKO has no account number) - only the house bank identity tells them apart
  METHOD add_second_account_statement.
    add_statement( iv_opening = iv_opening iv_closing = iv_closing ).
    DATA(lv_last) = lines( mt_stmts ).
    mt_stmts[ lv_last ]-stmt_key = 'S0002'.
    mt_stmts[ lv_last ]-hbkid    = 'BOFA1'.
    mt_stmts[ lv_last ]-hktid    = 'COLL1'.
    LOOP AT mt_stmts ASSIGNING FIELD-SYMBOL(<ls_stmt>).
      CLEAR <ls_stmt>-account_no.
    ENDLOOP.
  ENDMETHOD.


  " A25: a statement of another house bank account is never the predecessor
  METHOD s01_other_account_not_prior.
    TRY.
        add_statement( iv_opening = '500.00' iv_closing = '600.00' ).
        add_second_account_statement( iv_opening = '100.00' iv_closing = '999.00' ).
        mt_stmts[ 2 ]-stmt_date = gc_test-today - 1.
        CLEAR mt_stmts[ 2 ]-has_opening.
        run( iv_class = 'ZCL_CD_EBS_R_S01_CONTINUITY' is_rule = rule( 'S01' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'Another account''s closing must not be compared' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A25: two accounts with the same statement date and number in one package are no duplicate
  METHOD s07_two_accounts_same_number.
    TRY.
        add_statement( ).
        add_second_account_statement( ).
        run( iv_class = 'ZCL_CD_EBS_R_S07_DUPLICATE' is_rule = rule( 'S07' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'Different house bank accounts must not collide in S07' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A25 / A16: the G/L account is found through the house bank identity of an imported statement
  METHOD r18_gl_by_house_bank.
    TRY.
        mo_sap_dao->mv_gl_balance = '1150.00'.
        add_statement( iv_opening = '1000.00' iv_closing = '1150.00' ).
        CLEAR mt_stmts[ 1 ]-account_no.
        run( iv_class = 'ZCL_CD_EBS_R_R18_GL_BALANCE' is_rule = rule( 'R18' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'R18 must find the G/L account by house bank account' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A33: the SAP house bank identity wins over an account number configured elsewhere
  METHOD s04_house_bank_preferred.
    DATA ls_other TYPE zif_cd_ebs_types=>ty_account_cfg.
    TRY.
        ls_other-bukrs      = gc_test-bukrs.
        ls_other-hbkid      = 'BOFA1'.
        ls_other-hktid      = 'COLL1'.
        ls_other-account_no = '000999999999'.
        ls_other-currency   = 'EUR'.
        ls_other-active     = abap_true.
        INSERT ls_other INTO TABLE mo_cfg_dao->mt_accounts.
        add_statement( ).
        mt_stmts[ 1 ]-account_no = ls_other-account_no.
        run( iv_class = 'ZCL_CD_EBS_R_S04_ACCOUNT' is_rule = rule( 'S04' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'The house bank account (USD) must be used, not the EUR one' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A33: a statement without currency cannot be checked - reported instead of skipped
  METHOD s04_missing_currency.
    TRY.
        add_statement( ).
        CLEAR mt_stmts[ 1 ]-currency.
        run( iv_class = 'ZCL_CD_EBS_R_S04_ACCOUNT' is_rule = rule( 'S04' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-account_currency_missing
                         iv_msg        = 'A statement without currency must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD add_history_item.
    DATA ls_item TYPE zif_cd_ebs_feb_dao=>ty_item.
    ls_item-kukey = iv_kukey.
    ls_item-esnum = 1.
    ls_item-vorgc = '168'.
    ls_item-epvoz = 'H'.
    ls_item-kwbtr = iv_amount.
    ls_item-chect = gc_test-ref.
    ls_item-budat = gc_test-today - 1.
    INSERT ls_item INTO TABLE mo_feb_dao->mt_recent.
  ENDMETHOD.


  METHOD run_r22.
    add_statement( ).
    mt_stmts[ 1 ]-kukey = '00000009'.
    add_line( ).
    run( iv_class = 'ZCL_CD_EBS_R_R22_DUP_HISTORY' is_rule = rule( iv_rule_id = 'R22' iv_window_days = 5 ) ).
  ENDMETHOD.


  " A14 (business decision): the same entry already imported in another statement of the
  " account within the look-back window is reported
  METHOD r22_entry_in_earlier_stmt.
    TRY.
        add_history_item( '00000008' ).
        run_r22( ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-duplicate_history
                         iv_msg        = 'An entry already in an earlier statement must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A14: the statement's own entries (same KUKEY) are not a duplicate
  METHOD r22_own_statement_ignored.
    TRY.
        add_history_item( '00000009' ).
        run_r22( ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'The statement itself must be excluded' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A14: a different amount is a different entry
  METHOD r22_other_amount_not_dup.
    TRY.
        add_history_item( iv_kukey = '00000008' iv_amount = '999.00' ).
        run_r22( ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'Another amount must not be a duplicate' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A14: the look-back window comes from the rule (WINDOW_DAYS) - 5 days before the statement date
  METHOD r22_window_from_rule.
    TRY.
        run_r22( ).
        cl_abap_unit_assert=>assert_equals( act = mo_feb_dao->mv_from exp = CONV d( gc_test-today - 5 )
                                            msg = 'The history must be read from the statement date minus WINDOW_DAYS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A26: a sweep the business does not post (map disposition NOT_POSTED) is complete unposted
  METHOD s10_unposted_sweep_ok.
    TRY.
        add_statement( ).
        add_line( ).
        mt_lines[ 1 ]-not_posted = abap_true.
        run( iv_class = 'ZCL_CD_EBS_R_S10_COMPLETE' is_rule = rule( 'S10' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'An unposted sweep (NOT_POSTED) must not be incomplete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A34: an entry without debit/credit indicator cannot be balanced - reported, never treated as credit
  METHOD s02_unknown_cdi_reported.
    TRY.
        add_statement( iv_opening = '1000.00' iv_closing = '1250.00' ).
        add_line( iv_cdi = space iv_amount = '250.00' ).
        run( iv_class = 'ZCL_CD_EBS_R_S02_BALANCE' is_rule = rule( 'S02' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-cdi_unknown
                         iv_msg        = 'An entry without debit/credit indicator must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A34: declared gross credits and debits are compared separately - equal overstatements on
  " both sides cancel out in the net, not in the gross comparison
  METHOD s02_gross_totals_compared.
    TRY.
        add_statement( iv_opening = '1000.00' iv_closing = '1250.00' ).
        mt_stmts[ 1 ]-has_totals    = abap_true.
        mt_stmts[ 1 ]-total_credits = '300.00'.
        mt_stmts[ 1 ]-total_debits  = '50.00'.
        add_line( iv_cdi = zif_cd_ebs_types=>gc_cdi-credit iv_amount = '250.00' ).
        run( iv_class = 'ZCL_CD_EBS_R_S02_BALANCE' is_rule = rule( 'S02' ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mt_findings ) exp = 2
                                            msg = 'Credits 250 vs 300 and debits 0 vs 50 must both be reported' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mt_findings[ check_code = zif_cd_ebs_types=>gc_check_code-gross_totals ] ) )
          msg = 'The gross deviation must be reported as GROSS_TOTALS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD s01_nearest_package_prior.
    TRY.
        " day 3 statement, opening 500 = closing of day 2
        add_statement( iv_opening = '500.00' iv_closing = '600.00' ).
        " day 2 (nearest) closes at 500
        add_statement( iv_opening = '400.00' iv_closing = '500.00' ).
        mt_stmts[ 2 ]-stmt_key  = 'S0002'.
        mt_stmts[ 2 ]-stmt_no   = '00041'.
        mt_stmts[ 2 ]-stmt_date = gc_test-today - 1.
        " day 1 closes at 400 and comes last in the table
        add_statement( iv_opening = '300.00' iv_closing = '400.00' ).
        mt_stmts[ 3 ]-stmt_key  = 'S0003'.
        mt_stmts[ 3 ]-stmt_no   = '00040'.
        mt_stmts[ 3 ]-stmt_date = gc_test-today - 2.
        CLEAR: mt_stmts[ 2 ]-has_opening, mt_stmts[ 3 ]-has_opening.
        run( iv_class = 'ZCL_CD_EBS_R_S01_CONTINUITY' is_rule = rule( 'S01' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'Day 3 must be compared with day 2, the nearest predecessor' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A15: a stored statement newer than every in-package candidate is the predecessor
  METHOD s01_newer_stored_prior_wins.
    TRY.
        mo_feb_dao->ms_prior-aznum = '00041'.
        mo_feb_dao->ms_prior-azdat = gc_test-today - 1.
        mo_feb_dao->ms_prior-esbtr = '500.00'.
        mo_feb_dao->ms_prior-esvoz = 'H'.
        add_statement( iv_opening = '500.00' iv_closing = '600.00' ).
        " in-package candidate two days back closes at 400
        add_statement( iv_opening = '300.00' iv_closing = '400.00' ).
        mt_stmts[ 2 ]-stmt_key  = 'S0003'.
        mt_stmts[ 2 ]-stmt_no   = '00040'.
        mt_stmts[ 2 ]-stmt_date = gc_test-today - 2.
        CLEAR mt_stmts[ 2 ]-has_opening.
        run( iv_class = 'ZCL_CD_EBS_R_S01_CONTINUITY' is_rule = rule( 'S01' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'The stored day-2 statement is nearer than the package day-1 one' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


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


  " No silent pass (review 2026-11-06): a statement whose account has no G/L account
  " cannot be reconciled - reported instead of skipped
  METHOD r18_unmapped_gl_reported.
    TRY.
        CLEAR mo_cfg_dao->mt_accounts[ 1 ]-gl_account.
        mo_sap_dao->mv_gl_balance = '1150.00'.
        add_statement( iv_opening = '1000.00' iv_closing = '1150.00' ).
        run( iv_class = 'ZCL_CD_EBS_R_R18_GL_BALANCE' is_rule = rule( 'R18' ) ).
        assert_one_code( iv_check_code = 'GL_ACCOUNT_NOT_MAPPED'
                         iv_msg        = 'A statement without G/L account must be reported by R18' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
