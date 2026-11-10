*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_dash_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the EBS validation dashboard on cl_cds_test_environment
*& doubles of the base tables (FEBKO, FEBEP, ZCA_OPS_FINDING, ZCA_OPS_RUN,
*& ZCD_EBS_RULE_DEF, DFKKRP, DFKKRK, DFKKNRP): validation status of a
*& statement and a line from its open findings, masking of the bank account,
*& hidden messages of file-source statements, line counters and unevaluated
*& lines of a run, KPI = last completed run of the day, as-of / stale, and
*& returns / NOC by reason (DFKKRP-RLGRD, DFKKNRP-FLGRD via INFOF without
*& leading zeros); does not prove live SAP runtime behavior.
*& VERIFY-ADT: create( i_select_base_dependencies = abap_true ) doubles the
*& tables behind the view stack (incl. CROSS JOIN, UNION and aggregates) on
*& 7.58; $session.system_date and tstmp_current_utctimestamp are not doubled
*& (test data is built relative to today).
*& Modification log:
*& 2026-11-06 | Initial version (EBS validation dashboard).
*& 2026-11-06 | Modern-syntax sweep: test helper LTD_ROWS.
*& 2026-11-06 | Payment engine account scope (user decision): lines carry FEBEP-XBLNR, the account is
*&            | derived from it (ZCD_EBS_ACCT-ACCOUNT_NO); all-PE statement shown with PE account and
*&            | G/L, mixed / blank XBLNR / inactive account / no line hidden, totals by BAI code + XBLNR.
*& 2026-11-07 | moncfg_threshold_applies: ZCD_OPS_MONCFG threshold of EBS (base dependency doubled).
*& 2026-11-07 | Rule registry rows (ltd_rows=>rule_defs) for the classification from ZCD_EBS_RULE_DEF-FINDING_CLASS.
*& 2026-11-08 | Table consolidation: moncfg_threshold_applies with a value row of MON_STALE_AFTER_MIN_EBS
*&            | over its definition (ZCA_PARAM_DEF / _VAL doubled as base dependencies of ZI_CD_OpsStaleCfg).
*&---------------------------------------------------------------------*
"! Test data builders: one row per call, filled field by field (house rule)
CLASS ltd_rows DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS gc_pe_area TYPE zif_ca_ops_types=>ty_area VALUE 'CD_EBS'.
    CONSTANTS gc_house_bank TYPE c LENGTH 5 VALUE 'PNC01'.
    CONSTANTS gc_account_id TYPE c LENGTH 5 VALUE 'DISB1'.
    CONSTANTS gc_company TYPE c LENGTH 4 VALUE 'US01'.
    CONSTANTS gc_currency TYPE c LENGTH 5 VALUE 'USD'.
    CONSTANTS gc_gl_account TYPE c LENGTH 10 VALUE '0011000100'.
    "! FEBEP-XBLNR = bank text + payment engine account (10) + counter (user decision 2026-11-06)
    CONSTANTS gc_xblnr TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412334'.
    CONSTANTS gc_pe_account TYPE zif_cd_ebs_types=>ty_pe_account VALUE '8XX1174412'.
    TYPES tt_acct TYPE STANDARD TABLE OF zcd_ebs_acct WITH EMPTY KEY.
    TYPES tt_rule_def TYPE STANDARD TABLE OF zcd_ebs_rule_def WITH EMPTY KEY.

    "! Rule registry rows of the dashboard classification (seed: S07 / R09 / R22 duplicate,
    "! S13 posting incomplete - ZCD_EBS_RULE_DEF-FINDING_CLASS)
    CLASS-METHODS rule_defs
      RETURNING
        VALUE(rt_defs) TYPE tt_rule_def.

    CLASS-METHODS today
      RETURNING
        VALUE(rv_date) TYPE d.

    CLASS-METHODS now
      RETURNING
        VALUE(rv_now) TYPE timestampl.

    CLASS-METHODS seconds_ago
      IMPORTING
        iv_seconds    TYPE i
      RETURNING
        VALUE(rv_ts)  TYPE timestampl.

    CLASS-METHODS statement
      IMPORTING
        iv_kukey       TYPE zif_cd_ebs_types=>ty_kukey
      RETURNING
        VALUE(rs_stmt) TYPE febko.

    CLASS-METHODS line
      IMPORTING
        iv_kukey       TYPE zif_cd_ebs_types=>ty_kukey
        iv_esnum       TYPE zif_cd_ebs_types=>ty_esnum
        iv_reference   TYPE clike OPTIONAL
        iv_belnr       TYPE clike OPTIONAL
        iv_bai_code    TYPE clike OPTIONAL
        iv_dc_ind      TYPE clike OPTIONAL
        iv_amount      TYPE febep-kwbtr OPTIONAL
        iv_xblnr       TYPE zif_cd_ebs_types=>ty_xblnr DEFAULT gc_xblnr
      RETURNING
        VALUE(rs_line) TYPE febep.

    "! Finding as ZCL_CD_EBS_FINDING writes it (statement / line key from KUKEY, ESNUM)
    CLASS-METHODS finding
      IMPORTING
        iv_run_id         TYPE zif_ca_ops_types=>ty_run_id
        iv_finding_no     TYPE i
        iv_object_type    TYPE zif_ca_ops_types=>ty_object_type
        iv_object_key     TYPE clike
        iv_rule_id        TYPE zif_ca_ops_types=>ty_rule_id
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
        iv_disposition    TYPE zif_ca_ops_types=>ty_disposition DEFAULT zif_ca_ops_types=>gc_disposition-open
      RETURNING
        VALUE(rs_finding) TYPE zca_ops_finding.

    CLASS-METHODS run
      IMPORTING
        iv_run_id     TYPE zif_ca_ops_types=>ty_run_id
        iv_status     TYPE zif_ca_ops_types=>ty_run_status
        iv_ended_at   TYPE timestampl
        iv_test_mode  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_run) TYPE zca_ops_run.

    "! Payment engine account (ZCD_EBS_ACCT) of the default XBLNR: only statements whose every line
    "! carries an active one are on the dashboard
    CLASS-METHODS account
      IMPORTING
        iv_hktid       TYPE clike DEFAULT gc_account_id
        iv_account_no  TYPE clike DEFAULT gc_pe_account
        iv_active      TYPE abap_boolean DEFAULT abap_true
      RETURNING
        VALUE(rs_acct) TYPE zcd_ebs_acct.

    "! Statement key FEB<KUKEY> and line key FEB<KUKEY>/<ESNUM without zeros>
    CLASS-METHODS stmt_key
      IMPORTING
        iv_kukey      TYPE zif_cd_ebs_types=>ty_kukey
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.

    CLASS-METHODS line_key
      IMPORTING
        iv_kukey      TYPE zif_cd_ebs_types=>ty_kukey
        iv_esnum      TYPE zif_cd_ebs_types=>ty_esnum
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.
ENDCLASS.


