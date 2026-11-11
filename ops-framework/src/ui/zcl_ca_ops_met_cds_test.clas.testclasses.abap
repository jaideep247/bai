*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_met_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the response-time metrics on cl_cds_test_environment doubles of
*& the direct dependencies of each view: the first assignment over the rows of
*& one episode, re-opened only after a resolution of the same object, check and
*& company code, the seconds and flags of an episode, and the counters, time
*& buckets and minutes (null when not assigned) of ZR_CA_OpsExcMetric. Does not
*& prove live SAP runtime behavior. VERIFY-ADT: doubles of CDS view dependencies
*& (7.58).
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: response-time metrics).
*&---------------------------------------------------------------------*
"! ZI_CA_OPSEXCASSIGN1: the earliest ASSIGN of any row of an episode
CLASS ltc_assign DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area       TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        old_run    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E1',
        new_run    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E2',
        first_seen TYPE timestampl VALUE '20261111080000.0000000',
        classified TYPE timestampl VALUE '20261111080500.0000000',
        assigned_1 TYPE timestampl VALUE '20261111081000.0000000',
        assigned_2 TYPE timestampl VALUE '20261111085000.0000000',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS first_assign_of_episode FOR TESTING.
ENDCLASS.


CLASS ltc_assign IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSEXCASSIGN1' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_finding TYPE zca_ops_finding.
    DATA lt_history TYPE STANDARD TABLE OF zca_ops_exc_hist WITH EMPTY KEY.
    DATA ls_history TYPE zca_ops_exc_hist.
    go_env->clear_doubles( ).
    " one exception carried forward: the earlier row superseded, the current row open
    ls_finding-area          = gc-area.
    ls_finding-object_type   = 'FILE'.
    ls_finding-object_key    = 'BANK_A/FILE_0001'.
    ls_finding-check_code    = 'NO_BANK_ACK'.
    ls_finding-first_seen_at = gc-first_seen.
    ls_finding-run_id        = gc-old_run.
    ls_finding-finding_no    = 1.
    ls_finding-disposition   = zif_ca_ops_types=>gc_disposition-superseded.
    INSERT ls_finding INTO TABLE lt_findings.
    ls_finding-run_id        = gc-new_run.
    ls_finding-disposition   = zif_ca_ops_types=>gc_disposition-open.
    INSERT ls_finding INTO TABLE lt_findings.
    go_env->insert_test_data( lt_findings ).
    ls_history-hist_uuid  = '000000000000000000000000000000F1'.
    ls_history-run_id     = gc-old_run.
    ls_history-finding_no = 1.
    ls_history-action     = zif_ca_ops_exc_types=>gc_action-assign.
    ls_history-created_at = gc-assigned_1.
    INSERT ls_history INTO TABLE lt_history.
    ls_history-hist_uuid  = '000000000000000000000000000000F2'.
    ls_history-run_id     = gc-new_run.
    ls_history-created_at = gc-assigned_2.
    INSERT ls_history INTO TABLE lt_history.
    ls_history-hist_uuid  = '000000000000000000000000000000F3'.
    ls_history-action     = zif_ca_ops_exc_types=>gc_action-classify.
    ls_history-created_at = gc-classified.
    INSERT ls_history INTO TABLE lt_history.
    go_env->insert_test_data( lt_history ).
  ENDMETHOD.


  " Rule: time to assign counts from the first assignment of the exception, on whatever row it was made;
  " a classification is no assignment
  METHOD first_assign_of_episode.
    TRY.
        SELECT firstassignedat FROM zi_ca_opsexcassign1 INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One episode' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-firstassignedat exp = gc-assigned_1
                                            msg = 'The first assignment, on the superseded row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSEXCREOPEN: raised again after an earlier resolution of the same object, check and company code
CLASS ltc_reopen DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        resolved TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E3',
        again    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E4',
        other_cc TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E5',
        earlier  TYPE timestampl VALUE '20261101080000.0000000',
        later    TYPE timestampl VALUE '20261111080000.0000000',
        bukrs    TYPE bukrs VALUE 'ZT01',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS raised_again_after_resolve FOR TESTING.
ENDCLASS.


