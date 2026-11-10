*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_ovw_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the production-support overview page on
*& cl_cds_test_environment doubles of ZCA_OPS_RUN and ZCA_OPS_FINDING:
*& monitor freshness per area with the area's own stale threshold (FMON 15
*& minutes and full runs only, EBS and HCK 26 hours, no completed run =
*& stale), open critical exceptions across areas (B / E, open or assigned
*& only), overdue days, and the hidden message of EBS bank-file statement
*& findings; does not prove live SAP runtime behavior.
*& VERIFY-ADT: create( i_select_base_dependencies = abap_true ) over the UNION
*& of the three as-of views on 7.58.
*& Modification log:
*& 2026-11-06 | Initial version (production-support overview page).
*& 2026-11-08 | Fourth freshness row CORE: the payment outcome snapshot lag (ZCD_PAY_OUTWM-CURRENT_TO,
*&            | the recheck left out, stale after 30 minutes without parameter definition).
*& 2026-11-10 | Control center: daily controls (counters of the framework's review rows), payment lifecycle
*&            | (newest non-proposal run per payment document, stages from configuration), reconciliation
*&            | variances (latest measurement beyond tolerance, expected / actual, disposition from the
*&            | exception workflow); doubles of the direct dependencies of each view.
*&---------------------------------------------------------------------*
"! ZR_CD_OPSFRESHNESS: one row per batch monitor, area threshold, stale
CLASS ltc_freshness DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_run,
        fmon      TYPE zif_ca_ops_types=>ty_run_id VALUE 'F0000000000000000000000000000001',
        fmon_one  TYPE zif_ca_ops_types=>ty_run_id VALUE 'F0000000000000000000000000000002',
        ebs       TYPE zif_ca_ops_types=>ty_run_id VALUE 'F0000000000000000000000000000003',
      END OF gc_run.
    CONSTANTS gc_variant_all TYPE zif_ca_ops_types=>ty_variant VALUE 'ALL'.
    CONSTANTS gc_variant_iface TYPE zif_ca_ops_types=>ty_variant VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_seconds_fresh TYPE i VALUE 600.
    CONSTANTS gc_seconds_old TYPE i VALUE 108000.
    CONSTANTS gc_fmon_minutes TYPE i VALUE 15.
    CONSTANTS gc_areas TYPE i VALUE 4.
    "! Snapshot lag: documents processed up to 40 minutes ago, statement 10 minutes ago, recheck far
    "! behind (no time: left out) - lag 40 minutes, stale after the delivered 30
    CONSTANTS gc_seconds_lag TYPE i VALUE 2400.
    CONSTANTS gc_seconds_recent TYPE i VALUE 600.
    CONSTANTS gc_lag_minutes TYPE i VALUE 40.
    CONSTANTS gc_lag_limit TYPE i VALUE 30.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS one_row_per_monitor_area FOR TESTING.
    METHODS stale_by_area_threshold FOR TESTING.
    METHODS snapshot_lag_row        FOR TESTING.

    METHODS run
      IMPORTING
        iv_run_id     TYPE zif_ca_ops_types=>ty_run_id
        iv_pe_area    TYPE zif_ca_ops_types=>ty_area
        iv_variant    TYPE zif_ca_ops_types=>ty_variant
        iv_seconds    TYPE i
      RETURNING
        VALUE(rs_run) TYPE zca_ops_run.
ENDCLASS.


CLASS ltc_freshness IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity               = 'ZR_CD_OPSFRESHNESS'
                                              i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.

    go_env->clear_doubles( ).
    " FMON: a full run 10 minutes ago (fresh); a single-interface run just now does not count
    INSERT run( iv_run_id = gc_run-fmon iv_pe_area = zif_cd_ops_types=>gc_pe_area-file_monitor
                iv_variant = gc_variant_all iv_seconds = gc_seconds_fresh ) INTO TABLE lt_runs.
    INSERT run( iv_run_id = gc_run-fmon_one iv_pe_area = zif_cd_ops_types=>gc_pe_area-file_monitor
                iv_variant = gc_variant_iface iv_seconds = 0 ) INTO TABLE lt_runs.
    " EBS: 30 hours ago (stale after 26 h); HCK: no run at all
    INSERT run( iv_run_id = gc_run-ebs iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs
                iv_variant = gc_variant_all iv_seconds = gc_seconds_old ) INTO TABLE lt_runs.
    go_env->insert_test_data( i_data = lt_runs ).
  ENDMETHOD.


  METHOD run.
    GET TIME STAMP FIELD DATA(lv_now).
    rs_run-run_id     = iv_run_id.
    rs_run-area    = iv_pe_area.
    rs_run-variant    = iv_variant.
    rs_run-status     = zif_ca_ops_types=>gc_run_status-success.
    rs_run-ended_at   = cl_abap_tstmp=>subtract_secs( tstmp = CONV timestamp( lv_now ) secs = iv_seconds ).
    rs_run-started_at = rs_run-ended_at.
  ENDMETHOD.


  METHOD one_row_per_monitor_area.
    TRY.
        SELECT paymentenginearea, runid, staleafterminutes FROM zr_cd_opsfreshness
          ORDER BY paymentenginearea INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = gc_areas
                                            msg = 'FMON, EBS, HCK and the snapshot lag: one row each, also without a run' ).
        DATA(ls_fmon) = VALUE #( lt_rows[ paymentenginearea = zif_cd_ops_types=>gc_pe_area-file_monitor ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_fmon-runid exp = gc_run-fmon
                                            msg = 'FMON freshness = last full run, not a single-interface run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_fmon-staleafterminutes exp = gc_fmon_minutes
                                            msg = 'FMON applies its 15-minute threshold' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD stale_by_area_threshold.
    TRY.
        SELECT paymentenginearea, isstale, asofat FROM zr_cd_opsfreshness
          ORDER BY paymentenginearea INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_rows[ paymentenginearea = zif_cd_ops_types=>gc_pe_area-file_monitor ]-isstale OPTIONAL )
          exp = abap_false msg = 'A full FMON run 10 minutes ago is fresh' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_rows[ paymentenginearea = zif_cd_ops_types=>gc_pe_area-ebs ]-isstale OPTIONAL )
          exp = abap_true msg = 'An EBS run 30 hours ago is stale' ).
        DATA(ls_hck) = VALUE #( lt_rows[ paymentenginearea = zif_cd_ops_types=>gc_pe_area-health_check ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_hck-isstale exp = abap_true
                                            msg = 'No morning report run at all is stale' ).
        cl_abap_unit_assert=>assert_initial( act = ls_hck-asofat msg = 'No completed run: no as-of time' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-08): the CORE row is the snapshot lag - minutes since the oldest processed-to instant
  " of the evidence sources (recheck left out), stale above MON_STALE_AFTER_MIN_CORE (30 delivered)
  METHOD snapshot_lag_row.
    DATA lt_watermarks TYPE STANDARD TABLE OF zcd_pay_outwm WITH EMPTY KEY.
    DATA ls_watermark TYPE zcd_pay_outwm.
    TRY.
        GET TIME STAMP FIELD DATA(lv_now).
        ls_watermark-source     = zif_cd_ops_payout_types=>gc_source-documents.
        ls_watermark-current_to = cl_abap_tstmp=>subtract_secs( tstmp = CONV timestamp( lv_now ) secs = gc_seconds_lag ).
        INSERT ls_watermark INTO TABLE lt_watermarks.
        ls_watermark-source     = zif_cd_ops_payout_types=>gc_source-statement.
        ls_watermark-current_to = cl_abap_tstmp=>subtract_secs( tstmp = CONV timestamp( lv_now ) secs = gc_seconds_recent ).
        INSERT ls_watermark INTO TABLE lt_watermarks.
        ls_watermark-source     = zif_cd_ops_payout_types=>gc_source-recheck.
        ls_watermark-current_to = cl_abap_tstmp=>subtract_secs( tstmp = CONV timestamp( lv_now ) secs = gc_seconds_old ).
        INSERT ls_watermark INTO TABLE lt_watermarks.
        go_env->insert_test_data( i_data = lt_watermarks ).
        SELECT paymentenginearea, ageminutes, isstale, staleafterminutes FROM zr_cd_opsfreshness
          WHERE paymentenginearea = @zif_cd_ops_types=>gc_pe_area-core
          ORDER BY paymentenginearea
          INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One snapshot lag row' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-ageminutes exp = gc_lag_minutes
                                            msg = 'Lag of the source furthest behind, recheck left out' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-staleafterminutes exp = gc_lag_limit
                                            msg = 'Delivered threshold 30 minutes' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isstale exp = abap_true msg = 'Stale above the threshold' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_OPSCRITEXC: open B / E exceptions of every area, overdue, hidden bank-file message
