*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the cash data access on doubles of the SAP tables, the
*& journal view ZI_CA_OpsCashJrnl and the framework's control / process
*& register: payments per run with the payments without document; jobs by
*& a name pattern with _ taken literally; open lots and returns lots (status
*& not done), items in clarification, returns without returns document;
*& statements per account and day, lines not posted, lines of a house bank
*& without payment lot; clearing resets of paid payments only; reversed
*& payment documents; open, error and closed keys without G/L document;
*& the owner (control first, else process); the factory calendar through
*& its test seam. Status values are test values, not SAP facts. Does not
*& prove live SAP runtime behavior (PlanViz CASH-PV1 .. CASH-PV6).
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltc_cash_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs TYPE bukrs VALUE 'ZT01',
        open  TYPE c LENGTH 1 VALUE '1',
        done  TYPE c LENGTH 1 VALUE '9',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_cash_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS done
      RETURNING
        VALUE(rt_range) TYPE zif_ca_ops_types=>tt_param_range.

    METHODS payment_runs_aggregated   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS jobs_by_pattern           FOR TESTING RAISING zcx_ca_ops_error.
    METHODS lots_open_and_clarified   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS returns_open_and_pending  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS statements_and_lines      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS resets_of_paid_payments   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS reversed_payment_document FOR TESTING RAISING zcx_ca_ops_error.
    METHODS keys_open_error_not_in_gl FOR TESTING RAISING zcx_ca_ops_error.
    METHODS owner_control_then_proc   FOR TESTING.
    METHODS calendar_through_seam     FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_cash_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #(
               ( 'DPAYH' ) ( 'TBTCO' ) ( 'DFKKZK' ) ( 'DFKKZP' ) ( 'DFKKRK' ) ( 'DFKKRP' ) ( 'FEBKO' ) ( 'FEBEP' )
               ( 'DFKKRAPT' ) ( 'DFKKKO' ) ( 'DFKKSUMC' ) ( 'DFKKSUM' ) ( 'ZI_CA_OPSCASHJRNL' )
               ( 'ZCA_OPS_CTLCHK' ) ( 'ZCA_OPS_CONTROL' ) ( 'ZCA_OPS_PROC' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_cash_dao( ).
  ENDMETHOD.


  METHOD done.
    rt_range = VALUE #( ( sign = zif_ca_ops_types=>gc_range-sign_include option = zif_ca_ops_types=>gc_range-option_equal
                          low = gc-done ) ).
  ENDMETHOD.


  " Rule: one row per run, proposal flag, company code and currency; DOC1R initial counted and summed apart
  METHOD payment_runs_aggregated.
    DATA lt_dpayh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    lt_dpayh = VALUE #( ( laufd = '20261112' laufi = 'PAY01' payno = 1 bbukr = gc-bukrs waers = 'EUR'
                          rwbtr = '100.00' doc1r = '000000000001' )
                        ( laufd = '20261112' laufi = 'PAY01' payno = 2 bbukr = gc-bukrs waers = 'EUR'
                          rwbtr = '250.00' )
                        ( laufd = '20261112' laufi = 'PAY01' payno = 3 bbukr = gc-bukrs waers = 'EUR'
                          rwbtr = '350.00' xvorl = abap_true )
                        ( laufd = '20261001' laufi = 'OLD01' payno = 1 bbukr = gc-bukrs waers = 'EUR'
                          rwbtr = '9.00' ) ).
    go_env->insert_test_data( lt_dpayh ).

    DATA(lt_runs) = mo_cut->payment_runs( iv_from = '20261109' iv_to = '20261116' iv_max = 100 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_runs ) exp = 2 ).
    DATA(ls_paid) = lt_runs[ proposal = abap_false ].
    cl_abap_unit_assert=>assert_equals( act = ls_paid-item_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_paid-amount exp = '350.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_paid-nodoc_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_paid-nodoc_amount exp = '250.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_runs[ proposal = abap_true ]-amount exp = '350.00' ).
  ENDMETHOD.


  " Rule: * = any characters, an underscore of the pattern is a literal (not one character)
  METHOD jobs_by_pattern.
    DATA lt_tbtco TYPE STANDARD TABLE OF tbtco WITH EMPTY KEY.
    lt_tbtco = VALUE #( ( jobname = 'ZT_PAYRUN_1' jobcount = '00000001' status = 'F' strtdate = '20261113' )
                        ( jobname = 'ZTXPAYRUN_1' jobcount = '00000002' status = 'F' strtdate = '20261113' )
                        ( jobname = 'ZT_PAYRUN_2' jobcount = '00000003' status = 'F' strtdate = '20261001' ) ).
    go_env->insert_test_data( lt_tbtco ).

    DATA(lt_jobs) = mo_cut->jobs( iv_pattern = 'ZT_PAYRUN*' iv_from = '20261109' iv_to = '20261116' iv_max = 10 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_jobs ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_jobs[ 1 ]-jobcount exp = '00000001' ).
  ENDMETHOD.


  " Rule: a lot of a status that is not done, created up to the day, per company code / currency of its items
  METHOD lots_open_and_clarified.
    DATA lt_zk TYPE STANDARD TABLE OF dfkkzk WITH EMPTY KEY.
    DATA lt_zp TYPE STANDARD TABLE OF dfkkzp WITH EMPTY KEY.
    lt_zk = VALUE #( ( keyz1 = 'LOT1' stazs = gc-open erdat = '20261110' )
                     ( keyz1 = 'LOT2' stazs = gc-done erdat = '20261110' )
                     ( keyz1 = 'LOT3' stazs = gc-open erdat = '20261116' ) ).
    lt_zp = VALUE #( ( keyz1 = 'LOT1' posza = 1 bukrs = gc-bukrs waers = 'EUR' betrz = '10.00' budat = '20261110' )
                     ( keyz1 = 'LOT1' posza = 2 bukrs = gc-bukrs waers = 'EUR' betrz = '15.00' budat = '20261110'
                       xklae = abap_true )
                     ( keyz1 = 'LOT2' posza = 1 bukrs = gc-bukrs waers = 'EUR' betrz = '99.00' budat = '20261110' )
                     ( keyz1 = 'LOT3' posza = 1 bukrs = gc-bukrs waers = 'EUR' betrz = '1.00' budat = '20261116'
                       xklae = abap_true ) ).
    go_env->insert_test_data( lt_zk ).
    go_env->insert_test_data( lt_zp ).

    DATA(lt_open) = mo_cut->open_lots( it_done = done( ) iv_created_to = '20261115' iv_max = 10 ).
    DATA(lt_clarif) = mo_cut->lot_clarifications( iv_posted_to = '20261113' iv_max = 10 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_open ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-object_id exp = 'LOT1' ).
    cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-item_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-amount exp = '25.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-oldest exp = '20261110' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_clarif ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_clarif[ 1 ]-amount exp = '15.00' ).
  ENDMETHOD.


  " Rule: returns lot not done; returns in clarification; returns without returns document
  METHOD returns_open_and_pending.
    DATA lt_rk TYPE STANDARD TABLE OF dfkkrk WITH EMPTY KEY.
    DATA lt_rp TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    lt_rk = VALUE #( ( keyr1 = 'RET1' stars = gc-open erdat = '20261111' )
                     ( keyr1 = 'RET2' stars = gc-done erdat = '20261111' ) ).
    lt_rp = VALUE #( ( keyr1 = 'RET1' posra = 1 bukrs = gc-bukrs waers = 'EUR' betrr = '40.00' budat = '20261111' )
                     ( keyr1 = 'RET2' posra = 1 bukrs = gc-bukrs waers = 'EUR' betrr = '60.00' budat = '20261111'
                       rlbel = '000000000077' xklae = abap_true ) ).
    go_env->insert_test_data( lt_rk ).
    go_env->insert_test_data( lt_rp ).

    DATA(lt_open) = mo_cut->open_returns_lots( it_done = done( ) iv_created_to = '20261115' iv_max = 10 ).
    DATA(lt_clarif) = mo_cut->return_clarifications( iv_posted_to = '20261115' iv_max = 10 ).
    DATA(lt_nodoc) = mo_cut->returns_without_document( iv_posted_to = '20261115' iv_max = 10 ).

    cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-object_id exp = 'RET1' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_open ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_clarif[ 1 ]-object_id exp = 'RET2' ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ 1 ]-object_id exp = 'RET1' ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ 1 ]-amount exp = '40.00' ).
  ENDMETHOD.


  " Rule: statements per account and date; lines not posted; lines of a named house bank without payment lot
  METHOD statements_and_lines.
    DATA lt_ko TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA lt_ep TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA lt_zk TYPE STANDARD TABLE OF dfkkzk WITH EMPTY KEY.
    lt_ko = VALUE #( ( anwnd = '0001' absnd = 'A' azidt = '1' emkey = '1' kukey = '00000001' bukrs = gc-bukrs
                       hbkid = 'HB1' hktid = 'AC1' azdat = '20261113' edate = '20261113' )
                     ( anwnd = '0001' absnd = 'A' azidt = '2' emkey = '1' kukey = '00000002' bukrs = gc-bukrs
                       hbkid = 'HB1' hktid = 'AC1' azdat = '20261112' edate = '20261112' ) ).
    lt_ep = VALUE #( ( kukey = '00000001' esnum = 1 kwaer = 'EUR' kwbtr = '70.00' )
                     ( kukey = '00000001' esnum = 2 kwaer = 'EUR' kwbtr = '30.00' vb1ok = abap_true )
                     ( kukey = '00000002' esnum = 1 kwaer = 'EUR' kwbtr = '5.00' vb1ok = abap_true ) ).
    lt_zk = VALUE #( ( keyz1 = 'LOT9' kukey = '00000002' ) ).
    go_env->insert_test_data( lt_ko ).
    go_env->insert_test_data( lt_ep ).
    go_env->insert_test_data( lt_zk ).
    DATA(lt_banks) = VALUE zif_ca_ops_types=>tt_param_range( ( sign = zif_ca_ops_types=>gc_range-sign_include
                                                               option = zif_ca_ops_types=>gc_range-option_equal
                                                               low = 'HB1' ) ).

    DATA(lt_days) = mo_cut->statement_days( iv_from = '20261109' iv_to = '20261116' iv_max = 10 ).
    DATA(lt_unposted) = mo_cut->unposted_lines( iv_imported_to = '20261115' iv_max = 10 ).
    DATA(lt_no_lot) = mo_cut->lines_not_in_fica( it_banks = lt_banks iv_imported_to = '20261115' iv_max = 10 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_unposted ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_unposted[ 1 ]-amount exp = '70.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_no_lot[ 1 ]-object_id exp = '00000001' ).
    cl_abap_unit_assert=>assert_equals( act = lt_no_lot[ 1 ]-item_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_no_lot ) exp = 1 ).
  ENDMETHOD.


  " Rule: a reset counts only when the clearing document is the payment document of a payment run (not a proposal)
  METHOD resets_of_paid_payments.
    DATA lt_ra TYPE STANDARD TABLE OF dfkkrapt WITH EMPTY KEY.
    DATA lt_dpayh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    lt_ra = VALUE #( ( opbel = 'ITEM1' opupk = 1 augbl = 'PAYDOC1' stblg = 'RESET1' stdat = '20261115'
                       bukrs = gc-bukrs waers = 'EUR' betrw = '80.00' )
                     ( opbel = 'ITEM2' opupk = 1 augbl = 'OTHER1' stblg = 'RESET2' stdat = '20261115'
                       bukrs = gc-bukrs waers = 'EUR' betrw = '20.00' ) ).
    lt_dpayh = VALUE #( ( laufd = '20261112' laufi = 'PAY01' payno = 1 doc1r = 'PAYDOC1' bbukr = gc-bukrs ) ).
    go_env->insert_test_data( lt_ra ).
    go_env->insert_test_data( lt_dpayh ).

    DATA(lt_sums) = mo_cut->paid_clearing_resets( iv_reset_from = '20261115' it_augrd = VALUE #( ) iv_max = 10 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_sums ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-object_id exp = 'PAYDOC1' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-amount exp = '80.00' ).
  ENDMETHOD.


  " Rule: the payment document of a run whose STORB names a reversal entered in the window; an original with STBEL
  " filled (it is itself a reversal of another document) is not a reversed payment
  METHOD reversed_payment_document.
    DATA lt_dpayh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA lt_ko TYPE STANDARD TABLE OF dfkkko WITH EMPTY KEY.
    lt_dpayh = VALUE #( ( laufd = '20261112' laufi = 'PAY01' payno = 1 doc1r = 'PAYDOC1' bbukr = gc-bukrs
                          waers = 'EUR' rwbtr = '500.00' )
                        ( laufd = '20261112' laufi = 'PAY01' payno = 2 doc1r = 'PAYDOC2' bbukr = gc-bukrs
                          waers = 'EUR' rwbtr = '1.00' ) ).
    " the original names its reversal in STORB; the reversal names the original in STBEL (never STBEL on the original)
    lt_ko = VALUE #( ( opbel = 'PAYDOC1' storb = 'REVDOC1' )
                     ( opbel = 'REVDOC1' stbel = 'PAYDOC1' cpudt = '20261115' )
                     ( opbel = 'PAYDOC2' stbel = 'OTHER9' cpudt = '20261115' ) ).
    go_env->insert_test_data( lt_dpayh ).
    go_env->insert_test_data( lt_ko ).

    DATA(lt_sums) = mo_cut->reversed_payments( iv_reversed_from = '20261115' iv_max = 10 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_sums ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-object_id exp = 'PAYDOC1' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-object_sub exp = '20261112PAY01' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ 1 ]-amount exp = '500.00' ).
  ENDMETHOD.


  " Rule: open key past the day; error key; closed key without an unreversed G/L document of its company code
  METHOD keys_open_error_not_in_gl.
    DATA lt_sumc TYPE STANDARD TABLE OF dfkksumc WITH EMPTY KEY.
    DATA lt_sum TYPE STANDARD TABLE OF dfkksum WITH EMPTY KEY.
    DATA lt_jrnl TYPE STANDARD TABLE OF zi_ca_opscashjrnl WITH EMPTY KEY.
    lt_sumc = VALUE #( ( fikey = 'KEY_OPEN' cpudt = '20261110' )
                       ( fikey = 'KEY_ERR' cpudt = '20261110' xclos = abap_true cldat = '20261110' xerro = abap_true )
                       ( fikey = 'KEY_GAP' cpudt = '20261110' xclos = abap_true cldat = '20261110' )
                       ( fikey = 'KEY_OK' cpudt = '20261110' xclos = abap_true cldat = '20261110' ) ).
    lt_sum = VALUE #( ( bukrs = gc-bukrs fikey = 'KEY_OPEN' shkzg = 'S' hkont = '1' waers = 'EUR' betrw = '10.00' )
                      ( bukrs = gc-bukrs fikey = 'KEY_OPEN' shkzg = 'H' hkont = '2' waers = 'EUR' betrw = '-10.00' )
                      ( bukrs = gc-bukrs fikey = 'KEY_ERR' shkzg = 'S' hkont = '1' waers = 'EUR' betrw = '20.00' )
                      ( bukrs = gc-bukrs fikey = 'KEY_GAP' shkzg = 'S' hkont = '1' waers = 'EUR' betrw = '30.00' )
                      ( bukrs = gc-bukrs fikey = 'KEY_OK' shkzg = 'S' hkont = '1' waers = 'EUR' betrw = '40.00' ) ).
    lt_jrnl = VALUE #( ( companycode = gc-bukrs fiscalyear = '2026' accountingdocument = '0100000001'
                         referencedocumenttype = 'ZTREF' originalreferencedocument = 'KEY_OK' ) ).
    go_env->insert_test_data( lt_sumc ).
    go_env->insert_test_data( lt_sum ).
    go_env->insert_test_data( lt_jrnl ).

    DATA(lt_open) = mo_cut->open_keys( iv_created_to = '20261115' iv_max = 10 ).
    DATA(lt_error) = mo_cut->error_keys( 10 ).
    DATA(lt_gap) = mo_cut->keys_not_in_gl( iv_closed_to = '20261115' iv_awtyp = 'ZTREF' iv_max = 10 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_open ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-amount exp = '10.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_open[ 1 ]-item_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_error[ 1 ]-object_id exp = 'KEY_ERR' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_gap ) exp = 2 ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_gap[ object_id = 'KEY_OK' ] ) ) ).
  ENDMETHOD.


  " Rule: the active control covering the check (GROUP2) names the owner; without one the process owner
  METHOD owner_control_then_proc.
    DATA lt_chk TYPE STANDARD TABLE OF zca_ops_ctlchk WITH EMPTY KEY.
    DATA lt_ctl TYPE STANDARD TABLE OF zca_ops_control WITH EMPTY KEY.
    DATA lt_proc TYPE STANDARD TABLE OF zca_ops_proc WITH EMPTY KEY.
    lt_chk = VALUE #( ( area = gc-area control_id = 'ZT_CTL' check_area = gc-area
                        match_field = zif_ca_ops_ctl_types=>gc_match_field-group2 match_value = 'ZT_CHECK' ) ).
    lt_ctl = VALUE #( ( area = gc-area control_id = 'ZT_CTL' owner = 'ZT_OWNER' backup = 'ZT_BACKUP' team = 'ZT_TEAM'
                        cutoff_time = '100000' active = abap_true ) ).
    lt_proc = VALUE #( ( area = gc-area process_id = 'ZT_PROC' owner = 'ZT_PROC_OWN' ) ).
    go_env->insert_test_data( lt_chk ).
    go_env->insert_test_data( lt_ctl ).
    go_env->insert_test_data( lt_proc ).

    DATA(ls_control) = mo_cut->owner( iv_area = gc-area iv_check_id = 'ZT_CHECK' iv_process_id = 'ZT_PROC' ).
    DATA(ls_process) = mo_cut->owner( iv_area = gc-area iv_check_id = 'ZT_OTHER' iv_process_id = 'ZT_PROC' ).

    cl_abap_unit_assert=>assert_equals( act = ls_control-owner exp = 'ZT_OWNER' ).
    cl_abap_unit_assert=>assert_equals( act = ls_control-team exp = 'ZT_TEAM' ).
    cl_abap_unit_assert=>assert_equals( act = ls_control-cutoff_time exp = '100000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_process-owner exp = 'ZT_PROC_OWN' ).
    cl_abap_unit_assert=>assert_initial( ls_process-control_id ).
  ENDMETHOD.


  " Rule: indicator blank = working day; a moved date (indicator set) is not
  METHOD calendar_through_seam.
    TEST-INJECTION factory_date.
      lv_indicator = COND #( WHEN iv_date = '20261114' THEN '+' ).
      lv_subrc = 0.
    END-TEST-INJECTION.

    cl_abap_unit_assert=>assert_true( mo_cut->working_day( iv_date = '20261113' iv_calendar = 'ZT' ) ).
    cl_abap_unit_assert=>assert_false( mo_cut->working_day( iv_date = '20261114' iv_calendar = 'ZT' ) ).
  ENDMETHOD.

ENDCLASS.