CLASS ltc_reopen IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSEXCREOPEN' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_finding TYPE zca_ops_finding.
    go_env->clear_doubles( ).
    ls_finding-area        = gc-area.
    ls_finding-object_type = 'FILE'.
    ls_finding-object_key  = 'BANK_A/FILE_0001'.
    ls_finding-check_code  = 'NO_BANK_ACK'.
    ls_finding-severity    = zif_ca_ops_types=>gc_severity-error.
    ls_finding-finding_no  = 1.
    " resolved on 1 November
    ls_finding-run_id        = gc-resolved.
    ls_finding-first_seen_at = gc-earlier.
    ls_finding-disposition   = zif_ca_ops_types=>gc_disposition-resolved.
    INSERT ls_finding INTO TABLE lt_findings.
    " raised again on 11 November
    ls_finding-run_id        = gc-again.
    ls_finding-first_seen_at = gc-later.
    ls_finding-disposition   = zif_ca_ops_types=>gc_disposition-open.
    INSERT ls_finding INTO TABLE lt_findings.
    " the same object and check of another company code: another exception, never resolved
    ls_finding-run_id = gc-other_cc.
    ls_finding-bukrs  = gc-bukrs.
    INSERT ls_finding INTO TABLE lt_findings.
    go_env->insert_test_data( lt_findings ).
  ENDMETHOD.


  " Rule: an exception raised again after its resolution is re-opened; another company code's is not
  METHOD raised_again_after_resolve.
    TRY.
        SELECT runid, earlierresolved FROM zi_ca_opsexcreopen INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One re-opened exception' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-runid exp = gc-again msg = 'The one raised again' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-earlierresolved exp = 1 msg = 'One earlier resolution' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZI_CA_OPSEXCTIMES: seconds to assign / resolve and the flags of an episode
CLASS ltc_times DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area       TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        open_run   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E6',
        done_run   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E7',
        first_seen TYPE timestampl VALUE '20261111080000.0000000',
        assigned   TYPE timestampl VALUE '20261111083000.0000000',
        resolved   TYPE timestampl VALUE '20261111100000.0000000',
        raised_on  TYPE d VALUE '20261111',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS assigned_open_and_resolved FOR TESTING.
ENDCLASS.