CLASS ltd_rows IMPLEMENTATION.

  METHOD rule_defs.
    DATA ls_def TYPE zcd_ebs_rule_def.
    ls_def-rule_id       = 'S07'.
    ls_def-finding_class = zif_cd_ebs_types=>gc_finding_class-duplicate.
    INSERT ls_def INTO TABLE rt_defs.
    ls_def-rule_id       = 'R09'.
    INSERT ls_def INTO TABLE rt_defs.
    ls_def-rule_id       = 'R22'.
    INSERT ls_def INTO TABLE rt_defs.
    ls_def-rule_id       = 'S13'.
    ls_def-finding_class = zif_cd_ebs_types=>gc_finding_class-posting.
    INSERT ls_def INTO TABLE rt_defs.
  ENDMETHOD.


  METHOD today.
    rv_date = cl_abap_context_info=>get_system_date( ).
  ENDMETHOD.


  METHOD now.
    GET TIME STAMP FIELD rv_now.
  ENDMETHOD.


  METHOD seconds_ago.
    rv_ts = cl_abap_tstmp=>subtract_secs( tstmp = CONV timestamp( now( ) ) secs = iv_seconds ).
  ENDMETHOD.


  METHOD account.
    rs_acct-bukrs      = gc_company.
    rs_acct-hbkid      = gc_house_bank.
    rs_acct-hktid      = iv_hktid.
    rs_acct-account_no = iv_account_no.
    rs_acct-gl_account = gc_gl_account.
    rs_acct-currency   = gc_currency.
    rs_acct-active     = iv_active.
  ENDMETHOD.


  METHOD statement.
    rs_stmt-kukey = iv_kukey.
    rs_stmt-bukrs = gc_company.
    rs_stmt-hbkid = gc_house_bank.
    rs_stmt-hktid = gc_account_id.
    rs_stmt-azdat = today( ).
    rs_stmt-waers = gc_currency.
  ENDMETHOD.


  METHOD line.
    rs_line-kukey = iv_kukey.
    rs_line-esnum = iv_esnum.
    rs_line-budat = today( ).
    rs_line-chect = iv_reference.
    rs_line-belnr = iv_belnr.
    rs_line-vorgc = iv_bai_code.
    rs_line-epvoz = iv_dc_ind.
    rs_line-kwbtr = iv_amount.
    rs_line-xblnr = iv_xblnr.
  ENDMETHOD.


  METHOD finding.
    rs_finding-run_id      = iv_run_id.
    rs_finding-finding_no  = iv_finding_no.
    rs_finding-area     = gc_pe_area.
    rs_finding-object_type = iv_object_type.
    rs_finding-object_key  = iv_object_key.
    rs_finding-rule_id     = iv_rule_id.
    rs_finding-check_code  = iv_code.
    rs_finding-severity    = iv_severity.
    rs_finding-disposition = iv_disposition.
    rs_finding-created_at  = now( ).
  ENDMETHOD.


  METHOD run.
    rs_run-run_id     = iv_run_id.
    rs_run-area    = gc_pe_area.
    rs_run-test_mode  = iv_test_mode.
    rs_run-status     = iv_status.
    rs_run-ended_at   = iv_ended_at.
    rs_run-started_at = iv_ended_at.
  ENDMETHOD.


  METHOD stmt_key.
    rv_key = zif_cd_ebs_types=>gc_feb_stmt_prefix && |{ iv_kukey }|.
  ENDMETHOD.


  METHOD line_key.
    rv_key = zcl_cd_ebs_finding=>line_key( VALUE #( stmt_key = stmt_key( iv_kukey ) line_no = iv_esnum ) ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_EBSSTMT / ZR_CD_EBSLINE: validation status from open findings, line counts, as of
CLASS ltc_statement DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_run TYPE zif_ca_ops_types=>ty_run_id VALUE 'E0000000000000000000000000000001'.
    CONSTANTS:
      BEGIN OF gc_kukey,
        blocked    TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000101',
        error      TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000102',
        incomplete TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000103',
        warning    TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000104',
        clean      TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000105',
        resolved   TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000106',
      END OF gc_kukey.
    CONSTANTS:
      BEGIN OF gc_status,
        blocked     TYPE c LENGTH 20 VALUE 'BLOCKED',
        error       TYPE c LENGTH 20 VALUE 'ERROR',
        incomplete  TYPE c LENGTH 20 VALUE 'POSTING_INCOMPLETE',
        warning     TYPE c LENGTH 20 VALUE 'WARNING',
        no_findings TYPE c LENGTH 20 VALUE 'NO_FINDINGS',
      END OF gc_status.
    CONSTANTS:
      BEGIN OF gc_rule,
        unmapped   TYPE zif_ca_ops_types=>ty_rule_id VALUE 'R14',
        reference  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'R07',
        posting    TYPE zif_ca_ops_types=>ty_rule_id VALUE 'S13',
        duplicate  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'R09',
      END OF gc_rule.
    CONSTANTS:
      BEGIN OF gc_code,
        unmapped   TYPE zif_ca_ops_types=>ty_check_code VALUE 'UNMAPPED_BTC',
        not_found  TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAYMENT_NOT_FOUND',
        incomplete TYPE zif_ca_ops_types=>ty_check_code VALUE 'POSTING_INCOMPLETE',
        duplicate  TYPE zif_ca_ops_types=>ty_check_code VALUE 'DUPLICATE_ENTRY',
      END OF gc_code.
    CONSTANTS gc_line_1 TYPE zif_cd_ebs_types=>ty_esnum VALUE '00001'.
    CONSTANTS gc_line_2 TYPE zif_cd_ebs_types=>ty_esnum VALUE '00002'.
    CONSTANTS gc_belnr TYPE c LENGTH 10 VALUE '0100000001'.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    DATA mt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS status_follows_worst_finding FOR TESTING.
    METHODS closed_findings_are_ignored FOR TESTING.
    METHODS lines_counted_per_statement FOR TESTING.
    METHODS line_status_from_line_finding FOR TESTING.
    METHODS rows_carry_validation_as_of FOR TESTING.
    METHODS amounts_total_per_bai_code FOR TESTING.
    METHODS all_pe_statement_shown FOR TESTING.
    METHODS mixed_statement_hidden FOR TESTING.
    METHODS inactive_account_hidden FOR TESTING.
    METHODS totals_per_code_and_xblnr FOR TESTING.

    METHODS add_finding
      IMPORTING
        iv_type        TYPE zif_ca_ops_types=>ty_object_type
        iv_key         TYPE zif_ca_ops_types=>ty_object_key
        iv_rule        TYPE zif_ca_ops_types=>ty_rule_id
        iv_code        TYPE zif_ca_ops_types=>ty_check_code
        iv_severity    TYPE zif_ca_ops_types=>ty_severity
        iv_disposition TYPE zif_ca_ops_types=>ty_disposition DEFAULT zif_ca_ops_types=>gc_disposition-open.
    METHODS insert_scenario.
    METHODS status_of
      IMPORTING
        iv_kukey         TYPE zif_cd_ebs_types=>ty_kukey
      RETURNING
        VALUE(rv_status) TYPE string.
ENDCLASS.


CLASS ltc_statement IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_CD_EBSSTMT' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_EBSLINE' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    go_env->insert_test_data( i_data = ltd_rows=>rule_defs( ) ).
    CLEAR mt_findings.
  ENDMETHOD.


  METHOD add_finding.
    INSERT ltd_rows=>finding( iv_run_id      = gc_run
                              iv_finding_no  = lines( mt_findings ) + 1
                              iv_object_type = iv_type
                              iv_object_key  = iv_key
                              iv_rule_id     = iv_rule
                              iv_code        = iv_code
                              iv_severity    = iv_severity
                              iv_disposition = iv_disposition ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD insert_scenario.
    DATA lt_stmts TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.

    INSERT ltd_rows=>statement( gc_kukey-blocked ) INTO TABLE lt_stmts.
    INSERT ltd_rows=>statement( gc_kukey-error ) INTO TABLE lt_stmts.
    INSERT ltd_rows=>statement( gc_kukey-incomplete ) INTO TABLE lt_stmts.
    INSERT ltd_rows=>statement( gc_kukey-warning ) INTO TABLE lt_stmts.
    INSERT ltd_rows=>statement( gc_kukey-clean ) INTO TABLE lt_stmts.
    INSERT ltd_rows=>statement( gc_kukey-resolved ) INTO TABLE lt_stmts.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey-blocked iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_1 iv_belnr = gc_belnr ) INTO TABLE lt_lines.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_2 ) INTO TABLE lt_lines.
    " Payment engine scope: a statement is on the dashboard only with at least one line, every
    " line carrying an active payment engine account (default XBLNR of LTD_ROWS=>LINE)
    INSERT ltd_rows=>line( iv_kukey = gc_kukey-error iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey-incomplete iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey-warning iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey-resolved iv_esnum = gc_line_1 ) INTO TABLE lt_lines.

    " Blocked: an unmapped code on line 1 (B) and a warning; the worst wins
    add_finding( iv_type     = zcl_cd_ebs_finding=>gc_object_type-line
                 iv_key      = ltd_rows=>line_key( iv_kukey = gc_kukey-blocked iv_esnum = gc_line_1 )
                 iv_rule     = gc_rule-unmapped
                 iv_code     = gc_code-unmapped
                 iv_severity = zif_ca_ops_types=>gc_severity-block ).
    add_finding( iv_type     = zcl_cd_ebs_finding=>gc_object_type-line
                 iv_key      = ltd_rows=>line_key( iv_kukey = gc_kukey-blocked iv_esnum = gc_line_1 )
                 iv_rule     = gc_rule-duplicate
                 iv_code     = gc_code-duplicate
                 iv_severity = zif_ca_ops_types=>gc_severity-warning ).
    add_finding( iv_type     = zcl_cd_ebs_finding=>gc_object_type-statement
                 iv_key      = ltd_rows=>stmt_key( gc_kukey-error )
                 iv_rule     = gc_rule-reference
                 iv_code     = gc_code-not_found
                 iv_severity = zif_ca_ops_types=>gc_severity-error ).
    " POSTING_INCOMPLETE (W) outranks an ordinary warning, not an error
    add_finding( iv_type     = zcl_cd_ebs_finding=>gc_object_type-statement
                 iv_key      = ltd_rows=>stmt_key( gc_kukey-incomplete )
                 iv_rule     = gc_rule-posting
                 iv_code     = gc_code-incomplete
                 iv_severity = zif_ca_ops_types=>gc_severity-warning ).
    add_finding( iv_type     = zcl_cd_ebs_finding=>gc_object_type-statement
                 iv_key      = ltd_rows=>stmt_key( gc_kukey-warning )
                 iv_rule     = gc_rule-duplicate
                 iv_code     = gc_code-duplicate
                 iv_severity = zif_ca_ops_types=>gc_severity-warning ).
    " Resolved and waived findings never count
    add_finding( iv_type        = zcl_cd_ebs_finding=>gc_object_type-statement
                 iv_key         = ltd_rows=>stmt_key( gc_kukey-resolved )
                 iv_rule        = gc_rule-reference
                 iv_code        = gc_code-not_found
                 iv_severity    = zif_ca_ops_types=>gc_severity-error
                 iv_disposition = zif_ca_ops_types=>gc_disposition-resolved ).
    add_finding( iv_type        = zcl_cd_ebs_finding=>gc_object_type-statement
                 iv_key         = ltd_rows=>stmt_key( gc_kukey-resolved )
                 iv_rule        = gc_rule-unmapped
                 iv_code        = gc_code-unmapped
                 iv_severity    = zif_ca_ops_types=>gc_severity-block
                 iv_disposition = zif_ca_ops_types=>gc_disposition-waived ).
    INSERT ltd_rows=>run( iv_run_id   = gc_run
                          iv_status   = zif_ca_ops_types=>gc_run_status-warning
                          iv_ended_at = ltd_rows=>now( ) ) INTO TABLE lt_runs.

    go_env->insert_test_data( i_data = lt_stmts ).
    go_env->insert_test_data( i_data = VALUE ltd_rows=>tt_acct( ( ltd_rows=>account( ) ) ) ).
    go_env->insert_test_data( i_data = lt_lines ).
    go_env->insert_test_data( i_data = mt_findings ).
    go_env->insert_test_data( i_data = lt_runs ).
  ENDMETHOD.


  METHOD status_of.
    SELECT SINGLE validationstatus FROM zr_cd_ebsstmt WHERE kukey = @iv_kukey INTO @DATA(lv_status).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |Statement { iv_kukey } must be on the dashboard| ).
    rv_status = condense( lv_status ).
  ENDMETHOD.


  METHOD status_follows_worst_finding.
    TRY.
        insert_scenario( ).

        cl_abap_unit_assert=>assert_equals( act = status_of( gc_kukey-blocked ) exp = gc_status-blocked
                                            msg = 'A block finding on a line blocks its statement' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_kukey-error ) exp = gc_status-error
                                            msg = 'An open error finding makes the statement ERROR' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_kukey-incomplete ) exp = gc_status-incomplete
                                            msg = 'An open S13 finding shows POSTING_INCOMPLETE' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_kukey-warning ) exp = gc_status-warning
                                            msg = 'Only a warning: WARNING' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_kukey-clean ) exp = gc_status-no_findings
                                            msg = 'No open finding: NO_FINDINGS (never "clean")' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD closed_findings_are_ignored.
    TRY.
        insert_scenario( ).

        SELECT SINGLE openfindingcount, validationstatus FROM zr_cd_ebsstmt
          WHERE kukey = @gc_kukey-resolved INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The statement must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-openfindingcount exp = 0
                                            msg = 'Resolved and waived findings are not open' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-validationstatus ) exp = gc_status-no_findings
                                            msg = 'Closed findings do not drive the status' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD lines_counted_per_statement.
    TRY.
        insert_scenario( ).

        SELECT SINGLE linecount, postedlinecount, linefindingcount, duplicatecount FROM zr_cd_ebsstmt
          WHERE kukey = @gc_kukey-clean INTO @DATA(ls_clean).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The statement with two lines must be listed' ).
        SELECT SINGLE linecount, linefindingcount, duplicatecount FROM zr_cd_ebsstmt
          WHERE kukey = @gc_kukey-blocked INTO @DATA(ls_blocked).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The blocked statement must be listed' ).

        cl_abap_unit_assert=>assert_equals( act = ls_clean-linecount exp = 2 msg = 'Two FEBEP lines' ).
        cl_abap_unit_assert=>assert_equals( act = ls_clean-postedlinecount exp = 1
                                            msg = 'One line carries a posting document' ).
        cl_abap_unit_assert=>assert_equals( act = ls_blocked-linefindingcount exp = 2
                                            msg = 'Line findings count for their statement' ).
        cl_abap_unit_assert=>assert_equals( act = ls_blocked-duplicatecount exp = 1
                                            msg = 'Duplicate rule R09 is counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Every line carries an active payment engine account: statement and lines are shown with the
  " account derived from XBLNR and the G/L account of the matched ZCD_EBS_ACCT row
  METHOD all_pe_statement_shown.
    CONSTANTS lc_xblnr_2 TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412335'.
    DATA lt_stmts TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    TRY.
        INSERT ltd_rows=>statement( gc_kukey-clean ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_2 iv_xblnr = lc_xblnr_2 ) INTO TABLE lt_lines.
        go_env->insert_test_data( i_data = lt_stmts ).
        go_env->insert_test_data( i_data = VALUE ltd_rows=>tt_acct( ( ltd_rows=>account( ) ) ) ).
        go_env->insert_test_data( i_data = lt_lines ).

        SELECT kukey, glaccount, peaccount FROM zr_cd_ebsstmt ORDER BY kukey INTO TABLE @DATA(lt_shown).
        SELECT esnum, glaccount, peaccount, xblnr FROM zr_cd_ebsline ORDER BY esnum INTO TABLE @DATA(lt_shown_lines).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_shown ) exp = 1 msg = 'The all-PE statement is shown' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_shown[ 1 ]-peaccount OPTIONAL ) exp = ltd_rows=>gc_pe_account
                                            msg = 'Statement carries the payment engine account from XBLNR' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_shown[ 1 ]-glaccount OPTIONAL ) exp = ltd_rows=>gc_gl_account
                                            msg = 'G/L account from the matched account configuration' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_shown_lines ) exp = 2 msg = 'Both lines are shown' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_shown_lines[ 2 ]-peaccount OPTIONAL )
                                            exp = ltd_rows=>gc_pe_account
                                            msg = 'Bank text and counter removed: the account of the line' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_shown_lines[ 2 ]-xblnr OPTIONAL ) exp = lc_xblnr_2
                                            msg = 'XBLNR is shown as delivered' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_shown_lines[ 2 ]-glaccount OPTIONAL )
                                            exp = ltd_rows=>gc_gl_account msg = 'Every line carries its G/L account' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " One line of another account, a line without XBLNR, or no line at all: the statement and all
  " its lines stay off the dashboard
  METHOD mixed_statement_hidden.
    CONSTANTS lc_xblnr_other TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'BOA9999999999001'.
    CONSTANTS lc_kukey_mixed TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000201'.
    CONSTANTS lc_kukey_blank TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000202'.
    CONSTANTS lc_kukey_empty TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000203'.
    DATA lt_stmts TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    TRY.
        INSERT ltd_rows=>statement( gc_kukey-clean ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>statement( lc_kukey_mixed ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>statement( lc_kukey_blank ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>statement( lc_kukey_empty ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = lc_kukey_mixed iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = lc_kukey_mixed iv_esnum = gc_line_2 iv_xblnr = lc_xblnr_other ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = lc_kukey_blank iv_esnum = gc_line_1 ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = lc_kukey_blank iv_esnum = gc_line_2 iv_xblnr = space ) INTO TABLE lt_lines.
        go_env->insert_test_data( i_data = lt_stmts ).
        go_env->insert_test_data( i_data = VALUE ltd_rows=>tt_acct( ( ltd_rows=>account( ) ) ) ).
        go_env->insert_test_data( i_data = lt_lines ).

        SELECT kukey FROM zr_cd_ebsstmt ORDER BY kukey INTO TABLE @DATA(lt_shown).
        SELECT kukey FROM zr_cd_ebsline ORDER BY kukey INTO TABLE @DATA(lt_shown_lines).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_shown ) exp = 1
                                            msg = 'Only the statement whose every line is a payment engine account' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_shown[ 1 ]-kukey OPTIONAL ) exp = gc_kukey-clean
                                            msg = 'The all-PE statement is the one shown' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_shown_lines ) exp = 1
                                            msg = 'Not even the PE line of a mixed statement is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The account is configured but inactive: not a payment engine account
  METHOD inactive_account_hidden.
    CONSTANTS lc_inactive_hkt TYPE c LENGTH 5 VALUE 'INAC1'.
    CONSTANTS lc_inactive_acct TYPE zif_cd_ebs_types=>ty_pe_account VALUE '7000000001'.
    CONSTANTS lc_xblnr_inactive TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'PNC7000000001001'.
    CONSTANTS lc_kukey_inactive TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000204'.
    DATA lt_stmts TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    TRY.
        INSERT ltd_rows=>statement( lc_kukey_inactive ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>line( iv_kukey = lc_kukey_inactive iv_esnum = gc_line_1 iv_xblnr = lc_xblnr_inactive )
          INTO TABLE lt_lines.
        go_env->insert_test_data( i_data = lt_stmts ).
        go_env->insert_test_data( i_data = VALUE ltd_rows=>tt_acct( ( ltd_rows=>account( iv_hktid      = lc_inactive_hkt
                                                                                          iv_account_no = lc_inactive_acct
                                                                                          iv_active     = abap_false ) ) ) ).
        go_env->insert_test_data( i_data = lt_lines ).

        SELECT kukey FROM zr_cd_ebsstmt ORDER BY kukey INTO TABLE @DATA(lt_shown).
        SELECT kukey FROM zr_cd_ebsline ORDER BY kukey INTO TABLE @DATA(lt_shown_lines).

        cl_abap_unit_assert=>assert_initial( act = lt_shown msg = 'A statement of an inactive account is hidden' ).
        cl_abap_unit_assert=>assert_initial( act = lt_shown_lines msg = 'Its lines are hidden too' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " "Line amounts by BAI code": totals per BAI code + XBLNR (two counters of one account), and
  " per payment engine account (the counters of one account together)
  METHOD totals_per_code_and_xblnr.
    CONSTANTS lc_code TYPE c LENGTH 3 VALUE '475'.
    CONSTANTS lc_debit TYPE c LENGTH 1 VALUE 'S'.
    CONSTANTS lc_xblnr_2 TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412335'.
    DATA lt_stmts TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    TRY.
        INSERT ltd_rows=>statement( gc_kukey-clean ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_1 iv_bai_code = lc_code
                               iv_dc_ind = lc_debit iv_amount = '100.00' ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_2 iv_bai_code = lc_code
                               iv_dc_ind = lc_debit iv_amount = '20.00' ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = '00003' iv_bai_code = lc_code
                               iv_dc_ind = lc_debit iv_amount = '5.50' iv_xblnr = lc_xblnr_2 ) INTO TABLE lt_lines.
        go_env->insert_test_data( i_data = lt_stmts ).
        go_env->insert_test_data( i_data = VALUE ltd_rows=>tt_acct( ( ltd_rows=>account( ) ) ) ).
        go_env->insert_test_data( i_data = lt_lines ).

        " Presentation variant AmountByCode: group by BAI code + XBLNR
        SELECT baicode, xblnr, SUM( amount ) AS total, SUM( linecount ) AS lines
          FROM zr_cd_ebsline
          GROUP BY baicode, xblnr
          ORDER BY baicode, xblnr
          INTO TABLE @DATA(lt_by_xblnr).
        " ... and per payment engine account (the counters of one account together)
        SELECT peaccount, baicode, SUM( amount ) AS total
          FROM zr_cd_ebsline
          GROUP BY peaccount, baicode
          ORDER BY peaccount, baicode
          INTO TABLE @DATA(lt_by_account).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_by_xblnr ) exp = 2 msg = 'One total per BAI code and XBLNR' ).
        DATA(ls_first) = VALUE #( lt_by_xblnr[ xblnr = ltd_rows=>gc_xblnr ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_first-total exp = '120.00' msg = 'Lines of one XBLNR summed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_first-lines exp = 2 msg = 'Two lines behind the XBLNR total' ).
        DATA(ls_second) = VALUE #( lt_by_xblnr[ xblnr = lc_xblnr_2 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_second-total exp = '5.50' msg = 'The other counter separate' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_by_account ) exp = 1
                                            msg = 'Both counters belong to one payment engine account' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_by_account[ 1 ]-total OPTIONAL ) exp = '125.50'
                                            msg = 'Account total over its counters' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD amounts_total_per_bai_code.
    CONSTANTS lc_credit_code TYPE c LENGTH 3 VALUE '165'.
    CONSTANTS lc_debit_code TYPE c LENGTH 3 VALUE '475'.
    CONSTANTS lc_credit TYPE c LENGTH 1 VALUE 'H'.
    CONSTANTS lc_debit TYPE c LENGTH 1 VALUE 'S'.
    DATA lt_stmts TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    TRY.
        INSERT ltd_rows=>statement( gc_kukey-clean ) INTO TABLE lt_stmts.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_1 iv_bai_code = lc_credit_code
                               iv_dc_ind = lc_credit iv_amount = '100.00' ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = gc_line_2 iv_bai_code = lc_credit_code
                               iv_dc_ind = lc_credit iv_amount = '50.25' ) INTO TABLE lt_lines.
        INSERT ltd_rows=>line( iv_kukey = gc_kukey-clean iv_esnum = '00003' iv_bai_code = lc_debit_code
                               iv_dc_ind = lc_debit iv_amount = '30.00' ) INTO TABLE lt_lines.
        go_env->insert_test_data( i_data = lt_stmts ).
        go_env->insert_test_data( i_data = VALUE ltd_rows=>tt_acct( ( ltd_rows=>account( ) ) ) ).
        go_env->insert_test_data( i_data = lt_lines ).

        " The analytical list page sums Amount per BAI code, debit / credit and currency
        SELECT glaccount, baicode, debitcreditind, currency, SUM( amount ) AS total, SUM( linecount ) AS lines
          FROM zr_cd_ebsline
          GROUP BY glaccount, baicode, debitcreditind, currency
          ORDER BY glaccount, baicode
          INTO TABLE @DATA(lt_totals).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_totals ) exp = 2 msg = 'One total per BAI code and direction' ).
        DATA(ls_credit) = VALUE #( lt_totals[ baicode = lc_credit_code ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_credit-total exp = '150.25' msg = 'Credit lines of code 165 summed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_credit-glaccount exp = ltd_rows=>gc_gl_account
                                            msg = 'Totals per G/L account of the payment engine account' ).
        cl_abap_unit_assert=>assert_equals( act = ls_credit-lines exp = 2 msg = 'Two lines behind the total' ).
        cl_abap_unit_assert=>assert_equals( act = ls_credit-currency exp = ltd_rows=>gc_currency
                                            msg = 'Line without currency takes the statement currency' ).
        DATA(ls_debit) = VALUE #( lt_totals[ baicode = lc_debit_code ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_debit-total exp = '30.00' msg = 'Debit code 475 separate' ).
        cl_abap_unit_assert=>assert_equals( act = ls_debit-debitcreditind exp = lc_debit msg = 'Direction kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD line_status_from_line_finding.
    TRY.
        insert_scenario( ).

        SELECT kukey, esnum, validationstatus, openfindingcount, isposted FROM zr_cd_ebsline
          ORDER BY kukey, esnum INTO TABLE @DATA(lt_lines).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 7 msg = 'Every FEBEP line once' ).
        DATA(ls_blocked) = VALUE #( lt_lines[ kukey = gc_kukey-blocked esnum = gc_line_1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_blocked-validationstatus ) exp = gc_status-blocked
                                            msg = 'The line key FEB<KUKEY>/<ESNUM> links the finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_blocked-openfindingcount exp = 2
                                            msg = 'Both open findings of the line' ).
        DATA(ls_posted) = VALUE #( lt_lines[ kukey = gc_kukey-clean esnum = gc_line_1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_posted-isposted exp = abap_true
                                            msg = 'A line with BELNR is posted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD rows_carry_validation_as_of.
    TRY.
        insert_scenario( ).

        SELECT asofrunid, monitorisstale FROM zr_cd_ebsstmt ORDER BY kukey INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 6 msg = 'Every statement once' ).
        LOOP AT lt_rows INTO DATA(ls_row).
          cl_abap_unit_assert=>assert_equals( act = ls_row-asofrunid exp = gc_run
                                              msg = 'Every row names the run it is as of' ).
          cl_abap_unit_assert=>assert_equals( act = ls_row-monitorisstale exp = abap_false
                                              msg = 'A run that ended just now is not stale' ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_EBSFIND: keys, masking of the bank account, hidden messages of the file source
CLASS ltc_finding DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_run TYPE zif_ca_ops_types=>ty_run_id VALUE 'E0000000000000000000000000000002'.
    CONSTANTS gc_kukey TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000201'.
    CONSTANTS gc_esnum TYPE zif_cd_ebs_types=>ty_esnum VALUE '00012'.
    CONSTANTS gc_line_no TYPE c LENGTH 5 VALUE '12'.
    CONSTANTS gc_account TYPE zif_ca_ops_types=>ty_group VALUE '123456789012'.
    CONSTANTS gc_account_masked TYPE c LENGTH 8 VALUE '****9012'.
    CONSTANTS gc_file_stmt TYPE zif_ca_ops_types=>ty_object_key VALUE 'S0001'.
    CONSTANTS gc_bai TYPE zif_ca_ops_types=>ty_group VALUE 'BAI2:165'.
    CONSTANTS gc_message TYPE c LENGTH 40 VALUE 'Account 123456789012: balance mismatch'.
    CONSTANTS gc_rule TYPE zif_ca_ops_types=>ty_rule_id VALUE 'S02'.
    CONSTANTS gc_code TYPE zif_ca_ops_types=>ty_check_code VALUE 'BALANCE_MISMATCH'.
    CONSTANTS gc_source_file TYPE c LENGTH 4 VALUE 'FILE'.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS account_is_masked FOR TESTING.
    METHODS file_stmt_message_hidden FOR TESTING.
    METHODS line_key_gives_line_number FOR TESTING.
ENDCLASS.


CLASS ltc_finding IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity               = 'ZR_CD_EBSFIND'
                                              i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.

    go_env->clear_doubles( ).
    go_env->insert_test_data( i_data = ltd_rows=>rule_defs( ) ).
    DATA(ls_feb) = ltd_rows=>finding( iv_run_id      = gc_run
                                      iv_finding_no  = 1
                                      iv_object_type = zcl_cd_ebs_finding=>gc_object_type-statement
                                      iv_object_key  = ltd_rows=>stmt_key( gc_kukey )
                                      iv_rule_id     = gc_rule
                                      iv_code        = gc_code
                                      iv_severity    = zif_ca_ops_types=>gc_severity-block ).
    ls_feb-group1  = gc_account.
    ls_feb-message = gc_message.
    INSERT ls_feb INTO TABLE lt_findings.
    DATA(ls_file) = ltd_rows=>finding( iv_run_id      = gc_run
                                       iv_finding_no  = 2
                                       iv_object_type = zcl_cd_ebs_finding=>gc_object_type-statement
                                       iv_object_key  = gc_file_stmt
                                       iv_rule_id     = gc_rule
                                       iv_code        = gc_code
                                       iv_severity    = zif_ca_ops_types=>gc_severity-block ).
    ls_file-group1  = gc_account.
    ls_file-message = gc_message.
    INSERT ls_file INTO TABLE lt_findings.
    DATA(ls_line) = ltd_rows=>finding( iv_run_id      = gc_run
                                       iv_finding_no  = 3
                                       iv_object_type = zcl_cd_ebs_finding=>gc_object_type-line
                                       iv_object_key  = ltd_rows=>line_key( iv_kukey = gc_kukey iv_esnum = gc_esnum )
                                       iv_rule_id     = gc_rule
                                       iv_code        = gc_code
                                       iv_severity    = zif_ca_ops_types=>gc_severity-warning ).
    ls_line-group1 = gc_bai.
    INSERT ls_line INTO TABLE lt_findings.
    go_env->insert_test_data( i_data = lt_findings ).
  ENDMETHOD.


  METHOD account_is_masked.
    TRY.
        SELECT findingno, accountmasked, stmtobjectkey FROM zr_cd_ebsfind ORDER BY findingno INTO TABLE @DATA(lt_rows).

        DATA(ls_feb) = VALUE #( lt_rows[ findingno = 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_feb-accountmasked exp = gc_account_masked
                                            msg = 'Only the last four characters of the account are shown' ).
        cl_abap_unit_assert=>assert_equals( act = ls_feb-stmtobjectkey exp = ltd_rows=>stmt_key( gc_kukey )
                                            msg = 'The statement key FEB<KUKEY> is derived' ).
        cl_abap_unit_assert=>assert_char_np( act = ls_feb-accountmasked exp = |*{ gc_account(4) }*|
                                             msg = 'The leading account digits never appear' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD file_stmt_message_hidden.
    TRY.
        SELECT findingno, findingmessage, statementsource FROM zr_cd_ebsfind ORDER BY findingno INTO TABLE @DATA(lt_rows).

        DATA(ls_file) = VALUE #( lt_rows[ findingno = 2 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_initial( act = ls_file-findingmessage
                                             msg = 'A file-source statement message (may hold the account) is hidden' ).
        cl_abap_unit_assert=>assert_equals( act = ls_file-statementsource exp = gc_source_file
                                            msg = 'S0001 keys are bank-file statements' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD line_key_gives_line_number.
    TRY.
        SELECT SINGLE lineno, baicode, stmtobjectkey FROM zr_cd_ebsfind WHERE findingno = 3 INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The line finding must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-lineno ) exp = gc_line_no
                                            msg = 'The line number is the part after the slash' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-baicode exp = gc_bai msg = 'GROUP1 of a line is the BAI code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-stmtobjectkey exp = ltd_rows=>stmt_key( gc_kukey )
                                            msg = 'A line finding belongs to its statement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_EBSRUN / ZR_CD_EBSKPI / ZR_CD_EBSASOF: counters, unevaluated lines, last run of the day, stale
