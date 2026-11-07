*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_recon3.clas.testclasses.abap
*& Purpose:
*& Unit tests of the three-way reconciliation check through execute( ):
*& balanced day, break, timing of the next day, 468 within the redeposit
*& days without lot, Stripe group balanced and off by the fees, unmapped
*& bank code, multi-currency and two company codes kept apart, tolerance
*& boundary (parameter and set), empty window (evidence NONE, never green),
*& set without payment engine account, window from the report date,
*& unmatched ACH group, G/L <> control total. The reconciliation DAO, the EBS account
*& configuration and the parameters (ZCL_CD_OPS_PARAM_SEED) are injected;
*& no database read; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*&---------------------------------------------------------------------*
CLASS ltd_recon_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_recon_dao.
    DATA mt_sets TYPE zif_cd_hck_recon_types=>tt_set.
    DATA mt_roles TYPE zif_cd_hck_recon_types=>tt_btc_role.
    DATA mt_bank TYPE zif_cd_hck_recon_types=>tt_bank_day.
    DATA mt_last TYPE zif_cd_hck_recon_types=>tt_bank_last.
    DATA mt_no_lot TYPE zif_cd_hck_recon_types=>tt_bank_day.
    DATA mt_gl TYPE zif_cd_hck_recon_types=>tt_gl_day.
    DATA mt_fica TYPE zif_cd_hck_recon_types=>tt_fica_day.
    DATA mt_deposits TYPE zif_cd_hck_recon_types=>tt_deposit.
    DATA mt_assign TYPE zif_cd_hck_recon_types=>tt_doc_assign.
    DATA mt_sums TYPE zif_cd_hck_recon_types=>tt_assign_sum.
    DATA mt_open TYPE zif_cd_hck_recon_types=>tt_open_assign.
    DATA mv_from TYPE d.
    DATA mv_to TYPE d.
    DATA mt_accounts_read TYPE zif_cd_hck_recon_types=>tt_account.
ENDCLASS.

CLASS ltd_recon_dao IMPLEMENTATION.
  METHOD zif_cd_hck_recon_dao~get_sets.
    rt_sets = mt_sets.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_btc_roles.
    rt_roles = mt_roles.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_bank_days.
    mv_from = iv_from.
    mv_to   = iv_to.
    mt_accounts_read = it_accounts.
    rt_days = mt_bank.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_bank_last_days.
    rt_last = mt_last.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_bank_days_no_lot.
    rt_days = mt_no_lot.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_gl_days.
    rt_days = mt_gl.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_fica_days.
    rt_days = mt_fica.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_payment_days.
    CLEAR rt_days.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_deposits.
    rt_deposits = mt_deposits.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_doc_assignments.
    rt_assigns = mt_assign.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_assignment_sums.
    rt_sums = mt_sums.
  ENDMETHOD.

  METHOD zif_cd_hck_recon_dao~get_open_assignments.
    LOOP AT mt_open INTO DATA(ls_open) TO iv_max_rows.
      INSERT ls_open INTO TABLE rt_open.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_ebs_cfg DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao PARTIALLY IMPLEMENTED.
    DATA mt_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.
ENDCLASS.

