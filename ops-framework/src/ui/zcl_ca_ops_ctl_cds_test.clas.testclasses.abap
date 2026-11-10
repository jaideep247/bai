*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ctl_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the daily control review on cl_cds_test_environment doubles
*& of the direct dependencies of each view: which findings belong to a
*& control (exact RULE_ID / CHECK_CODE / GROUP2, area of the findings, live
*& dispositions only, rank B / E 2, W 1), the derived state (status code,
*& awaiting review: not signed off, worse status, newer finding) and the
*& overdue flag and counters of the BO root. Does not prove live SAP runtime
*& behavior. VERIFY-ADT: doubles of CDS view dependencies (7.58).
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
"! ZI_CA_OPSCTLFIND: findings of the covered checks of a control
CLASS ltc_find DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area       TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check_area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_B',
        control    TYPE zif_ca_ops_ctl_types=>ty_control_id VALUE 'ZT_PAYFILES',
        run        TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C1',
        day        TYPE d VALUE '20261110',
        rule       TYPE zif_ca_ops_types=>ty_rule_id VALUE 'F_MISSING',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS exact_match_and_live_only FOR TESTING.
ENDCLASS.


CLASS ltc_find IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSCTLFIND' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_checks TYPE STANDARD TABLE OF zca_ops_ctlchk WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF zi_ca_opsctlrunday WITH EMPTY KEY.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_checks = VALUE #( ( area = gc-area control_id = gc-control check_area = gc-check_area
                           match_field = zif_ca_ops_ctl_types=>gc_match_field-rule_id match_value = gc-rule ) ).
    lt_runs = VALUE #( ( runid = gc-run area = gc-check_area businessdate = gc-day ) ).
    " 1 open error of the rule, 2 waived error, 3 resolved error, 4 open warning of another rule,
    " 5 superseded warning of the rule (raised again later - still live for the date)
    lt_findings = VALUE #( ( run_id = gc-run finding_no = 1 area = gc-check_area rule_id = gc-rule
                             severity = zif_ca_ops_types=>gc_severity-error disposition = zif_ca_ops_types=>gc_disposition-open )
                           ( run_id = gc-run finding_no = 2 area = gc-check_area rule_id = gc-rule
                             severity = zif_ca_ops_types=>gc_severity-error disposition = zif_ca_ops_types=>gc_disposition-waived )
                           ( run_id = gc-run finding_no = 3 area = gc-check_area rule_id = gc-rule
                             severity = zif_ca_ops_types=>gc_severity-block disposition = zif_ca_ops_types=>gc_disposition-resolved )
                           ( run_id = gc-run finding_no = 4 area = gc-check_area rule_id = 'F_OTHER'
                             severity = zif_ca_ops_types=>gc_severity-warning disposition = zif_ca_ops_types=>gc_disposition-open )
                           ( run_id = gc-run finding_no = 5 area = gc-check_area rule_id = gc-rule
                             severity = zif_ca_ops_types=>gc_severity-warning disposition = zif_ca_ops_types=>gc_disposition-superseded ) ).
    go_env->insert_test_data( lt_checks ).
    go_env->insert_test_data( lt_runs ).
    go_env->insert_test_data( lt_findings ).
  ENDMETHOD.


  " Rule: exact value of the configured field; open, assigned and superseded count, resolved and waived not
  METHOD exact_match_and_live_only.
    SELECT findingno, statusrank, businessdate FROM zi_ca_opsctlfind ORDER BY findingno INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Open error and superseded warning only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-statusrank exp = zif_ca_ops_ctl_types=>gc_rank-action
                                        msg = 'Error ranks as action required' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-statusrank exp = zif_ca_ops_ctl_types=>gc_rank-watch
                                        msg = 'Warning ranks as watch' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-businessdate exp = gc-day msg = 'Business date of the run' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSCTLSTATE: status code and awaiting review
CLASS ltc_state DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area        TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        day         TYPE d VALUE '20261110',
        reviewed_at TYPE timestampl VALUE '20261110140000.0000000',
        later       TYPE timestampl VALUE '20261110150000.0000000',
        earlier     TYPE timestampl VALUE '20261110120000.0000000',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS status_and_awaiting FOR TESTING.
ENDCLASS.


