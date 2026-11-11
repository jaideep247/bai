*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_hovr_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the shift handover on cl_cds_test_environment doubles of the
*& direct dependencies of each view: the current shift start is the latest
*& start not after now, the previous one the latest before it; the handover
*& counts per team, area and company code since the previous shift start - new,
*& resolved and still open exceptions, escalations sent, controls awaiting
*& sign-off, planned downtime active for every team; an old resolved exception
*& is not counted and another company code stays its own row. Does not prove
*& live SAP runtime behavior. VERIFY-ADT: doubles of CDS view dependencies (7.58).
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: shift handover).
*&---------------------------------------------------------------------*
"! ZI_CA_OPSSHIFTCUR: the start of the current shift is the latest start not after now
CLASS ltc_current DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_team TYPE c LENGTH 10 VALUE 'ZT_TEAM'.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS latest_start_not_after_now FOR TESTING.
ENDCLASS.


CLASS ltc_current IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSSHIFTCUR' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  " Rule: of the starts 10 hours ago, 2 hours ago and in 6 hours the current shift began 2 hours ago
  METHOD latest_start_not_after_now.
    DATA lt_starts TYPE STANDARD TABLE OF zi_ca_opsshiftcand WITH EMPTY KEY.
    DATA ls_start TYPE zi_ca_opsshiftcand.
    DATA lv_now TYPE timestampl.
    go_env->clear_doubles( ).
    GET TIME STAMP FIELD lv_now.
    ls_start-team = gc_team.
    ls_start-starttime = '060000'.
    ls_start-startutc = cl_abap_tstmp=>add( tstmp = lv_now secs = -36000 ).
    INSERT ls_start INTO TABLE lt_starts.
    ls_start-starttime = '140000'.
    ls_start-startutc = cl_abap_tstmp=>add( tstmp = lv_now secs = -7200 ).
    DATA(lv_expected) = ls_start-startutc.
    INSERT ls_start INTO TABLE lt_starts.
    ls_start-starttime = '220000'.
    ls_start-startutc = cl_abap_tstmp=>add( tstmp = lv_now secs = 21600 ).
    INSERT ls_start INTO TABLE lt_starts.
    go_env->insert_test_data( lt_starts ).

    SELECT team, currentstartutc FROM zi_ca_opsshiftcur INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row per team' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-currentstartutc exp = lv_expected
                                        msg = 'The shift that began 2 hours ago' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSSHIFTPREV: the start of the previous shift is the latest start before the current one
CLASS ltc_previous DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        team    TYPE c LENGTH 10 VALUE 'ZT_TEAM',
        night   TYPE timestamp VALUE '20261110220000',
        morning TYPE timestamp VALUE '20261111060000',
        noon    TYPE timestamp VALUE '20261111140000',
        evening TYPE timestamp VALUE '20261111220000',
      END OF gc.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS latest_before_current FOR TESTING.
ENDCLASS.