CLASS ltc_critical DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_run TYPE zif_ca_ops_types=>ty_run_id VALUE 'F0000000000000000000000000000011'.
    CONSTANTS gc_code TYPE zif_ca_ops_types=>ty_check_code VALUE 'BALANCE_MISMATCH'.
    CONSTANTS gc_message TYPE c LENGTH 40 VALUE 'Account 123456789012: balance mismatch'.
    CONSTANTS gc_file_stmt TYPE zif_ca_ops_types=>ty_object_key VALUE 'S0001'.
    CONSTANTS gc_feb_stmt TYPE zif_ca_ops_types=>ty_object_key VALUE 'FEB00000501'.
    CONSTANTS gc_object TYPE zif_ca_ops_types=>ty_object_key VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_days_overdue TYPE i VALUE 2.
    CONSTANTS:
      BEGIN OF gc_no,
        fmon_error   TYPE i VALUE 1,
        ebs_block    TYPE i VALUE 2,
        hck_warning  TYPE i VALUE 3,
        core_closed  TYPE i VALUE 4,
        ebs_file     TYPE i VALUE 5,
      END OF gc_no.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS open_block_and_error_only FOR TESTING.
    METHODS overdue_days_are_counted FOR TESTING.
    METHODS bank_file_message_hidden FOR TESTING.

    METHODS finding
      IMPORTING
        iv_no             TYPE i
        iv_pe_area        TYPE zif_ca_ops_types=>ty_area
        iv_object_type    TYPE zif_ca_ops_types=>ty_object_type
        iv_object_key     TYPE zif_ca_ops_types=>ty_object_key
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
        iv_disposition    TYPE zif_ca_ops_types=>ty_disposition DEFAULT zif_ca_ops_types=>gc_disposition-open
      RETURNING
        VALUE(rs_finding) TYPE zca_ops_finding.
