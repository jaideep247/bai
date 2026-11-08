*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_recon_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the three-way reconciliation reads on doubles of
*& ZCD_HCK_RCSET, the posting area ZBTR (RECON entries, in memory), the bank line view
*& ZI_CD_HckRcBankLine (grouped per account / currency / day / code /
*& direction, last day, lines without returns lot - DFKKRP, deposits per
*& posting document), ACDOCA (per day and reference procedure, deposit
*& documents per assignment, assignment sums, groups that do not net to
*& zero with the cap), DFKKSUMC and DPAYH; empty key lists read nothing.
*& No real database read; does not prove live SAP runtime behavior
*& (VERIFY-DDIC field names, VERIFY-ADT: CDS entity and JOIN @itab doubles).
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*& 2026-11-08 | Table consolidation: roles from ZCD_HCK_BTCROLE usage RECON; a lifecycle row of the same code
*&            | is not read (roles_active_only).
*& 2026-11-08 | Customer posting areas: roles are ZBTR entries (ZCL_CD_OPS_POSTAREA_MEM); roles_recon_entries_only
*&            | - RECON / BAI2 entries only, never a lifecycle entry or a '*' entry.
*&---------------------------------------------------------------------*
CLASS ltc_recon_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        set_a    TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'COLL_US',
        set_b    TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'DISB_US',
        set_off  TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'OLD_SET',
        bukrs    TYPE zif_cd_hck_recon_types=>ty_bukrs VALUE 'US01',
        hkont    TYPE zif_cd_hck_recon_types=>ty_hkont VALUE '0011401000',
        other_gl TYPE zif_cd_hck_recon_types=>ty_hkont VALUE '0011409999',
        waers    TYPE zif_cd_hck_recon_types=>ty_waers VALUE 'USD',
        account  TYPE zif_cd_hck_recon_types=>ty_account VALUE '8XX1174412',
        other    TYPE zif_cd_hck_recon_types=>ty_account VALUE '9YY0000001',
        ledger   TYPE zif_cd_hck_recon_types=>ty_ledger VALUE '0L',
        ledger2  TYPE zif_cd_hck_recon_types=>ty_ledger VALUE '2L',
        awtyp    TYPE zif_cd_hck_recon_types=>ty_awtyp VALUE 'FKKSU',
        other_aw TYPE zif_cd_hck_recon_types=>ty_awtyp VALUE 'BKPF',
        leg      TYPE zif_cd_hck_recon_types=>ty_btc VALUE '166',
        redep    TYPE zif_cd_hck_recon_types=>ty_btc VALUE '468',
        deposit  TYPE zif_cd_hck_recon_types=>ty_btc VALUE '195',
        credit   TYPE zif_cd_hck_recon_types=>ty_cdi VALUE 'H',
        debit    TYPE zif_cd_hck_recon_types=>ty_cdi VALUE 'S',
        from     TYPE d VALUE '20261101',
        to       TYPE d VALUE '20261107',
        day1     TYPE d VALUE '20261102',
        day2     TYPE d VALUE '20261105',
        outside  TYPE d VALUE '20261020',
        ref_lot  TYPE c LENGTH 12 VALUE '000000400001',
        ref_none TYPE c LENGTH 12 VALUE '000000400002',
        belnr    TYPE zif_cd_hck_recon_types=>ty_belnr VALUE '0100000001',
        gjahr    TYPE zif_cd_hck_recon_types=>ty_gjahr VALUE '2026',
        descr    TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE 'STRIPE*PAYOUT1105',
        zuonr_ok TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE '000000500001',
        zuonr_op TYPE zif_cd_hck_recon_types=>ty_zuonr VALUE '000000500002',
        hbkid    TYPE zif_cd_hck_recon_types=>ty_hbkid VALUE 'JPMC1',
        hktid    TYPE zif_cd_hck_recon_types=>ty_hktid VALUE 'DISB1',
        "! Lifecycle entry of ZBTR (flow + method class, open role list)
        lifecycle TYPE zif_cd_hck_recon_types=>ty_set_id VALUE 'CCRD',
        collected TYPE zif_cd_hck_recon_types=>ty_role VALUE 'COLLECTED',
        btr       TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTR',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_hck_recon_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS insert_config.
    METHODS insert_bank_lines.
    METHODS insert_gl_lines.
    METHODS insert_subledger.
    METHODS bank_line
      IMPORTING
        iv_esnum       TYPE i
        iv_account     TYPE zif_cd_hck_recon_types=>ty_account
        iv_day         TYPE d
        iv_btc         TYPE zif_cd_hck_recon_types=>ty_btc
        iv_cdi         TYPE zif_cd_hck_recon_types=>ty_cdi
        iv_amount      TYPE zif_cd_hck_recon_types=>ty_amount
        iv_reference   TYPE clike OPTIONAL
        iv_belnr       TYPE zif_cd_hck_recon_types=>ty_belnr OPTIONAL
      RETURNING
        VALUE(rs_line) TYPE zi_cd_hckrcbankline.
    METHODS gl_line
      IMPORTING
        iv_docln       TYPE i
        iv_belnr       TYPE zif_cd_hck_recon_types=>ty_belnr
        iv_hkont       TYPE zif_cd_hck_recon_types=>ty_hkont DEFAULT gc_test-hkont
        iv_ledger      TYPE zif_cd_hck_recon_types=>ty_ledger DEFAULT gc_test-ledger
        iv_day         TYPE d
        iv_awtyp       TYPE zif_cd_hck_recon_types=>ty_awtyp DEFAULT gc_test-awtyp
        iv_zuonr       TYPE zif_cd_hck_recon_types=>ty_zuonr OPTIONAL
        iv_amount      TYPE zif_cd_hck_recon_types=>ty_amount
      RETURNING
        VALUE(rs_line) TYPE acdoca.
    METHODS accounts
      RETURNING
        VALUE(rt_accounts) TYPE zif_cd_hck_recon_types=>tt_account.
    METHODS keys
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_hck_recon_types=>tt_gl_key.
    METHODS key
      RETURNING
        VALUE(rs_key) TYPE zif_cd_hck_recon_types=>ty_gl_key.

    METHODS sets_active_ordered        FOR TESTING.
    METHODS roles_recon_entries_only   FOR TESTING.
    METHODS bank_days_grouped          FOR TESTING.
    METHODS bank_last_day_per_account  FOR TESTING.
    METHODS bank_no_lot_skips_lot      FOR TESTING.
    METHODS gl_days_per_awtyp          FOR TESTING.
    METHODS fica_days_grouped          FOR TESTING.
    METHODS payment_days_runs_only     FOR TESTING.
    METHODS deposits_per_document      FOR TESTING.
    METHODS doc_assignments_on_account FOR TESTING.
    METHODS assignment_sums_per_cdi    FOR TESTING.
    METHODS open_groups_not_netting    FOR TESTING.
    METHODS empty_lists_read_nothing   FOR TESTING.