CLASS ltc_run DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_run,
        early   TYPE zif_ca_ops_types=>ty_run_id VALUE 'E0000000000000000000000000000011',
        late    TYPE zif_ca_ops_types=>ty_run_id VALUE 'E0000000000000000000000000000012',
        running TYPE zif_ca_ops_types=>ty_run_id VALUE 'E0000000000000000000000000000013',
        test    TYPE zif_ca_ops_types=>ty_run_id VALUE 'E0000000000000000000000000000014',
      END OF gc_run.
    CONSTANTS:
      BEGIN OF gc_count,
        total   TYPE i VALUE 20,
        passed  TYPE i VALUE 10,
        warning TYPE i VALUE 3,
        failed  TYPE i VALUE 2,
        blocked TYPE i VALUE 1,
        early   TYPE i VALUE 99,
      END OF gc_count.
    CONSTANTS gc_unevaluated TYPE i VALUE 4.
    CONSTANTS gc_kukey TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000301'.
    CONSTANTS gc_s13 TYPE zif_ca_ops_types=>ty_rule_id VALUE 'S13'.
    CONSTANTS gc_s13_code TYPE zif_ca_ops_types=>ty_check_code VALUE 'POSTING_INCOMPLETE'.
    CONSTANTS gc_r22 TYPE zif_ca_ops_types=>ty_rule_id VALUE 'R22'.
    CONSTANTS gc_r22_code TYPE zif_ca_ops_types=>ty_check_code VALUE 'DUPLICATE_HISTORY'.
    CONSTANTS gc_plugin TYPE zif_ca_ops_types=>ty_check_code VALUE 'PLUGIN_ERROR'.
    CONSTANTS gc_seconds_old TYPE i VALUE 108000.
    CONSTANTS gc_stale_minutes TYPE i VALUE 1560.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS unevaluated_is_the_remainder FOR TESTING.
    METHODS run_counts_s13_and_duplicates FOR TESTING.
    METHODS kpi_shows_last_run_of_day FOR TESTING.
    METHODS as_of_skips_running_and_test FOR TESTING.
    METHODS stale_when_no_completed_run FOR TESTING.
    METHODS stale_after_26_hours FOR TESTING.
    METHODS moncfg_threshold_applies FOR TESTING.

    METHODS counted_run
      IMPORTING
        iv_run_id     TYPE zif_ca_ops_types=>ty_run_id
        iv_ended_at   TYPE timestampl
        iv_total      TYPE i DEFAULT gc_count-total
      RETURNING
        VALUE(rs_run) TYPE zca_ops_run.
    METHODS insert_runs.