ENDCLASS.


CLASS ltc_critical IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity               = 'ZR_CD_OPSCRITEXC'
                                              i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD finding.
    rs_finding-run_id      = gc_run.
    rs_finding-finding_no  = iv_no.
    rs_finding-area     = iv_pe_area.
    rs_finding-object_type = iv_object_type.
    rs_finding-object_key  = iv_object_key.
    rs_finding-check_code  = gc_code.
    rs_finding-severity    = iv_severity.
    rs_finding-disposition = iv_disposition.
    rs_finding-message     = gc_message.
  ENDMETHOD.


  METHOD setup.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.

    go_env->clear_doubles( ).
    DATA(ls_fmon) = finding( iv_no          = gc_no-fmon_error
                             iv_pe_area     = zif_cd_ops_types=>gc_pe_area-file_monitor
                             iv_object_type = zif_cd_fmon_types=>gc_object_type
                             iv_object_key  = gc_object
                             iv_severity    = zif_ca_ops_types=>gc_severity-error ).
    ls_fmon-due_date = cl_abap_context_info=>get_system_date( ) - gc_days_overdue.
    INSERT ls_fmon INTO TABLE lt_findings.
    INSERT finding( iv_no          = gc_no-ebs_block
                    iv_pe_area     = zif_cd_ops_types=>gc_pe_area-ebs
                    iv_object_type = zcl_cd_ebs_finding=>gc_object_type-statement
                    iv_object_key  = gc_feb_stmt
                    iv_severity    = zif_ca_ops_types=>gc_severity-block
                    iv_disposition = zif_ca_ops_types=>gc_disposition-assigned ) INTO TABLE lt_findings.
    INSERT finding( iv_no          = gc_no-hck_warning
                    iv_pe_area     = zif_cd_ops_types=>gc_pe_area-health_check
                    iv_object_type = zif_cd_hck_types=>gc_object_type
                    iv_object_key  = gc_object
                    iv_severity    = zif_ca_ops_types=>gc_severity-warning ) INTO TABLE lt_findings.
    INSERT finding( iv_no          = gc_no-core_closed
                    iv_pe_area     = zif_cd_ops_types=>gc_pe_area-core
                    iv_object_type = zif_cd_hck_types=>gc_object_type
                    iv_object_key  = gc_object
                    iv_severity    = zif_ca_ops_types=>gc_severity-error
                    iv_disposition = zif_ca_ops_types=>gc_disposition-resolved ) INTO TABLE lt_findings.
    INSERT finding( iv_no          = gc_no-ebs_file
                    iv_pe_area     = zif_cd_ops_types=>gc_pe_area-ebs
                    iv_object_type = zcl_cd_ebs_finding=>gc_object_type-statement
                    iv_object_key  = gc_file_stmt
                    iv_severity    = zif_ca_ops_types=>gc_severity-error ) INTO TABLE lt_findings.
    go_env->insert_test_data( i_data = lt_findings ).
  ENDMETHOD.


  METHOD open_block_and_error_only.
    TRY.
        SELECT findingno, paymentenginearea FROM zr_cd_opscritexc ORDER BY findingno INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3
                                            msg = 'FMON E, EBS B (assigned) and EBS E: open critical only' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ findingno = gc_no-hck_warning ] ) )
                                           msg = 'A warning is not critical' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ findingno = gc_no-core_closed ] ) )
                                           msg = 'A resolved exception is not open' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_rows[ findingno = gc_no-ebs_block ]-paymentenginearea OPTIONAL )
          exp = zif_cd_ops_types=>gc_pe_area-ebs msg = 'Every row carries its area (DCL)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD overdue_days_are_counted.
    TRY.
        SELECT SINGLE isoverdue, daysoverdue FROM zr_cd_opscritexc WHERE findingno = @gc_no-fmon_error
          INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The FMON exception must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isoverdue exp = abap_true msg = 'Due two days ago: overdue' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-daysoverdue exp = gc_days_overdue msg = 'Two days overdue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD bank_file_message_hidden.
    TRY.
        SELECT findingno, findingmessage FROM zr_cd_opscritexc ORDER BY findingno INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_initial( act = VALUE #( lt_rows[ findingno = gc_no-ebs_file ]-findingmessage OPTIONAL )
                                             msg = 'Bank-file statement message (may hold the account) is hidden' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_rows[ findingno = gc_no-ebs_block ]-findingmessage OPTIONAL )
                                            exp = gc_message
                                            msg = 'An imported statement (FEB key) keeps its message' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_OPSCTLDAY: the overview reads the framework's derived control rows unchanged (one truth)
