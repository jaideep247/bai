*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_flow_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the file monitoring dashboard on cl_cds_test_environment
*& doubles of the base tables (ZCD_FMON_FILE, ZCD_FMON_IFACE, ZCA_OPS_FINDING,
*& ZCA_OPS_RUN): flow bucket of every stage (incl. the PRISM status API stages),
*& success flag for ACK and no-ACK interfaces, measures per source / LOB /
*& payment method, SLA status from open exceptions, as-of = last completed
*& full FMON run, KPI per day and the latest-failures list; does not prove
*& live SAP runtime behavior.
*& VERIFY-ADT: create( i_select_base_dependencies = abap_true ) doubles the
*& tables behind the view stack (incl. CROSS JOIN, association paths and the
*& aggregate as-of view) on 7.58; tstmp_current_utctimestamp is not doubled.
*& Modification log:
*& 2026-11-06 | Initial version (FMON file monitoring dashboard).
*& 2026-11-06 | Modern-syntax sweep: test helper LTD_ROWS.
*& 2026-11-07 | moncfg_threshold_applies: ZCD_OPS_MONCFG threshold of FMON (base dependency doubled).
*& 2026-11-08 | Table consolidation: moncfg_threshold_applies with the definition default of
*&            | MON_STALE_AFTER_MIN_FMON and no value row (ZCA_PARAM_DEF doubled as base dependency of
*&            | ZI_CD_OpsStaleCfg).
*&---------------------------------------------------------------------*
"! Test data builders: one row per call, filled field by field (house rule)
CLASS ltd_rows DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS gc_variant_all TYPE zif_ca_ops_types=>ty_variant VALUE 'ALL'.
    CONSTANTS gc_date TYPE d VALUE '20261105'.

    CLASS-METHODS file
      IMPORTING
        iv_id          TYPE zif_cd_fmon_types=>ty_file_id
        iv_iface       TYPE zif_cd_fmon_types=>ty_iface_id
        iv_direction   TYPE zif_cd_fmon_types=>ty_direction
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
        iv_outcome     TYPE zif_cd_fmon_types=>ty_stage OPTIONAL
        iv_date        TYPE d DEFAULT gc_date
      RETURNING
        VALUE(rs_file) TYPE zcd_fmon_file.

    CLASS-METHODS iface
      IMPORTING
        iv_iface        TYPE zif_cd_fmon_types=>ty_iface_id
        iv_ack_expected TYPE abap_bool
      RETURNING
        VALUE(rs_iface) TYPE zcd_fmon_iface.

    "! Finding of a registered file: REFERENCE = file ID in hex, as ZCL_CD_FMON_UTIL=>NEW_FINDING
    CLASS-METHODS finding
      IMPORTING
        iv_file_id        TYPE zif_cd_fmon_types=>ty_file_id
        iv_finding_no     TYPE i
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
        iv_disposition    TYPE zif_ca_ops_types=>ty_disposition
        iv_pe_area        TYPE zif_ca_ops_types=>ty_area DEFAULT zif_cd_ops_types=>gc_pe_area-file_monitor
      RETURNING
        VALUE(rs_finding) TYPE zca_ops_finding.

    CLASS-METHODS run
      IMPORTING
        iv_run_id     TYPE zif_ca_ops_types=>ty_run_id
        iv_status     TYPE zif_ca_ops_types=>ty_run_status
        iv_ended_at   TYPE timestampl
        iv_variant    TYPE zif_ca_ops_types=>ty_variant DEFAULT gc_variant_all
        iv_test_mode  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_run) TYPE zca_ops_run.
ENDCLASS.


CLASS ltd_rows IMPLEMENTATION.

  METHOD file.
    rs_file-file_id       = iv_id.
    rs_file-iface_id      = iv_iface.
    rs_file-direction     = iv_direction.
    rs_file-stage         = iv_stage.
    rs_file-outcome       = iv_outcome.
    rs_file-business_date = iv_date.
    rs_file-file_name     = |{ iv_iface }_{ iv_date }_{ iv_id }|.
    rs_file-file_ref      = rs_file-file_name.
  ENDMETHOD.


  METHOD iface.
    rs_iface-iface_id     = iv_iface.
    rs_iface-ack_expected = iv_ack_expected.
    rs_iface-active       = abap_true.
  ENDMETHOD.


  METHOD finding.
    rs_finding-run_id      = iv_file_id.
    rs_finding-finding_no  = iv_finding_no.
    rs_finding-area     = iv_pe_area.
    rs_finding-object_type = zif_cd_fmon_types=>gc_object_type.
    rs_finding-object_key  = |FILE_{ iv_finding_no }|.
    rs_finding-reference   = zcl_cd_fmon_util=>file_hex( iv_file_id ).
    rs_finding-check_code  = iv_code.
    rs_finding-severity    = iv_severity.
    rs_finding-disposition = iv_disposition.
  ENDMETHOD.


  METHOD run.
    rs_run-run_id    = iv_run_id.
    rs_run-area   = zif_cd_ops_types=>gc_pe_area-file_monitor.
    rs_run-variant   = iv_variant.
    rs_run-test_mode = iv_test_mode.
    rs_run-status    = iv_status.
    rs_run-ended_at  = iv_ended_at.
    rs_run-started_at = iv_ended_at.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_FMONFLOW: bucket, success, measures, SLA status, as-of on every row
