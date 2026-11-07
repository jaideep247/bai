*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_recon_eval.clas.testclasses.abap
*& Purpose:
*& Unit tests of the pure three-way reconciliation rules: balanced day,
*& break, timing of the next day (offsetting) and of a statement not yet
*& loaded, a 468 without returns lot within / after the redeposit days,
*& cut-off, cheque and unmapped-code buckets, tolerance boundary, empty
*& day (never balanced), ignored codes, inverted bank sign, G/L <-> payment
*& engine break and transfer lag, Stripe group balanced / off by the fees /
*& deposit not posted / not on the clearing account, unmatched ACH groups.
*& Structures built field by field; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*&---------------------------------------------------------------------*
CLASS ltc_recon_eval DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        set_id    TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'COLL_US',
        bukrs     TYPE zif_cd_hck_recon_types=>ty_bukrs VALUE 'US01',
        hkont     TYPE zif_cd_hck_recon_types=>ty_hkont VALUE '0011401000',
        waers     TYPE zif_cd_hck_recon_types=>ty_waers VALUE 'USD',
        account   TYPE zif_cd_hck_recon_types=>ty_account VALUE '8XX1174412',
        from      TYPE d VALUE '20261101',
        to        TYPE d VALUE '20261107',
        report    TYPE d VALUE '20261108',
        day1      TYPE d VALUE '20261101',
        day2      TYPE d VALUE '20261102',
        day3      TYPE d VALUE '20261103',
        day5      TYPE d VALUE '20261105',
        day7      TYPE d VALUE '20261107',
        credit    TYPE zif_cd_hck_recon_types=>ty_cdi VALUE 'H',
        debit     TYPE zif_cd_hck_recon_types=>ty_cdi VALUE 'S',
        awtyp     TYPE zif_cd_hck_recon_types=>ty_awtyp VALUE 'FKKSU',
        other_aw  TYPE zif_cd_hck_recon_types=>ty_awtyp VALUE 'BKPF',
        leg       TYPE zif_cd_hck_recon_types=>ty_btc VALUE '166',
        return    TYPE zif_cd_hck_recon_types=>ty_btc VALUE '168',
        redeposit TYPE zif_cd_hck_recon_types=>ty_btc VALUE '468',
        cheque    TYPE zif_cd_hck_recon_types=>ty_btc VALUE '581',
        ignore    TYPE zif_cd_hck_recon_types=>ty_btc VALUE '010',
        unmapped  TYPE zif_cd_hck_recon_types=>ty_btc VALUE '999',
        deposit   TYPE zif_cd_hck_recon_types=>ty_btc VALUE '195',
        descr     TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE 'STRIPE*PAYOUT1105',
        belnr     TYPE zif_cd_hck_recon_types=>ty_belnr VALUE '0100000001',
        gjahr     TYPE zif_cd_hck_recon_types=>ty_gjahr VALUE '2026',
        ach_old   TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE '000000400001',
        ach_new   TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE '000000400002',
      END OF gc_test.

    DATA mo_cut TYPE REF TO zcl_cd_hck_recon_eval.
    DATA ms_input TYPE zif_cd_hck_recon_types=>ty_eval_input.

    METHODS setup.
    METHODS add_role
      IMPORTING
        iv_btc  TYPE zif_cd_hck_recon_types=>ty_btc
        iv_role TYPE zif_cd_hck_recon_types=>ty_role.
    METHODS add_bank
      IMPORTING
        iv_day    TYPE d
        iv_btc    TYPE zif_cd_hck_recon_types=>ty_btc
        iv_cdi    TYPE zif_cd_hck_recon_types=>ty_cdi
        iv_amount TYPE zif_cd_hck_recon_types=>ty_amount
        iv_no_lot TYPE abap_bool DEFAULT abap_false.
    METHODS add_gl
      IMPORTING
        iv_day    TYPE d
        iv_amount TYPE zif_cd_hck_recon_types=>ty_amount
        iv_awtyp  TYPE zif_cd_hck_recon_types=>ty_awtyp DEFAULT gc_test-awtyp.
    METHODS add_fica
      IMPORTING
        iv_day    TYPE d
        iv_amount TYPE zif_cd_hck_recon_types=>ty_amount.
    METHODS day
      IMPORTING
        is_result     TYPE zif_cd_hck_recon_types=>ty_eval_result
        iv_day        TYPE d
      RETURNING
        VALUE(rs_day) TYPE zif_cd_hck_recon_types=>ty_group_day.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_recon_types=>ty_eval_result.

    METHODS balanced_day_is_balanced    FOR TESTING.
    METHODS difference_is_break         FOR TESTING.
    METHODS next_day_statement_timing   FOR TESTING.
    METHODS missing_statement_timing    FOR TESTING.
    METHODS old_missing_statement_break FOR TESTING.
    METHODS redeposit_no_lot_in_days    FOR TESTING.
    METHODS redeposit_after_days_break  FOR TESTING.
    METHODS cutoff_return_is_timing     FOR TESTING.
    METHODS cheque_bucket_is_variance   FOR TESTING.
    METHODS unmapped_code_is_variance   FOR TESTING.
    METHODS tolerance_boundary          FOR TESTING.
    METHODS empty_day_never_balanced    FOR TESTING.
    METHODS ignored_code_not_counted    FOR TESTING.
    METHODS inverted_bank_sign          FOR TESTING.
    METHODS leg_off_is_not_compared     FOR TESTING.
    METHODS subledger_break             FOR TESTING.
    METHODS subledger_transfer_lag      FOR TESTING.
    METHODS stripe_group_balanced       FOR TESTING.
    METHODS stripe_group_off_by_fees    FOR TESTING.
    METHODS stripe_deposit_not_posted   FOR TESTING.
    METHODS stripe_deposit_not_cleared  FOR TESTING.
    METHODS ach_unmatched_old_and_new   FOR TESTING.
