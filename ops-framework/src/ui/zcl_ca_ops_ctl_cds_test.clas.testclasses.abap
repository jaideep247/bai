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
*& 2026-11-10 | Company-code isolation: the company code of a finding reaches its slice (ltc_find); the
*&            | slices of a control and date (ltc_slice: area-level always, a company code with findings,
*&            | open exceptions or a sign-off); the status of a slice counts only the findings of its own
*&            | company code (ltc_day).
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
        bukrs      TYPE bukrs VALUE 'ZT01',
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
    lt_findings = VALUE #( ( run_id = gc-run finding_no = 1 area = gc-check_area rule_id = gc-rule bukrs = gc-bukrs
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
    SELECT findingno, statusrank, businessdate, companycode FROM zi_ca_opsctlfind ORDER BY findingno
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Open error and superseded warning only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-statusrank exp = zif_ca_ops_ctl_types=>gc_rank-action
                                        msg = 'Error ranks as action required' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-statusrank exp = zif_ca_ops_ctl_types=>gc_rank-watch
                                        msg = 'Warning ranks as watch' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-businessdate exp = gc-day msg = 'Business date of the run' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-companycode exp = gc-bukrs msg = 'Company code of the finding' ).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 2 ]-companycode msg = 'Area-level finding: blank company code' ).
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


"! ZI_CA_OPSCTLSLICE: which slices a control has on a business date
CLASS ltc_slice DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        control  TYPE zif_ca_ops_ctl_types=>ty_control_id VALUE 'ZT_PAYFILES',
        inactive TYPE zif_ca_ops_ctl_types=>ty_control_id VALUE 'ZT_OFF',
        day      TYPE d VALUE '20261110',
        finding  TYPE bukrs VALUE 'ZT01',
        open     TYPE bukrs VALUE 'ZT02',
        reviewed TYPE bukrs VALUE 'ZT03',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS slices_of_a_control FOR TESTING.
ENDCLASS.


CLASS ltc_slice IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSCTLSLICE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_controls TYPE STANDARD TABLE OF zca_ops_control WITH EMPTY KEY.
    DATA lt_days TYPE STANDARD TABLE OF zi_ca_opsbusday WITH EMPTY KEY.
    DATA lt_find_days TYPE STANDARD TABLE OF zi_ca_opsctlfindday WITH EMPTY KEY.
    DATA lt_open TYPE STANDARD TABLE OF zi_ca_opsctlopen WITH EMPTY KEY.
    DATA lt_reviews TYPE STANDARD TABLE OF zca_ops_review WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_controls = VALUE #( ( area = gc-area control_id = gc-control active = abap_true )
                           ( area = gc-area control_id = gc-inactive ) ).
    lt_days = VALUE #( ( businessdate = gc-day ) ).
    " findings of the date: area-level and ZT01; open exceptions now: ZT02; a sign-off of ZT03; findings of
    " the inactive control never make a slice
    lt_find_days = VALUE #( ( area = gc-area controlid = gc-control businessdate = gc-day statusrank = 1 )
                            ( area = gc-area controlid = gc-control businessdate = gc-day companycode = gc-finding
                              statusrank = 2 )
                            ( area = gc-area controlid = gc-inactive businessdate = gc-day companycode = gc-finding
                              statusrank = 2 ) ).
    lt_open = VALUE #( ( area = gc-area controlid = gc-control companycode = gc-open openexceptions = 1 ) ).
    lt_reviews = VALUE #( ( area = gc-area control_id = gc-control business_date = gc-day bukrs = gc-reviewed ) ).
    go_env->insert_test_data( lt_controls ).
    go_env->insert_test_data( lt_days ).
    go_env->insert_test_data( lt_find_days ).
    go_env->insert_test_data( lt_open ).
    go_env->insert_test_data( lt_reviews ).
  ENDMETHOD.


  " Rule: the area-level slice always; a company code with findings of the date, open exceptions or a sign-off
  METHOD slices_of_a_control.
    SELECT controlid, companycode FROM zi_ca_opsctlslice ORDER BY controlid, companycode INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 4 msg = 'Area-level, ZT01, ZT02, ZT03' ).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 1 ]-companycode msg = 'Area-level slice first' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-companycode exp = gc-finding msg = 'Slice of the findings' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-companycode exp = gc-open msg = 'Slice of the open exceptions' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 4 ]-companycode exp = gc-reviewed msg = 'Slice of the sign-off' ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ controlid = gc-inactive ] ) )
                                       msg = 'An inactive control has no slice' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSCTLDAY: the status and counts of a slice are those of its own company code only
