*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_btc_seq.clas.testclasses.abap
*& Purpose:
*& Unit tests of the bank code lifecycle evidence with the seeded roles
*& and outcomes: every seeded sequence (collections 166 / 143 / 468 with
*& delayed redeposit, disbursement ACH 466 / 168 / 166 / 468, wire 495 /
*& 195), redeposit pending inside and outside its maximum age, unexpected
*& sequence, returns lot count and amount mismatches, lot without return
*& line, ordering by statement date / line, one code with different
*& meanings per flow, ISO code of a CAMT line, codes without role ignored,
*& invalid pattern, one read per kind. Runtime DAO, payment trace
*& repository and clock are doubles; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user correction of rule 4: BAI lifecycle per payment).
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
    METHODS code_without_role_ignored  FOR TESTING.
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
    CLEAR: mo_dao, mo_trace.
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


  " Rule: a code without a role of the flow / class is ignored (listed nowhere)
  METHOD code_without_role_ignored.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = evaluate( iv_flow = gc_d iv_class = gc_ach iv_codes = `466,999` iv_target = `CLEARED` )-found
          msg = 'Unmapped code ignored' ).
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
