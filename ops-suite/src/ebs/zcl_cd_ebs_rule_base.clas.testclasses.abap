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
*& 2026-11-06 | Audit A28: incomplete reason mapping, NOC vs return.
*& 2026-11-06 | Audit A65: references sharing 12 characters, key length above width, malformed reference.
*& 2026-11-06 | FS-CD review: in-flight grace AWAITING_LOT_TRANSFER (window, after window, 166D lot, creation time).
*& 2026-11-06 | Performance fix 1: register memo (one read per package, new package re-reads, no key leak), zero flag parity.
*& 2026-11-06 | Performance fix 2: R22 history once per account per package, statement windows kept apart.
*& 2026-11-06 | Performance fix 4: rows of a key found by secondary key wherever they sit in the result.
*& 2026-11-06 | Performance fix 6: LTD_SAP_DAO answers get_gl_balances (balance per request, reads counted).
*& 2026-11-06 | Operating model: S13 POSTING_INCOMPLETE (one per statement with the count, file statement ignored).
*& 2026-11-06 | Return / NOC reason correction: R05 bank-file tests on the file source; LTC_R05_LOT_REASON
*&            | (FEB source: returns lot DFKKRP-RLGRD, NOC lot DFKKNRP-FLGRD by INFOF).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN, inline CAST.
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
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
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
    DATA mv_gl_reads TYPE i.
    DATA mt_gl_requests TYPE zif_cd_ebs_sap_dao=>tt_gl_request.
    DATA mt_docno_seen TYPE zif_cd_ebs_sap_dao=>tt_docno.
    DATA mt_ztnum_seen TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    DATA mv_check_reads TYPE i.
    DATA mt_lookup_rows TYPE zif_cd_ebs_sap_dao=>tt_lookup_row.
    DATA ms_lookup_used TYPE zif_cd_ebs_types=>ty_lookup_cfg.
    DATA mt_noc_items TYPE zif_cd_ebs_sap_dao=>tt_noc_item.
    DATA mt_infof_seen TYPE zif_cd_ebs_sap_dao=>tt_infof.
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
  METHOD zif_cd_ebs_sap_dao~get_noc_items.
    mt_infof_seen = it_infof.
    LOOP AT mt_noc_items ASSIGNING FIELD-SYMBOL(<ls_noc>).
      IF line_exists( it_infof[ table_line = <ls_noc>-infof ] ).
        INSERT <ls_noc> INTO TABLE rt_items.
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
    mv_check_reads = mv_check_reads + 1.
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
  METHOD zif_cd_ebs_sap_dao~get_gl_balances.
    mv_gl_reads += 1.
    mt_gl_requests = it_requests.
    LOOP AT it_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      INSERT VALUE #( request_no = <ls_request>-request_no balance = mv_gl_balance ) INTO TABLE rt_balances.
    ENDLOOP.
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
    DATA mv_recent_reads TYPE i.
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
    mv_recent_reads = mv_recent_reads + 1.
    " Window on the statement date, as the repository applies it
    LOOP AT mt_recent ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE azdat >= iv_from AND azdat <= iv_to.
      INSERT <ls_item> INTO TABLE rt_items.
    ENDLOOP.
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
        mt_findings = CAST zif_cd_ebs_rule( zcl_cd_ops_factory=>get_plugin( iv_class ) )->execute(
                        is_rule       = is_rule
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
    METHODS r05_placeholder_rejected     FOR TESTING.
    METHODS r05_noc_on_return_entry      FOR TESTING.
    METHODS r05_required_without_map     FOR TESTING.
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


  " R05 (bank file before import): a return reason not mapped to an payment engine reason fails
  METHOD r05_unknown_reason_fails.
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    ls_reason-reason      = 'R01'.
    ls_reason-fica_reason = '001'.
    INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
    add_statement( iv_source = zif_cd_ebs_types=>gc_source-file ).
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
    add_statement( iv_source = zif_cd_ebs_types=>gc_source-file ).
    add_line( ).
    mt_lines[ 1 ]-return_reason = 'R01'.
    run( iv_class = 'ZCL_CD_EBS_R_R05_REASON' is_rule = rule( 'R05' ) ).
    cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'Mapped reason must pass R05' ).
  ENDMETHOD.


  " A28: a mapping row without an effective payment engine reason (placeholder) is incomplete
  METHOD r05_placeholder_rejected.
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    TRY.
        ls_reason-reason      = 'R01'.
        ls_reason-fica_reason = '<PE'.
        INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
        add_statement( iv_source = zif_cd_ebs_types=>gc_source-file ).
        add_line( ).
        mt_lines[ 1 ]-return_reason = 'R01'.
        run( iv_class = 'ZCL_CD_EBS_R_R05_REASON' is_rule = rule( 'R05' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_map_incomplete
                         iv_msg        = 'A placeholder mapping must not count as mapped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A28: a NOC code on an entry routed as a return (PARAM2 RETURN) is the wrong kind
  METHOD r05_noc_on_return_entry.
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    TRY.
        ls_reason-reason      = 'C01'.
        ls_reason-fica_reason = '051'.
        ls_reason-is_noc      = abap_true.
        INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
        add_statement( iv_source = zif_cd_ebs_types=>gc_source-file ).
        add_line( ).
        mt_lines[ 1 ]-return_reason = 'C01'.
        run( iv_class = 'ZCL_CD_EBS_R_R05_REASON' is_rule = rule( iv_rule_id = 'R05' iv_param2 = 'RETURN' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_kind
                         iv_msg        = 'A NOC code on a return entry must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A28: a required reason cannot be validated without any mapping - incomplete configuration
  METHOD r05_required_without_map.
    TRY.
        add_statement( iv_source = zif_cd_ebs_types=>gc_source-file ).
        add_line( ).
        mt_lines[ 1 ]-return_reason = 'R01'.
        run( iv_class = 'ZCL_CD_EBS_R_R05_REASON' is_rule = rule( iv_rule_id = 'R05' iv_param1 = 'REQUIRED' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_map_incomplete
                         iv_msg        = 'A required reason without mapping must be reported, not format-checked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
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
    METHODS r07_rows_by_doc_key_parity   FOR TESTING.
    METHODS r08_zero_flag_off_rows_apart FOR TESTING.
    METHODS r08_zero_flag_on_rows_merged FOR TESTING.
    METHODS register_read_once_package   FOR TESTING.
    METHODS register_new_package_rereads FOR TESTING.
    METHODS register_memo_keys_not_leak  FOR TESTING.
    METHODS add_zero_pair.
    METHODS r21_missing_record_reported  FOR TESTING.
    METHODS r21_any_allowed_status_ok    FOR TESTING.
    METHODS r21_status_not_allowed       FOR TESTING.
    METHODS r21_unknown_lookup_raises    FOR TESTING.
    METHODS r07_refs_share_12_chars      FOR TESTING.
    METHODS r07_key_length_over_width    FOR TESTING.
    METHODS r07_ref_format_rejected      FOR TESTING.
    METHODS r21_key_length_over_width    FOR TESTING.
    METHODS r07r_in_flight_awaits        FOR TESTING.
    METHODS r07r_after_grace_fails       FOR TESTING.
    METHODS r07l_lot_in_flight_awaits    FOR TESTING.
    METHODS r07_creation_time_decides    FOR TESTING.
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


  " Fix 4 parity: the payment rows of a document are found through the secondary key even when
  " rows of another document sit between them - document 12345 has a PAID run, 67890 has none
  METHOD r07_rows_by_doc_key_parity.
    DATA ls_payment TYPE zif_cd_ebs_sap_dao=>ty_payment.
    TRY.
        ls_payment-doc1r  = gc_test-docno.
        ls_payment-laufi  = 'RUN3'.
        ls_payment-status = 'RETURNED'.
        INSERT ls_payment INTO TABLE mo_sap_dao->mt_payments.
        ls_payment-doc1r  = '000000067890'.
        ls_payment-laufi  = 'RUN2'.
        INSERT ls_payment INTO TABLE mo_sap_dao->mt_payments.
        ls_payment-doc1r  = gc_test-docno.
        ls_payment-laufi  = 'RUN1'.
        ls_payment-status = 'PAID'.
        INSERT ls_payment INTO TABLE mo_sap_dao->mt_payments.
        add_statement( ).
        add_line( ).
        add_line( iv_reference = '67890' ).
        run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( iv_rule_id = 'R07' iv_param1 = 'PAID' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-payment_status
                         iv_msg        = 'Only the document without a PAID run may fail' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-object_key
                                            exp = zcl_cd_ebs_finding=>line_key( mt_lines[ 2 ] )
                                            msg = 'The finding belongs to the line of document 67890' ).
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
  " A65: two 13-character references sharing their first 12 characters are rejected
  " (REF_TOO_LONG), never truncated onto document 123456789012; a 12-character one matches
  METHOD r07_refs_share_12_chars.
    TRY.
        INSERT VALUE #( doc1r = '123456789012' status = 'PAID' ) INTO TABLE mo_sap_dao->mt_payments.
        add_statement( ).
        add_line( iv_reference = '1234567890123' ).
        add_line( iv_reference = '1234567890124' ).
        add_line( iv_reference = '123456789012' ).
        run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( 'R07' ) ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR f IN mt_findings ( CONV string( f-check_code ) ) )
          exp = VALUE string_table( ( CONV string( zif_cd_ebs_types=>gc_check_code-ref_too_long ) )
                                    ( CONV string( zif_cd_ebs_types=>gc_check_code-ref_too_long ) ) )
          msg = 'Both overlength references must be rejected, not matched on their first 12 characters' ).
        cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->mt_docno_seen
                                            exp = VALUE zif_cd_ebs_sap_dao=>tt_docno( ( '123456789012' ) )
                                            msg = 'Only the reference that fits may be queried' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A65: EBS_KEYLEN_DOCNO above the 12-character key width is a configuration finding
  METHOD r07_key_length_over_width.
    TRY.
        INSERT VALUE #( name = zif_cd_ebs_types=>gc_param-keylen_docno value = '15' ) INTO TABLE mo_store->mt_params.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( 'R07' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-key_length_config
                         iv_msg        = 'A key length above the DDIC width must be rejected explicitly' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A65: a reference with characters outside 0-9 / A-Z cannot be a document number (REF_FORMAT)
  METHOD r07_ref_format_rejected.
    TRY.
        add_statement( ).
        add_line( iv_reference = 'AB-12' ).
        run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( 'R07' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-ref_format
                         iv_msg        = 'A malformed reference must be rejected before conversion' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A65: a REFERENCE lookup whose key length exceeds the lookup key width is rejected
  METHOD r21_key_length_over_width.
    TRY.
        add_lookup( ).
        mo_cfg_dao->mt_lookups[ lookup_id = 'TESTLKP' ]-key_kind   = zif_cd_ebs_types=>gc_lookup_key-reference.
        mo_cfg_dao->mt_lookups[ lookup_id = 'TESTLKP' ]-key_length = 80.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R21_LOOKUP' is_rule = rule( iv_rule_id = 'R21' iv_param1 = 'TESTLKP' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-key_length_config
                         iv_msg        = 'A lookup key length above the key width must be rejected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FS-CD review: lot item not found 8 h after the start of the statement date, grace 24 h:
  " AWAITING_LOT_TRANSFER (W, NOTIFY), the original message kept in DETAILS
  METHOD r07r_in_flight_awaits.
    TRY.
        INSERT VALUE #( name = zif_cd_ebs_types=>gc_param-inflight_hours value = '24' ) INTO TABLE mo_store->mt_params.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07R_RETURN_LOT' is_rule = rule( 'R07R' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-awaiting_lot_transfer
                         iv_msg        = 'A lot item not found inside the grace window must await the transfer' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Awaiting lot transfer is a warning' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-action exp = zif_cd_ops_types=>gc_action-notify
                                            msg = 'Awaiting lot transfer only notifies' ).
        cl_abap_unit_assert=>assert_not_initial( act = mt_findings[ 1 ]-details
                                                 msg = 'The original not-found message must be kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FS-CD review: after the grace window (4 h, statement 8 h old) the not-found stands
  METHOD r07r_after_grace_fails.
    TRY.
        INSERT VALUE #( name = zif_cd_ebs_types=>gc_param-inflight_hours value = '4' ) INTO TABLE mo_store->mt_params.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07R_RETURN_LOT' is_rule = rule( 'R07R' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-return_item_not_found
                         iv_msg        = 'After the grace window the lot item must be found' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FS-CD review: 166D chain - retrieval AF logged, returns lot not yet created, inside the window
  METHOD r07l_lot_in_flight_awaits.
    TRY.
        INSERT VALUE #( name = zif_cd_ebs_types=>gc_param-inflight_hours value = '24' ) INTO TABLE mo_store->mt_params.
        INSERT VALUE #( augbl = gc_test-docno status = 'AF' ) INTO TABLE mo_sap_dao->mt_retrievals.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07L_RETRIEVAL'
             is_rule  = rule( iv_rule_id = 'R07L' iv_param1 = 'AF' iv_param3 = zif_cd_ebs_types=>gc_rule_keyword-lot ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-awaiting_lot_transfer
                         iv_msg        = 'A returns lot not yet created inside the window must await the transfer' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FS-CD review: the creation time decides when present - created 07:00, now 08:00, grace 2 h
  METHOD r07_creation_time_decides.
    TRY.
        INSERT VALUE #( name = zif_cd_ebs_types=>gc_param-inflight_hours value = '2' ) INTO TABLE mo_store->mt_params.
        add_statement( ).
        mt_stmts[ 1 ]-created_date = gc_test-today.
        mt_stmts[ 1 ]-created_time = '070000'.
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07_PAYMENT' is_rule = rule( 'R07' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-awaiting_lot_transfer
                         iv_msg        = 'A statement created one hour ago is inside a two-hour window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


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
        CAST zif_cd_ebs_rule( zcl_cd_ops_factory=>get_plugin( 'ZCL_CD_EBS_R_R21_LOOKUP' ) )->execute(
          is_rule       = rule( iv_rule_id = 'R21' iv_param1 = 'NOSUCH' )
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


  " Fix 1 arrange: register rows 12345 and 012345 of the same account; bank lines 12345 and 012345
  METHOD add_zero_pair.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    ls_check-ztnum  = gc_test-ref.
    ls_check-hbkid  = gc_test-hbkid.
    ls_check-hktid  = gc_test-hktid.
    ls_check-amount = gc_test-amount.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    ls_check-ztnum  = |0{ gc_test-ref }|.
    INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
    add_statement( ).
    add_line( ).
    add_line( iv_reference = |0{ gc_test-ref }| ).
  ENDMETHOD.


  " Fix 1 parity: EBS_ZTNUM_IGNORE_ZEROS off - 12345 and 012345 stay two checks in the index
  METHOD r08_zero_flag_off_rows_apart.
    TRY.
        INSERT VALUE #( name = 'EBS_ZTNUM_IGNORE_ZEROS' value = space ) INTO TABLE mo_store->mt_params.
        add_zero_pair( ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'Zeros significant: each line must match only its own row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 1 parity: EBS_ZTNUM_IGNORE_ZEROS on (default) - both rows are the same check for both lines
  METHOD r08_zero_flag_on_rows_merged.
    TRY.
        add_zero_pair( ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mt_findings ) exp = 2
                                            msg = 'Zeros ignored: each line must sum both rows (mismatch twice)' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-check_code
                                            exp = zif_cd_ebs_types=>gc_check_code-check_amount_mismatch
                                            msg = 'The doubled register amount must be an amount mismatch' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 1: R07C and R08 on the same lines of one package read DFKKCR once
  METHOD register_read_once_package.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum    = gc_test-ref.
        ls_check-hbkid    = gc_test-hbkid.
        ls_check-hktid    = gc_test-hktid.
        ls_check-amount   = gc_test-amount.
        ls_check-crstatus = '99'.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R07C_CHECK' is_rule = rule( 'R07C' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-check_status
                         iv_msg        = 'R07C must still see the cancelled register row' ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'R08 must see the same register row (amount equal)' ).
        cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->mv_check_reads exp = 1
                                            msg = 'The second check rule of the package must not read DFKKCR again' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 1: a new package (other statement key) never reuses the register rows of the previous one
  METHOD register_new_package_rereads.
    DATA ls_check TYPE zif_cd_ebs_sap_dao=>ty_check.
    TRY.
        ls_check-ztnum  = gc_test-ref.
        ls_check-hbkid  = gc_test-hbkid.
        ls_check-hktid  = gc_test-hktid.
        ls_check-amount = gc_test-amount.
        INSERT ls_check INTO TABLE mo_sap_dao->mt_checks.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'First package: amounts equal' ).
        " Next package: other statement, register amount changed in the meantime
        LOOP AT mt_stmts ASSIGNING FIELD-SYMBOL(<ls_stmt>).
          <ls_stmt>-stmt_key = 'S0002'.
        ENDLOOP.
        LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
          <ls_line>-stmt_key = 'S0002'.
        ENDLOOP.
        LOOP AT mo_sap_dao->mt_checks ASSIGNING FIELD-SYMBOL(<ls_row>).
          <ls_row>-amount = '1.00'.
        ENDLOOP.
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-check_amount_mismatch
                         iv_msg        = 'A new package must read the register again (changed amount)' ).
        cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->mv_check_reads exp = 2
                                            msg = 'One register read per package' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 1 parity of keys: rows read for one rule group never reach a line of another group
  " whose own query keys would not have read them (012345 is not a query key of line 12345)
  METHOD register_memo_keys_not_leak.
    TRY.
        add_zero_pair( ).
        DATA(lt_all) = mt_lines.
        " Group 1: line 012345 - its keys read both rows (012345 and canonical 12345)
        DELETE mt_lines WHERE reference = gc_test-ref.
        run( iv_class = 'ZCL_CD_EBS_R_R12_CODE_TOTAL' is_rule = rule( 'R12' ) ).
        " Group 2: line 12345 alone - one read today returns only row 12345
        mt_lines = lt_all.
        DELETE mt_lines WHERE reference <> gc_test-ref.
        run( iv_class = 'ZCL_CD_EBS_R_R08_CHECK_AMOUNT' is_rule = rule( 'R08' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'Line 12345 must sum only the rows of its own query keys' ).
        cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->mv_check_reads exp = 1
                                            msg = 'Key 12345 was read with group 1 and must come from the memo' ).
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


"! Return / NOC reason correction 2026-11-06 (FEB source): FEBEP carries no reason - R05
"! checks the reason of the returns lot item (DFKKRP-RLGRD by SELW1 = payment document) and
"! of the NOC lot item (DFKKNRP-FLGRD by INFOF = payment document or payment reference)
CLASS ltc_r05_lot_reason DEFINITION FINAL FOR TESTING
  INHERITING FROM ltc_rule_fixture
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_r05,
        class      TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_EBS_R_R05_REASON',
        id         TYPE zif_cd_ops_types=>ty_rule_id VALUE 'R05',
        ret_reason TYPE zif_cd_ebs_sap_dao=>ty_lot_reason VALUE '001',
        ret_other  TYPE zif_cd_ebs_sap_dao=>ty_lot_reason VALUE '002',
        noc_reason TYPE zif_cd_ebs_sap_dao=>ty_lot_reason VALUE '051',
        noc_other  TYPE zif_cd_ebs_sap_dao=>ty_lot_reason VALUE '052',
        unknown    TYPE zif_cd_ebs_sap_dao=>ty_lot_reason VALUE '999',
        noc_lot    TYPE c LENGTH 12 VALUE 'NOC000000001',
      END OF gc_r05.

    METHODS setup.
    METHODS teardown.
    "! Map rows: R01 -> return reason 001, R02 -> placeholder, C01 -> NOC reason 051
    METHODS add_reason_map.
    METHODS add_return_item
      IMPORTING
        iv_rlgrd TYPE zif_cd_ebs_sap_dao=>ty_lot_reason
        iv_opbel TYPE zif_cd_ebs_sap_dao=>ty_docno DEFAULT '000000000001'.
    METHODS add_noc_item
      IMPORTING
        iv_infof TYPE zif_cd_ebs_sap_dao=>ty_infof
        iv_flgrd TYPE zif_cd_ebs_sap_dao=>ty_lot_reason
        iv_posna TYPE zif_cd_ebs_sap_dao=>ty_noc_item-posna DEFAULT 1.
    METHODS run_r05
      IMPORTING
        iv_param1 TYPE clike OPTIONAL
        iv_param2 TYPE clike OPTIONAL.

    METHODS return_valid_reason_passes   FOR TESTING.
    METHODS return_blank_reason_missing  FOR TESTING.
    METHODS return_unknown_reason_fails  FOR TESTING.
    METHODS return_placeholder_unmapped  FOR TESTING.
    METHODS return_two_reasons_ambiguous FOR TESTING.
    METHODS no_lot_item_not_evaluated    FOR TESTING.
    METHODS noc_found_by_payment_doc     FOR TESTING.
    METHODS noc_found_by_reference       FOR TESTING.
    METHODS noc_return_reason_unmapped   FOR TESTING.
    METHODS noc_two_reasons_ambiguous    FOR TESTING.
    METHODS file_source_reads_no_lots    FOR TESTING.
ENDCLASS.


CLASS ltc_r05_lot_reason IMPLEMENTATION.

  METHOD setup.
    prepare_fixture( ).
    add_reason_map( ).
    add_statement( ).
    add_line( ).
  ENDMETHOD.


  METHOD teardown.
    clear_fixture( ).
  ENDMETHOD.


  METHOD add_reason_map.
    DATA ls_reason TYPE zif_cd_ebs_types=>ty_reason_map.
    ls_reason-reason      = 'R01'.
    ls_reason-fica_reason = gc_r05-ret_reason.
    INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
    ls_reason-reason      = 'R02'.
    ls_reason-fica_reason = '<PE'.
    INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
    ls_reason-reason      = 'C01'.
    ls_reason-fica_reason = gc_r05-noc_reason.
    ls_reason-is_noc      = abap_true.
    INSERT ls_reason INTO TABLE mo_cfg_dao->mt_reasons.
  ENDMETHOD.


  METHOD add_return_item.
    DATA ls_item TYPE zif_cd_ebs_sap_dao=>ty_return_item.
    ls_item-selw1     = gc_test-docno.
    ls_item-opbel     = iv_opbel.
    ls_item-lot_stars = '5'.
    ls_item-rlgrd     = iv_rlgrd.
    INSERT ls_item INTO TABLE mo_sap_dao->mt_items.
  ENDMETHOD.


  METHOD add_noc_item.
    DATA ls_item TYPE zif_cd_ebs_sap_dao=>ty_noc_item.
    ls_item-keyn1 = gc_r05-noc_lot.
    ls_item-posna = iv_posna.
    ls_item-infof = iv_infof.
    ls_item-flgrd = iv_flgrd.
    INSERT ls_item INTO TABLE mo_sap_dao->mt_noc_items.
  ENDMETHOD.


  METHOD run_r05.
    run( iv_class = gc_r05-class
         is_rule  = rule( iv_rule_id = gc_r05-id iv_param1 = iv_param1 iv_param2 = iv_param2 ) ).
  ENDMETHOD.


  " A returns lot item for the payment document with a configured return reason passes
  METHOD return_valid_reason_passes.
    TRY.
        add_return_item( gc_r05-ret_reason ).
        run_r05( ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'A configured RLGRD must pass R05' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_sap_dao->mt_docno_seen[ table_line = gc_test-docno ] ) )
                                          msg = 'The returns lot must be read by the payment document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " RLGRD blank: the return was processed without a reason - REASON_MISSING
  METHOD return_blank_reason_missing.
    TRY.
        add_return_item( space ).
        run_r05( ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_missing
                         iv_msg        = 'A returns lot item without RLGRD must be REASON_MISSING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " RLGRD not among the configured payment engine return reasons - REASON_UNMAPPED
  METHOD return_unknown_reason_fails.
    TRY.
        add_return_item( gc_r05-unknown ).
        run_r05( ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
                         iv_msg        = 'An unconfigured RLGRD must be REASON_UNMAPPED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A seeded placeholder is no configured reason; a NOC reason is no return reason
  METHOD return_placeholder_unmapped.
    TRY.
        add_return_item( '<PE' ).
        run_r05( ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
                         iv_msg        = 'A placeholder RLGRD must be REASON_UNMAPPED' ).
        CLEAR: mt_findings, mo_sap_dao->mt_items.
        add_return_item( gc_r05-noc_reason ).
        run_r05( iv_param2 = zif_cd_ebs_types=>gc_rule_keyword-return ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
                         iv_msg        = 'A NOC reason on a returns lot item must be REASON_UNMAPPED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two returns lot items of one payment with different reasons - REASON_AMBIGUOUS, once
  METHOD return_two_reasons_ambiguous.
    TRY.
        add_return_item( gc_r05-ret_reason ).
        add_return_item( iv_rlgrd = gc_r05-ret_other iv_opbel = '000000000002' ).
        run_r05( ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_ambiguous
                         iv_msg        = 'Different RLGRD for one payment must be REASON_AMBIGUOUS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " No returns / NOC lot item: R07R / S13 own that - R05 is not evaluated (even REQUIRED)
  METHOD no_lot_item_not_evaluated.
    TRY.
        run_r05( iv_param1 = zif_cd_ebs_types=>gc_rule_keyword-required ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'Without a lot item R05 must not report the line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " NOC lot item whose INFOF holds the payment document (AUGBL) with a configured NOC reason
  " passes; an unconfigured FLGRD is REASON_UNMAPPED; a NOC assignment never reads DFKKRP
  METHOD noc_found_by_payment_doc.
    TRY.
        add_noc_item( iv_infof = CONV #( gc_test-docno ) iv_flgrd = gc_r05-noc_reason ).
        run_r05( iv_param2 = zif_cd_ebs_types=>gc_rule_keyword-noc ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'A configured FLGRD must pass R05' ).
        cl_abap_unit_assert=>assert_initial( act = mo_sap_dao->mt_docno_seen
                                             msg = 'A NOC assignment must not read the returns lot' ).
        CLEAR mo_sap_dao->mt_noc_items.
        add_noc_item( iv_infof = CONV #( gc_test-docno ) iv_flgrd = gc_r05-unknown ).
        run_r05( iv_param2 = zif_cd_ebs_types=>gc_rule_keyword-noc ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
                         iv_msg        = 'An unconfigured FLGRD must be REASON_UNMAPPED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " NOC lot item whose INFOF holds the payment reference as the bank delivered it (not the
  " 12-character document key): found and matched; a blank FLGRD is REASON_MISSING
  METHOD noc_found_by_reference.
    TRY.
        add_noc_item( iv_infof = CONV #( gc_test-ref ) iv_flgrd = gc_r05-noc_reason ).
        run_r05( ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'A NOC item found by the reference must pass' ).
        mo_sap_dao->mt_noc_items[ 1 ]-flgrd = space.
        run_r05( ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_missing
                         iv_msg        = 'A NOC item without FLGRD must be REASON_MISSING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A return reason on a NOC lot item is no NOC reason (returns and NOCs stay distinct)
  METHOD noc_return_reason_unmapped.
    TRY.
        add_noc_item( iv_infof = CONV #( gc_test-docno ) iv_flgrd = gc_r05-ret_reason ).
        run_r05( iv_param2 = zif_cd_ebs_types=>gc_rule_keyword-noc ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
                         iv_msg        = 'A return reason as FLGRD must be REASON_UNMAPPED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two NOC items of one payment (by document and by reference) with different FLGRD
  METHOD noc_two_reasons_ambiguous.
    TRY.
        add_noc_item( iv_infof = CONV #( gc_test-docno ) iv_flgrd = gc_r05-noc_reason ).
        add_noc_item( iv_infof = CONV #( gc_test-ref ) iv_flgrd = gc_r05-noc_other iv_posna = 2 ).
        run_r05( iv_param2 = zif_cd_ebs_types=>gc_rule_keyword-noc ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_ambiguous
                         iv_msg        = 'Different FLGRD for one payment must be REASON_AMBIGUOUS' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Bank file before import: the reason of the file is checked as before - no lot is read
  METHOD file_source_reads_no_lots.
    TRY.
        mt_stmts[ 1 ]-source = zif_cd_ebs_types=>gc_source-file.
        mt_lines[ 1 ]-return_reason = 'R01'.
        add_return_item( gc_r05-unknown ).
        run_r05( ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings msg = 'The mapped file reason must pass' ).
        cl_abap_unit_assert=>assert_initial( act = mo_sap_dao->mt_docno_seen
                                             msg = 'The file source must not read the returns lot' ).
        cl_abap_unit_assert=>assert_initial( act = mo_sap_dao->mt_infof_seen
                                             msg = 'The file source must not read the NOC lot' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
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
        iv_amount TYPE zif_cd_ops_types=>ty_amount DEFAULT gc_test-amount
        iv_azdat  TYPE d OPTIONAL.
    METHODS run_r22.
    METHODS r22_history_once_per_package FOR TESTING.
    METHODS r22_windows_per_statement    FOR TESTING.
    METHODS r18_gl_by_house_bank         FOR TESTING.
    METHODS r18_one_read_per_package     FOR TESTING.
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
    METHODS s13_open_entries_one_finding FOR TESTING.
    METHODS s13_posted_statement_ok      FOR TESTING.
    METHODS s13_file_statement_ignored   FOR TESTING.
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


  " Fix 6: two closing statements, one balance read; each statement compared on its own
  METHOD r18_one_read_per_package.
    TRY.
        mo_sap_dao->mv_gl_balance = '1150.00'.
        add_statement( iv_opening = '1000.00' iv_closing = '1150.00' ).
        add_statement( iv_opening = '1150.00' iv_closing = '1200.00' ).
        mt_stmts[ 2 ]-stmt_key  = 'S0002'.
        mt_stmts[ 2 ]-stmt_date = gc_test-today + 1.
        run( iv_class = 'ZCL_CD_EBS_R_R18_GL_BALANCE' is_rule = rule( 'R18' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-gl_ne_closing
                         iv_msg        = 'Only the statement closing at 1200 differs from the G/L' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-object_key exp = mt_stmts[ 2 ]-stmt_key
                                            msg = 'The finding belongs to the second statement' ).
        cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->mv_gl_reads exp = 1
                                            msg = 'One G/L balance read for the package' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_sap_dao->mt_gl_requests ) exp = 2
                                            msg = 'One request per closing statement' ).
        cl_abap_unit_assert=>assert_equals( act = mo_sap_dao->mt_gl_requests[ 2 ]-stmt_date
                                            exp = mt_stmts[ 2 ]-stmt_date
                                            msg = 'Each request carries its own statement date' ).
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
    ls_item-azdat = COND #( WHEN iv_azdat IS SUPPLIED THEN iv_azdat ELSE gc_test-today - 1 ).
    INSERT ls_item INTO TABLE mo_feb_dao->mt_recent.
  ENDMETHOD.


  " Fix 2: R22 (group *) runs once per rule group - the history is read once per package
  METHOD r22_history_once_per_package.
    TRY.
        add_history_item( '00000008' ).
        add_statement( ).
        mt_stmts[ 1 ]-kukey = '00000009'.
        add_line( ).
        DATA(lo_rule) = CAST zif_cd_ebs_rule( zcl_cd_ops_factory=>get_plugin( 'ZCL_CD_EBS_R_R22_DUP_HISTORY' ) ).
        DATA(ls_rule) = rule( iv_rule_id = 'R22' iv_window_days = 5 ).
        DATA(lt_first) = lo_rule->execute( is_rule = ls_rule it_statements = mt_stmts it_lines = mt_lines ).
        mt_findings = lo_rule->execute( is_rule = ls_rule it_statements = mt_stmts it_lines = mt_lines ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings exp = lt_first
                                            msg = 'The second rule group must get the same result' ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-duplicate_history
                         iv_msg        = 'The duplicate must still be reported from the memo' ).
        cl_abap_unit_assert=>assert_equals( act = mo_feb_dao->mv_recent_reads exp = 1
                                            msg = 'One history read per account and package' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 2 parity: one read over the union of two statements' windows, each statement still
  " sees only its own window (an entry 12 days old is a duplicate only for the 10-day-old statement)
  METHOD r22_windows_per_statement.
    TRY.
        add_history_item( iv_kukey = '00000005' iv_azdat = CONV d( gc_test-today - 12 ) ).
        add_statement( ).
        mt_stmts[ 1 ]-kukey = '00000009'.
        add_statement( ).
        mt_stmts[ 2 ]-kukey     = '00000007'.
        mt_stmts[ 2 ]-stmt_key  = 'S0002'.
        mt_stmts[ 2 ]-stmt_date = gc_test-today - 10.
        add_line( ).
        add_line( ).
        mt_lines[ 2 ]-stmt_key = 'S0002'.
        run( iv_class = 'ZCL_CD_EBS_R_R22_DUP_HISTORY' is_rule = rule( iv_rule_id = 'R22' iv_window_days = 5 ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-duplicate_history
                         iv_msg        = 'Only the statement whose window holds the entry may report it' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-object_key
                                            exp = zcl_cd_ebs_finding=>line_key( mt_lines[ 2 ] )
                                            msg = 'The finding belongs to the line of the older statement' ).
        cl_abap_unit_assert=>assert_equals( act = mo_feb_dao->mv_recent_reads exp = 1
                                            msg = 'Both statements of the account share one read' ).
        cl_abap_unit_assert=>assert_equals( act = mo_feb_dao->mv_from exp = CONV d( gc_test-today - 15 )
                                            msg = 'The read starts at the earliest window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
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

  " Operating model 2026-11-06: entries the engine marked POSTING_OPEN (expected to post, not
  " posted) give ONE POSTING_INCOMPLETE for their statement, with count and total
  METHOD s13_open_entries_one_finding.
    DATA lv_open_total TYPE zif_cd_ops_types=>ty_amount.
    TRY.
        lv_open_total = gc_test-amount * 2.
        add_statement( ).
        add_line( ).
        add_line( ).
        add_line( ).
        mt_lines[ 1 ]-posting_open = abap_true.
        mt_lines[ 2 ]-posting_open = abap_true.
        run( iv_class = 'ZCL_CD_EBS_R_S13_POSTED' is_rule = rule( 'S13' ) ).
        assert_one_code( iv_check_code = zif_cd_ebs_types=>gc_check_code-posting_incomplete
                         iv_msg        = 'Unposted entries must give one POSTING_INCOMPLETE per statement' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-object_key
                                            exp = CONV zif_cd_ops_types=>ty_object_key( gc_test-stmt_key )
                                            msg = 'The finding names the statement' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-amount exp = lv_open_total
                                            msg = 'The amount is the total of the unposted entries' ).
        cl_abap_unit_assert=>assert_equals( act = mt_findings[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Severity comes from the rule configuration' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A statement whose entries are posted (or not expected to post) is complete
  METHOD s13_posted_statement_ok.
    TRY.
        add_statement( ).
        add_line( ).
        run( iv_class = 'ZCL_CD_EBS_R_S13_POSTED' is_rule = rule( 'S13' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'A statement without unposted entries must pass S13' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A bank file before import has no posting state - S13 never reports it
  METHOD s13_file_statement_ignored.
    TRY.
        add_statement( iv_source = zif_cd_ebs_types=>gc_source-file ).
        add_line( ).
        mt_lines[ 1 ]-posting_open = abap_true.
        run( iv_class = 'ZCL_CD_EBS_R_S13_POSTED' is_rule = rule( 'S13' ) ).
        cl_abap_unit_assert=>assert_initial( act = mt_findings
                                             msg = 'S13 must ignore a bank file statement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