CLASS ltd_ebs_cfg IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_accounts.
    rt_accounts = mt_accounts.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_recon3 DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        check_id TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_RECON_3WAY',
        set_us   TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'COLL_US',
        set_cad  TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'COLL_CA',
        set_us2  TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'COLL_US2',
        set_strp TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'STRIPE_US',
        bukrs    TYPE zif_cd_hck_recon_types=>ty_bukrs VALUE 'US01',
        bukrs2   TYPE zif_cd_hck_recon_types=>ty_bukrs VALUE 'US02',
        hkont    TYPE zif_cd_hck_recon_types=>ty_hkont VALUE '11401000',
        hkont_in TYPE zif_cd_hck_recon_types=>ty_hkont VALUE '0011401000',
        stripe   TYPE zif_cd_hck_recon_types=>ty_hkont VALUE '0011405000',
        usd      TYPE zif_cd_hck_recon_types=>ty_waers VALUE 'USD',
        cad      TYPE zif_cd_hck_recon_types=>ty_waers VALUE 'CAD',
        hbkid    TYPE zif_cd_hck_recon_types=>ty_hbkid VALUE 'JPMC1',
        hktid    TYPE zif_cd_hck_recon_types=>ty_hktid VALUE 'COLL1',
        hktid_st TYPE zif_cd_hck_recon_types=>ty_hktid VALUE '16650',
        account  TYPE zif_cd_hck_recon_types=>ty_account VALUE '8XX1174412',
        acct_us2 TYPE zif_cd_hck_recon_types=>ty_account VALUE '8XX2000002',
        acct_st  TYPE zif_cd_hck_recon_types=>ty_account VALUE '8XX0016650',
        report   TYPE d VALUE '20261108',
        from     TYPE d VALUE '20261101',
        to       TYPE d VALUE '20261107',
        day1     TYPE d VALUE '20261101',
        day2     TYPE d VALUE '20261102',
        day3     TYPE d VALUE '20261103',
        day5     TYPE d VALUE '20261105',
        leg      TYPE zif_cd_hck_recon_types=>ty_btc VALUE '166',
        redep    TYPE zif_cd_hck_recon_types=>ty_btc VALUE '468',
        unmapped TYPE zif_cd_hck_recon_types=>ty_btc VALUE '999',
        deposit  TYPE zif_cd_hck_recon_types=>ty_btc VALUE '195',
        credit   TYPE zif_cd_hck_recon_types=>ty_cdi VALUE 'H',
        debit    TYPE zif_cd_hck_recon_types=>ty_cdi VALUE 'S',
        awtyp    TYPE zif_cd_hck_recon_types=>ty_awtyp VALUE 'FKKSU',
        belnr    TYPE zif_cd_hck_recon_types=>ty_belnr VALUE '0100000001',
        gjahr    TYPE zif_cd_hck_recon_types=>ty_gjahr VALUE '2026',
        descr    TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE 'STRIPE*PAYOUT1105',
        tol_one  TYPE string VALUE `1.00`,
        ach_zuonr TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE '000000400001',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        "! Second set: CAD on the same account (multi-currency) / US02 (two company codes)
        cad_set      TYPE abap_bool,
        us2_set      TYPE abap_bool,
        stripe_set   TYPE abap_bool,
        "! The set's house bank account has no ZCD_EBS_ACCT row
        no_account   TYPE abap_bool,
        set_tol      TYPE zif_cd_hck_recon_types=>ty_amount,
        ach_kind     TYPE abap_bool,
        "! G/L leg also compared with the payment engine control total (leg mapping)
        with_fica    TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_recon_dao.
    DATA mo_ebs TYPE REF TO ltd_ebs_cfg.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS add_set
      IMPORTING
        iv_set_id TYPE zif_cd_hck_recon_types=>ty_set_id
        iv_bukrs  TYPE zif_cd_hck_recon_types=>ty_bukrs
        iv_hkont  TYPE zif_cd_hck_recon_types=>ty_hkont DEFAULT gc_test-hkont
        iv_waers  TYPE zif_cd_hck_recon_types=>ty_waers
        iv_hktid  TYPE zif_cd_hck_recon_types=>ty_hktid DEFAULT gc_test-hktid
        iv_kind   TYPE zif_cd_hck_recon_types=>ty_kind DEFAULT zif_cd_hck_recon_types=>gc_kind-threeway
        iv_tol    TYPE zif_cd_hck_recon_types=>ty_amount DEFAULT 0
        iv_fica   TYPE abap_bool DEFAULT abap_false
        iv_acct   TYPE zif_cd_hck_recon_types=>ty_account.
    METHODS add_role
      IMPORTING
        iv_set_id TYPE zif_cd_hck_recon_types=>ty_set_id
        iv_btc    TYPE zif_cd_hck_recon_types=>ty_btc
        iv_role   TYPE zif_cd_hck_recon_types=>ty_role.
    METHODS add_bank
      IMPORTING
        iv_day     TYPE d
        iv_amount  TYPE zif_cd_hck_recon_types=>ty_amount
        iv_btc     TYPE zif_cd_hck_recon_types=>ty_btc DEFAULT gc_test-leg
        iv_cdi     TYPE zif_cd_hck_recon_types=>ty_cdi DEFAULT gc_test-credit
        iv_waers   TYPE zif_cd_hck_recon_types=>ty_waers DEFAULT gc_test-usd
        iv_account TYPE zif_cd_hck_recon_types=>ty_account DEFAULT gc_test-account
        iv_no_lot  TYPE abap_bool DEFAULT abap_false.
    METHODS add_gl
      IMPORTING
        iv_day    TYPE d
        iv_amount TYPE zif_cd_hck_recon_types=>ty_amount
        iv_bukrs  TYPE zif_cd_hck_recon_types=>ty_bukrs DEFAULT gc_test-bukrs
        iv_waers  TYPE zif_cd_hck_recon_types=>ty_waers DEFAULT gc_test-usd.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
    METHODS findings_of
      IMPORTING
        is_result       TYPE zif_cd_hck_types=>ty_check_result
        iv_code         TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rt_found) TYPE zif_cd_ops_types=>tt_finding.
    METHODS worst
      IMPORTING
        is_result     TYPE zif_cd_hck_types=>ty_check_result
      RETURNING
        VALUE(rv_sev) TYPE zif_cd_ops_types=>ty_severity.

    METHODS balanced_day_no_finding    FOR TESTING.
    METHODS break_is_error_with_amount FOR TESTING.
    METHODS timing_next_day_is_info    FOR TESTING.
    METHODS redeposit_468_is_info      FOR TESTING.
    METHODS stripe_balanced_no_break   FOR TESTING.
    METHODS stripe_off_by_fees_breaks  FOR TESTING.
    METHODS unmapped_btc_is_warning    FOR TESTING.
    METHODS currencies_kept_apart      FOR TESTING.
    METHODS company_codes_kept_apart   FOR TESTING.
    METHODS tolerance_param_and_set    FOR TESTING.
    METHODS empty_window_is_no_evidence FOR TESTING.
    METHODS set_without_account_config FOR TESTING.
    METHODS window_ends_before_report  FOR TESTING.
    METHODS ach_unmatched_group_breaks FOR TESTING.
    METHODS subledger_break_is_error   FOR TESTING.