CLASS ltc_day DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area    TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        control TYPE zif_ca_ops_ctl_types=>ty_control_id VALUE 'ZT_PAYFILES',
        day     TYPE d VALUE '20261110',
        own     TYPE bukrs VALUE 'ZT01',
        other   TYPE bukrs VALUE 'ZT02',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS status_per_company_code FOR TESTING.
ENDCLASS.


CLASS ltc_day IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSCTLDAY' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_slices TYPE STANDARD TABLE OF zi_ca_opsctlslice WITH EMPTY KEY.
    DATA lt_controls TYPE STANDARD TABLE OF zca_ops_control WITH EMPTY KEY.
    DATA lt_days TYPE STANDARD TABLE OF zi_ca_opsbusday WITH EMPTY KEY.
    DATA lt_find_days TYPE STANDARD TABLE OF zi_ca_opsctlfindday WITH EMPTY KEY.
    DATA lt_open TYPE STANDARD TABLE OF zi_ca_opsctlopen WITH EMPTY KEY.
    DATA lt_reviews TYPE STANDARD TABLE OF zca_ops_review WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_slices = VALUE #( ( area = gc-area controlid = gc-control businessdate = gc-day )
                         ( area = gc-area controlid = gc-control businessdate = gc-day companycode = gc-own )
                         ( area = gc-area controlid = gc-control businessdate = gc-day companycode = gc-other ) ).
    lt_controls = VALUE #( ( area = gc-area control_id = gc-control active = abap_true ) ).
    lt_days = VALUE #( ( businessdate = gc-day ) ).
    " area-level: nothing; ZT01: a watch finding, 1 open exception; ZT02: action required, 3 open, signed off
    lt_find_days = VALUE #( ( area = gc-area controlid = gc-control businessdate = gc-day companycode = gc-own
                              statusrank = 1 findingcount = 1 )
                            ( area = gc-area controlid = gc-control businessdate = gc-day companycode = gc-other
                              statusrank = 2 findingcount = 3 ) ).
    lt_open = VALUE #( ( area = gc-area controlid = gc-control companycode = gc-own openexceptions = 1 )
                       ( area = gc-area controlid = gc-control companycode = gc-other openexceptions = 3 ) ).
    lt_reviews = VALUE #( ( area = gc-area control_id = gc-control business_date = gc-day bukrs = gc-other
                            status_at_review = zif_ca_ops_ctl_types=>gc_status-action ) ).
    go_env->insert_test_data( lt_slices ).
    go_env->insert_test_data( lt_controls ).
    go_env->insert_test_data( lt_days ).
    go_env->insert_test_data( lt_find_days ).
    go_env->insert_test_data( lt_open ).
    go_env->insert_test_data( lt_reviews ).
  ENDMETHOD.


  " Rule: a slice never shows the rank, findings, open exceptions or sign-off of another company code
  METHOD status_per_company_code.
    SELECT companycode, statusrank, findingcount, openexceptions, statusatreview
      FROM zi_ca_opsctlday ORDER BY companycode INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 msg = 'One row per slice' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-statusrank exp = 0 msg = 'Area-level slice: healthy' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-openexceptions exp = 0 msg = 'Area-level slice: no exception' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-statusrank exp = 1 msg = 'ZT01: its own watch only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-openexceptions exp = 1 msg = 'ZT01: its own exception only' ).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 2 ]-statusatreview msg = 'ZT01: not signed off by ZT02' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-statusrank exp = 2 msg = 'ZT02: action required' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-findingcount exp = 3 msg = 'ZT02: its three findings' ).
  ENDMETHOD.

ENDCLASS.
