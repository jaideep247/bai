*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_btc_seq.clas.testclasses.abap
*& Purpose:
*& Unit tests of the bank code lifecycle evidence with the seeded roles
*& and outcomes: every seeded sequence (collections 166 / 143 / 468 with
*& delayed redeposit, disbursement ACH 466 / 168 / 166 / 468, wire 495 /
*& 195), redeposit pending inside and outside its maximum age, unexpected
*& sequence, returns lot count and amount mismatches, lot without return
*& line, ordering by statement date / line, one code with different
*& meanings per flow, ISO code of a CAMT line, unmapped monetary codes
*& (INDETERMINATE, BTC_ROLE_MISSING) and the approved informational
*& exclusions / lines without amount, invalid pattern, one read per kind. Runtime DAO, payment trace
*& repository and clock are doubles; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user correction of rule 4: BAI lifecycle per payment).
*& 2026-11-07 | ltc_ev_btc_seq_chq: cheque lifecycle 581 / 255 / corrections (link by cheque number,
*&            | register state, clarification, manual clearing, register amount).
*& 2026-11-07 | Design review: unknown monetary code = INDETERMINATE + BTC_ROLE_MISSING; exclusion
*&            | list HCK_BTC_INFO_BAI2 and zero-amount lines ignored; parameters injected; cheque lines
*&            | with the house bank account, a line of two cheques of one account = CHEQUE_LINK_AMBIGUOUS.
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_roles TYPE zif_cd_hck_runtime_types=>tt_btc_role.
    DATA mt_outcomes TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_btc_roles.
    rt_roles = mt_roles.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_seq_outcomes.
    rt_outcomes = mt_outcomes.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
    DATA mt_returns TYPE zif_cd_ops_trace_types=>tt_return.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mv_line_reads TYPE i.
    DATA mv_lot_reads TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    mv_line_reads = mv_line_reads + 1.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ).
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_returns.
    mv_lot_reads = mv_lot_reads + 1.
    rt_returns = mt_returns.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    rt_checks = mt_checks.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261111'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_btc_seq DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_doc    TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_ref    TYPE zif_cd_ops_trace_types=>ty_ref VALUE '300001',
      gc_bai    TYPE zif_cd_hck_runtime_types=>ty_scheme VALUE 'BAI2',
      gc_iso    TYPE zif_cd_hck_runtime_types=>ty_scheme VALUE 'ISO',
      gc_amount TYPE zif_cd_ops_types=>ty_amount VALUE '250.00',
      gc_first  TYPE d VALUE '20261102',
      gc_d      TYPE zif_cd_hck_runtime_types=>ty_flow VALUE 'D',
      gc_c      TYPE zif_cd_hck_runtime_types=>ty_flow VALUE 'C',
      gc_ach    TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'ACH',
      gc_wire   TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'WIR'.

    "! One seeded sequence and what it must give
    TYPES:
      BEGIN OF ty_case,
        flow    TYPE zif_cd_hck_runtime_types=>ty_flow,
        class   TYPE zif_cd_hck_runtime_types=>ty_method_class,
        codes   TYPE string,
        lots    TYPE i,
        outcome TYPE string,
      END OF ty_case.
    TYPES tt_case TYPE STANDARD TABLE OF ty_case WITH EMPTY KEY.

    DATA mo_dao TYPE REF TO ltd_runtime_dao.
    DATA mo_trace TYPE REF TO ltd_trace_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS role
      IMPORTING
        iv_flow    TYPE zif_cd_hck_runtime_types=>ty_flow
        iv_class   TYPE zif_cd_hck_runtime_types=>ty_method_class
        iv_scheme  TYPE zif_cd_hck_runtime_types=>ty_scheme DEFAULT gc_bai
        iv_code    TYPE clike
        iv_role    TYPE clike
        iv_compare TYPE abap_bool DEFAULT abap_false.
    METHODS outcome
      IMPORTING
        iv_flow     TYPE zif_cd_hck_runtime_types=>ty_flow
        iv_class    TYPE zif_cd_hck_runtime_types=>ty_method_class
        iv_seq      TYPE zif_cd_hck_runtime_types=>ty_rule_seq
        iv_pattern  TYPE clike
        iv_outcome  TYPE clike
        iv_expected TYPE clike
        iv_max_age  TYPE i DEFAULT 0.
    "! Lines of the codes (comma list) one day apart from iv_first, lot items, then collect
    METHODS evaluate
      IMPORTING
        iv_flow            TYPE zif_cd_hck_runtime_types=>ty_flow
        iv_class           TYPE zif_cd_hck_runtime_types=>ty_method_class
        iv_codes           TYPE clike
        iv_lots            TYPE i DEFAULT 0
        iv_lot_amount      TYPE zif_cd_ops_types=>ty_amount DEFAULT gc_amount
        iv_target          TYPE clike
        iv_first           TYPE d DEFAULT gc_first
      RETURNING
        VALUE(rs_evidence) TYPE zif_cd_hck_runtime_types=>ty_evidence
      RAISING
        zcx_cd_ops_error.
    METHODS collect
      IMPORTING
        iv_flow            TYPE zif_cd_hck_runtime_types=>ty_flow
        iv_class           TYPE zif_cd_hck_runtime_types=>ty_method_class
        iv_target          TYPE clike
      RETURNING
        VALUE(rs_evidence) TYPE zif_cd_hck_runtime_types=>ty_evidence
      RAISING
        zcx_cd_ops_error.

    METHODS every_seeded_sequence      FOR TESTING.
    METHODS redeposit_inside_max_age   FOR TESTING.
    METHODS redeposit_outside_max_age  FOR TESTING.
    METHODS unexpected_sequence        FOR TESTING.
    METHODS lot_count_mismatch         FOR TESTING.
    METHODS lot_without_return_line    FOR TESTING.
    METHODS amount_mismatch            FOR TESTING.
    METHODS ordered_by_date_and_line   FOR TESTING.
    METHODS code_468_differs_by_flow   FOR TESTING.
    METHODS iso_code_of_camt_line      FOR TESTING.
    METHODS unknown_monetary_indeterminate FOR TESTING.
    METHODS unknown_excluded_code_ignored FOR TESTING.
    METHODS unknown_zero_amount_ignored FOR TESTING.
    METHODS invalid_pattern_raises     FOR TESTING.
    METHODS one_read_per_kind          FOR TESTING.