ENDCLASS.


CLASS ltc_run IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_CD_EBSRUN' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_EBSKPI' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_EBSASOF' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    go_env->insert_test_data( i_data = ltd_rows=>rule_defs( ) ).
  ENDMETHOD.


  METHOD counted_run.
    rs_run = ltd_rows=>run( iv_run_id   = iv_run_id
                            iv_status   = zif_ca_ops_types=>gc_run_status-warning
                            iv_ended_at = iv_ended_at ).
    rs_run-total_items   = iv_total.
    rs_run-passed_items  = gc_count-passed.
    rs_run-warning_items = gc_count-warning.
    rs_run-failed_items  = gc_count-failed.
    rs_run-blocked_items = gc_count-blocked.
  ENDMETHOD.


  METHOD insert_runs.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.

    INSERT counted_run( iv_run_id = gc_run-early iv_ended_at = ltd_rows=>seconds_ago( 120 )
                        iv_total  = gc_count-early ) INTO TABLE lt_runs.
    INSERT counted_run( iv_run_id = gc_run-late iv_ended_at = ltd_rows=>seconds_ago( 60 ) ) INTO TABLE lt_runs.
    DATA(ls_running) = counted_run( iv_run_id = gc_run-running iv_ended_at = ltd_rows=>now( ) ).
    ls_running-status = zif_ca_ops_types=>gc_run_status-running.
    INSERT ls_running INTO TABLE lt_runs.
    DATA(ls_test) = counted_run( iv_run_id = gc_run-test iv_ended_at = ltd_rows=>now( ) ).
    ls_test-test_mode = abap_true.
    INSERT ls_test INTO TABLE lt_runs.

    INSERT ltd_rows=>finding( iv_run_id      = gc_run-late
                              iv_finding_no  = 1
                              iv_object_type = zcl_cd_ebs_finding=>gc_object_type-statement
                              iv_object_key  = ltd_rows=>stmt_key( gc_kukey )
                              iv_rule_id     = gc_s13
                              iv_code        = gc_s13_code
                              iv_severity    = zif_ca_ops_types=>gc_severity-warning ) INTO TABLE lt_findings.
    INSERT ltd_rows=>finding( iv_run_id      = gc_run-late
                              iv_finding_no  = 2
                              iv_object_type = zcl_cd_ebs_finding=>gc_object_type-statement
                              iv_object_key  = ltd_rows=>stmt_key( gc_kukey )
                              iv_rule_id     = gc_r22
                              iv_code        = gc_r22_code
                              iv_severity    = zif_ca_ops_types=>gc_severity-warning ) INTO TABLE lt_findings.
    " A run-level finding has a blank statement key: never counted as a statement
    INSERT ltd_rows=>finding( iv_run_id      = gc_run-late
                              iv_finding_no  = 3
                              iv_object_type = zcl_cd_ebs_finding=>gc_object_type-run
                              iv_object_key  = gc_r22
                              iv_rule_id     = gc_r22
                              iv_code        = gc_plugin
                              iv_severity    = zif_ca_ops_types=>gc_severity-error ) INTO TABLE lt_findings.
    go_env->insert_test_data( i_data = lt_runs ).
    go_env->insert_test_data( i_data = lt_findings ).
  ENDMETHOD.


  METHOD unevaluated_is_the_remainder.
    TRY.
        insert_runs( ).

        SELECT SINGLE linecount, unevaluatedlinecount, iscompleted FROM zr_cd_ebsrun
          WHERE runid = @gc_run-late INTO @DATA(ls_run).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The run must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-linecount exp = gc_count-total msg = 'Lines validated' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-unevaluatedlinecount exp = gc_unevaluated
                                            msg = 'Unevaluated = total - passed - warning - failed - blocked' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-iscompleted exp = abap_true msg = 'Status W is completed' ).
        SELECT COUNT(*) FROM zr_cd_ebsrun WHERE runid = @gc_run-test INTO @DATA(lv_test).
        cl_abap_unit_assert=>assert_equals( act = lv_test exp = 0 msg = 'Test-mode runs are not listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD run_counts_s13_and_duplicates.
    TRY.
        insert_runs( ).

        SELECT SINGLE postingincompletecount, duplicatecount, statementswithfindings, errorfindingcount
          FROM zr_cd_ebsrun WHERE runid = @gc_run-late INTO @DATA(ls_run).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The run must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-postingincompletecount exp = 1 msg = 'One S13 finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-duplicatecount exp = 2
                                            msg = 'Rule R22 findings count as duplicates' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-statementswithfindings exp = 1
                                            msg = 'One statement; the blank key of the run finding is not one' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-errorfindingcount exp = 1 msg = 'One error finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD kpi_shows_last_run_of_day.
    TRY.
        insert_runs( ).

        SELECT runid, linecount, islatest FROM zr_cd_ebskpi ORDER BY rundate INTO TABLE @DATA(lt_days).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 1 msg = 'One KPI row per run date' ).
        DATA(ls_day) = VALUE #( lt_days[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-runid exp = gc_run-late
                                            msg = 'The last completed run of the day, not the running one' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-linecount exp = gc_count-total
                                            msg = 'Counters of that run only - runs of a day are never added' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-islatest exp = abap_true msg = 'It is the as-of run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD as_of_skips_running_and_test.
    TRY.
        insert_runs( ).

        SELECT SINGLE runid, isstale FROM zr_cd_ebsasof INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The as-of row must exist' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-runid exp = gc_run-late
                                            msg = 'Running and test-mode runs do not advance the as-of' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_false msg = 'A fresh run is not stale' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD stale_when_no_completed_run.
    TRY.
        DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.
        DATA(ls_aborted) = counted_run( iv_run_id = gc_run-running iv_ended_at = ltd_rows=>now( ) ).
        ls_aborted-status = zif_ca_ops_types=>gc_run_status-aborted.
        INSERT ls_aborted INTO TABLE lt_runs.
        go_env->insert_test_data( i_data = lt_runs ).

        SELECT asofat, isstale FROM zr_cd_ebsasof ORDER BY asofat INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row also without a run' ).
        DATA(ls_row) = VALUE #( lt_rows[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_initial( act = ls_row-asofat msg = 'No completed run: no as-of time' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_true
                                            msg = 'No completed run is stale, never clean statements' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the parameter MON_STALE_AFTER_MIN_EBS decides (value row 60 minutes over the definition
  " default 1560; table consolidation 2026-11-08, was ZCD_OPS_MONCFG): a run two hours old is stale,
  " although the delivered 26 hours would keep it fresh
  METHOD moncfg_threshold_applies.
    CONSTANTS lc_minutes TYPE i VALUE 60.
    CONSTANTS lc_two_hours TYPE i VALUE 7200.
    DATA lt_def TYPE STANDARD TABLE OF zca_param_def WITH EMPTY KEY.
    DATA ls_def TYPE zca_param_def.
    DATA lt_val TYPE STANDARD TABLE OF zca_param_val WITH EMPTY KEY.
    DATA ls_val TYPE zca_param_val.
    TRY.
        DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.
        INSERT counted_run( iv_run_id = gc_run-early iv_ended_at = ltd_rows=>seconds_ago( lc_two_hours ) )
               INTO TABLE lt_runs.
        go_env->insert_test_data( i_data = lt_runs ).
        ls_def-area          = zif_cd_ops_types=>gc_param_area-ops.
        ls_def-name          = |{ zif_cd_ops_types=>gc_param_prefix-stale_after_min }{ zif_cd_ops_types=>gc_pe_area-ebs }|.
        ls_def-kind          = zif_ca_param_types=>gc_kind-single.
        ls_def-value_type    = zif_ca_param_types=>gc_value_type-int.
        ls_def-default_value = |{ gc_stale_minutes }|.
        INSERT ls_def INTO TABLE lt_def.
        go_env->insert_test_data( i_data = lt_def ).
        ls_val-area = ls_def-area.
        ls_val-name = ls_def-name.
        ls_val-numb = 1.
        ls_val-sign = zif_ca_param_types=>gc_sign-include.
        ls_val-opti = zif_ca_param_types=>gc_option-eq.
        ls_val-low  = |{ lc_minutes }|.
        INSERT ls_val INTO TABLE lt_val.
        go_env->insert_test_data( i_data = lt_val ).

        SELECT SINGLE isstale, staleafterminutes FROM zr_cd_ebsasof INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The as-of row must exist' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_true
                                            msg = 'Beyond the configured 60 minutes: stale' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-staleafterminutes exp = lc_minutes
                                            msg = 'The configured threshold is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD stale_after_26_hours.
    TRY.
        DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.
        INSERT counted_run( iv_run_id = gc_run-early iv_ended_at = ltd_rows=>seconds_ago( gc_seconds_old ) )
               INTO TABLE lt_runs.
        go_env->insert_test_data( i_data = lt_runs ).

        SELECT SINGLE isstale, ageminutes FROM zr_cd_ebsasof INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The as-of row must exist' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_true msg = 'A run 30 hours old is stale' ).
        cl_abap_unit_assert=>assert_number_between( lower = gc_stale_minutes upper = cl_abap_math=>max_int4
                                                    number = ls_row-ageminutes
                                                    msg = 'The age exceeds 26 hours' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_EBSRETNOC: returns by DFKKRP-RLGRD, NOCs by DFKKNRP-FLGRD via INFOF without leading zeros
CLASS ltc_returns DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_kukey TYPE zif_cd_ebs_types=>ty_kukey VALUE '00000401'.
    CONSTANTS gc_line_ret TYPE zif_cd_ebs_types=>ty_esnum VALUE '00001'.
    CONSTANTS gc_line_noc TYPE zif_cd_ebs_types=>ty_esnum VALUE '00002'.
    CONSTANTS gc_line_none TYPE zif_cd_ebs_types=>ty_esnum VALUE '00003'.
    CONSTANTS gc_doc_ret TYPE c LENGTH 12 VALUE '500000000001'.
    CONSTANTS gc_doc_noc TYPE c LENGTH 12 VALUE '500000000002'.
    CONSTANTS gc_doc_none TYPE c LENGTH 12 VALUE '500000000003'.
    "! INFOF carries the payment document with leading zeros (normalised before the compare)
    CONSTANTS gc_infof_noc TYPE c LENGTH 50 VALUE '000500000000002'.
    CONSTANTS gc_return_doc TYPE c LENGTH 12 VALUE '600000000001'.
    CONSTANTS gc_return_reason TYPE c LENGTH 3 VALUE 'R01'.
    CONSTANTS gc_noc_reason TYPE c LENGTH 3 VALUE 'C02'.
    CONSTANTS gc_noc_lot TYPE c LENGTH 12 VALUE 'NOC000000001'.
    CONSTANTS gc_noc_item TYPE n LENGTH 6 VALUE '000001'.
    CONSTANTS:
      BEGIN OF gc_kind,
        return TYPE c LENGTH 6 VALUE 'RETURN',
        noc    TYPE c LENGTH 6 VALUE 'NOC',
      END OF gc_kind.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS return_reason_from_dfkkrp FOR TESTING.
    METHODS noc_reason_via_infof FOR TESTING.
ENDCLASS.


CLASS ltc_returns IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity               = 'ZR_CD_EBSRETNOC'
                                              i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_stmts TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA lt_returns TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA lt_nocs TYPE STANDARD TABLE OF dfkknrp WITH EMPTY KEY.
    DATA ls_return TYPE dfkkrp.
    DATA ls_noc TYPE dfkknrp.

    go_env->clear_doubles( ).
    INSERT ltd_rows=>statement( gc_kukey ) INTO TABLE lt_stmts.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey iv_esnum = gc_line_ret iv_reference = gc_doc_ret ) INTO TABLE lt_lines.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey iv_esnum = gc_line_noc iv_reference = gc_doc_noc ) INTO TABLE lt_lines.
    INSERT ltd_rows=>line( iv_kukey = gc_kukey iv_esnum = gc_line_none iv_reference = gc_doc_none ) INTO TABLE lt_lines.
    ls_return-selw1 = gc_doc_ret.
    ls_return-opbel = gc_return_doc.
    ls_return-rlgrd = gc_return_reason.
    INSERT ls_return INTO TABLE lt_returns.
    ls_noc-keyn1 = gc_noc_lot.
    ls_noc-posna = gc_noc_item.
    ls_noc-infof = gc_infof_noc.
    ls_noc-flgrd = gc_noc_reason.
    INSERT ls_noc INTO TABLE lt_nocs.
    go_env->insert_test_data( i_data = lt_stmts ).
    go_env->insert_test_data( i_data = VALUE ltd_rows=>tt_acct( ( ltd_rows=>account( ) ) ) ).
    go_env->insert_test_data( i_data = lt_lines ).
    go_env->insert_test_data( i_data = lt_returns ).
    go_env->insert_test_data( i_data = lt_nocs ).
  ENDMETHOD.


  METHOD return_reason_from_dfkkrp.
    TRY.
        SELECT esnum, lotkind, reason FROM zr_cd_ebsretnoc WHERE lotkind = @gc_kind-return
          ORDER BY esnum INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One returns lot item' ).
        DATA(ls_row) = VALUE #( lt_rows[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-esnum exp = gc_line_ret
                                            msg = 'Linked by DFKKRP-SELW1 = FEBEP-CHECT' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-reason ) exp = gc_return_reason
                                            msg = 'The reason is DFKKRP-RLGRD' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD noc_reason_via_infof.
    TRY.
        SELECT esnum, reason FROM zr_cd_ebsretnoc WHERE lotkind = @gc_kind-noc ORDER BY esnum
          INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One NOC lot item' ).
        DATA(ls_row) = VALUE #( lt_rows[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-esnum exp = gc_line_noc
                                            msg = 'INFOF with leading zeros matches the payment document' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-reason ) exp = gc_noc_reason
                                            msg = 'The NOC reason is DFKKNRP-FLGRD' ).
        SELECT COUNT(*) FROM zr_cd_ebsretnoc WHERE esnum = @gc_line_none INTO @DATA(lv_none).
        cl_abap_unit_assert=>assert_equals( act = lv_none exp = 0 msg = 'A line without lot item has no row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