CLASS ltc_flow DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_bucket,
        received     TYPE c LENGTH 12 VALUE 'RECEIVED',
        at_prism     TYPE c LENGTH 12 VALUE 'AT_PRISM',
        sent         TYPE c LENGTH 12 VALUE 'SENT',
        processed    TYPE c LENGTH 12 VALUE 'PROCESSED',
        acknowledged TYPE c LENGTH 12 VALUE 'ACKNOWLEDGED',
        rejected     TYPE c LENGTH 12 VALUE 'REJECTED',
        partial      TYPE c LENGTH 12 VALUE 'PARTIAL',
        unknown      TYPE c LENGTH 12 VALUE 'UNKNOWN',
      END OF gc_bucket.
    CONSTANTS:
      BEGIN OF gc_sla,
        no_findings TYPE c LENGTH 12 VALUE 'NO_FINDINGS',
        breached    TYPE c LENGTH 12 VALUE 'BREACHED',
        late        TYPE c LENGTH 12 VALUE 'LATE',
        ok          TYPE c LENGTH 12 VALUE 'OK',
      END OF gc_sla.
    "! Stages of the PRISM status API (agreed values, not yet in ZIF_CD_FMON_TYPES)
    CONSTANTS:
      BEGIN OF gc_prism,
        received  TYPE zif_cd_fmon_types=>ty_stage VALUE 'PRISM_RECEIVED',
        delivered TYPE zif_cd_fmon_types=>ty_stage VALUE 'PRISM_DELIVERED',
        failed    TYPE zif_cd_fmon_types=>ty_stage VALUE 'PRISM_FAILED',
      END OF gc_prism.
    CONSTANTS gc_custom_stage TYPE zif_cd_fmon_types=>ty_stage VALUE 'CUSTOM_STAGE'.
    CONSTANTS gc_iface_ack TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_iface_noack TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'BLACKLINE_OUT'.
    CONSTANTS gc_iface_in TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'BAI_JPMC_IN'.
    CONSTANTS gc_iface_unknown TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'NOT_REGISTERED'.
    CONSTANTS gc_run_end TYPE timestampl VALUE '20261105103000'.
    CONSTANTS gc_run_id TYPE zif_ca_ops_types=>ty_run_id VALUE 'A0000000000000000000000000000001'.
    CONSTANTS:
      BEGIN OF gc_dim,
        pclm   TYPE zif_cd_fmon_types=>ty_system VALUE 'PCLM',
        base   TYPE zif_cd_fmon_types=>ty_system VALUE 'BASE',
        life   TYPE zif_cd_fmon_types=>ty_lob VALUE 'LIFE',
        pc     TYPE zif_cd_fmon_types=>ty_lob VALUE 'PC',
        ach    TYPE zif_cd_fmon_types=>ty_pay_method VALUE 'ACH',
        cheque TYPE zif_cd_fmon_types=>ty_pay_method VALUE 'CHK',
      END OF gc_dim.
    CONSTANTS:
      BEGIN OF gc_measure,
        records_1 TYPE i VALUE 10,
        records_2 TYPE i VALUE 5,
        records_3 TYPE i VALUE 7,
        total_1   TYPE zif_ca_ops_types=>ty_amount VALUE '100.50',
        total_2   TYPE zif_ca_ops_types=>ty_amount VALUE '20.25',
        total_3   TYPE zif_ca_ops_types=>ty_amount VALUE '7.00',
        nack      TYPE i VALUE 2,
      END OF gc_measure.

    TYPES:
      BEGIN OF ty_expect,
        file_id TYPE zif_cd_fmon_types=>ty_file_id,
        stage   TYPE zif_cd_fmon_types=>ty_stage,
        outcome TYPE zif_cd_fmon_types=>ty_stage,
        bucket  TYPE c LENGTH 12,
      END OF ty_expect.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    DATA mt_files TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.
    DATA mt_ifaces TYPE STANDARD TABLE OF zcd_fmon_iface WITH EMPTY KEY.
    DATA mt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA mt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.
    DATA mt_expect TYPE STANDARD TABLE OF ty_expect WITH EMPTY KEY.
    DATA mv_next_id TYPE i.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS bucket_maps_every_stage FOR TESTING.
    METHODS success_needs_ack_if_expected FOR TESTING.
    METHODS success_on_delivery_no_ack FOR TESTING.
    METHODS success_inbound_fully_only FOR TESTING.
    METHODS success_unregistered_iface FOR TESTING.
    METHODS measures_sum_per_source_lob FOR TESTING.
    METHODS sla_breached_on_missing_stage FOR TESTING.
    METHODS sla_late_on_late_finding FOR TESTING.
    METHODS sla_ok_with_other_finding FOR TESTING.
    METHODS sla_closed_findings_ignored FOR TESTING.
    METHODS breached_wins_over_late FOR TESTING.
    METHODS rows_carry_monitor_as_of FOR TESTING.

    "! Next file ID (1, 2, 3 ... in the last byte)
    METHODS new_id
      RETURNING
        VALUE(rv_id) TYPE zif_cd_fmon_types=>ty_file_id.
    METHODS add_case
      IMPORTING
        iv_direction TYPE zif_cd_fmon_types=>ty_direction
        iv_stage     TYPE zif_cd_fmon_types=>ty_stage
        iv_outcome   TYPE zif_cd_fmon_types=>ty_stage OPTIONAL
        iv_bucket    TYPE csequence.
    METHODS add_file
      IMPORTING
        iv_iface     TYPE zif_cd_fmon_types=>ty_iface_id
        iv_direction TYPE zif_cd_fmon_types=>ty_direction
        iv_stage     TYPE zif_cd_fmon_types=>ty_stage
        iv_outcome   TYPE zif_cd_fmon_types=>ty_stage OPTIONAL
        iv_nack      TYPE i DEFAULT 0
      RETURNING
        VALUE(rv_id) TYPE zif_cd_fmon_types=>ty_file_id.
    METHODS add_measured
      IMPORTING
        iv_source  TYPE zif_cd_fmon_types=>ty_system
        iv_lob     TYPE zif_cd_fmon_types=>ty_lob
        iv_method  TYPE zif_cd_fmon_types=>ty_pay_method
        iv_records TYPE i
        iv_total   TYPE zif_ca_ops_types=>ty_amount.
    METHODS add_finding
      IMPORTING
        iv_file_id     TYPE zif_cd_fmon_types=>ty_file_id
        iv_code        TYPE zif_ca_ops_types=>ty_check_code
        iv_severity    TYPE zif_ca_ops_types=>ty_severity DEFAULT zif_ca_ops_types=>gc_severity-error
        iv_disposition TYPE zif_ca_ops_types=>ty_disposition DEFAULT zif_ca_ops_types=>gc_disposition-open
        iv_pe_area     TYPE zif_ca_ops_types=>ty_area DEFAULT zif_cd_ops_types=>gc_pe_area-file_monitor.
    METHODS persist.
    METHODS success_of
      IMPORTING
        iv_id          TYPE zif_cd_fmon_types=>ty_file_id
      RETURNING
        VALUE(rv_flag) TYPE abap_bool.
    METHODS sla_of
      IMPORTING
        iv_id         TYPE zif_cd_fmon_types=>ty_file_id
      RETURNING
        VALUE(rv_sla) TYPE string.