ENDCLASS.


CLASS ltc_ev_btc_seq IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    " Seed (config/hck_seed.md): collections ACH
    role( iv_flow = gc_c iv_class = gc_ach iv_code = '166' iv_role = 'COLLECTED' ).
    role( iv_flow = gc_c iv_class = gc_ach iv_code = '143' iv_role = 'COLLECTED' ).
    role( iv_flow = gc_c iv_class = gc_ach iv_code = '468' iv_role = 'COLLECT_FAIL' iv_compare = abap_true ).
    role( iv_flow = gc_c iv_class = gc_ach iv_scheme = gc_iso iv_code = 'PMNT-RDDT-ESDD' iv_role = 'COLLECTED' ).
    outcome( iv_flow = gc_c iv_class = gc_ach iv_seq = '010' iv_pattern = 'COLLECTED'
             iv_outcome = 'CLEARED' iv_expected = '0' ).
    outcome( iv_flow = gc_c iv_class = gc_ach iv_seq = '020' iv_pattern = 'COLLECT_FAIL'
             iv_outcome = 'REDEPOSIT_PENDING' iv_expected = '0' iv_max_age = 10 ).
    outcome( iv_flow = gc_c iv_class = gc_ach iv_seq = '030' iv_pattern = 'COLLECT_FAIL,COLLECTED'
             iv_outcome = 'CLEARED' iv_expected = '0' ).
    outcome( iv_flow = gc_c iv_class = gc_ach iv_seq = '040' iv_pattern = 'COLLECT_FAIL,COLLECT_FAIL'
             iv_outcome = 'RETURNED' iv_expected = '1' ).
    " Disbursement ACH
    role( iv_flow = gc_d iv_class = gc_ach iv_code = '466' iv_role = 'ORIGINAL' ).
    role( iv_flow = gc_d iv_class = gc_ach iv_code = '168' iv_role = 'RETURNED' iv_compare = abap_true ).
    role( iv_flow = gc_d iv_class = gc_ach iv_code = '166' iv_role = 'RETRIEVED' ).
    role( iv_flow = gc_d iv_class = gc_ach iv_code = '468' iv_role = 'RETRIEVE_FAIL' ).
    outcome( iv_flow = gc_d iv_class = gc_ach iv_seq = '010' iv_pattern = 'ORIGINAL'
             iv_outcome = 'CLEARED' iv_expected = '0' ).
    outcome( iv_flow = gc_d iv_class = gc_ach iv_seq = '020' iv_pattern = 'ORIGINAL,RETURNED'
             iv_outcome = 'RETURNED' iv_expected = '1' ).
    outcome( iv_flow = gc_d iv_class = gc_ach iv_seq = '030' iv_pattern = 'ORIGINAL,RETRIEVED'
             iv_outcome = 'RETRIEVED' iv_expected = '0' ).
    outcome( iv_flow = gc_d iv_class = gc_ach iv_seq = '040' iv_pattern = 'ORIGINAL,RETRIEVE_FAIL'
             iv_outcome = 'RETRIEVAL_FAILED' iv_expected = '0' ).
    outcome( iv_flow = gc_d iv_class = gc_ach iv_seq = '050' iv_pattern = 'ORIGINAL,RETRIEVED,RETURNED,RETRIEVE_FAIL'
             iv_outcome = 'RETURNED' iv_expected = '1' ).
    " Wire disbursement
    role( iv_flow = gc_d iv_class = gc_wire iv_code = '495' iv_role = 'ORIGINAL' ).
    role( iv_flow = gc_d iv_class = gc_wire iv_code = '195' iv_role = 'RETURNED' iv_compare = abap_true ).
    outcome( iv_flow = gc_d iv_class = gc_wire iv_seq = '010' iv_pattern = 'ORIGINAL'
             iv_outcome = 'CLEARED' iv_expected = '0' ).
    outcome( iv_flow = gc_d iv_class = gc_wire iv_seq = '020' iv_pattern = 'ORIGINAL,RETURNED'
             iv_outcome = 'RETURNED' iv_expected = '1' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_trace, mo_params.
  ENDMETHOD.


  METHOD role.
    DATA ls_role TYPE zif_cd_hck_runtime_types=>ty_btc_role_row.
    ls_role-flow           = iv_flow.
    ls_role-method_class   = iv_class.
    ls_role-scheme         = iv_scheme.
    ls_role-btc_code       = iv_code.
    ls_role-role           = iv_role.
    ls_role-compare_amount = iv_compare.
    INSERT ls_role INTO TABLE mo_dao->mt_roles.
  ENDMETHOD.


  METHOD outcome.
    DATA ls_outcome TYPE zif_cd_hck_runtime_types=>ty_seq_outcome.
    ls_outcome-flow            = iv_flow.
    ls_outcome-method_class    = iv_class.
    ls_outcome-seq             = iv_seq.
    ls_outcome-seq_pattern     = iv_pattern.
    ls_outcome-outcome         = iv_outcome.
    ls_outcome-expected_dfkkrp = iv_expected.
    ls_outcome-max_age_days    = iv_max_age.
    INSERT ls_outcome INTO TABLE mo_dao->mt_outcomes.
  ENDMETHOD.


  METHOD evaluate.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    DATA ls_return TYPE zif_cd_ops_trace_types=>ty_return.
    CLEAR: mo_trace->mt_lines, mo_trace->mt_returns.
    SPLIT iv_codes AT ',' INTO TABLE DATA(lt_codes).
    LOOP AT lt_codes ASSIGNING FIELD-SYMBOL(<lv_code>).
      CLEAR ls_line.
      ls_line-kukey = '00000101'.
      ls_line-esnum = sy-tabix.
      ls_line-chect = gc_ref.
      ls_line-vorgc = <lv_code>.
      ls_line-budat = iv_first + sy-tabix - 1.
      ls_line-kwbtr = gc_amount.
      INSERT ls_line INTO TABLE mo_trace->mt_lines.
    ENDLOOP.
    DO iv_lots TIMES.
      ls_return-selw1  = gc_doc.
      ls_return-opbel  = |00000070000{ sy-index }|.
      ls_return-amount = iv_lot_amount.
      INSERT ls_return INTO TABLE mo_trace->mt_returns.
    ENDDO.
    rs_evidence = collect( iv_flow = iv_flow iv_class = iv_class iv_target = iv_target ).
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    INSERT VALUE #( doc1r = gc_doc laufd = '20261101' flow = iv_flow class = iv_class ) INTO TABLE lt_payments.
    DATA(ls_result) = NEW zcl_cd_hck_ev_btc_seq( )->zif_cd_hck_evidence~collect(
                        it_payments = lt_payments
                        is_rule     = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_BTC_SEQ' param1 = iv_target )
                        iv_max_rows = 100 ).
    rs_evidence = VALUE #( ls_result-evidence[ doc1r = gc_doc ] OPTIONAL ).
  ENDMETHOD.


  " Rule: every seeded sequence gives its seeded outcome without anomaly
  METHOD every_seeded_sequence.
    TRY.
        DATA(lt_cases) = VALUE tt_case(
          ( flow = gc_c class = gc_ach codes = `166` outcome = `CLEARED` )
          ( flow = gc_c class = gc_ach codes = `143` outcome = `CLEARED` )
          ( flow = gc_c class = gc_ach codes = `468,166` outcome = `CLEARED` )
          ( flow = gc_c class = gc_ach codes = `468,468` lots = 1 outcome = `RETURNED` )
          ( flow = gc_d class = gc_ach codes = `466` outcome = `CLEARED` )
          ( flow = gc_d class = gc_ach codes = `466,168` lots = 1 outcome = `RETURNED` )
          ( flow = gc_d class = gc_ach codes = `466,166` outcome = `RETRIEVED` )
          ( flow = gc_d class = gc_ach codes = `466,468` outcome = `RETRIEVAL_FAILED` )
          ( flow = gc_d class = gc_ach codes = `466,166,168,468` lots = 1 outcome = `RETURNED` )
          ( flow = gc_d class = gc_wire codes = `495` outcome = `CLEARED` )
          ( flow = gc_d class = gc_wire codes = `495,195` lots = 1 outcome = `RETURNED` ) ).
        LOOP AT lt_cases ASSIGNING FIELD-SYMBOL(<ls_case>).
          DATA(ls_evidence) = evaluate( iv_flow   = <ls_case>-flow
                                        iv_class  = <ls_case>-class
                                        iv_codes  = <ls_case>-codes
                                        iv_lots   = <ls_case>-lots
                                        iv_target = <ls_case>-outcome ).
          cl_abap_unit_assert=>assert_true( act = ls_evidence-found
                                            msg = |{ <ls_case>-flow }{ <ls_case>-class } { <ls_case>-codes }: { <ls_case>-outcome }| ).
          cl_abap_unit_assert=>assert_initial( act = ls_evidence-anomaly
                                               msg = |{ <ls_case>-flow }{ <ls_case>-class } { <ls_case>-codes }: consistent| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one collection failure without returns lot within 10 days = redeposit pending (fine)
  METHOD redeposit_inside_max_age.
    TRY.
        DATA(ls_evidence) = evaluate( iv_flow = gc_c iv_class = gc_ach iv_codes = `468`
                                      iv_target = `REDEPOSIT_PENDING` iv_first = '20261105' ).
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = 'Pending' ).
        cl_abap_unit_assert=>assert_initial( act = ls_evidence-anomaly msg = 'Fine within 10 days' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: older than its maximum age = PENDING_OUTCOME_MISSING (redeposit outcome missing)
  METHOD redeposit_outside_max_age.
    TRY.
        DATA(ls_evidence) = evaluate( iv_flow = gc_c iv_class = gc_ach iv_codes = `468`
                                      iv_target = `REDEPOSIT_PENDING` iv_first = '20261025' ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'No longer pending' ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = zif_cd_hck_runtime_types=>gc_code-pending_overdue
                                            msg = 'Redeposit outcome missing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a sequence no active pattern matches is UNEXPECTED_SEQUENCE with codes and dates
  METHOD unexpected_sequence.
    TRY.
        DATA(ls_evidence) = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466,466` iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = zif_cd_hck_runtime_types=>gc_code-unexpected_seq
                                            msg = 'Unexpected' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = `466 2026-11-03` ) >= 0 )
                                          msg = 'Codes and dates listed' ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'Not cleared' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: returns lot items other than EXPECTED_DFKKRP = RETURN_INCONSISTENT (missing lot, extra lot)
  METHOD lot_count_mismatch.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466,168` iv_target = `RETURNED` )-anomaly
          exp = zif_cd_hck_runtime_types=>gc_code-return_inconsist
          msg = 'Return line without returns lot' ).
        cl_abap_unit_assert=>assert_equals(
          act = evaluate( iv_flow = gc_c iv_class = gc_ach iv_codes = `468,468` iv_lots = 2 iv_target = `RETURNED` )-anomaly
          exp = zif_cd_hck_runtime_types=>gc_code-return_inconsist
          msg = 'Two lot items, one expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a returns lot without any line of a role = RETURN_INCONSISTENT
  METHOD lot_without_return_line.
    TRY.
        DATA(ls_evidence) = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `999` iv_lots = 1 iv_target = `RETURNED` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                            msg = 'Lot without return line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the amount of the last compared line (the return) must equal the returns lot
  METHOD amount_mismatch.
    TRY.
        DATA(ls_evidence) = evaluate( iv_flow = gc_d iv_class = gc_wire iv_codes = `495,195` iv_lots = 1
                                      iv_lot_amount = '200.00' iv_target = `RETURNED` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                            msg = 'Amount differs' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the roles are ordered by statement date, statement and line - not by read order
  METHOD ordered_by_date_and_line.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    TRY.
        ls_line-chect = gc_ref.
        ls_line-kukey = '00000102'.
        ls_line-esnum = 1.
        ls_line-vorgc = '168'.
        ls_line-budat = '20261105'.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        ls_line-kukey = '00000101'.
        ls_line-esnum = 7.
        ls_line-vorgc = '466'.
        ls_line-budat = '20261103'.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        INSERT VALUE #( selw1 = gc_doc ) INTO TABLE mo_trace->mt_returns.
        DATA(ls_evidence) = collect( iv_flow = gc_d iv_class = gc_ach iv_target = `RETURNED` ).
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = 'ORIGINAL,RETURNED in date order' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: 468 is a collection failure for collections and a retrieval failure for disbursement ACH
  METHOD code_468_differs_by_flow.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = evaluate( iv_flow = gc_c iv_class = gc_ach iv_codes = `468` iv_target = `REDEPOSIT_PENDING`
                          iv_first = '20261109' )-found
          msg = 'Collections: failure, redeposit pending' ).
        cl_abap_unit_assert=>assert_initial(
          act = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `468` iv_target = `RETRIEVAL_FAILED` )-found
          msg = 'Disbursements: 468 alone is no seeded sequence' ).
        cl_abap_unit_assert=>assert_true(
          act = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466,468` iv_target = `RETRIEVAL_FAILED` )-found
          msg = 'Disbursements: retrieval failed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a CAMT line has its ISO code (external transaction) as role key with scheme ISO
  METHOD iso_code_of_camt_line.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    TRY.
        ls_line-chect = gc_ref.
        ls_line-vgext = 'PMNT-RDDT-ESDD'.
        ls_line-budat = gc_first.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        cl_abap_unit_assert=>assert_true( act = collect( iv_flow = gc_c iv_class = gc_ach iv_target = `CLEARED` )-found
                                          msg = 'ISO code collected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review 1): ORIGINAL then a monetary code without a role of the flow / class
  " = lifecycle INDETERMINATE (never CLEARED) and BTC_ROLE_MISSING naming code, date, amount, class
  METHOD unknown_monetary_indeterminate.
    TRY.
        DATA(ls_evidence) = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466,999` iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'Never CLEARED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly
                                            exp = zif_cd_hck_runtime_types=>gc_code-btc_role_missing
                                            msg = 'Role missing' ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Error' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( find( val = ls_evidence-detail sub = zif_cd_hck_runtime_types=>gc_outcome-indeterminate ) >= 0
                         AND find( val = ls_evidence-detail sub = |{ gc_bai } 999| ) >= 0
                         AND find( val = ls_evidence-detail sub = |{ CONV d( gc_first + 1 ) DATE = ISO }| ) >= 0
                         AND find( val = ls_evidence-detail sub = |{ gc_amount STYLE = SIMPLE }| ) >= 0
                         AND find( val = ls_evidence-detail sub = |{ gc_d }{ gc_ach }| ) >= 0 )
          msg = 'Detail names INDETERMINATE, scheme / code, date, amount, flow / class' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review 1): an unknown code on the approved exclusion list of its scheme
  " (HCK_BTC_INFO_BAI2) is ignored - the lifecycle decides as without the line
  METHOD unknown_excluded_code_ignored.
    TRY.
        mo_params->set( iv_name  = CONV #( |{ zif_cd_hck_runtime_types=>gc_param_prefix-btc_info }{ gc_bai }| )
                        iv_value = `998,999` ).
        DATA(ls_evidence) = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466,999` iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = 'Excluded code ignored: CLEARED' ).
        cl_abap_unit_assert=>assert_initial( act = ls_evidence-anomaly msg = 'No anomaly' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a line without amount (non-monetary) and without role is not part of the lifecycle
  METHOD unknown_zero_amount_ignored.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    TRY.
        evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466` iv_target = `CLEARED` ).
        ls_line-kukey = '00000101'.
        ls_line-esnum = 9.
        ls_line-chect = gc_ref.
        ls_line-vorgc = '999'.
        ls_line-budat = gc_first.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        DATA(ls_evidence) = collect( iv_flow = gc_d iv_class = gc_ach iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = 'Zero-amount line ignored' ).
        cl_abap_unit_assert=>assert_initial( act = ls_evidence-anomaly msg = 'No anomaly' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an invalid PCRE pattern makes the kind unusable (never 'no match')
  METHOD invalid_pattern_raises.
    outcome( iv_flow = gc_d iv_class = gc_wire iv_seq = '090' iv_pattern = '(ORIGINAL' iv_outcome = 'CLEARED' iv_expected = '0' ).
    TRY.
        evaluate( iv_flow = gc_d iv_class = gc_wire iv_codes = `495` iv_target = `CLEARED` ).
        cl_abap_unit_assert=>fail( msg = 'Invalid pattern must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one statement-line read and one returns-lot read per collect
  METHOD one_read_per_kind.
    TRY.
        evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466` iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_line_reads exp = 1 msg = 'One line read' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_lot_reads exp = 1 msg = 'One lot read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_ev_btc_seq_chq DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_doc    TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      "! 20 characters; the statement carries the last 13
      gc_ztnum  TYPE zif_cd_ops_trace_types=>ty_ref VALUE 'JPMC0011234567890123',
      gc_chect  TYPE zif_cd_ops_trace_types=>ty_ref VALUE '1234567890123',
      "! Second cheque of the same account with the same last 13 characters
      gc_twin_doc   TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300009',
      gc_twin_ztnum TYPE zif_cd_ops_trace_types=>ty_ref VALUE 'JPMC0091234567890123',
      gc_bukrs  TYPE zif_cd_ops_trace_types=>ty_bukrs VALUE 'US01',
      gc_hbkid  TYPE c LENGTH 5 VALUE 'JPMC1',
      gc_hktid  TYPE c LENGTH 5 VALUE 'CHK01',
      gc_amount TYPE zif_cd_ops_types=>ty_amount VALUE '250.00',
      gc_d      TYPE zif_cd_hck_runtime_types=>ty_flow VALUE 'D',
      gc_chq    TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'CHQ',
      gc_blank  TYPE zif_cd_hck_runtime_types=>ty_rule_param VALUE 'BLANK',
      gc_clarify TYPE zif_cd_ops_types=>ty_check_code VALUE 'CHEQUE_CLARIFICATION',
      gc_manual TYPE zif_cd_ops_types=>ty_check_code VALUE 'MANUAL_CLEARING_REQUIRED',
      gc_fpchr  TYPE zif_cd_hck_types=>ty_text VALUE 'Correction on the statement - clear manually in FPCHR'.

    DATA mo_dao TYPE REF TO ltd_runtime_dao.
    DATA mo_trace TYPE REF TO ltd_trace_dao.

    METHODS setup.
    METHODS teardown.
    METHODS role
      IMPORTING
        iv_code    TYPE clike
        iv_role    TYPE clike
        iv_compare TYPE c DEFAULT space.
    METHODS outcome
      IMPORTING
        iv_seq       TYPE zif_cd_hck_runtime_types=>ty_rule_seq
        iv_pattern   TYPE clike
        iv_outcome   TYPE clike
        iv_reg_state TYPE clike OPTIONAL
        iv_finding   TYPE clike OPTIONAL
        iv_text      TYPE clike OPTIONAL.
    "! Cheque (DFKKCR-DOC1R = AUGBL) with state, payment amount, lines of the codes (CHECT = last 13 of ZTNUM)
    METHODS evaluate
      IMPORTING
        iv_codes           TYPE clike
        iv_state           TYPE clike DEFAULT space
        iv_payment_amount  TYPE zif_cd_ops_types=>ty_amount DEFAULT gc_amount
        iv_target          TYPE clike
        iv_chect           TYPE zif_cd_ops_trace_types=>ty_ref DEFAULT gc_chect
        "! A second cheque of the same account with the same last 13 characters
        iv_twin            TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_evidence) TYPE zif_cd_hck_runtime_types=>ty_evidence
      RAISING
        zcx_cd_ops_error.

    METHODS cashed_and_returned       FOR TESTING.
    METHODS returned_still_cashed     FOR TESTING.
    METHODS multiple_581_clarification FOR TESTING.
    METHODS multiple_255_clarification FOR TESTING.
    METHODS correction_state_blank    FOR TESTING.
    METHODS correction_state_cashed   FOR TESTING.
    METHODS cheque_amount_mismatch    FOR TESTING.
    METHODS link_by_suffix_13         FOR TESTING.
    METHODS unexpected_cheque_order   FOR TESTING.
    METHODS ambiguous_line_not_evaluated FOR TESTING.
ENDCLASS.


CLASS ltc_ev_btc_seq_chq IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
    " Seed (config/hck_seed.md section 8e / 8f): disbursement cheques
    role( iv_code = '581' iv_role = 'CASHED' iv_compare = zif_cd_hck_runtime_types=>gc_compare-register ).
    role( iv_code = '255' iv_role = 'RETURNED' ).
    role( iv_code = '399' iv_role = 'CORRECTION' ).
    role( iv_code = '699' iv_role = 'CORRECTION' ).
    outcome( iv_seq = '001' iv_pattern = '.*CORRECTION.*' iv_outcome = 'CLEARED_MANUAL' iv_reg_state = 'B' ).
    outcome( iv_seq = '002' iv_pattern = '.*CORRECTION.*' iv_outcome = 'MANUAL_CLEARING'
             iv_finding = gc_manual iv_text = gc_fpchr ).
    outcome( iv_seq = '010' iv_pattern = '.*(CASHED.*CASHED|RETURNED.*RETURNED).*' iv_outcome = 'CLARIFICATION'
             iv_finding = gc_clarify iv_text = 'Several 581 / 255 for one cheque - check the clarification worklist' ).
    outcome( iv_seq = '020' iv_pattern = 'CASHED' iv_outcome = 'CLEARED' ).
    outcome( iv_seq = '030' iv_pattern = '(CASHED,)?RETURNED' iv_outcome = 'RETURNED' iv_reg_state = gc_blank ).
    outcome( iv_seq = '040' iv_pattern = '(CASHED,)?RETURNED' iv_outcome = 'RETURNED_VOIDED' iv_reg_state = 'V' ).
    outcome( iv_seq = '050' iv_pattern = '(CASHED,)?RETURNED' iv_outcome = 'RETURN_NOT_REGISTERED' iv_reg_state = 'B'
             iv_finding = zif_cd_hck_runtime_types=>gc_code-return_inconsist
             iv_text = '255 on the statement but the cheque register still shows cashed' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_trace.
  ENDMETHOD.


  METHOD role.
    DATA ls_role TYPE zif_cd_hck_runtime_types=>ty_btc_role_row.
    ls_role-flow           = gc_d.
    ls_role-method_class   = gc_chq.
    ls_role-scheme         = 'BAI2'.
    ls_role-btc_code       = iv_code.
    ls_role-role           = iv_role.
    ls_role-compare_amount = iv_compare.
    INSERT ls_role INTO TABLE mo_dao->mt_roles.
  ENDMETHOD.


  METHOD outcome.
    DATA ls_outcome TYPE zif_cd_hck_runtime_types=>ty_seq_outcome.
    ls_outcome-flow            = gc_d.
    ls_outcome-method_class    = gc_chq.
    ls_outcome-seq             = iv_seq.
    ls_outcome-seq_pattern     = iv_pattern.
    ls_outcome-outcome         = iv_outcome.
    " Confirmed: no returns lot for a returned cheque (only the register changes)
    ls_outcome-expected_dfkkrp = '0'.
    ls_outcome-reg_state       = iv_reg_state.
    ls_outcome-finding         = iv_finding.
    ls_outcome-description     = iv_text.
    INSERT ls_outcome INTO TABLE mo_dao->mt_outcomes.
  ENDMETHOD.


  METHOD evaluate.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    CLEAR: mo_trace->mt_lines, mo_trace->mt_checks.
    ls_check-doc1r  = gc_doc.
    ls_check-ztnum  = gc_ztnum.
    ls_check-state  = iv_state.
    ls_check-hbkid  = gc_hbkid.
    ls_check-hktid  = gc_hktid.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
    IF iv_twin = abap_true.
      ls_check-doc1r = gc_twin_doc.
      ls_check-ztnum = gc_twin_ztnum.
      INSERT ls_check INTO TABLE mo_trace->mt_checks.
    ENDIF.
    SPLIT iv_codes AT ',' INTO TABLE DATA(lt_codes).
    LOOP AT lt_codes ASSIGNING FIELD-SYMBOL(<lv_code>).
      CLEAR ls_line.
      ls_line-kukey = '00000201'.
      ls_line-esnum = sy-tabix.
      ls_line-chect = iv_chect.
      ls_line-vorgc = <lv_code>.
      ls_line-budat = CONV d( '20261001' ) + sy-tabix.
      ls_line-kwbtr = gc_amount.
      ls_line-bukrs = gc_bukrs.
      ls_line-hbkid = gc_hbkid.
      ls_line-hktid = gc_hktid.
      INSERT ls_line INTO TABLE mo_trace->mt_lines.
    ENDLOOP.
    INSERT VALUE #( doc1r = gc_doc laufd = '20260920' flow = gc_d class = gc_chq amount = - iv_payment_amount
                    bukrs = gc_bukrs )
      INTO TABLE lt_payments.
    IF iv_twin = abap_true.
      INSERT VALUE #( doc1r = gc_twin_doc laufd = '20260920' flow = gc_d class = gc_chq amount = - iv_payment_amount
                      bukrs = gc_bukrs )
        INTO TABLE lt_payments.
    ENDIF.
    DATA(ls_result) = NEW zcl_cd_hck_ev_btc_seq( )->zif_cd_hck_evidence~collect(
                        it_payments = lt_payments
                        is_rule     = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_BTC_SEQ' param1 = iv_target
                                               param2 = zif_cd_hck_runtime_types=>gc_link_cheque param3 = '13' )
                        iv_max_rows = 100 ).
    rs_evidence = VALUE #( ls_result-evidence[ doc1r = gc_doc ] OPTIONAL ).
  ENDMETHOD.


  " Rule: 581 with state B = cleared; 581,255 or 255 with state blank = returned (no DFKKRP, not
  " aged); 255 with state V = voided after the return (consistent)
  METHOD cashed_and_returned.
    TRY.
        DATA(ls_evidence) = evaluate( iv_codes = `581` iv_state = 'B' iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = '581: cleared' ).
        cl_abap_unit_assert=>assert_initial( act = ls_evidence-anomaly msg = '581: consistent' ).
        ls_evidence = evaluate( iv_codes = `581,255` iv_target = `RETURNED` ).
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = '581,255 with blank state: returned' ).
        cl_abap_unit_assert=>assert_initial( act = ls_evidence-anomaly msg = 'No returns lot expected' ).
        cl_abap_unit_assert=>assert_true( act = evaluate( iv_codes = `255` iv_target = `RETURNED` )-found
                                          msg = '255 alone: returned' ).
        cl_abap_unit_assert=>assert_true( act = evaluate( iv_codes = `581,255` iv_state = 'V' iv_target = `RETURNED_VOIDED` )-found
                                          msg = 'Voided after the return' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: 255 while the register still shows B = RETURN_INCONSISTENT (register not updated); a
  " returns lot for a cheque = RETURN_INCONSISTENT (unexpected lot)
  METHOD returned_still_cashed.
    TRY.
        DATA(ls_evidence) = evaluate( iv_codes = `581,255` iv_state = 'B' iv_target = `RETURNED` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                            msg = 'Register still cashed' ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'Not a consistent return' ).
        INSERT VALUE #( selw1 = gc_doc ) INTO TABLE mo_trace->mt_returns.
        ls_evidence = evaluate( iv_codes = `581,255` iv_target = `RETURNED` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                            msg = 'Unexpected returns lot' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: several 581 for one cheque = CHEQUE_CLARIFICATION (configured finding, severity E)
  METHOD multiple_581_clarification.
    TRY.
        DATA(ls_evidence) = evaluate( iv_codes = `581,581` iv_state = 'B' iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = gc_clarify msg = 'Clarification' ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-severity exp = zif_cd_ops_types=>gc_severity-error msg = 'Error' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = `clarification worklist` ) >= 0 )
                                          msg = 'Says where to look' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: several 255 for one cheque = CHEQUE_CLARIFICATION
  METHOD multiple_255_clarification.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = evaluate( iv_codes = `581,255,255` iv_target = `RETURNED` )-anomaly
                                            exp = gc_clarify msg = 'Clarification' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a correction code while the register is not B = MANUAL_CLEARING_REQUIRED naming the cheque
  " number, codes with dates and FPCHR
  METHOD correction_state_blank.
    TRY.
        DATA(ls_evidence) = evaluate( iv_codes = `581,399` iv_target = `CLEARED,CLEARED_MANUAL` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = gc_manual msg = 'Manual clearing required' ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'Not cleared' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = CONV string( gc_ztnum ) ) >= 0 )
                                          msg = 'Cheque number named' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = `399 2026-10-03` ) >= 0 )
                                          msg = 'Codes and dates named' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = `FPCHR` ) >= 0 )
                                          msg = 'FPCHR named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a correction after support cleared the cheque (state B) = CLEARED_MANUAL, no finding
  METHOD correction_state_cashed.
    TRY.
        DATA(ls_evidence) = evaluate( iv_codes = `581,699` iv_state = 'B' iv_target = `CLEARED,CLEARED_MANUAL` ).
        cl_abap_unit_assert=>assert_true( act = ls_evidence-found msg = 'Cleared manually' ).
        cl_abap_unit_assert=>assert_initial( act = ls_evidence-anomaly msg = 'No finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the 581 amount must equal the payment amount (DPAYH of the AUGBL; role compared with R)
  METHOD cheque_amount_mismatch.
    TRY.
        DATA(ls_evidence) = evaluate( iv_codes = `581` iv_state = 'B' iv_payment_amount = '300.00' iv_target = `CLEARED` ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly exp = zif_cd_hck_runtime_types=>gc_code-cheque_amount
                                            msg = 'Amount mismatch' ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'Not cleared' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: cheque lines are linked by FEBEP-CHECT = last 13 characters of ZTNUM, not by the document
  METHOD link_by_suffix_13.
    TRY.
        cl_abap_unit_assert=>assert_true( act = evaluate( iv_codes = `581` iv_state = 'B' iv_target = `CLEARED` )-found
                                          msg = 'Suffix 13 linked' ).
        cl_abap_unit_assert=>assert_initial(
          act = evaluate( iv_codes = `581` iv_state = 'B' iv_target = `CLEARED` iv_chect = '300001' )
          msg = 'The payment document is no cheque link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (design review 3): a 581 that fits two cheques of the same account is attributed to neither;
  " the lifecycle is not evaluated (never CLEARED) and the payment carries CHEQUE_LINK_AMBIGUOUS
  METHOD ambiguous_line_not_evaluated.
    TRY.
        DATA(ls_evidence) = evaluate( iv_codes = `581` iv_state = 'B' iv_target = `CLEARED` iv_twin = abap_true ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'Not cleared' ).
        cl_abap_unit_assert=>assert_equals( act = ls_evidence-anomaly
                                            exp = zif_cd_hck_runtime_types=>gc_code-cheque_ambiguous
                                            msg = 'Ambiguous cheque line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a cheque sequence no row matches (255 before 581) is UNEXPECTED_SEQUENCE
  METHOD unexpected_cheque_order.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = evaluate( iv_codes = `255,581` iv_target = `CLEARED` )-anomaly
                                            exp = zif_cd_hck_runtime_types=>gc_code-unexpected_seq
                                            msg = 'Unexpected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