ENDCLASS.


CLASS ltc_recon3 IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_ebs = NEW #( ).
    mo_params = NEW #( ).
    zcl_cd_hck_injector=>inject_recon_dao( mo_dao ).
    zcl_cd_ebs_injector=>inject_cfg_dao( mo_ebs ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_ebs, mo_params.
  ENDMETHOD.


  METHOD configure_scenario.
    add_set( iv_set_id = gc_test-set_us
             iv_bukrs  = gc_test-bukrs
             iv_waers  = gc_test-usd
             iv_tol    = is_flags-set_tol
             iv_fica   = is_flags-with_fica
             iv_kind   = COND #( WHEN is_flags-ach_kind = abap_true THEN zif_cd_hck_recon_types=>gc_kind-ach_zuonr
                                 ELSE zif_cd_hck_recon_types=>gc_kind-threeway )
             iv_acct   = COND #( WHEN is_flags-no_account = abap_false THEN gc_test-account ) ).
    add_role( iv_set_id = gc_test-set_us iv_btc = gc_test-leg iv_role = zif_cd_hck_recon_types=>gc_role-leg ).
    add_role( iv_set_id = gc_test-set_us iv_btc = gc_test-redep iv_role = zif_cd_hck_recon_types=>gc_role-redeposit ).
    IF is_flags-cad_set = abap_true.
      add_set( iv_set_id = gc_test-set_cad iv_bukrs = gc_test-bukrs iv_waers = gc_test-cad iv_acct = gc_test-account ).
      add_role( iv_set_id = gc_test-set_cad iv_btc = gc_test-leg iv_role = zif_cd_hck_recon_types=>gc_role-leg ).
    ENDIF.
    IF is_flags-us2_set = abap_true.
      add_set( iv_set_id = gc_test-set_us2 iv_bukrs = gc_test-bukrs2 iv_waers = gc_test-usd iv_acct = gc_test-acct_us2 ).
      add_role( iv_set_id = gc_test-set_us2 iv_btc = gc_test-leg iv_role = zif_cd_hck_recon_types=>gc_role-leg ).
    ENDIF.
    IF is_flags-stripe_set = abap_true.
      add_set( iv_set_id = gc_test-set_strp iv_bukrs = gc_test-bukrs iv_hkont = gc_test-stripe iv_waers = gc_test-usd
               iv_hktid  = gc_test-hktid_st iv_kind = zif_cd_hck_recon_types=>gc_kind-stripe iv_acct = gc_test-acct_st ).
      add_role( iv_set_id = gc_test-set_strp iv_btc = gc_test-deposit iv_role = zif_cd_hck_recon_types=>gc_role-deposit ).
    ENDIF.
    INSERT VALUE #( account = gc_test-account last_day = gc_test-to ) INTO TABLE mo_dao->mt_last.
  ENDMETHOD.


  METHOD add_set.
    DATA ls_set TYPE zif_cd_hck_recon_types=>ty_set.
    DATA ls_account TYPE zif_cd_ebs_types=>ty_account_cfg.
    ls_set-set_id    = iv_set_id.
    ls_set-kind      = iv_kind.
    ls_set-side      = 'C'.
    ls_set-bukrs     = iv_bukrs.
    ls_set-hkont     = iv_hkont.
    ls_set-waers     = iv_waers.
    ls_set-hbkid     = gc_test-hbkid.
    ls_set-hktid     = iv_hktid.
    ls_set-leg_bank  = abap_true.
    ls_set-leg_fica  = iv_fica.
    ls_set-tolerance = iv_tol.
    INSERT ls_set INTO TABLE mo_dao->mt_sets.
    IF iv_acct IS NOT INITIAL.
      ls_account-bukrs      = iv_bukrs.
      ls_account-hbkid      = gc_test-hbkid.
      ls_account-hktid      = iv_hktid.
      ls_account-account_no = to_lower( iv_acct ).
      ls_account-active     = abap_true.
      INSERT ls_account INTO TABLE mo_ebs->mt_accounts.
    ENDIF.
  ENDMETHOD.


  METHOD add_role.
    DATA ls_role TYPE zif_cd_hck_recon_types=>ty_btc_role.
    ls_role-set_id = iv_set_id.
    ls_role-btc    = iv_btc.
    ls_role-role   = iv_role.
    INSERT ls_role INTO TABLE mo_dao->mt_roles.
  ENDMETHOD.


  METHOD add_bank.
    DATA ls_bank TYPE zif_cd_hck_recon_types=>ty_bank_day.
    ls_bank-account    = iv_account.
    ls_bank-currency   = iv_waers.
    ls_bank-day        = iv_day.
    ls_bank-btc        = iv_btc.
    ls_bank-cdi        = iv_cdi.
    ls_bank-amount     = iv_amount.
    ls_bank-line_count = 1.
    INSERT ls_bank INTO TABLE mo_dao->mt_bank.
    IF iv_no_lot = abap_true.
      INSERT ls_bank INTO TABLE mo_dao->mt_no_lot.
    ENDIF.
  ENDMETHOD.


  METHOD add_gl.
    DATA ls_gl TYPE zif_cd_hck_recon_types=>ty_gl_day.
    ls_gl-bukrs      = iv_bukrs.
    ls_gl-hkont      = gc_test-hkont_in.
    ls_gl-currency   = iv_waers.
    ls_gl-day        = iv_day.
    ls_gl-awtyp      = gc_test-awtyp.
    ls_gl-amount     = iv_amount.
    ls_gl-line_count = 1.
    INSERT ls_gl INTO TABLE mo_dao->mt_gl.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    ls_def-check_id = gc_test-check_id.
    rs_result = CAST zif_cd_hck_check( NEW zcl_cd_hck_c_recon3( ) )->execute(
      is_def        = ls_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_test-report ) ).
  ENDMETHOD.


  METHOD findings_of.
    rt_found = VALUE #( FOR ls_finding IN is_result-findings WHERE ( check_code = iv_code ) ( ls_finding ) ).
  ENDMETHOD.


  METHOD worst.
    rv_sev = zcl_cd_ops_util=>worst_severity( is_result-findings ).
  ENDMETHOD.


  " Rule: bank = G/L on a day is green - no warning or error, the difference 0 is stored per day
  METHOD balanced_day_no_finding.
    TRY.
        configure_scenario( VALUE #( ) ).
        add_bank( iv_day = gc_test-day5 iv_amount = 100 ).
        add_gl( iv_day = gc_test-day5 iv_amount = 100 ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_differs( act = worst( ls_result ) exp = zif_cd_ops_types=>gc_severity-error
                                             msg = 'No error' ).
        cl_abap_unit_assert=>assert_differs( act = worst( ls_result ) exp = zif_cd_ops_types=>gc_severity-warning
                                             msg = 'No warning' ).
        DATA(ls_metric) = ls_result-metrics[ metric = zif_cd_hck_recon_types=>gc_metric-diff_bank_gl dim2 = '2026-11-05' ].
        cl_abap_unit_assert=>assert_equals( act = ls_metric-value exp = 0 msg = 'Difference 0 stored' ).
        cl_abap_unit_assert=>assert_equals( act = ls_metric-dim1 exp = 'US01/0011401000/USD'
                                            msg = 'Group BUKRS/HKONT (internal)/WAERS' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-evidence msg = 'All evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: bank <> G/L not explained is RECON_BREAK (E, owned exception) with the residual and currency
  METHOD break_is_error_with_amount.
    TRY.
        configure_scenario( VALUE #( ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 60 ).
        DATA(lt_breaks) = findings_of( is_result = act( ) iv_code = zif_cd_hck_recon_types=>gc_code-recon_break ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_breaks ) exp = 1 msg = 'One break' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Error' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-action exp = zif_cd_ops_types=>gc_action-exception
                                            msg = 'Owned exception' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-amount exp = 40 msg = 'Residual' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-currency exp = gc_test-usd msg = 'Currency' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-object_key
                                            exp = 'A_RECON_3WAY/US01/0011401000/USD/2026-11-01/BANK'
                                            msg = 'Key: check / group / day / leg' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the statement of the next day is timing - information only, not red
  METHOD timing_next_day_is_info.
    TRY.
        configure_scenario( VALUE #( ) ).
        add_gl( iv_day = gc_test-day2 iv_amount = 100 ).
        add_bank( iv_day = gc_test-day3 iv_amount = 100 ).
        DATA(ls_result) = act( ).
        DATA(lt_timing) = findings_of( is_result = ls_result iv_code = zif_cd_hck_recon_types=>gc_code-recon_timing ).
        cl_abap_unit_assert=>assert_equals( act = lines( VALUE zif_cd_ops_types=>tt_finding(
                                                    FOR ls_t IN lt_timing WHERE ( object_key CS 'BANK' ) ( ls_t ) ) )
                                            exp = 2 msg = 'Both days listed as timing' ).
        cl_abap_unit_assert=>assert_equals( act = lt_timing[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'Information' ).
        cl_abap_unit_assert=>assert_initial( act = findings_of( is_result = ls_result
                                                                iv_code   = zif_cd_hck_recon_types=>gc_code-recon_break )
                                             msg = 'No break' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a 468 without returns lot within 10 days is the delayed redeposit - listed, not red
  METHOD redeposit_468_is_info.
    TRY.
        configure_scenario( VALUE #( ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 ).
        add_bank( iv_day = gc_test-day1 iv_amount = 30 iv_btc = gc_test-redep iv_cdi = gc_test-debit
                  iv_no_lot = abap_true ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        DATA(ls_result) = act( ).
        DATA(lt_timing) = findings_of( is_result = ls_result iv_code = zif_cd_hck_recon_types=>gc_code-recon_timing ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_timing ) exp = 1 msg = 'Listed once' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_timing[ 1 ]-message CS zif_cd_hck_recon_types=>gc_bucket-redeposit )
                                          msg = 'Bucket REDEPOSIT named' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ metric = zif_cd_hck_recon_types=>gc_metric-bucket
                                                                     dim2   = zif_cd_hck_recon_types=>gc_bucket-redeposit ]-value
                                            exp = 1 msg = 'Bucket count stored' ).
        cl_abap_unit_assert=>assert_differs( act = worst( ls_result ) exp = zif_cd_ops_types=>gc_severity-error
                                             msg = 'Not red' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: charges + fees = BAI 195 deposit: the Stripe group is balanced (difference 0 stored)
  METHOD stripe_balanced_no_break.
    TRY.
        configure_scenario( VALUE #( stripe_set = abap_true ) ).
        INSERT VALUE #( account = gc_test-acct_st currency = gc_test-usd bukrs = gc_test-bukrs belnr = gc_test-belnr
                        gjahr = gc_test-gjahr day = gc_test-day5 cdi = gc_test-credit amount = 970 line_count = 1 )
               INTO TABLE mo_dao->mt_deposits.
        INSERT VALUE #( bukrs = gc_test-bukrs belnr = gc_test-belnr gjahr = gc_test-gjahr zuonr = gc_test-descr
                        cdi = gc_test-credit amount = -970 line_count = 1 ) INTO TABLE mo_dao->mt_assign.
        INSERT VALUE #( zuonr = gc_test-descr cdi = gc_test-debit amount = 1000 line_count = 3 ) INTO TABLE mo_dao->mt_sums.
        INSERT VALUE #( zuonr = gc_test-descr cdi = gc_test-credit amount = -1000 line_count = 2 ) INTO TABLE mo_dao->mt_sums.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = findings_of( is_result = ls_result
                                                                iv_code   = zif_cd_hck_recon_types=>gc_code-stripe_break )
                                             msg = 'No Stripe break' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ metric = zif_cd_hck_recon_types=>gc_metric-stripe_diff ]-value
                                            exp = 0 msg = 'Difference 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a descriptor group without its fee lines is off by the fees - STRIPE_GROUP_BREAK (E)
  METHOD stripe_off_by_fees_breaks.
    TRY.
        configure_scenario( VALUE #( stripe_set = abap_true ) ).
        INSERT VALUE #( account = gc_test-acct_st currency = gc_test-usd bukrs = gc_test-bukrs belnr = gc_test-belnr
                        gjahr = gc_test-gjahr day = gc_test-day5 cdi = gc_test-credit amount = 970 line_count = 1 )
               INTO TABLE mo_dao->mt_deposits.
        INSERT VALUE #( bukrs = gc_test-bukrs belnr = gc_test-belnr gjahr = gc_test-gjahr zuonr = gc_test-descr
                        cdi = gc_test-credit amount = -970 line_count = 1 ) INTO TABLE mo_dao->mt_assign.
        INSERT VALUE #( zuonr = gc_test-descr cdi = gc_test-debit amount = 1000 line_count = 3 ) INTO TABLE mo_dao->mt_sums.
        INSERT VALUE #( zuonr = gc_test-descr cdi = gc_test-credit amount = -970 line_count = 1 ) INTO TABLE mo_dao->mt_sums.
        DATA(lt_breaks) = findings_of( is_result = act( ) iv_code = zif_cd_hck_recon_types=>gc_code-stripe_break ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_breaks ) exp = 1 msg = 'One Stripe break' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-amount exp = 30 msg = 'Off by the fees' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-reference exp = gc_test-set_strp msg = 'Set named' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_breaks[ 1 ]-message CS gc_test-descr )
                                          msg = 'Descriptor named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a bank code without role in the set is a new / unmapped code - warning naming the code
  METHOD unmapped_btc_is_warning.
    TRY.
        configure_scenario( VALUE #( ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 ).
        add_bank( iv_day = gc_test-day1 iv_amount = 25 iv_btc = gc_test-unmapped ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        DATA(lt_variance) = findings_of( is_result = act( ) iv_code = zif_cd_hck_recon_types=>gc_code-recon_variance ).
        DATA(ls_codes) = VALUE #( lt_variance[ details = CONV string( gc_test-unmapped ) ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_codes-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Unmapped code is a warning' ).
        cl_abap_unit_assert=>assert_equals( act = ls_codes-amount exp = 25 msg = 'Amount of the code' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_variance ) exp = 2 msg = 'Day variance and code list' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one set per currency - USD balanced, CAD break; amounts never summed across currencies
  METHOD currencies_kept_apart.
    TRY.
        configure_scenario( VALUE #( cad_set = abap_true ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        add_bank( iv_day = gc_test-day1 iv_amount = 80 iv_waers = gc_test-cad ).
        add_gl( iv_day = gc_test-day1 iv_amount = 50 iv_waers = gc_test-cad ).
        DATA(ls_result) = act( ).
        DATA(lt_breaks) = findings_of( is_result = ls_result iv_code = zif_cd_hck_recon_types=>gc_code-recon_break ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_breaks ) exp = 1 msg = 'Only CAD breaks' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-currency exp = gc_test-cad msg = 'CAD' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-amount exp = 30 msg = 'CAD amounts only' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-metrics[ metric = zif_cd_hck_recon_types=>gc_metric-diff_bank_gl
                                   dim1   = 'US01/0011401000/USD' dim2 = '2026-11-01' ]-value
          exp = 0 msg = 'USD balanced on its own' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: company codes are separate groups (own account, own G/L key)
  METHOD company_codes_kept_apart.
    TRY.
        configure_scenario( VALUE #( us2_set = abap_true ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 iv_account = gc_test-acct_us2 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 70 iv_bukrs = gc_test-bukrs2 ).
        DATA(lt_breaks) = findings_of( is_result = act( ) iv_code = zif_cd_hck_recon_types=>gc_code-recon_break ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_breaks ) exp = 1 msg = 'Only US02 breaks' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-reference exp = gc_test-set_us2 msg = 'Set of US02' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-amount exp = 30 msg = 'US02 amounts only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a difference equal to HCK_RECON_TOLERANCE is balanced; the set's own tolerance wins
  METHOD tolerance_param_and_set.
    TRY.
        mo_params->set( iv_name = zif_cd_hck_recon_types=>gc_param-tolerance iv_value = gc_test-tol_one ).
        configure_scenario( VALUE #( ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 101 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        cl_abap_unit_assert=>assert_initial( act = findings_of( is_result = act( )
                                                                iv_code   = zif_cd_hck_recon_types=>gc_code-recon_break )
                                             msg = 'At the parameter tolerance: no break' ).
        mo_dao->mt_sets[ 1 ]-tolerance = '0.50'.
        cl_abap_unit_assert=>assert_equals( act = lines( findings_of( is_result = act( )
                                                                      iv_code   = zif_cd_hck_recon_types=>gc_code-recon_break ) )
                                            exp = 1 msg = 'Set tolerance 0.50 wins: break' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing in the window is no evidence (the engine shows grey) - never green, listed as info
  METHOD empty_window_is_no_evidence.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-evidence exp = zif_cd_hck_types=>gc_evidence-none
                                            msg = 'Evidence NONE' ).
        cl_abap_unit_assert=>assert_equals( act = lines( findings_of( is_result = ls_result
                                                                      iv_code   = zif_cd_hck_recon_types=>gc_code-recon_no_data ) )
                                            exp = 1 msg = 'No-data information' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ metric = zif_cd_hck_recon_types=>gc_metric-days
                                                                     dim2   = zif_cd_hck_recon_types=>gc_status-empty ]-value
                                            exp = 7 msg = 'Seven empty days counted' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists(
                                                   ls_result-metrics[ metric = zif_cd_hck_recon_types=>gc_metric-diff_bank_gl ] ) )
                                           msg = 'No difference stored for an empty day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a set whose house bank account has no active payment engine account is RECON_CONFIG (W)
  METHOD set_without_account_config.
    TRY.
        configure_scenario( VALUE #( no_account = abap_true ) ).
        DATA(ls_result) = act( ).
        DATA(lt_config) = findings_of( is_result = ls_result iv_code = zif_cd_hck_recon_types=>gc_code-recon_config ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_config ) exp = 1 msg = 'Configuration finding' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_config[ 1 ]-message
                                                         CS zif_cd_hck_recon_types=>gc_config_reason-no_account )
                                          msg = 'Reason named' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_accounts_read msg = 'No bank line read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the window ends the day before the report date and goes back the look-back days (7)
  METHOD window_ends_before_report.
    TRY.
        configure_scenario( VALUE #( ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_from exp = gc_test-from msg = 'Window start' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_to exp = gc_test-to msg = 'Window end' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_accounts_read[ 1 ] exp = gc_test-account
                                            msg = 'XBLNR account from ZCD_EBS_ACCT, upper case' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ACH collections clear one-to-one by assignment: an old unmatched group is a RECON_BREAK
  METHOD ach_unmatched_group_breaks.
    TRY.
        configure_scenario( VALUE #( ach_kind = abap_true ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        INSERT VALUE #( zuonr = gc_test-ach_zuonr first_day = gc_test-day2 amount = 45 line_count = 1 )
               INTO TABLE mo_dao->mt_open.
        DATA(lt_breaks) = findings_of( is_result = act( ) iv_code = zif_cd_hck_recon_types=>gc_code-recon_break ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_breaks ) exp = 1 msg = 'One unmatched day' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-amount exp = 45 msg = 'Open amount' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_breaks[ 1 ]-object_key CS zif_cd_hck_recon_types=>gc_leg-ach )
                                          msg = 'ACH key' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: G/L transfer <> payment engine control total after the timing days is RECON_SUBLEDGER_BREAK (E)
  METHOD subledger_break_is_error.
    TRY.
        configure_scenario( VALUE #( with_fica = abap_true ) ).
        add_bank( iv_day = gc_test-day1 iv_amount = 100 ).
        add_gl( iv_day = gc_test-day1 iv_amount = 100 ).
        INSERT VALUE #( bukrs = gc_test-bukrs hkont = gc_test-hkont_in currency = gc_test-usd day = gc_test-day1
                        amount = 80 line_count = 2 ) INTO TABLE mo_dao->mt_fica.
        DATA(ls_result) = act( ).
        DATA(lt_breaks) = findings_of( is_result = ls_result iv_code = zif_cd_hck_recon_types=>gc_code-subledger_break ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_breaks ) exp = 1 msg = 'One subledger break' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-amount exp = 20 msg = 'G/L 100 - control total 80' ).
        cl_abap_unit_assert=>assert_equals( act = lt_breaks[ 1 ]-object_key
                                            exp = 'A_RECON_3WAY/US01/0011401000/USD/2026-11-01/FICA'
                                            msg = 'Key of the subledger leg' ).
        cl_abap_unit_assert=>assert_initial( act = findings_of( is_result = ls_result
                                                                iv_code   = zif_cd_hck_recon_types=>gc_code-recon_break )
                                             msg = 'Bank = G/L' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