CLASS ltc_control_day DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_day TYPE d VALUE '20261110'.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS counters_of_the_review FOR TESTING.
ENDCLASS.


CLASS ltc_control_day IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_OPSCTLDAY' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_reviews TYPE STANDARD TABLE OF zr_ca_opsctlreview WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_reviews = VALUE #(
      ( area = zif_cd_ops_types=>gc_pe_area-file_monitor controlid = 'PAYMENT_FILES' businessdate = gc_day
        controlstatus = zif_ca_ops_ctl_types=>gc_status-action statusrank = 2 openexceptions = 3 controlcount = 1
        actionrequiredcount = 1 flaggedcount = 1 awaitingcount = 1 isawaitingreview = abap_true isflagged = abap_true )
      ( area = zif_cd_ops_types=>gc_pe_area-health_check controlid = 'CLEARING_JOB' businessdate = gc_day
        controlstatus = zif_ca_ops_ctl_types=>gc_status-healthy controlcount = 1 reviewedcount = 1
        isreviewed = abap_true ) ).
    go_env->insert_test_data( lt_reviews ).
  ENDMETHOD.


  METHOD counters_of_the_review.
    SELECT businessdate, SUM( controlcount ) AS controls, SUM( reviewedcount ) AS reviewed,
           SUM( awaitingcount ) AS awaiting, SUM( actionrequiredcount ) AS action, SUM( openexceptions ) AS exceptions
      FROM zr_cd_opsctlday
      WHERE businessdate = @gc_day
      GROUP BY businessdate
      ORDER BY businessdate
      INTO TABLE @DATA(lt_kpi).
    DATA(ls_kpi) = VALUE #( lt_kpi[ 1 ] OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = ls_kpi-controls exp = 2 msg = 'Two controls on the date' ).
    cl_abap_unit_assert=>assert_equals( act = ls_kpi-reviewed exp = 1 msg = 'Checks reviewed 1 / 2' ).
    cl_abap_unit_assert=>assert_equals( act = ls_kpi-awaiting exp = 1 msg = 'One awaiting review' ).
    cl_abap_unit_assert=>assert_equals( act = ls_kpi-action exp = 1 msg = 'One requires action' ).
    cl_abap_unit_assert=>assert_equals( act = ls_kpi-exceptions exp = 3 msg = 'Open exceptions of the controls' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CD_PAYLIFERUN: newest non-proposal run row per payment document, live status
CLASS ltc_life_run DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        doc_rerun TYPE c LENGTH 12 VALUE '000000900001',
        doc_once  TYPE c LENGTH 12 VALUE '000000900002',
        doc_prop  TYPE c LENGTH 12 VALUE '000000900003',
        run_a     TYPE c LENGTH 6 VALUE 'RUN01',
        run_b     TYPE c LENGTH 6 VALUE 'RUN02',
        issued    TYPE c LENGTH 10 VALUE 'ISSUED',
        cleared   TYPE c LENGTH 10 VALUE 'CLEARED',
        bukrs     TYPE bukrs VALUE 'ZT01',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS newest_run_counts_once FOR TESTING.
ENDCLASS.


CLASS ltc_life_run IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CD_PAYLIFERUN' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_runs TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    go_env->clear_doubles( ).
    DATA(lv_yesterday) = CONV d( sy-datum - 1 ).
    " doc_rerun: paid yesterday (run A, ISSUED) and again today (run B, CLEARED) - counted once, today;
    " doc_once: today, ISSUED; doc_prop: only a proposal run - no payment
    lt_runs = VALUE #( ( laufd = lv_yesterday laufi = gc-run_a doc1r = gc-doc_rerun bukrs = gc-bukrs
                         zz_payment_status = gc-issued )
                       ( laufd = sy-datum laufi = gc-run_b doc1r = gc-doc_rerun bukrs = gc-bukrs
                         zz_payment_status = gc-cleared )
                       ( laufd = sy-datum laufi = gc-run_a doc1r = gc-doc_once bukrs = gc-bukrs
                         zz_payment_status = gc-issued )
                       ( laufd = sy-datum laufi = gc-run_a doc1r = gc-doc_prop bukrs = gc-bukrs xvorl = abap_true
                         zz_payment_status = gc-issued ) ).
    go_env->insert_test_data( lt_runs ).
  ENDMETHOD.


  METHOD newest_run_counts_once.
    SELECT businessdate, paymentdocument, paymentstatus FROM zi_cd_payliferun
      ORDER BY paymentdocument INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Two payments; the proposal run is none' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-businessdate exp = sy-datum
                                        msg = 'A re-run payment counts on its newest run date' ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 1 ]-paymentstatus ) exp = CONV string( gc-cleared )
                                        msg = 'Status of the newest run row' ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_PAYLIFECYCLE: configured stages pick the counted values; inactive stages are not shown