CLASS ltc_state IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSCTLSTATE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_days TYPE STANDARD TABLE OF zi_ca_opsctlday WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " C1 not signed off; C2 signed off at watch, now watch, no newer finding; C3 signed off at watch, now
    " action required; C4 signed off at healthy, newer finding (still healthy rank: information only)
    lt_days = VALUE #( ( area = gc-area controlid = 'C1' businessdate = gc-day statusrank = 0 )
                       ( area = gc-area controlid = 'C2' businessdate = gc-day statusrank = 1 lastfindingat = gc-earlier
                         statusatreview = zif_ca_ops_ctl_types=>gc_status-watch reviewrank = 1 reviewedat = gc-reviewed_at )
                       ( area = gc-area controlid = 'C3' businessdate = gc-day statusrank = 2
                         statusatreview = zif_ca_ops_ctl_types=>gc_status-watch reviewrank = 1 reviewedat = gc-reviewed_at )
                       ( area = gc-area controlid = 'C4' businessdate = gc-day statusrank = 0 lastfindingat = gc-later
                         statusatreview = zif_ca_ops_ctl_types=>gc_status-healthy reviewrank = 0 reviewedat = gc-reviewed_at ) ).
    go_env->insert_test_data( lt_days ).
  ENDMETHOD.


  METHOD status_and_awaiting.
    SELECT controlid, controlstatus, isreviewed, isawaitingreview, isflagged FROM zi_ca_opsctlstate
      ORDER BY controlid INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 4 msg = 'One row per control and date' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-controlstatus exp = zif_ca_ops_ctl_types=>gc_status-healthy
                                        msg = 'Rank 0 = healthy' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isawaitingreview exp = abap_true msg = 'Not signed off: awaiting' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-isawaitingreview exp = abap_false
                                        msg = 'Signed off at the same status: done' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-isflagged exp = abap_true msg = 'Watch is flagged' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-controlstatus exp = zif_ca_ops_ctl_types=>gc_status-action
                                        msg = 'Rank 2 = action required' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-isawaitingreview exp = abap_true
                                        msg = 'Worse than at sign-off: awaiting again' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 4 ]-isawaitingreview exp = abap_true
                                        msg = 'A finding after the sign-off: awaiting again' ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CA_OPSCTLREVIEW: overdue review and counters
CLASS ltc_review DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        today     TYPE d VALUE '20261110',
        yesterday TYPE d VALUE '20261109',
        cutoff    TYPE t VALUE '083000',
        now_time  TYPE t VALUE '091500',
        late_cut  TYPE t VALUE '100000',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS overdue_and_counters FOR TESTING.
ENDCLASS.


CLASS ltc_review IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CA_OPSCTLREVIEW' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_states TYPE STANDARD TABLE OF zi_ca_opsctlstate WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " today 09:15: P1 awaiting, cut-off 08:30 (overdue); P2 awaiting, cut-off 10:00 (not yet);
    " P3 signed off, action required; Y1 yesterday awaiting (overdue)
    lt_states = VALUE #(
      ( area = gc-area controlid = 'P1' businessdate = gc-today today = gc-today nowtime = gc-now_time
        cutofftime = gc-cutoff statusrank = 1 controlstatus = zif_ca_ops_ctl_types=>gc_status-watch
        isawaitingreview = abap_true isflagged = abap_true )
      ( area = gc-area controlid = 'P2' businessdate = gc-today today = gc-today nowtime = gc-now_time
        cutofftime = gc-late_cut statusrank = 0 controlstatus = zif_ca_ops_ctl_types=>gc_status-healthy
        isawaitingreview = abap_true )
      ( area = gc-area controlid = 'P3' businessdate = gc-today today = gc-today nowtime = gc-now_time
        cutofftime = gc-cutoff statusrank = 2 controlstatus = zif_ca_ops_ctl_types=>gc_status-action
        isreviewed = abap_true isflagged = abap_true )
      ( area = gc-area controlid = 'Y1' businessdate = gc-yesterday today = gc-today nowtime = gc-now_time
        cutofftime = gc-late_cut statusrank = 0 controlstatus = zif_ca_ops_ctl_types=>gc_status-healthy
        isawaitingreview = abap_true ) ).
    go_env->insert_test_data( lt_states ).
  ENDMETHOD.


  METHOD overdue_and_counters.
    SELECT controlid, isreviewoverdue, overduecount, reviewedcount, actionrequiredcount, watchcount,
           statuscriticality
      FROM zr_ca_opsctlreview ORDER BY controlid INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isreviewoverdue exp = abap_true
                                        msg = 'Awaiting after the 08:30 cut-off: overdue' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-isreviewoverdue exp = abap_false
                                        msg = 'Before its 10:00 cut-off: not yet' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-overduecount exp = 0 msg = 'Signed off: never overdue' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-reviewedcount exp = 1 msg = 'Counted as reviewed' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-actionrequiredcount exp = 1 msg = 'Counted as action required' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-statuscriticality exp = 1 msg = 'Action required is red' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-watchcount exp = 1 msg = 'Counted as watch' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 4 ]-isreviewoverdue exp = abap_true
                                        msg = 'Yesterday not signed off: overdue' ).
  ENDMETHOD.

ENDCLASS.