ENDCLASS.


CLASS ltc_flow IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity               = 'ZR_CD_FMONFLOW'
                                              i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    CLEAR: mt_files, mt_ifaces, mt_findings, mt_runs, mt_expect, mv_next_id.
    INSERT ltd_rows=>iface( iv_iface = gc_iface_ack iv_ack_expected = abap_true ) INTO TABLE mt_ifaces.
    INSERT ltd_rows=>iface( iv_iface = gc_iface_noack iv_ack_expected = abap_false ) INTO TABLE mt_ifaces.
    INSERT ltd_rows=>iface( iv_iface = gc_iface_in iv_ack_expected = abap_false ) INTO TABLE mt_ifaces.
    " One completed full run: the cross join with the as-of view needs no row, but rows carry it
    INSERT ltd_rows=>run( iv_run_id   = gc_run_id
                          iv_status   = zif_ca_ops_types=>gc_run_status-success
                          iv_ended_at = gc_run_end ) INTO TABLE mt_runs.
  ENDMETHOD.


  METHOD new_id.
    mv_next_id = mv_next_id + 1.
    rv_id = CONV xstring( |{ mv_next_id ALIGN = RIGHT PAD = '0' WIDTH = 32 }| ).
  ENDMETHOD.


  METHOD add_case.
    DATA ls_expect TYPE ty_expect.
    ls_expect-file_id = add_file( iv_iface     = COND #( WHEN iv_direction = zif_cd_fmon_types=>gc_direction-inbound
                                                         THEN gc_iface_in ELSE gc_iface_ack )
                                  iv_direction = iv_direction
                                  iv_stage     = iv_stage
                                  iv_outcome   = iv_outcome ).
    ls_expect-stage   = iv_stage.
    ls_expect-outcome = iv_outcome.
    ls_expect-bucket  = iv_bucket.
    INSERT ls_expect INTO TABLE mt_expect.
  ENDMETHOD.


  METHOD add_file.
    rv_id = new_id( ).
    DATA(ls_file) = ltd_rows=>file( iv_id        = rv_id
                                    iv_iface     = iv_iface
                                    iv_direction = iv_direction
                                    iv_stage     = iv_stage
                                    iv_outcome   = iv_outcome ).
    ls_file-nack_count = iv_nack.
    INSERT ls_file INTO TABLE mt_files.
  ENDMETHOD.


  METHOD add_measured.
    DATA(lv_id) = add_file( iv_iface     = gc_iface_ack
                            iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                            iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
    ASSIGN mt_files[ file_id = lv_id ] TO FIELD-SYMBOL(<ls_file>).
    <ls_file>-source_sys    = iv_source.
    <ls_file>-lob           = iv_lob.
    <ls_file>-pay_method    = iv_method.
    <ls_file>-record_count  = iv_records.
    <ls_file>-control_total = iv_total.
  ENDMETHOD.


  METHOD add_finding.
    INSERT ltd_rows=>finding( iv_file_id     = iv_file_id
                              iv_finding_no  = lines( mt_findings ) + 1
                              iv_code        = iv_code
                              iv_severity    = iv_severity
                              iv_disposition = iv_disposition
                              iv_pe_area     = iv_pe_area ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD persist.
    IF mt_files IS NOT INITIAL.
      go_env->insert_test_data( i_data = mt_files ).
    ENDIF.
    IF mt_ifaces IS NOT INITIAL.
      go_env->insert_test_data( i_data = mt_ifaces ).
    ENDIF.
    IF mt_findings IS NOT INITIAL.
      go_env->insert_test_data( i_data = mt_findings ).
    ENDIF.
    IF mt_runs IS NOT INITIAL.
      go_env->insert_test_data( i_data = mt_runs ).
    ENDIF.
  ENDMETHOD.


  METHOD success_of.
    SELECT SINGLE issuccess FROM zr_cd_fmonflow WHERE fileid = @iv_id INTO @rv_flag.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |File { iv_id } must be on the dashboard| ).
  ENDMETHOD.


  METHOD sla_of.
    SELECT SINGLE slastatus FROM zr_cd_fmonflow WHERE fileid = @iv_id INTO @DATA(lv_sla).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |File { iv_id } must be on the dashboard| ).
    rv_sla = condense( lv_sla ).
  ENDMETHOD.


  METHOD bucket_maps_every_stage.
    TRY.
        DATA(lv_out) = zif_cd_fmon_types=>gc_direction-outbound.
        DATA(lv_in) = zif_cd_fmon_types=>gc_direction-inbound.
        add_case( iv_direction = lv_out iv_stage = zif_cd_fmon_types=>gc_stage-generated iv_bucket = gc_bucket-received ).
        add_case( iv_direction = lv_out iv_stage = zif_cd_fmon_types=>gc_stage-sent iv_bucket = gc_bucket-sent ).
        add_case( iv_direction = lv_out iv_stage = zif_cd_fmon_types=>gc_stage-forwarded iv_bucket = gc_bucket-sent ).
        add_case( iv_direction = lv_out iv_stage = zif_cd_fmon_types=>gc_stage-ack
                  iv_outcome   = zif_cd_fmon_types=>gc_stage-ack iv_bucket = gc_bucket-acknowledged ).
        add_case( iv_direction = lv_out iv_stage = zif_cd_fmon_types=>gc_stage-nack
                  iv_outcome   = zif_cd_fmon_types=>gc_stage-nack iv_bucket = gc_bucket-rejected ).
        add_case( iv_direction = lv_in iv_stage = zif_cd_fmon_types=>gc_stage-received iv_bucket = gc_bucket-received ).
        add_case( iv_direction = lv_in iv_stage = zif_cd_fmon_types=>gc_stage-loaded iv_bucket = gc_bucket-processed ).
        add_case( iv_direction = lv_in iv_stage = zif_cd_fmon_types=>gc_stage-fully
                  iv_outcome   = zif_cd_fmon_types=>gc_stage-fully iv_bucket = gc_bucket-processed ).
        add_case( iv_direction = lv_in iv_stage = zif_cd_fmon_types=>gc_stage-loaded
                  iv_outcome   = zif_cd_fmon_types=>gc_stage-partially iv_bucket = gc_bucket-partial ).
        add_case( iv_direction = lv_in iv_stage = zif_cd_fmon_types=>gc_stage-loaded
                  iv_outcome   = zif_cd_fmon_types=>gc_stage-failed iv_bucket = gc_bucket-rejected ).
        " PRISM status API stages (inactive until the API writes them)
        add_case( iv_direction = lv_out iv_stage = gc_prism-received iv_bucket = gc_bucket-at_prism ).
        add_case( iv_direction = lv_in iv_stage = gc_prism-received iv_bucket = gc_bucket-at_prism ).
        add_case( iv_direction = lv_out iv_stage = gc_prism-delivered iv_bucket = gc_bucket-sent ).
        add_case( iv_direction = lv_in iv_stage = gc_prism-delivered iv_bucket = gc_bucket-received ).
        add_case( iv_direction = lv_out iv_stage = gc_prism-failed iv_bucket = gc_bucket-rejected ).
        add_case( iv_direction = lv_out iv_stage = zif_cd_fmon_types=>gc_stage-sent
                  iv_outcome   = gc_prism-failed iv_bucket = gc_bucket-rejected ).
        add_case( iv_direction = lv_out iv_stage = gc_custom_stage iv_bucket = gc_bucket-unknown ).
        persist( ).

        SELECT fileid, flowbucket FROM zr_cd_fmonflow ORDER BY fileid INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = lines( mt_expect )
                                            msg = 'Every file must appear exactly once' ).
        LOOP AT mt_expect INTO DATA(ls_expect).
          cl_abap_unit_assert=>assert_equals(
            act = VALUE #( lt_rows[ fileid = ls_expect-file_id ]-flowbucket OPTIONAL )
            exp = ls_expect-bucket
            msg = |Stage { ls_expect-stage } / outcome { ls_expect-outcome } must map to { ls_expect-bucket }| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD success_needs_ack_if_expected.
    TRY.
        DATA(lv_sent) = add_file( iv_iface     = gc_iface_ack
                                  iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                  iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
        DATA(lv_acked) = add_file( iv_iface     = gc_iface_ack
                                   iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                   iv_stage     = zif_cd_fmon_types=>gc_stage-ack
                                   iv_outcome   = zif_cd_fmon_types=>gc_stage-ack ).
        DATA(lv_part_nack) = add_file( iv_iface     = gc_iface_ack
                                       iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                       iv_stage     = zif_cd_fmon_types=>gc_stage-ack
                                       iv_outcome   = zif_cd_fmon_types=>gc_stage-ack
                                       iv_nack      = gc_measure-nack ).
        persist( ).

        cl_abap_unit_assert=>assert_equals( act = success_of( lv_sent ) exp = abap_false
                                            msg = 'ACK expected: a sent file is not yet successful' ).
        cl_abap_unit_assert=>assert_equals( act = success_of( lv_acked ) exp = abap_true
                                            msg = 'ACK expected: an acknowledged file is successful' ).
        cl_abap_unit_assert=>assert_equals( act = success_of( lv_part_nack ) exp = abap_false
                                            msg = 'A payment-level NACK after the ACK is not a success' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD success_on_delivery_no_ack.
    TRY.
        DATA(lv_sent) = add_file( iv_iface     = gc_iface_noack
                                  iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                  iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
        DATA(lv_delivered) = add_file( iv_iface     = gc_iface_noack
                                       iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                       iv_stage     = gc_prism-delivered ).
        DATA(lv_generated) = add_file( iv_iface     = gc_iface_noack
                                       iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                       iv_stage     = zif_cd_fmon_types=>gc_stage-generated ).
        DATA(lv_failed) = add_file( iv_iface     = gc_iface_noack
                                    iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                    iv_stage     = zif_cd_fmon_types=>gc_stage-sent
                                    iv_outcome   = gc_prism-failed ).
        persist( ).

        cl_abap_unit_assert=>assert_equals( act = success_of( lv_sent ) exp = abap_true
                                            msg = 'No ACK expected: sent to PRISM is the success' ).
        cl_abap_unit_assert=>assert_equals( act = success_of( lv_delivered ) exp = abap_true
                                            msg = 'No ACK expected: delivered by PRISM is a success' ).
        cl_abap_unit_assert=>assert_equals( act = success_of( lv_generated ) exp = abap_false
                                            msg = 'Generated only is not delivered' ).
        cl_abap_unit_assert=>assert_equals( act = success_of( lv_failed ) exp = abap_false
                                            msg = 'PRISM_FAILED is never a success' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD success_inbound_fully_only.
    TRY.
        DATA(lv_fully) = add_file( iv_iface     = gc_iface_in
                                   iv_direction = zif_cd_fmon_types=>gc_direction-inbound
                                   iv_stage     = zif_cd_fmon_types=>gc_stage-fully
                                   iv_outcome   = zif_cd_fmon_types=>gc_stage-fully ).
        DATA(lv_partial) = add_file( iv_iface     = gc_iface_in
                                     iv_direction = zif_cd_fmon_types=>gc_direction-inbound
                                     iv_stage     = zif_cd_fmon_types=>gc_stage-loaded
                                     iv_outcome   = zif_cd_fmon_types=>gc_stage-partially ).
        DATA(lv_loaded) = add_file( iv_iface     = gc_iface_in
                                    iv_direction = zif_cd_fmon_types=>gc_direction-inbound
                                    iv_stage     = zif_cd_fmon_types=>gc_stage-loaded ).
        persist( ).

        cl_abap_unit_assert=>assert_equals( act = success_of( lv_fully ) exp = abap_true
                                            msg = 'Inbound fully processed is a success' ).
        cl_abap_unit_assert=>assert_equals( act = success_of( lv_partial ) exp = abap_false
                                            msg = 'Inbound partially processed is not a success' ).
        cl_abap_unit_assert=>assert_equals( act = success_of( lv_loaded ) exp = abap_false
                                            msg = 'Inbound loaded only is not a success' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD success_unregistered_iface.
    TRY.
        DATA(lv_sent) = add_file( iv_iface     = gc_iface_unknown
                                  iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                  iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
        persist( ).

        cl_abap_unit_assert=>assert_equals( act = success_of( lv_sent ) exp = abap_false
                                            msg = 'Interface without a row: ACK assumed, sent is no success' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD measures_sum_per_source_lob.
    TRY.
        add_measured( iv_source = gc_dim-pclm iv_lob = gc_dim-life iv_method = gc_dim-ach
                      iv_records = gc_measure-records_1 iv_total = gc_measure-total_1 ).
        add_measured( iv_source = gc_dim-pclm iv_lob = gc_dim-life iv_method = gc_dim-ach
                      iv_records = gc_measure-records_2 iv_total = gc_measure-total_2 ).
        add_measured( iv_source = gc_dim-base iv_lob = gc_dim-pc iv_method = gc_dim-cheque
                      iv_records = gc_measure-records_3 iv_total = gc_measure-total_3 ).
        persist( ).

        SELECT sourcesystem, lob, paymentmethod,
               SUM( filecount ) AS files, SUM( recordcount ) AS records, SUM( controltotal ) AS total
          FROM zr_cd_fmonflow
          GROUP BY sourcesystem, lob, paymentmethod
          ORDER BY sourcesystem, lob, paymentmethod
          INTO TABLE @DATA(lt_groups).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_groups ) exp = 2
                                            msg = 'One group per source / LOB / payment method' ).
        DATA(ls_pclm) = VALUE #( lt_groups[ sourcesystem = gc_dim-pclm ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_pclm-files exp = 2 msg = 'PCLM / LIFE / ACH: two files' ).
        cl_abap_unit_assert=>assert_equals( act = ls_pclm-records exp = gc_measure-records_1 + gc_measure-records_2
                                            msg = 'Records add up per group' ).
        cl_abap_unit_assert=>assert_equals( act = ls_pclm-total exp = gc_measure-total_1 + gc_measure-total_2
                                            msg = 'Control totals add up per group' ).
        DATA(ls_base) = VALUE #( lt_groups[ sourcesystem = gc_dim-base ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_base-records exp = gc_measure-records_3
                                            msg = 'BASE / PC / CHK keeps its own records' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD sla_breached_on_missing_stage.
    TRY.
        DATA(lv_id) = add_file( iv_iface     = gc_iface_ack
                                iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
        add_finding( iv_file_id = lv_id iv_code = zif_cd_fmon_types=>gc_check_code-no_bank_ack ).
        persist( ).

        cl_abap_unit_assert=>assert_equals( act = sla_of( lv_id ) exp = gc_sla-breached
                                            msg = 'An open NO_<stage> exception breaches the SLA' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD sla_late_on_late_finding.
    TRY.
        DATA(lv_id) = add_file( iv_iface     = gc_iface_ack
                                iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                iv_stage     = zif_cd_fmon_types=>gc_stage-ack
                                iv_outcome   = zif_cd_fmon_types=>gc_stage-ack ).
        add_finding( iv_file_id  = lv_id
                     iv_code     = zif_cd_fmon_types=>gc_check_code-bank_ack_late
                     iv_severity = zif_ca_ops_types=>gc_severity-warning ).
        persist( ).

        cl_abap_unit_assert=>assert_equals( act = sla_of( lv_id ) exp = gc_sla-late
                                            msg = 'An open <stage>_LATE exception makes the file late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD sla_ok_with_other_finding.
    TRY.
        DATA(lv_id) = add_file( iv_iface     = gc_iface_ack
                                iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                iv_stage     = zif_cd_fmon_types=>gc_stage-ack
                                iv_outcome   = zif_cd_fmon_types=>gc_stage-ack ).
        add_finding( iv_file_id = lv_id iv_code = zif_cd_fmon_types=>gc_check_code-ack_count ).
        persist( ).

        SELECT SINGLE slastatus, openfindingcount, worstseverity FROM zr_cd_fmonflow
          WHERE fileid = @lv_id INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The row must exist' ).

        cl_abap_unit_assert=>assert_equals( act = condense( CONV string( ls_row-slastatus ) ) exp = gc_sla-ok
                                            msg = 'Open exceptions that are not about the SLA leave it OK' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-openfindingcount exp = 1 msg = 'One open exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-worstseverity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Worst open severity is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD sla_closed_findings_ignored.
    TRY.
        DATA(lv_id) = add_file( iv_iface     = gc_iface_ack
                                iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
        add_finding( iv_file_id     = lv_id
                     iv_code        = zif_cd_fmon_types=>gc_check_code-no_bank_ack
                     iv_disposition = zif_ca_ops_types=>gc_disposition-resolved ).
        add_finding( iv_file_id     = lv_id
                     iv_code        = zif_cd_fmon_types=>gc_check_code-no_bank_ack
                     iv_disposition = zif_ca_ops_types=>gc_disposition-superseded ).
        add_finding( iv_file_id     = lv_id
                     iv_code        = zif_cd_fmon_types=>gc_check_code-no_bank_ack
                     iv_disposition = zif_ca_ops_types=>gc_disposition-waived ).
        add_finding( iv_file_id     = lv_id
                     iv_code        = zif_cd_fmon_types=>gc_check_code-no_bank_ack
                     iv_disposition = zif_ca_ops_types=>gc_disposition-information ).
        " same reference, other payment engine area: not an FMON exception
        add_finding( iv_file_id = lv_id
                     iv_code    = zif_cd_fmon_types=>gc_check_code-no_bank_ack
                     iv_pe_area = zif_cd_ops_types=>gc_pe_area-health_check ).
        persist( ).

        cl_abap_unit_assert=>assert_equals( act = sla_of( lv_id ) exp = gc_sla-no_findings
                                            msg = 'Resolved, superseded, waived, info and other areas do not count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD breached_wins_over_late.
    TRY.
        DATA(lv_id) = add_file( iv_iface     = gc_iface_ack
                                iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
        add_finding( iv_file_id     = lv_id
                     iv_code        = zif_cd_fmon_types=>gc_check_code-prism_late
                     iv_severity    = zif_ca_ops_types=>gc_severity-warning
                     iv_disposition = zif_ca_ops_types=>gc_disposition-assigned ).
        add_finding( iv_file_id = lv_id iv_code = zif_cd_fmon_types=>gc_check_code-no_bank_ack ).
        persist( ).

        SELECT SINGLE slastatus, openfindingcount, breachedfilecount, latefilecount FROM zr_cd_fmonflow
          WHERE fileid = @lv_id INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The row must exist' ).

        cl_abap_unit_assert=>assert_equals( act = condense( CONV string( ls_row-slastatus ) ) exp = gc_sla-breached
                                            msg = 'Breached outranks late' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-openfindingcount exp = 2
                                            msg = 'Open and assigned exceptions both count' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-breachedfilecount + ls_row-latefilecount exp = 1
                                            msg = 'A file counts once: breached, not also late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD rows_carry_monitor_as_of.
    TRY.
        DATA(lv_id) = add_file( iv_iface     = gc_iface_ack
                                iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                                iv_stage     = zif_cd_fmon_types=>gc_stage-sent ).
        persist( ).

        SELECT SINGLE asofat, asofrunid FROM zr_cd_fmonflow WHERE fileid = @lv_id INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The row must exist' ).

        cl_abap_unit_assert=>assert_equals( act = ls_row-asofat exp = gc_run_end
                                            msg = 'Every row carries the end of the last completed run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-asofrunid exp = gc_run_id
                                            msg = 'Every row names the run it is as of' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_FMONASOF: as of = end of the last completed full FMON run; stale flag
CLASS ltc_as_of DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_t1 TYPE timestampl VALUE '20261105080000'.
    CONSTANTS gc_t2 TYPE timestampl VALUE '20261105083000'.
    CONSTANTS gc_t3 TYPE timestampl VALUE '20261105090000'.
    CONSTANTS gc_t4 TYPE timestampl VALUE '20261105093000'.
    CONSTANTS gc_t5 TYPE timestampl VALUE '20261105100000'.
    CONSTANTS gc_t_old TYPE timestampl VALUE '20200101000000'.
    CONSTANTS gc_iface_variant TYPE zif_ca_ops_types=>ty_variant VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_stale_minutes TYPE i VALUE 15.
    CONSTANTS:
      BEGIN OF gc_run,
        r1 TYPE zif_ca_ops_types=>ty_run_id VALUE 'B0000000000000000000000000000001',
        r2 TYPE zif_ca_ops_types=>ty_run_id VALUE 'B0000000000000000000000000000002',
        r3 TYPE zif_ca_ops_types=>ty_run_id VALUE 'B0000000000000000000000000000003',
        r4 TYPE zif_ca_ops_types=>ty_run_id VALUE 'B0000000000000000000000000000004',
        r5 TYPE zif_ca_ops_types=>ty_run_id VALUE 'B0000000000000000000000000000005',
      END OF gc_run.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    DATA mt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS as_of_skips_running_and_abort FOR TESTING.
    METHODS as_of_skips_test_and_iface_run FOR TESTING.
    METHODS stale_when_no_completed_run FOR TESTING.
    METHODS stale_when_run_is_old FOR TESTING.
    METHODS moncfg_threshold_applies FOR TESTING.
    METHODS fresh_run_is_not_stale FOR TESTING.

    METHODS add_run
      IMPORTING
        iv_run_id    TYPE zif_ca_ops_types=>ty_run_id
        iv_status    TYPE zif_ca_ops_types=>ty_run_status
        iv_ended_at  TYPE timestampl
        iv_variant   TYPE zif_ca_ops_types=>ty_variant DEFAULT ltd_rows=>gc_variant_all
        iv_test_mode TYPE abap_bool DEFAULT abap_false.
    METHODS persist.
ENDCLASS.


CLASS ltc_as_of IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity               = 'ZR_CD_FMONASOF'
                                              i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    CLEAR mt_runs.
  ENDMETHOD.


  METHOD add_run.
    INSERT ltd_rows=>run( iv_run_id    = iv_run_id
                          iv_status    = iv_status
                          iv_ended_at  = iv_ended_at
                          iv_variant   = iv_variant
                          iv_test_mode = iv_test_mode ) INTO TABLE mt_runs.
  ENDMETHOD.


  METHOD persist.
    IF mt_runs IS NOT INITIAL.
      go_env->insert_test_data( i_data = mt_runs ).
    ENDIF.
  ENDMETHOD.


  METHOD as_of_skips_running_and_abort.
    TRY.
        add_run( iv_run_id = gc_run-r1 iv_status = zif_ca_ops_types=>gc_run_status-success iv_ended_at = gc_t1 ).
        add_run( iv_run_id = gc_run-r2 iv_status = zif_ca_ops_types=>gc_run_status-error iv_ended_at = gc_t2 ).
        add_run( iv_run_id = gc_run-r3 iv_status = zif_ca_ops_types=>gc_run_status-aborted iv_ended_at = gc_t3 ).
        add_run( iv_run_id = gc_run-r4 iv_status = zif_ca_ops_types=>gc_run_status-running iv_ended_at = gc_t4 ).
        persist( ).

        SELECT runid, asofat, runstatus FROM zr_cd_fmonasof ORDER BY runid INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'The as-of view has one row' ).
        DATA(ls_row) = VALUE #( lt_rows[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-asofat exp = gc_t2
                                            msg = 'As of = end of the last completed run, not aborted / running' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-runid exp = gc_run-r2 msg = 'The completed run is named' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-runstatus exp = zif_ca_ops_types=>gc_run_status-error
                                            msg = 'A run that finished with error findings is completed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD as_of_skips_test_and_iface_run.
    TRY.
        add_run( iv_run_id = gc_run-r1 iv_status = zif_ca_ops_types=>gc_run_status-warning iv_ended_at = gc_t1 ).
        add_run( iv_run_id    = gc_run-r2
                 iv_status    = zif_ca_ops_types=>gc_run_status-success
                 iv_ended_at  = gc_t2
                 iv_test_mode = abap_true ).
        add_run( iv_run_id   = gc_run-r5
                 iv_status   = zif_ca_ops_types=>gc_run_status-success
                 iv_ended_at = gc_t5
                 iv_variant  = gc_iface_variant ).
        persist( ).

        SELECT SINGLE runid, asofat FROM zr_cd_fmonasof INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The row must exist' ).

        cl_abap_unit_assert=>assert_equals( act = ls_row-asofat exp = gc_t1
                                            msg = 'Test-mode and single-interface runs do not advance the as-of' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-runid exp = gc_run-r1 msg = 'The full run is named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD stale_when_no_completed_run.
    TRY.
        add_run( iv_run_id = gc_run-r3 iv_status = zif_ca_ops_types=>gc_run_status-aborted iv_ended_at = gc_t3 ).
        persist( ).

        SELECT asofat, isstale FROM zr_cd_fmonasof ORDER BY asofat INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1
                                            msg = 'One row also without a completed run' ).
        DATA(ls_row) = VALUE #( lt_rows[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_initial( act = ls_row-asofat msg = 'No completed run: no as-of time' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_true
                                            msg = 'No completed run is stale, never quiet traffic' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD stale_when_run_is_old.
    TRY.
        add_run( iv_run_id = gc_run-r1 iv_status = zif_ca_ops_types=>gc_run_status-success iv_ended_at = gc_t_old ).
        persist( ).

        SELECT SINGLE isstale, ageminutes FROM zr_cd_fmonasof INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The row must exist' ).

        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_true msg = 'An old run is stale' ).
        cl_abap_unit_assert=>assert_number_between( lower = gc_stale_minutes upper = cl_abap_math=>max_int4
                                                    number = ls_row-ageminutes
                                                    msg = 'The age of an old run exceeds the threshold' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the definition default of MON_STALE_AFTER_MIN_FMON decides when no value row is maintained
  " (here a landscape definition of 600 minutes; table consolidation 2026-11-08, was ZCD_OPS_MONCFG):
  " a run two hours old is not stale, although the CDS fallback 15 minutes would make it stale
  METHOD moncfg_threshold_applies.
    CONSTANTS lc_minutes TYPE i VALUE 600.
    CONSTANTS lc_two_hours TYPE i VALUE 7200.
    DATA lt_def TYPE STANDARD TABLE OF zca_param_def WITH EMPTY KEY.
    DATA ls_def TYPE zca_param_def.
    TRY.
        GET TIME STAMP FIELD DATA(lv_now).
        add_run( iv_run_id   = gc_run-r1
                 iv_status   = zif_ca_ops_types=>gc_run_status-success
                 iv_ended_at = cl_abap_tstmp=>subtractsecs( tstmp = CONV timestampl( lv_now ) secs = lc_two_hours ) ).
        persist( ).
        ls_def-area          = zif_cd_ops_types=>gc_param_area-ops.
        ls_def-name          = |{ zif_cd_ops_types=>gc_param_prefix-stale_after_min }{
                                  zif_cd_ops_types=>gc_pe_area-file_monitor }|.
        ls_def-kind          = zif_ca_param_types=>gc_kind-single.
        ls_def-value_type    = zif_ca_param_types=>gc_value_type-int.
        ls_def-default_value = |{ lc_minutes }|.
        INSERT ls_def INTO TABLE lt_def.
        go_env->insert_test_data( i_data = lt_def ).

        SELECT SINGLE isstale, staleafterminutes FROM zr_cd_fmonasof INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The row must exist' ).

        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_false
                                            msg = 'Within the configured 600 minutes: not stale' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-staleafterminutes exp = lc_minutes
                                            msg = 'The configured threshold is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD fresh_run_is_not_stale.
    TRY.
        GET TIME STAMP FIELD DATA(lv_now).
        add_run( iv_run_id   = gc_run-r1
                 iv_status   = zif_ca_ops_types=>gc_run_status-success
                 iv_ended_at = CONV timestampl( lv_now ) ).
        persist( ).

        SELECT SINGLE isstale, ageminutes FROM zr_cd_fmonasof INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The row must exist' ).

        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_false
                                            msg = 'A run that ended just now is not stale' ).
        cl_abap_unit_assert=>assert_number_between( lower = 0 upper = gc_stale_minutes number = ls_row-ageminutes
                                                    msg = 'The age of a fresh run is below the threshold' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_FMONFLOWKPI / ZR_CD_FMONFLOWFAIL: counts per business date, latest-failures list
CLASS ltc_kpi DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_day_1 TYPE d VALUE '20261104'.
    CONSTANTS gc_day_2 TYPE d VALUE '20261105'.
    CONSTANTS gc_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_iface_in TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_RET_PNC_IN'.
    CONSTANTS gc_unprocessed TYPE i VALUE 3.
    CONSTANTS:
      BEGIN OF gc_id,
        rejected TYPE zif_cd_fmon_types=>ty_file_id VALUE 'C0000000000000000000000000000001',
        acked    TYPE zif_cd_fmon_types=>ty_file_id VALUE 'C0000000000000000000000000000002',
        partial  TYPE zif_cd_fmon_types=>ty_file_id VALUE 'C0000000000000000000000000000003',
        sent     TYPE zif_cd_fmon_types=>ty_file_id VALUE 'C0000000000000000000000000000004',
      END OF gc_id.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS kpi_counts_buckets_per_day FOR TESTING.
    METHODS failures_list_bad_files_only FOR TESTING.

    METHODS insert_scenario.
ENDCLASS.


CLASS ltc_kpi IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_CD_FMONFLOWKPI' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_FMONFLOWFAIL' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
  ENDMETHOD.


  METHOD insert_scenario.
    DATA lt_files TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.
    DATA lt_ifaces TYPE STANDARD TABLE OF zcd_fmon_iface WITH EMPTY KEY.

    INSERT ltd_rows=>iface( iv_iface = gc_iface iv_ack_expected = abap_true ) INTO TABLE lt_ifaces.
    INSERT ltd_rows=>iface( iv_iface = gc_iface_in iv_ack_expected = abap_false ) INTO TABLE lt_ifaces.
    INSERT ltd_rows=>file( iv_id        = gc_id-rejected
                           iv_iface     = gc_iface
                           iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                           iv_stage     = zif_cd_fmon_types=>gc_stage-nack
                           iv_outcome   = zif_cd_fmon_types=>gc_stage-nack
                           iv_date      = gc_day_1 ) INTO TABLE lt_files.
    INSERT ltd_rows=>file( iv_id        = gc_id-acked
                           iv_iface     = gc_iface
                           iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                           iv_stage     = zif_cd_fmon_types=>gc_stage-ack
                           iv_outcome   = zif_cd_fmon_types=>gc_stage-ack
                           iv_date      = gc_day_1 ) INTO TABLE lt_files.
    DATA(ls_partial) = ltd_rows=>file( iv_id        = gc_id-partial
                                       iv_iface     = gc_iface_in
                                       iv_direction = zif_cd_fmon_types=>gc_direction-inbound
                                       iv_stage     = zif_cd_fmon_types=>gc_stage-loaded
                                       iv_outcome   = zif_cd_fmon_types=>gc_stage-partially
                                       iv_date      = gc_day_1 ).
    ls_partial-unprocessed_count = gc_unprocessed.
    INSERT ls_partial INTO TABLE lt_files.
    INSERT ltd_rows=>file( iv_id        = gc_id-sent
                           iv_iface     = gc_iface
                           iv_direction = zif_cd_fmon_types=>gc_direction-outbound
                           iv_stage     = zif_cd_fmon_types=>gc_stage-sent
                           iv_date      = gc_day_2 ) INTO TABLE lt_files.
    go_env->insert_test_data( i_data = lt_files ).
    go_env->insert_test_data( i_data = lt_ifaces ).
  ENDMETHOD.


  METHOD kpi_counts_buckets_per_day.
    TRY.
        insert_scenario( ).

        SELECT businessdate, filecount, rejectedfilecount, ackfilecount, partialfilecount,
               intransitfilecount, unprocessedfilecount, unprocessedcount, successfilecount
          FROM zr_cd_fmonflowkpi
          ORDER BY businessdate
          INTO TABLE @DATA(lt_days).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 2 msg = 'One KPI row per business date' ).
        DATA(ls_day_1) = VALUE #( lt_days[ businessdate = gc_day_1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_1-filecount exp = 3 msg = 'Day 1: three files' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_1-rejectedfilecount exp = 1 msg = 'Day 1: one rejected' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_1-ackfilecount exp = 1 msg = 'Day 1: one acknowledged' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_1-partialfilecount exp = 1 msg = 'Day 1: one partial' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_1-successfilecount exp = 1 msg = 'Day 1: one success' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_1-unprocessedfilecount exp = 1
                                            msg = 'Day 1: one file with unprocessed items' ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_1-unprocessedcount exp = gc_unprocessed
                                            msg = 'Day 1: unprocessed items add up' ).
        DATA(ls_day_2) = VALUE #( lt_days[ businessdate = gc_day_2 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_day_2-intransitfilecount exp = 1 msg = 'Day 2: one in transit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD failures_list_bad_files_only.
    TRY.
        insert_scenario( ).

        SELECT fileid FROM zr_cd_fmonflowfail ORDER BY fileid INTO TABLE @DATA(lt_failed).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_failed ) exp = 2
                                            msg = 'Only rejected and partial files are failures' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_failed[ fileid = gc_id-rejected ] ) )
                                          msg = 'The rejected file is listed' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_failed[ fileid = gc_id-partial ] ) )
                                          msg = 'The partially processed file is listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