CLASS ltc_lifecycle DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        day     TYPE d VALUE '20261110',
        bukrs   TYPE c LENGTH 4 VALUE 'ZT01',
        payrun  TYPE c LENGTH 10 VALUE 'PAYRUN',
        request TYPE c LENGTH 10 VALUE 'REQUEST',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS stages_from_configuration FOR TESTING.
ENDCLASS.


CLASS ltc_lifecycle IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_PAYLIFECYCLE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_stages TYPE STANDARD TABLE OF zcd_ops_paystage WITH EMPTY KEY.
    DATA lt_counts TYPE STANDARD TABLE OF zi_cd_paylifecntu WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_stages = VALUE #( ( stage = 'PENDING' seq = 10 label = 'Pending' source = gc-request match_value = 'REQ_OPEN'
                           active = abap_true )
                         ( stage = 'ISSUED' seq = 40 label = 'Issued' source = gc-payrun match_value = 'ISSUED'
                           active = abap_true )
                         ( stage = 'STOPPED' seq = 90 label = 'Stopped' source = gc-payrun match_value = 'STOPPED' ) ).
    lt_counts = VALUE #( ( stagesource = gc-payrun businessdate = gc-day companycode = gc-bukrs matchvalue = 'ISSUED'
                           paymentcount = 1200 )
                         ( stagesource = gc-payrun businessdate = gc-day companycode = gc-bukrs matchvalue = 'STOPPED'
                           paymentcount = 2 )
                         ( stagesource = gc-request businessdate = gc-day matchvalue = 'REQ_OPEN' paymentcount = 15 )
                         ( stagesource = gc-payrun businessdate = gc-day companycode = gc-bukrs matchvalue = 'REQ_OPEN'
                           paymentcount = 99 ) ).
    go_env->insert_test_data( lt_stages ).
    go_env->insert_test_data( lt_counts ).
  ENDMETHOD.


  METHOD stages_from_configuration.
    SELECT stage, stagesequence, paymentcount FROM zr_cd_paylifecycle
      WHERE businessdate = @gc-day ORDER BY stagesequence INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Active stages only, source must match' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-paymentcount exp = 15
                                        msg = 'Pending = open requests due on the date (REQUEST source)' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-paymentcount exp = 1200
                                        msg = 'Issued = payments of the date with status ISSUED' ).
  ENDMETHOD.