ENDCLASS.


CLASS ltc_recon_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_HCK_RCSET' ) ( 'ZI_CD_HCKRCBANKLINE' )
                                   ( 'DFKKRP' ) ( 'ACDOCA' ) ( 'DFKKSUMC' ) ( 'DPAYH' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    insert_config( ).
    insert_bank_lines( ).
    insert_gl_lines( ).
    insert_subledger( ).
    mo_cut = NEW zcl_cd_hck_recon_dao( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_postarea_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD insert_config.
    DATA lt_sets TYPE STANDARD TABLE OF zcd_hck_rcset WITH EMPTY KEY.
    DATA ls_set TYPE zcd_hck_rcset.
    ls_set-set_id   = gc_test-set_b.
    ls_set-kind     = zif_cd_hck_recon_types=>gc_kind-threeway.
    ls_set-bukrs    = gc_test-bukrs.
    ls_set-hkont    = gc_test-hkont.
    ls_set-waers    = gc_test-waers.
    ls_set-leg_bank = abap_true.
    ls_set-active   = abap_true.
    INSERT ls_set INTO TABLE lt_sets.
    ls_set-set_id = gc_test-set_a.
    INSERT ls_set INTO TABLE lt_sets.
    ls_set-set_id = gc_test-set_off.
    ls_set-active = abap_false.
    INSERT ls_set INTO TABLE lt_sets.
    go_env->insert_test_data( lt_sets ).
    " Bank code roles: entries of the customer posting area ZBTR (USAGE / SCOPE / SCHEME / CODE -> ROLE)
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
    DATA(lo_mem) = NEW zcl_cd_ops_postarea_mem( ).
    lo_mem->add( iv_area    = gc_test-btr
                 iv_keys    = |{ zif_cd_hck_types=>gc_btc_usage-recon }/{ gc_test-set_a }/| &&
                              |{ zif_cd_ebs_types=>gc_scheme-bai2 }/{ gc_test-leg }|
                 iv_results = |{ zif_cd_hck_recon_types=>gc_role-leg }| ).
    " An ISO entry and a '*' entry are no reconciliation roles (configuration check POSTAREA_INVALID)
    lo_mem->add( iv_area    = gc_test-btr
                 iv_keys    = |{ zif_cd_hck_types=>gc_btc_usage-recon }/{ gc_test-set_a }/| &&
                              |{ zif_cd_ebs_types=>gc_scheme-iso }/{ gc_test-redep }|
                 iv_results = |{ zif_cd_hck_recon_types=>gc_role-redeposit }| ).
    lo_mem->add( iv_area    = gc_test-btr
                 iv_keys    = |{ zif_cd_hck_types=>gc_btc_usage-recon }/{ gc_test-set_b }/| &&
                              |{ zif_cd_ebs_types=>gc_scheme-bai2 }/{ zif_cd_ops_postarea_types=>gc_generic }|
                 iv_results = |{ zif_cd_hck_recon_types=>gc_role-ignore }| ).
    " Table consolidation 2026-11-08: a lifecycle role of the same code (usage LIFECYCLE, scope =
    " flow + method class) must never reach the reconciliation
    lo_mem->add( iv_area    = gc_test-btr
                 iv_keys    = |{ zif_cd_hck_types=>gc_btc_usage-lifecycle }/{ gc_test-lifecycle }/| &&
                              |{ zif_cd_ebs_types=>gc_scheme-bai2 }/{ gc_test-deposit }|
                 iv_results = |{ gc_test-collected }| ).
    zcl_cd_ops_postarea_injector=>inject_dao( lo_mem ).
  ENDMETHOD.


  METHOD bank_line.
    rs_line-kukey           = '00000000000001'.
    rs_line-esnum           = iv_esnum.
    rs_line-companycode     = gc_test-bukrs.
    rs_line-peaccount       = iv_account.
    rs_line-currency        = gc_test-waers.
    rs_line-bookingdate     = iv_day.
    rs_line-baicode         = iv_btc.
    rs_line-debitcreditind  = iv_cdi.
    rs_line-amount          = iv_amount.
    rs_line-bankreference   = iv_reference.
    rs_line-postingdocument = iv_belnr.
    IF iv_belnr IS NOT INITIAL.
      rs_line-postingyear = gc_test-gjahr.
    ENDIF.
  ENDMETHOD.


  METHOD insert_bank_lines.
    DATA lt_lines TYPE STANDARD TABLE OF zi_cd_hckrcbankline WITH EMPTY KEY.
    DATA lt_lots TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA ls_lot TYPE dfkkrp.
    " Two credits of one code on day 1 (one group), a debit, a 468 with and without returns lot,
    " a posted deposit; another account and a line outside the window are not read
    INSERT bank_line( iv_esnum = 1 iv_account = gc_test-account iv_day = gc_test-day1
                      iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 100 ) INTO TABLE lt_lines.
    INSERT bank_line( iv_esnum = 2 iv_account = gc_test-account iv_day = gc_test-day1
                      iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 50 ) INTO TABLE lt_lines.
    INSERT bank_line( iv_esnum = 3 iv_account = gc_test-account iv_day = gc_test-day1
                      iv_btc = gc_test-leg iv_cdi = gc_test-debit iv_amount = 20 ) INTO TABLE lt_lines.
    INSERT bank_line( iv_esnum = 4 iv_account = gc_test-account iv_day = gc_test-day2
                      iv_btc = gc_test-redep iv_cdi = gc_test-debit iv_amount = 30
                      iv_reference = gc_test-ref_lot ) INTO TABLE lt_lines.
    INSERT bank_line( iv_esnum = 5 iv_account = gc_test-account iv_day = gc_test-day2
                      iv_btc = gc_test-redep iv_cdi = gc_test-debit iv_amount = 40
                      iv_reference = gc_test-ref_none ) INTO TABLE lt_lines.
    INSERT bank_line( iv_esnum = 6 iv_account = gc_test-account iv_day = gc_test-day2
                      iv_btc = gc_test-deposit iv_cdi = gc_test-credit iv_amount = 970
                      iv_belnr = gc_test-belnr ) INTO TABLE lt_lines.
    INSERT bank_line( iv_esnum = 7 iv_account = gc_test-other iv_day = gc_test-day1
                      iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 999 ) INTO TABLE lt_lines.
    INSERT bank_line( iv_esnum = 8 iv_account = gc_test-account iv_day = gc_test-outside
                      iv_btc = gc_test-leg iv_cdi = gc_test-credit iv_amount = 999 ) INTO TABLE lt_lines.
    go_env->insert_test_data( lt_lines ).
    ls_lot-selw1 = gc_test-ref_lot.
    INSERT ls_lot INTO TABLE lt_lots.
    go_env->insert_test_data( lt_lots ).
  ENDMETHOD.


  METHOD gl_line.
    rs_line-rldnr  = iv_ledger.
    rs_line-rbukrs = gc_test-bukrs.
    rs_line-gjahr  = gc_test-gjahr.
    rs_line-belnr  = iv_belnr.
    rs_line-docln  = iv_docln.
    rs_line-racct  = iv_hkont.
    rs_line-rwcur  = gc_test-waers.
    rs_line-budat  = iv_day.
    rs_line-awtyp  = iv_awtyp.
    rs_line-zuonr  = iv_zuonr.
    rs_line-drcrk  = COND #( WHEN iv_amount < 0 THEN gc_test-credit ELSE gc_test-debit ).
    rs_line-wsl    = iv_amount.
  ENDMETHOD.


  METHOD insert_gl_lines.
    DATA lt_lines TYPE STANDARD TABLE OF acdoca WITH EMPTY KEY.
    " Day 1: two transfer lines and one other posting; another account, ledger and day are not read
    INSERT gl_line( iv_docln = 1 iv_belnr = '0200000001' iv_day = gc_test-day1 iv_amount = 60 ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 2 iv_belnr = '0200000001' iv_day = gc_test-day1 iv_amount = 70 ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0200000002' iv_day = gc_test-day1 iv_amount = 5
                    iv_awtyp = gc_test-other_aw ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0200000003' iv_day = gc_test-day1 iv_amount = 999
                    iv_hkont = gc_test-other_gl ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0200000004' iv_day = gc_test-day1 iv_amount = 999
                    iv_ledger = gc_test-ledger2 ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0200000005' iv_day = gc_test-outside iv_amount = 999 ) INTO TABLE lt_lines.
    " Stripe: the deposit document's clearing line and the descriptor group (charges, fees)
    INSERT gl_line( iv_docln = 1 iv_belnr = gc_test-belnr iv_day = gc_test-day2 iv_amount = -970
                    iv_awtyp = gc_test-other_aw iv_zuonr = gc_test-descr ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 2 iv_belnr = gc_test-belnr iv_day = gc_test-day2 iv_amount = 970
                    iv_awtyp = gc_test-other_aw iv_hkont = gc_test-other_gl ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0300000001' iv_day = gc_test-day1 iv_amount = 1000
                    iv_zuonr = gc_test-descr ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0300000002' iv_day = gc_test-day1 iv_amount = -30
                    iv_awtyp = gc_test-other_aw iv_zuonr = gc_test-descr ) INTO TABLE lt_lines.
    " ACH: one pair netting to zero, one payment still open
    INSERT gl_line( iv_docln = 1 iv_belnr = '0400000001' iv_day = gc_test-day1 iv_amount = 80
                    iv_zuonr = gc_test-zuonr_ok ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0400000002' iv_day = gc_test-day2 iv_amount = -80
                    iv_awtyp = gc_test-other_aw iv_zuonr = gc_test-zuonr_ok ) INTO TABLE lt_lines.
    INSERT gl_line( iv_docln = 1 iv_belnr = '0400000003' iv_day = gc_test-day2 iv_amount = 45
                    iv_zuonr = gc_test-zuonr_op ) INTO TABLE lt_lines.
    go_env->insert_test_data( lt_lines ).
  ENDMETHOD.


  METHOD insert_subledger.
    DATA lt_sumc TYPE STANDARD TABLE OF dfkksumc WITH EMPTY KEY.
    DATA ls_sumc TYPE dfkksumc.
    DATA lt_dpayh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_dpayh TYPE dpayh.
    ls_sumc-fikey = 'FK0001'.
    ls_sumc-bukrs = gc_test-bukrs.
    ls_sumc-hkont = gc_test-hkont.
    ls_sumc-waers = gc_test-waers.
    ls_sumc-budat = gc_test-day1.
    ls_sumc-betrw = 100.
    INSERT ls_sumc INTO TABLE lt_sumc.
    ls_sumc-fikey = 'FK0002'.
    ls_sumc-betrw = 30.
    INSERT ls_sumc INTO TABLE lt_sumc.
    ls_sumc-fikey = 'FK0003'.
    ls_sumc-hkont = gc_test-other_gl.
    INSERT ls_sumc INTO TABLE lt_sumc.
    go_env->insert_test_data( lt_sumc ).

    ls_dpayh-laufd = gc_test-day1.
    ls_dpayh-laufi = 'R00001'.
    ls_dpayh-doc1r = '000000300001'.
    ls_dpayh-bukrs = gc_test-bukrs.
    ls_dpayh-hbkid = gc_test-hbkid.
    ls_dpayh-hktid = gc_test-hktid.
    ls_dpayh-waers = gc_test-waers.
    ls_dpayh-rwbtr = '-100.00'.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    ls_dpayh-laufi = 'R00002'.
    ls_dpayh-doc1r = '000000300002'.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    " Proposal run and a row without payment document are not read
    ls_dpayh-laufi = 'R00003'.
    ls_dpayh-doc1r = '000000300003'.
    ls_dpayh-xvorl = abap_true.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    CLEAR ls_dpayh-xvorl.
    ls_dpayh-laufi = 'R00004'.
    CLEAR ls_dpayh-doc1r.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    go_env->insert_test_data( lt_dpayh ).
  ENDMETHOD.


  METHOD accounts.
    INSERT gc_test-account INTO TABLE rt_accounts.
  ENDMETHOD.


  METHOD keys.
    INSERT key( ) INTO TABLE rt_keys.
  ENDMETHOD.


  METHOD key.
    rs_key-bukrs    = gc_test-bukrs.
    rs_key-hkont    = gc_test-hkont.
    rs_key-currency = gc_test-waers.
  ENDMETHOD.


  " Rule: active sets only, ordered by set id
  METHOD sets_active_ordered.
    TRY.
        DATA(lt_sets) = mo_cut->get_sets( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_sets ) exp = 2 msg = 'Inactive set not read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sets[ 1 ]-set_id exp = gc_test-set_a msg = 'Ordered by set id' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sets[ 1 ]-leg_bank exp = abap_true msg = 'Leg mapping read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the RECON / BAI2 entries of ZBTR are the roles of the sets
  METHOD roles_recon_entries_only.
    TRY.
        DATA(lt_roles) = mo_cut->get_btc_roles( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_roles ) exp = 1
                                            msg = 'ISO entry, * entry and the lifecycle entry not read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_roles[ 1 ]-btc exp = gc_test-leg msg = 'Code read as BTC' ).
        cl_abap_unit_assert=>assert_equals( act = lt_roles[ 1 ]-set_id exp = gc_test-set_a msg = 'Scope read as set id' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_roles[ role = gc_test-collected ] ) )
                                           msg = 'A lifecycle role never leaks into the reconciliation' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: bank lines of the accounts in the window, one row per day / code / direction (SUM, COUNT)
  METHOD bank_days_grouped.
    TRY.
        DATA(lt_days) = mo_cut->get_bank_days( it_accounts = accounts( ) iv_from = gc_test-from iv_to = gc_test-to ).
        DATA(ls_credit) = lt_days[ day = gc_test-day1 btc = gc_test-leg cdi = gc_test-credit ].
        cl_abap_unit_assert=>assert_equals( act = ls_credit-amount exp = 150 msg = 'Two credits summed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_credit-line_count exp = 2 msg = 'Two lines counted' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 4
                                            msg = 'Credit, debit, 468, 195 - other account and day not read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the last booking day of the account's lines in the range
  METHOD bank_last_day_per_account.
    TRY.
        DATA(lt_last) = mo_cut->get_bank_last_days( it_accounts = accounts( ) iv_from = gc_test-from
                                                    iv_to = gc_test-to ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_last ) exp = 1 msg = 'One account' ).
        cl_abap_unit_assert=>assert_equals( act = lt_last[ 1 ]-last_day exp = gc_test-day2 msg = 'Last day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a 468 whose reference has a returns lot (DFKKRP-SELW1) is not read as pending
  METHOD bank_no_lot_skips_lot.
    TRY.
        DATA(lt_days) = mo_cut->get_bank_days_no_lot( it_accounts = accounts( )
                                                      it_btcs     = VALUE #( ( gc_test-redep ) )
                                                      iv_from     = gc_test-from
                                                      iv_to       = gc_test-to ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 1 msg = 'One group' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ 1 ]-amount exp = 40 msg = 'Only the line without lot' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: G/L lines of the key (ledger, account, currency, window) per day and reference procedure
  METHOD gl_days_per_awtyp.
    TRY.
        DATA(lt_days) = mo_cut->get_gl_days( it_keys = keys( ) iv_ledger = gc_test-ledger
                                             iv_from = gc_test-from iv_to = gc_test-to ).
        DATA(ls_fica) = lt_days[ day = gc_test-day1 awtyp = gc_test-awtyp ].
        cl_abap_unit_assert=>assert_equals( act = ls_fica-amount exp = 1210
                                            msg = 'Transfer lines of day 1 (60 + 70 + 1000 + 80)' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ day = gc_test-day1 awtyp = gc_test-other_aw ]-amount
                                            exp = -25 msg = 'Other postings of day 1 apart (5 - 30)' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_days[ amount = 999 ] ) )
                                           msg = 'Other account, ledger and day not read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: payment engine transfer totals of the key per posting day
  METHOD fica_days_grouped.
    TRY.
        DATA(lt_days) = mo_cut->get_fica_days( it_keys = keys( ) iv_from = gc_test-from iv_to = gc_test-to ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 1 msg = 'One day of the account' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ 1 ]-amount exp = 130 msg = 'Two keys summed' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ 1 ]-line_count exp = 2 msg = 'Two rows' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: payment documents of payment runs only (no proposal, DOC1R filled) per house bank account
  METHOD payment_days_runs_only.
    TRY.
        DATA(lt_days) = mo_cut->get_payment_days(
          it_banks = VALUE #( ( bukrs = gc_test-bukrs hbkid = gc_test-hbkid hktid = gc_test-hktid
                                currency = gc_test-waers ) )
          iv_from  = gc_test-from
          iv_to    = gc_test-to ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 1 msg = 'One run day' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ 1 ]-amount exp = -200 msg = 'Two payments' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: deposit lines per posting document
  METHOD deposits_per_document.
    TRY.
        DATA(lt_deposits) = mo_cut->get_deposits( it_accounts = accounts( )
                                                  it_btcs     = VALUE #( ( gc_test-deposit ) )
                                                  iv_from     = gc_test-from
                                                  iv_to       = gc_test-to ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_deposits ) exp = 1 msg = 'One deposit' ).
        cl_abap_unit_assert=>assert_equals( act = lt_deposits[ 1 ]-belnr exp = gc_test-belnr msg = 'Its document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_deposits[ 1 ]-amount exp = 970 msg = 'Its amount' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only the clearing-account lines of the deposit document, with their assignment
  METHOD doc_assignments_on_account.
    TRY.
        DATA(lt_assign) = mo_cut->get_doc_assignments(
          it_docs   = VALUE #( ( bukrs = gc_test-bukrs belnr = gc_test-belnr gjahr = gc_test-gjahr ) )
          iv_hkont  = gc_test-hkont
          iv_ledger = gc_test-ledger ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_assign ) exp = 1 msg = 'Bank G/L line not read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_assign[ 1 ]-zuonr exp = gc_test-descr msg = 'Descriptor' ).
        cl_abap_unit_assert=>assert_equals( act = lt_assign[ 1 ]-amount exp = -970 msg = 'Deposit credit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every clearing-account line of the descriptor, per debit / credit
  METHOD assignment_sums_per_cdi.
    TRY.
        DATA(lt_sums) = mo_cut->get_assignment_sums( is_key    = key( )
                                                     it_zuonr  = VALUE #( ( gc_test-descr ) )
                                                     iv_ledger = gc_test-ledger
                                                     iv_from   = gc_test-from
                                                     iv_to     = gc_test-to ).
        cl_abap_unit_assert=>assert_equals( act = lt_sums[ cdi = gc_test-debit ]-amount exp = 1000 msg = 'Charges' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sums[ cdi = gc_test-credit ]-amount exp = -1000
                                            msg = 'Deposit and fee' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: assignment groups that net to zero are cleared; the others are read, oldest first, capped
  METHOD open_groups_not_netting.
    TRY.
        DATA(lt_open) = mo_cut->get_open_assignments( is_key      = key( )
                                                      iv_ledger   = gc_test-ledger
                                                      iv_from     = gc_test-from
                                                      iv_to       = gc_test-to
                                                      iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_open[ zuonr = gc_test-zuonr_ok ] ) )
                                           msg = 'Netting pair not open' ).
        cl_abap_unit_assert=>assert_equals( act = lt_open[ zuonr = gc_test-zuonr_op ]-amount exp = 45
                                            msg = 'Open payment read' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_open ) exp = 1
                                            msg = 'Lines without assignment are no group' ).
        DATA(lt_capped) = mo_cut->get_open_assignments( is_key      = key( )
                                                        iv_ledger   = gc_test-ledger
                                                        iv_from     = gc_test-from
                                                        iv_to       = gc_test-to
                                                        iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_capped ) exp = 1 msg = 'Capped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an empty account / key / code list reads nothing - never "all"
  METHOD empty_lists_read_nothing.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_bank_days( it_accounts = VALUE #( )
                                                                          iv_from     = gc_test-from
                                                                          iv_to       = gc_test-to )
                                             msg = 'No account, no bank line' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_gl_days( it_keys   = VALUE #( )
                                                                        iv_ledger = gc_test-ledger
                                                                        iv_from   = gc_test-from
                                                                        iv_to     = gc_test-to )
                                             msg = 'No key, no G/L line' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_bank_days_no_lot( it_accounts = accounts( )
                                                                                 it_btcs     = VALUE #( )
                                                                                 iv_from     = gc_test-from
                                                                                 iv_to       = gc_test-to )
                                             msg = 'No code, no line' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_assignment_sums( is_key    = key( )
                                                                                it_zuonr  = VALUE #( )
                                                                                iv_ledger = gc_test-ledger
                                                                                iv_from   = gc_test-from
                                                                                iv_to     = gc_test-to )
                                             msg = 'No descriptor, no line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