CLASS ltc_previous IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSSHIFTPREV' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  " Rule: three shifts a day, the current one from 14:00 - the handover counts since 06:00
  METHOD latest_before_current.
    DATA lt_starts TYPE STANDARD TABLE OF zi_ca_opsshiftcand WITH EMPTY KEY.
    DATA ls_start TYPE zi_ca_opsshiftcand.
    DATA lt_current TYPE STANDARD TABLE OF zi_ca_opsshiftcur WITH EMPTY KEY.
    go_env->clear_doubles( ).
    ls_start-team = gc-team.
    ls_start-startutc = gc-night.
    INSERT ls_start INTO TABLE lt_starts.
    ls_start-startutc = gc-morning.
    INSERT ls_start INTO TABLE lt_starts.
    ls_start-startutc = gc-noon.
    INSERT ls_start INTO TABLE lt_starts.
    ls_start-startutc = gc-evening.
    INSERT ls_start INTO TABLE lt_starts.
    go_env->insert_test_data( lt_starts ).
    INSERT VALUE #( team = gc-team currentstartutc = gc-noon ) INTO TABLE lt_current.
    go_env->insert_test_data( lt_current ).

    SELECT SINGLE previousstartutc FROM zi_ca_opsshiftprev WHERE team = @gc-team INTO @DATA(lv_previous).
    cl_abap_unit_assert=>assert_equals( act = lv_previous exp = gc-morning msg = 'The morning shift' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSHOVREVT: the handover counts per team, area and company code since the previous shift start
CLASS ltc_events DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        team      TYPE c LENGTH 10 VALUE 'ZT_TEAM',
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs     TYPE bukrs VALUE 'ZT01',
        since     TYPE timestamp VALUE '20261111060000',
        next_end  TYPE timestamp VALUE '20261112060000',
        after     TYPE timestampl VALUE '20261111070000.0000000',
        before    TYPE timestampl VALUE '20261110120000.0000000',
        run_new   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C1',
        run_res   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C2',
        run_old   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C3',
        run_gone  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C4',
        run_cc    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C5',
        alert_id  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C6',
        window_id TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000C7',
      END OF gc.

    TYPES:
      BEGIN OF ty_sum,
        team        TYPE c LENGTH 10,
        companycode TYPE bukrs,
        new_count   TYPE i,
        resolved    TYPE i,
        open_count  TYPE i,
        escalated   TYPE i,
        awaiting    TYPE i,
        downtime    TYPE i,
      END OF ty_sum.
    TYPES tt_sum TYPE STANDARD TABLE OF ty_sum WITH EMPTY KEY.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS sums
      RETURNING
        VALUE(rt_sums) TYPE tt_sum.

    METHODS counts_since_previous_shift FOR TESTING.
    METHODS company_code_own_row        FOR TESTING.
    METHODS downtime_for_every_team     FOR TESTING.
ENDCLASS.


CLASS ltc_events IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSHOVREVT' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_windows TYPE STANDARD TABLE OF zi_ca_opsshiftwin WITH EMPTY KEY.
    DATA lt_episodes TYPE STANDARD TABLE OF zi_ca_opsexcepisode WITH EMPTY KEY.
    DATA ls_episode TYPE zi_ca_opsexcepisode.
    DATA lt_log TYPE STANDARD TABLE OF zca_ops_allog WITH EMPTY KEY.
    DATA ls_log TYPE zca_ops_allog.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_finding TYPE zca_ops_finding.
    DATA lt_teams TYPE STANDARD TABLE OF zi_ca_opsfindteam WITH EMPTY KEY.
    DATA lt_reviews TYPE STANDARD TABLE OF zr_ca_opsctlreview WITH EMPTY KEY.
    DATA ls_review TYPE zr_ca_opsctlreview.
    DATA lt_downtime TYPE STANDARD TABLE OF zi_ca_opsdtwnow WITH EMPTY KEY.
    DATA ls_downtime TYPE zi_ca_opsdtwnow.
    go_env->clear_doubles( ).
    " the team's shift window and the default shift (team blank)
    INSERT VALUE #( team = gc-team previousstartutc = gc-since nextendutc = gc-next_end ) INTO TABLE lt_windows.
    INSERT VALUE #( team = space previousstartutc = gc-since nextendutc = gc-next_end ) INTO TABLE lt_windows.
    go_env->insert_test_data( lt_windows ).

    ls_episode-team      = gc-team.
    ls_episode-area      = gc-area.
    ls_episode-findingno = 1.
    " new since the previous shift start and open
    ls_episode-runid       = gc-run_new.
    ls_episode-disposition = zif_ca_ops_types=>gc_disposition-open.
    ls_episode-firstseenat = gc-after.
    INSERT ls_episode INTO TABLE lt_episodes.
    " older, resolved since
    ls_episode-runid       = gc-run_res.
    ls_episode-disposition = zif_ca_ops_types=>gc_disposition-resolved.
    ls_episode-firstseenat = gc-before.
    ls_episode-resolvedat  = gc-after.
    INSERT ls_episode INTO TABLE lt_episodes.
    " older, still assigned
    ls_episode-runid       = gc-run_old.
    ls_episode-disposition = zif_ca_ops_types=>gc_disposition-assigned.
    CLEAR ls_episode-resolvedat.
    INSERT ls_episode INTO TABLE lt_episodes.
    " older, resolved before the previous shift: not part of the handover
    ls_episode-runid       = gc-run_gone.
    ls_episode-disposition = zif_ca_ops_types=>gc_disposition-resolved.
    ls_episode-resolvedat  = gc-before.
    INSERT ls_episode INTO TABLE lt_episodes.
    " new and open in a company code
    ls_episode-runid       = gc-run_cc.
    ls_episode-companycode = gc-bukrs.
    ls_episode-disposition = zif_ca_ops_types=>gc_disposition-open.
    ls_episode-firstseenat = gc-after.
    CLEAR ls_episode-resolvedat.
    INSERT ls_episode INTO TABLE lt_episodes.
    go_env->insert_test_data( lt_episodes ).

    " one escalation sent since, of the old assigned exception's row
    ls_log-alert_id   = gc-alert_id.
    ls_log-run_id     = gc-run_old.
    ls_log-finding_no = 1.
    ls_log-esc_step   = 1.
    ls_log-status     = zif_ca_ops_types=>gc_alert_status-sent.
    ls_log-sent_at    = gc-after.
    INSERT ls_log INTO TABLE lt_log.
    go_env->insert_test_data( lt_log ).
    ls_finding-run_id     = gc-run_old.
    ls_finding-finding_no = 1.
    ls_finding-area       = gc-area.
    INSERT ls_finding INTO TABLE lt_findings.
    go_env->insert_test_data( lt_findings ).
    INSERT VALUE #( runid = gc-run_old findingno = 1 team = gc-team ) INTO TABLE lt_teams.
    go_env->insert_test_data( lt_teams ).

    " a control of today awaiting sign-off, another one signed off
    ls_review-area             = gc-area.
    ls_review-controlid        = 'ZT_CTL_1'.
    ls_review-team             = gc-team.
    ls_review-iscurrentday     = abap_true.
    ls_review-isawaitingreview = abap_true.
    INSERT ls_review INTO TABLE lt_reviews.
    ls_review-controlid        = 'ZT_CTL_2'.
    ls_review-isawaitingreview = abap_false.
    INSERT ls_review INTO TABLE lt_reviews.
    go_env->insert_test_data( lt_reviews ).

    " an approved planned downtime window active now
    ls_downtime-windowid        = gc-window_id.
    ls_downtime-area            = gc-area.
    ls_downtime-isapproved      = abap_true.
    ls_downtime-isactive        = abap_true.
    ls_downtime-startsinseconds = -3600.
    ls_downtime-endsinseconds   = 3600.
    INSERT ls_downtime INTO TABLE lt_downtime.
    go_env->insert_test_data( lt_downtime ).
  ENDMETHOD.


  METHOD sums.
    SELECT team, companycode, SUM( newcount ) AS new_count, SUM( resolvedcount ) AS resolved,
           SUM( opencount ) AS open_count, SUM( escalatedcount ) AS escalated,
           SUM( awaitingsignoff ) AS awaiting, SUM( downtimeactive ) AS downtime
      FROM zi_ca_opshovrevt
      WHERE isrelevant = @abap_true
      GROUP BY team, companycode
      ORDER BY team, companycode
      INTO CORRESPONDING FIELDS OF TABLE @rt_sums.
  ENDMETHOD.


  " Rule: since the previous shift start - one new, one resolved, two still open (new and old), one escalation,
  " one control awaiting sign-off; an exception resolved before is not part of the handover
  METHOD counts_since_previous_shift.
    DATA(lt_sums) = sums( ).
    DATA(ls_team) = VALUE #( lt_sums[ team = gc-team companycode = space ] OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = ls_team-new_count exp = 1 msg = 'One new exception' ).
    cl_abap_unit_assert=>assert_equals( act = ls_team-resolved exp = 1 msg = 'One resolved since' ).
    cl_abap_unit_assert=>assert_equals( act = ls_team-open_count exp = 2 msg = 'Two still open' ).
    cl_abap_unit_assert=>assert_equals( act = ls_team-escalated exp = 1 msg = 'One escalation' ).
    cl_abap_unit_assert=>assert_equals( act = ls_team-awaiting exp = 1 msg = 'One control awaiting sign-off' ).
  ENDMETHOD.


  " Rule: an exception of a company code is counted on its own row (company-code isolation)
  METHOD company_code_own_row.
    DATA(lt_sums) = sums( ).
    DATA(ls_cc) = VALUE #( lt_sums[ team = gc-team companycode = gc-bukrs ] OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = ls_cc-new_count exp = 1 msg = 'New in the company code' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cc-open_count exp = 1 msg = 'Open in the company code' ).
  ENDMETHOD.


  " Rule: a planned downtime window has no team: every team with shift times sees it (area-level row)
  METHOD downtime_for_every_team.
    DATA(lt_sums) = sums( ).
    cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_sums[ team = gc-team companycode = space ]-downtime OPTIONAL )
                                        exp = 1
                                        msg = 'The team sees the active window' ).
    cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_sums[ team = space companycode = space ]-downtime OPTIONAL )
                                        exp = 1
                                        msg = 'The default shift too' ).
  ENDMETHOD.

ENDCLASS.