ENDCLASS.


"! ZI_CD_OPSVARBANK: latest measurement of a group-day, beyond tolerance only, expected / actual
CLASS ltc_variance_leg DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        check    TYPE c LENGTH 20 VALUE 'A_RECON_3WAY',
        group    TYPE c LENGTH 35 VALUE 'ZT01/0000123456/USD',
        group_ok TYPE c LENGTH 35 VALUE 'ZT01/0000654321/USD',
        day      TYPE c LENGTH 35 VALUE '2026-11-09',
        run_old  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D1',
        run_new  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D2',
        old_at   TYPE timestampl VALUE '20261109120000.0000000',
        new_at   TYPE timestampl VALUE '20261110120000.0000000',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS latest_beyond_tolerance FOR TESTING.

    METHODS metric
      IMPORTING
        iv_run           TYPE zif_ca_ops_types=>ty_run_id
        iv_group         TYPE clike
        iv_metric        TYPE clike
        iv_value         TYPE decfloat34
        iv_at            TYPE timestampl
      RETURNING
        VALUE(rs_metric) TYPE zcd_hck_metric.
ENDCLASS.


CLASS ltc_variance_leg IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CD_OPSVARBANK' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD metric.
    rs_metric = VALUE #( run_id = iv_run check_id = gc-check metric = iv_metric dim1 = iv_group dim2 = gc-day
                         value = iv_value measured_at = iv_at ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_metrics TYPE STANDARD TABLE OF zcd_hck_metric WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " group: yesterday's run measured 500.00, today's run 120.00 (latest); bank 1000.00, G/L 880.00, tolerance 1.00
    " group_ok: today's difference 0.50 within the tolerance 1.00 - no variance
    lt_metrics = VALUE #( ( metric( iv_run = gc-run_old iv_group = gc-group iv_metric = 'RC_DIFF_BANK_GL'
                                    iv_value = '500.00' iv_at = gc-old_at ) )
                          ( metric( iv_run = gc-run_old iv_group = gc-group iv_metric = 'RC_TOLERANCE_PARAM'
                                    iv_value = '1.00' iv_at = gc-old_at ) )
                          ( metric( iv_run = gc-run_new iv_group = gc-group iv_metric = 'RC_DIFF_BANK_GL'
                                    iv_value = '120.00' iv_at = gc-new_at ) )
                          ( metric( iv_run = gc-run_new iv_group = gc-group iv_metric = 'RC_TOLERANCE_PARAM'
                                    iv_value = '1.00' iv_at = gc-new_at ) )
                          ( metric( iv_run = gc-run_new iv_group = gc-group iv_metric = 'RC_BANK'
                                    iv_value = '1000.00' iv_at = gc-new_at ) )
                          ( metric( iv_run = gc-run_new iv_group = gc-group iv_metric = 'RC_GL'
                                    iv_value = '880.00' iv_at = gc-new_at ) )
                          ( metric( iv_run = gc-run_new iv_group = gc-group_ok iv_metric = 'RC_DIFF_BANK_GL'
                                    iv_value = '0.50' iv_at = gc-new_at ) )
                          ( metric( iv_run = gc-run_new iv_group = gc-group_ok iv_metric = 'RC_TOLERANCE_SET'
                                    iv_value = '1.00' iv_at = gc-new_at ) ) ).
    go_env->insert_test_data( lt_metrics ).
  ENDMETHOD.


  METHOD latest_beyond_tolerance.
    SELECT recongroup, runid, difference, expectedamount, actualamount, recondate, findingkey
      FROM zi_cd_opsvarbank ORDER BY recongroup INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One variance: the latest run, beyond tolerance' ).
    DATA(ls_row) = lt_rows[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_row-runid exp = gc-run_new msg = 'The newer run replaces the older' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-expectedamount exp = CONV decfloat34( '1000.00' ) msg = 'Expected = bank leg' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-actualamount exp = CONV decfloat34( '880.00' ) msg = 'SAP actual = G/L leg' ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-recondate exp = CONV d( '20261109' ) msg = 'Business date = reconciled day' ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_row-findingkey )
                                        exp = |{ gc-check }/{ gc-group }/{ gc-day }/BANK|
                                        msg = 'Object key of the finding of the group-day and leg' ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_OPSVARIANCE: disposition from the exception workflow