ENDCLASS.


CLASS ltc_recon_eval IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    CLEAR ms_input.
    ms_input-set-set_id   = gc_test-set_id.
    ms_input-set-kind     = zif_cd_hck_recon_types=>gc_kind-threeway.
    ms_input-set-bukrs    = gc_test-bukrs.
    ms_input-set-hkont    = gc_test-hkont.
    ms_input-set-waers    = gc_test-waers.
    ms_input-set-leg_bank = abap_true.
    ms_input-set-leg_fica = abap_true.
    ms_input-from           = gc_test-from.
    ms_input-to             = gc_test-to.
    ms_input-report_date    = gc_test-report.
    ms_input-timing_days    = 3.
    ms_input-redeposit_days = 10.
    ms_input-credit_ind     = gc_test-credit.
    ms_input-debit_ind      = gc_test-debit.
    ms_input-fica_awtyp     = gc_test-awtyp.
    ms_input-last_bank_day  = gc_test-to.
    add_role( iv_btc = gc_test-leg       iv_role = zif_cd_hck_recon_types=>gc_role-leg ).
    add_role( iv_btc = gc_test-return    iv_role = zif_cd_hck_recon_types=>gc_role-cutoff ).
    add_role( iv_btc = gc_test-redeposit iv_role = zif_cd_hck_recon_types=>gc_role-redeposit ).
    add_role( iv_btc = gc_test-cheque    iv_role = zif_cd_hck_recon_types=>gc_role-cheque ).
    add_role( iv_btc = gc_test-ignore    iv_role = zif_cd_hck_recon_types=>gc_role-ignore ).
    add_role( iv_btc = gc_test-deposit   iv_role = zif_cd_hck_recon_types=>gc_role-deposit ).
  ENDMETHOD.


  METHOD add_role.
    DATA ls_role TYPE zif_cd_hck_recon_types=>ty_btc_role.
    ls_role-set_id = gc_test-set_id.
    ls_role-btc    = iv_btc.
    ls_role-role   = iv_role.
    INSERT ls_role INTO TABLE ms_input-roles.
  ENDMETHOD.


  METHOD add_bank.
    DATA ls_bank TYPE zif_cd_hck_recon_types=>ty_bank_day.
    ls_bank-account    = gc_test-account.
    ls_bank-currency   = gc_test-waers.
    ls_bank-day        = iv_day.
    ls_bank-btc        = iv_btc.
    ls_bank-cdi        = iv_cdi.
    ls_bank-amount     = iv_amount.
    ls_bank-line_count = 1.
    INSERT ls_bank INTO TABLE ms_input-bank_days.
    IF iv_no_lot = abap_true.
      INSERT ls_bank INTO TABLE ms_input-bank_no_lot.
    ENDIF.
  ENDMETHOD.


  METHOD add_gl.
    DATA ls_gl TYPE zif_cd_hck_recon_types=>ty_gl_day.
    ls_gl-bukrs      = gc_test-bukrs.
    ls_gl-hkont      = gc_test-hkont.
    ls_gl-currency   = gc_test-waers.
    ls_gl-day        = iv_day.
    ls_gl-awtyp      = iv_awtyp.
    ls_gl-amount     = iv_amount.
    ls_gl-line_count = 1.
    INSERT ls_gl INTO TABLE ms_input-gl_days.
  ENDMETHOD.


  METHOD add_fica.
    DATA ls_fica TYPE zif_cd_hck_recon_types=>ty_fica_day.
    ls_fica-bukrs      = gc_test-bukrs.
    ls_fica-hkont      = gc_test-hkont.
    ls_fica-currency   = gc_test-waers.
    ls_fica-day        = iv_day.
    ls_fica-amount     = iv_amount.
    ls_fica-line_count = 1.
    INSERT ls_fica INTO TABLE ms_input-fica_days.
  ENDMETHOD.


  METHOD day.
    rs_day = VALUE #( is_result-days[ day = iv_day ] OPTIONAL ).
  ENDMETHOD.


  METHOD act.
    rs_result = mo_cut->evaluate( ms_input ).
  ENDMETHOD.


  " Rule: bank = G/L transfer = control total on a day is balanced on both legs
  METHOD balanced_day_is_balanced.
    TRY.
        add_bank( iv_day = gc_test-day5 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ).
        add_gl( iv_day = gc_test-day5 iv_amount = 100 ).
        add_fica( iv_day = gc_test-day5 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day5 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-balanced
                                            msg = 'Bank = G/L' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-sub_status exp = zif_cd_hck_recon_types=>gc_status-balanced
                                            msg = 'G/L = control total' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-diff_bank_gl exp = 0 msg = 'No difference' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a difference that no timing or bucket explains is a break with the residual
  METHOD difference_is_break.
    TRY.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 60 ).
        add_fica( iv_day = gc_test-day1 iv_amount = 60 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-break
                                            msg = 'Unexplained difference is a break' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-residual exp = 40 msg = 'Residual 40' ).
        cl_abap_unit_assert=>assert_initial( act = ls_day-buckets msg = 'No bucket' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the bank line of the next day that offsets the G/L day within the timing days is timing
  METHOD next_day_statement_timing.
    TRY.
        add_gl( iv_day = gc_test-day2 iv_amount = 100 ).
        add_bank( iv_day = gc_test-day3 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = day( is_result = ls_result iv_day = gc_test-day2 )-status
                                            exp = zif_cd_hck_recon_types=>gc_status-timing msg = 'G/L day is timing' ).
        cl_abap_unit_assert=>assert_equals( act = day( is_result = ls_result iv_day = gc_test-day3 )-status
                                            exp = zif_cd_hck_recon_types=>gc_status-timing msg = 'Bank day is timing' ).
        cl_abap_unit_assert=>assert_equals( act = day( is_result = ls_result iv_day = gc_test-day2 )-buckets[ 1 ]
                                            exp = zif_cd_hck_recon_types=>gc_bucket-timing msg = 'Bucket TIMING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a day after the last loaded statement, younger than the timing days, is timing
  METHOD missing_statement_timing.
    TRY.
        ms_input-last_bank_day = gc_test-day5.
        add_gl( iv_day = gc_test-day7 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day7 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-timing
                                            msg = 'Statement not yet loaded' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-residual exp = -100 msg = 'Open amount kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a missing statement older than the timing days is no longer timing
  METHOD old_missing_statement_break.
    TRY.
        CLEAR ms_input-last_bank_day.
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-break
                                            msg = 'Seven days without statement is a break' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a 468 without returns lot within the redeposit days explains the difference (listed, not red)
  METHOD redeposit_no_lot_in_days.
    TRY.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ).
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-redeposit iv_cdi = gc_test-debit iv_amount = 30
                  iv_no_lot = abap_true ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-diff_bank_gl exp = -30 msg = 'Bank 70 vs G/L 100' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-timing
                                            msg = 'Pending redeposit is timing' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-buckets[ 1 ] exp = zif_cd_hck_recon_types=>gc_bucket-redeposit
                                            msg = 'Bucket REDEPOSIT' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-residual exp = 0 msg = 'Fully explained' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: after the redeposit days the 468 without lot is no longer explained
  METHOD redeposit_after_days_break.
    TRY.
        ms_input-redeposit_days = 2.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ).
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-redeposit iv_cdi = gc_test-debit iv_amount = 30
                  iv_no_lot = abap_true ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-break
                                            msg = 'Redeposit overdue' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-residual exp = -30 msg = 'Residual = the 468' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a return processed in the next period (cut-off) is listed as timing, not red
  METHOD cutoff_return_is_timing.
    TRY.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-return iv_cdi = gc_test-debit iv_amount = 20 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-timing
                                            msg = 'Cut-off is timing' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-buckets[ 1 ] exp = zif_cd_hck_recon_types=>gc_bucket-cutoff
                                            msg = 'Bucket CUTOFF' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a cheque exception explains the difference as a variance (warning)
  METHOD cheque_bucket_is_variance.
    TRY.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-cheque iv_cdi = gc_test-debit iv_amount = 250 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-variance
                                            msg = 'Cheque exception is a variance' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-buckets[ 1 ] exp = zif_cd_hck_recon_types=>gc_bucket-cheque
                                            msg = 'Bucket CHEQUE' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a code without role in the set is a new / unmapped code: variance and listed with its amount
  METHOD unmapped_code_is_variance.
    TRY.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ).
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-unmapped iv_cdi = gc_test-credit iv_amount = 30 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        DATA(ls_result) = act( ).
        DATA(ls_day) = day( is_result = ls_result iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-variance
                                            msg = 'Unmapped code is a variance' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-buckets[ 1 ] exp = zif_cd_hck_recon_types=>gc_bucket-unmapped
                                            msg = 'Bucket UNMAPPED' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-unmapped ) exp = 1 msg = 'One unmapped code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-unmapped[ 1 ]-btc exp = gc_test-unmapped msg = 'Code 999' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-unmapped[ 1 ]-amount exp = 30 msg = 'Its amount' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a difference equal to the tolerance is balanced, one cent more is a break
  METHOD tolerance_boundary.
    TRY.
        ms_input-tolerance = 1.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = '101.00' ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        add_bank( iv_day = gc_test-day5 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = '101.01' ).
        add_gl( iv_day = gc_test-day5 iv_amount = 100 ).
        ms_input-timing_days = 0.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = day( is_result = ls_result iv_day = gc_test-day1 )-status
                                            exp = zif_cd_hck_recon_types=>gc_status-balanced msg = 'At the tolerance' ).
        cl_abap_unit_assert=>assert_equals( act = day( is_result = ls_result iv_day = gc_test-day5 )-status
                                            exp = zif_cd_hck_recon_types=>gc_status-break msg = 'Above the tolerance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a day without any evidence is EMPTY (grey) - never balanced
  METHOD empty_day_never_balanced.
    TRY.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-days ) exp = 7 msg = 'Every day of the window' ).
        LOOP AT ls_result-days ASSIGNING FIELD-SYMBOL(<ls_day>).
          cl_abap_unit_assert=>assert_equals( act = <ls_day>-status exp = zif_cd_hck_recon_types=>gc_status-empty
                                              msg = 'Empty, not balanced' ).
          cl_abap_unit_assert=>assert_equals( act = <ls_day>-sub_status exp = zif_cd_hck_recon_types=>gc_status-empty
                                              msg = 'Subledger empty too' ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an IGNORE code is no money of the set (not in the leg, no evidence)
  METHOD ignored_code_not_counted.
    TRY.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-ignore iv_cdi = gc_test-credit iv_amount = 1000 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-bank exp = 0 msg = 'Not in the bank leg' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-empty
                                            msg = 'No evidence of the set' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the leg mapping inverts the bank sign (bank debit = G/L debit of the clearing account)
  METHOD inverted_bank_sign.
    TRY.
        ms_input-set-invert_bank = abap_true.
        add_bank( iv_day = gc_test-day5 iv_btc = gc_test-leg iv_cdi = gc_test-debit iv_amount = 100 ).
        add_gl( iv_day = gc_test-day5 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day5 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-bank exp = 100 msg = 'Debit inverted to +100' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-balanced
                                            msg = 'Balanced with the leg mapping' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a leg switched off in the set is not compared (status NONE, never a break)
  METHOD leg_off_is_not_compared.
    TRY.
        ms_input-set-leg_bank = abap_false.
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        add_fica( iv_day = gc_test-day1 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-none
                                            msg = 'Bank leg not compared' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-sub_status exp = zif_cd_hck_recon_types=>gc_status-balanced
                                            msg = 'Subledger compared' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: G/L transfer <> control total after the timing days is a subledger break
  METHOD subledger_break.
    TRY.
        add_bank( iv_day = gc_test-day1 iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 5 iv_awtyp = gc_test-other_aw ).
        add_fica( iv_day = gc_test-day1 iv_amount = 80 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-status exp = zif_cd_hck_recon_types=>gc_status-balanced
                                            msg = 'Bank = G/L transfer' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-sub_status exp = zif_cd_hck_recon_types=>gc_status-break
                                            msg = 'G/L <> control total' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-diff_gl_fica exp = 20 msg = 'Difference 20' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-gl_other exp = 5 msg = 'Other postings apart' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a control total not yet transferred within the timing days is timing (transfer lag)
  METHOD subledger_transfer_lag.
    TRY.
        add_fica( iv_day = gc_test-day7 iv_amount = 100 ).
        DATA(ls_day) = day( is_result = act( ) iv_day = gc_test-day7 ).
        cl_abap_unit_assert=>assert_equals( act = ls_day-sub_status exp = zif_cd_hck_recon_types=>gc_status-timing
                                            msg = 'Transfer of yesterday not yet run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: charges + fees of the descriptor group = the BAI 195 deposit (deposit lines left out)
  METHOD stripe_group_balanced.
    DATA lt_deposits TYPE zif_cd_hck_recon_types=>tt_deposit.
    DATA ls_deposit TYPE zif_cd_hck_recon_types=>ty_deposit.
    DATA lt_assign TYPE zif_cd_hck_recon_types=>tt_doc_assign.
    DATA ls_assign TYPE zif_cd_hck_recon_types=>ty_doc_assign.
    DATA lt_sums TYPE zif_cd_hck_recon_types=>tt_assign_sum.
    DATA ls_sum TYPE zif_cd_hck_recon_types=>ty_assign_sum.
    TRY.
        ls_deposit-currency = gc_test-waers.
        ls_deposit-bukrs    = gc_test-bukrs.
        ls_deposit-belnr    = gc_test-belnr.
        ls_deposit-gjahr    = gc_test-gjahr.
        ls_deposit-day      = gc_test-day5.
        ls_deposit-cdi      = gc_test-credit.
        ls_deposit-amount   = 970.
        INSERT ls_deposit INTO TABLE lt_deposits.
        ls_assign-bukrs  = gc_test-bukrs.
        ls_assign-belnr  = gc_test-belnr.
        ls_assign-gjahr  = gc_test-gjahr.
        ls_assign-zuonr  = gc_test-descr.
        ls_assign-cdi    = gc_test-credit.
        ls_assign-amount = -970.
        INSERT ls_assign INTO TABLE lt_assign.
        ls_sum-zuonr  = gc_test-descr.
        ls_sum-cdi    = gc_test-debit.
        ls_sum-amount = 1000.
        INSERT ls_sum INTO TABLE lt_sums.
        ls_sum-cdi    = gc_test-credit.
        ls_sum-amount = -1000.
        INSERT ls_sum INTO TABLE lt_sums.
        DATA(lt_groups) = mo_cut->evaluate_stripe( is_input      = ms_input
                                                   it_deposits   = lt_deposits
                                                   it_doc_assign = lt_assign
                                                   it_group_sums = lt_sums ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_groups ) exp = 1 msg = 'One descriptor group' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-charges exp = 1000 msg = 'Charges' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-fees exp = -30 msg = 'Fees' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-deposit exp = 970 msg = 'Deposit' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-status exp = zif_cd_hck_recon_types=>gc_status-balanced
                                            msg = 'Group = deposit + fees' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: fees not posted in the group leave it off by the fees - STRIPE_GROUP_BREAK
  METHOD stripe_group_off_by_fees.
    DATA lt_deposits TYPE zif_cd_hck_recon_types=>tt_deposit.
    DATA ls_deposit TYPE zif_cd_hck_recon_types=>ty_deposit.
    DATA lt_assign TYPE zif_cd_hck_recon_types=>tt_doc_assign.
    DATA ls_assign TYPE zif_cd_hck_recon_types=>ty_doc_assign.
    DATA lt_sums TYPE zif_cd_hck_recon_types=>tt_assign_sum.
    DATA ls_sum TYPE zif_cd_hck_recon_types=>ty_assign_sum.
    TRY.
        ls_deposit-currency = gc_test-waers.
        ls_deposit-bukrs    = gc_test-bukrs.
        ls_deposit-belnr    = gc_test-belnr.
        ls_deposit-gjahr    = gc_test-gjahr.
        ls_deposit-day      = gc_test-day5.
        ls_deposit-cdi      = gc_test-credit.
        ls_deposit-amount   = 970.
        INSERT ls_deposit INTO TABLE lt_deposits.
        ls_assign-bukrs  = gc_test-bukrs.
        ls_assign-belnr  = gc_test-belnr.
        ls_assign-gjahr  = gc_test-gjahr.
        ls_assign-zuonr  = gc_test-descr.
        ls_assign-cdi    = gc_test-credit.
        ls_assign-amount = -970.
        INSERT ls_assign INTO TABLE lt_assign.
        ls_sum-zuonr  = gc_test-descr.
        ls_sum-cdi    = gc_test-debit.
        ls_sum-amount = 1000.
        INSERT ls_sum INTO TABLE lt_sums.
        ls_sum-cdi    = gc_test-credit.
        ls_sum-amount = -970.
        INSERT ls_sum INTO TABLE lt_sums.
        DATA(lt_groups) = mo_cut->evaluate_stripe( is_input      = ms_input
                                                   it_deposits   = lt_deposits
                                                   it_doc_assign = lt_assign
                                                   it_group_sums = lt_sums ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-fees exp = 0 msg = 'No fee line' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-difference exp = 30 msg = 'Off by the fees' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-status exp = zif_cd_hck_recon_types=>gc_status-break
                                            msg = 'Stripe group break' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a deposit not yet posted is timing while young, a break after the timing days
  METHOD stripe_deposit_not_posted.
    DATA lt_deposits TYPE zif_cd_hck_recon_types=>tt_deposit.
    DATA ls_deposit TYPE zif_cd_hck_recon_types=>ty_deposit.
    TRY.
        ls_deposit-currency = gc_test-waers.
        ls_deposit-cdi      = gc_test-credit.
        ls_deposit-amount   = 970.
        ls_deposit-day      = gc_test-day7.
        INSERT ls_deposit INTO TABLE lt_deposits.
        ls_deposit-day      = gc_test-day1.
        INSERT ls_deposit INTO TABLE lt_deposits.
        DATA(lt_groups) = mo_cut->evaluate_stripe( is_input      = ms_input
                                                   it_deposits   = lt_deposits
                                                   it_doc_assign = VALUE #( )
                                                   it_group_sums = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ day = gc_test-day7 ]-status
                                            exp = zif_cd_hck_recon_types=>gc_status-timing msg = 'Yesterday: timing' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ day = gc_test-day1 ]-status
                                            exp = zif_cd_hck_recon_types=>gc_status-break msg = 'A week: break' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a posted deposit without a clearing-account line can never be cleared by F.13 - break
  METHOD stripe_deposit_not_cleared.
    DATA lt_deposits TYPE zif_cd_hck_recon_types=>tt_deposit.
    DATA ls_deposit TYPE zif_cd_hck_recon_types=>ty_deposit.
    TRY.
        ls_deposit-currency = gc_test-waers.
        ls_deposit-bukrs    = gc_test-bukrs.
        ls_deposit-belnr    = gc_test-belnr.
        ls_deposit-gjahr    = gc_test-gjahr.
        ls_deposit-cdi      = gc_test-credit.
        ls_deposit-amount   = 970.
        ls_deposit-day      = gc_test-day7.
        INSERT ls_deposit INTO TABLE lt_deposits.
        DATA(lt_groups) = mo_cut->evaluate_stripe( is_input      = ms_input
                                                   it_deposits   = lt_deposits
                                                   it_doc_assign = VALUE #( )
                                                   it_group_sums = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-belnr exp = gc_test-belnr msg = 'Names the document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-status exp = zif_cd_hck_recon_types=>gc_status-break
                                            msg = 'Not on the clearing account' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unmatched ACH assignment group is timing within the timing days, a break after;
  " a group that started before the window is not judged here
  METHOD ach_unmatched_old_and_new.
    DATA lt_open TYPE zif_cd_hck_recon_types=>tt_open_assign.
    DATA ls_open TYPE zif_cd_hck_recon_types=>ty_open_assign.
    TRY.
        ls_open-zuonr      = gc_test-ach_old.
        ls_open-first_day  = gc_test-day1.
        ls_open-amount     = 50.
        ls_open-line_count = 1.
        INSERT ls_open INTO TABLE lt_open.
        ls_open-zuonr      = gc_test-ach_new.
        ls_open-first_day  = gc_test-day7.
        INSERT ls_open INTO TABLE lt_open.
        ls_open-first_day  = '20261020'.
        INSERT ls_open INTO TABLE lt_open.
        DATA(lt_days) = mo_cut->evaluate_ach( is_input = ms_input it_open = lt_open ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 2 msg = 'Two days in the window' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ day = gc_test-day1 ]-status
                                            exp = zif_cd_hck_recon_types=>gc_status-break msg = 'Old group: break' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ day = gc_test-day1 ]-first_zuonr
                                            exp = gc_test-ach_old msg = 'First assignment named' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ day = gc_test-day7 ]-status
                                            exp = zif_cd_hck_recon_types=>gc_status-timing msg = 'New group: timing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