CLASS ltc_times IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CA_OPSEXCTIMES' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_episodes TYPE STANDARD TABLE OF zi_ca_opsexcepisode WITH EMPTY KEY.
    DATA ls_episode TYPE zi_ca_opsexcepisode.
    DATA lt_assigned TYPE STANDARD TABLE OF zi_ca_opsexcassign1 WITH EMPTY KEY.
    DATA ls_assigned TYPE zi_ca_opsexcassign1.
    DATA lt_reopen TYPE STANDARD TABLE OF zi_ca_opsexcreopen WITH EMPTY KEY.
    DATA ls_reopen TYPE zi_ca_opsexcreopen.
    go_env->clear_doubles( ).
    ls_episode-area        = gc-area.
    ls_episode-objecttype  = 'FILE'.
    ls_episode-checkcode   = 'NO_BANK_ACK'.
    ls_episode-severity    = zif_ca_ops_types=>gc_severity-error.
    ls_episode-firstseenat = gc-first_seen.
    ls_episode-raiseddate  = gc-raised_on.
    ls_episode-findingno   = 1.
    " assigned after 30 minutes, still open
    ls_episode-runid       = gc-open_run.
    ls_episode-objectkey   = 'BANK_A/FILE_0001'.
    ls_episode-disposition = zif_ca_ops_types=>gc_disposition-assigned.
    INSERT ls_episode INTO TABLE lt_episodes.
    " resolved after two hours without an assignment, re-opened before
    ls_episode-runid       = gc-done_run.
    ls_episode-objectkey   = 'BANK_A/FILE_0002'.
    ls_episode-disposition = zif_ca_ops_types=>gc_disposition-resolved.
    ls_episode-resolvedat  = gc-resolved.
    INSERT ls_episode INTO TABLE lt_episodes.
    go_env->insert_test_data( lt_episodes ).
    ls_assigned-area            = gc-area.
    ls_assigned-objecttype      = 'FILE'.
    ls_assigned-objectkey       = 'BANK_A/FILE_0001'.
    ls_assigned-checkcode       = 'NO_BANK_ACK'.
    ls_assigned-firstseenat     = gc-first_seen.
    ls_assigned-firstassignedat = gc-assigned.
    INSERT ls_assigned INTO TABLE lt_assigned.
    go_env->insert_test_data( lt_assigned ).
    ls_reopen-runid           = gc-done_run.
    ls_reopen-findingno       = 1.
    ls_reopen-earlierresolved = 1.
    INSERT ls_reopen INTO TABLE lt_reopen.
    go_env->insert_test_data( lt_reopen ).
  ENDMETHOD.


  " Rule: seconds to assign from the first raise to the first assignment, to resolve from the raise to the
  " resolution; flags say which apply; the month of the raise; re-opened from the earlier resolution
  METHOD assigned_open_and_resolved.
    TRY.
        SELECT SINGLE assignseconds, isassigned, isopen, raisedmonth FROM zi_ca_opsexctimes
          WHERE runid = @gc-open_run
          INTO @DATA(ls_open).
        cl_abap_unit_assert=>assert_equals( act = ls_open-assignseconds exp = 1800 msg = 'Assigned after 30 minutes' ).
        cl_abap_unit_assert=>assert_equals( act = ls_open-isassigned exp = abap_true msg = 'Assigned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_open-isopen exp = abap_true msg = 'Still open (assigned)' ).
        cl_abap_unit_assert=>assert_equals( act = ls_open-raisedmonth exp = '202611' msg = 'Month of the raise' ).
        SELECT SINGLE resolveseconds, isassigned, isresolved, reopenedcount FROM zi_ca_opsexctimes
          WHERE runid = @gc-done_run
          INTO @DATA(ls_done).
        cl_abap_unit_assert=>assert_equals( act = ls_done-resolveseconds exp = 7200 msg = 'Resolved after two hours' ).
        cl_abap_unit_assert=>assert_equals( act = ls_done-isassigned exp = abap_false msg = 'Never assigned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_done-isresolved exp = abap_true msg = 'Resolved' ).
        cl_abap_unit_assert=>assert_equals( act = ls_done-reopenedcount exp = 1 msg = 'Re-opened' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CA_OPSEXCMETRIC: counters, buckets and minutes of the metrics
CLASS ltc_metric DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        fast  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E8',
        slow  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E9',
        never TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000EA',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS counters_and_buckets      FOR TESTING.
    METHODS minutes_only_when_applies FOR TESTING.
ENDCLASS.


CLASS ltc_metric IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CA_OPSEXCMETRIC' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_times TYPE STANDARD TABLE OF zi_ca_opsexctimes WITH EMPTY KEY.
    DATA ls_time TYPE zi_ca_opsexctimes.
    go_env->clear_doubles( ).
    ls_time-area      = gc-area.
    ls_time-checkcode = 'NO_BANK_ACK'.
    ls_time-severity  = zif_ca_ops_types=>gc_severity-error.
    ls_time-findingno = 1.
    " assigned after 10 minutes, resolved after 2 hours
    ls_time-runid          = gc-fast.
    ls_time-isassigned     = abap_true.
    ls_time-assignseconds  = 600.
    ls_time-isresolved     = abap_true.
    ls_time-resolveseconds = 7200.
    INSERT ls_time INTO TABLE lt_times.
    " assigned after 100 minutes, open for 100 000 seconds (1-3 days)
    CLEAR: ls_time-isresolved, ls_time-resolveseconds.
    ls_time-runid         = gc-slow.
    ls_time-assignseconds = 6000.
    ls_time-isopen        = abap_true.
    ls_time-openseconds   = 100000.
    INSERT ls_time INTO TABLE lt_times.
    " never assigned, open for more than a week, raised again after a resolution
    CLEAR: ls_time-isassigned, ls_time-assignseconds.
    ls_time-runid         = gc-never.
    ls_time-openseconds   = 700000.
    ls_time-reopenedcount = 1.
    INSERT ls_time INTO TABLE lt_times.
    go_env->insert_test_data( lt_times ).
  ENDMETHOD.


  " Rule: one raise per episode; assigned / resolved / open / re-opened counted; each episode in one time bucket
  METHOD counters_and_buckets.
    TRY.
        SELECT SUM( raisedcount ) AS raised, SUM( assignedcount ) AS assigned, SUM( resolvedcount ) AS resolved,
               SUM( opencount ) AS open_now, SUM( reopenedcount ) AS reopened, SUM( assignedin15min ) AS in_15_min,
               SUM( assignedin4hours ) AS in_4_hours, SUM( notassigned ) AS not_assigned,
               SUM( resolvedin4hours ) AS resolved_4_hours, SUM( open1to3days ) AS open_1_to_3,
               SUM( openover7days ) AS open_over_7
          FROM zr_ca_opsexcmetric
          INTO @DATA(ls_sum).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-raised exp = 3 msg = 'Three raised' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-assigned exp = 2 msg = 'Two assigned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-resolved exp = 1 msg = 'One resolved' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-open_now exp = 2 msg = 'Two open' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-reopened exp = 1 msg = 'One re-opened' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-in_15_min exp = 1 msg = 'Assigned within 15 minutes' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-in_4_hours exp = 1 msg = 'Assigned within 4 hours' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-not_assigned exp = 1 msg = 'Never assigned' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-resolved_4_hours exp = 1 msg = 'Resolved within 4 hours' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-open_1_to_3 exp = 1 msg = 'Open 1-3 days' ).
        cl_abap_unit_assert=>assert_equals( act = ls_sum-open_over_7 exp = 1 msg = 'Open more than 7 days' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: minutes to assign only for assigned episodes (an average ignores the others), in minutes
  METHOD minutes_only_when_applies.
    TRY.
        SELECT runid, minutestoassign FROM zr_ca_opsexcmetric
          WHERE minutestoassign IS NOT NULL
          ORDER BY runid
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Two assigned episodes' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-minutestoassign exp = '10.0' msg = '600 seconds' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-minutestoassign exp = '100.0' msg = '6000 seconds' ).
        SELECT COUNT(*) FROM zr_ca_opsexcmetric WHERE minutestoassign IS NULL INTO @DATA(lv_unassigned).
        cl_abap_unit_assert=>assert_equals( act = lv_unassigned exp = 1 msg = 'Not assigned: no minutes' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