CLASS ltc_variance DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        run TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E1',
        day TYPE d VALUE '20261109',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS disposition_from_exception FOR TESTING.
ENDCLASS.


CLASS ltc_variance IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_OPSVARIANCE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_variances TYPE STANDARD TABLE OF zi_cd_opsvaru WITH EMPTY KEY.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " G1 open break; G2 break classified TIMING; G3 classified by the check as timing; G4 resolved; G5 no finding
    lt_variances = VALUE #( FOR i = 1 UNTIL i > 5
                            ( checkid = 'A_RECON_3WAY' recongroup = |ZT01/000000000{ i }/USD| recondate = gc-day
                              leg = 'BANK' runid = gc-run expectedamount = '100.00' actualamount = '90.00'
                              findingkey = |K{ i }| ) ).
    lt_findings = VALUE #( ( run_id = gc-run finding_no = 1 area = zif_cd_ops_types=>gc_pe_area-health_check
                             object_key = 'K1' check_code = 'RECON_BREAK' disposition = zif_ca_ops_types=>gc_disposition-open )
                           ( run_id = gc-run finding_no = 2 area = zif_cd_ops_types=>gc_pe_area-health_check
                             object_key = 'K2' check_code = 'RECON_BREAK' disposition = zif_ca_ops_types=>gc_disposition-assigned
                             reason_code = zif_ca_ops_exc_types=>gc_reason_code-timing )
                           ( run_id = gc-run finding_no = 3 area = zif_cd_ops_types=>gc_pe_area-health_check
                             object_key = 'K3' check_code = 'RECON_TIMING' disposition = zif_ca_ops_types=>gc_disposition-information )
                           ( run_id = gc-run finding_no = 4 area = zif_cd_ops_types=>gc_pe_area-health_check
                             object_key = 'K4' check_code = 'RECON_BREAK' disposition = zif_ca_ops_types=>gc_disposition-resolved ) ).
    go_env->insert_test_data( lt_variances ).
    go_env->insert_test_data( lt_findings ).
  ENDMETHOD.


  METHOD disposition_from_exception.
    SELECT recongroup, variancedisposition, istiming, isunresolved, varianceamount
      FROM zr_cd_opsvariance ORDER BY recongroup INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 5 msg = 'One row per variance' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-isunresolved exp = abap_true msg = 'Open break: unresolved' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-varianceamount exp = CONV decfloat34( '-10.00' )
                                        msg = 'Variance = actual minus expected' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-istiming exp = abap_true msg = 'Classified TIMING in the exceptions app' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-isunresolved exp = abap_false msg = 'Timing is not unresolved' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-istiming exp = abap_true msg = 'Timing by the check (RECON_TIMING)' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 4 ]-isunresolved exp = abap_false msg = 'Resolved exception' ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_rows[ 5 ]-variancedisposition ) exp = `UNCLASSIFIED`
                                        msg = 'No finding: unclassified, unresolved' ).
  ENDMETHOD.

ENDCLASS.
