*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_dash_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the area dashboard (ZR_CA_OpsCheckStatus) on
*& cl_cds_test_environment doubles of its direct dependencies: the overview
*& card counters - one registered check per area-level slice (a company-code
*& slice never counts a check twice), stale only on the area-level slice,
*& flagged per slice with an open exception, needs attention = open exception
*& or stale; a fresh check without exceptions needs no attention. Does not
*& prove live SAP runtime behavior. VERIFY-ADT: doubles of CDS view
*& dependencies (7.58).
*& Modification log:
*& 2026-11-10 | Initial version (overview card of the area dashboard).
*&---------------------------------------------------------------------*
"! ZR_CA_OPSCHECKSTATUS: counters of the overview cards
CLASS ltc_counters DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area       TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        process    TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_PROC',
        flagged    TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_C1_FLAGGED',
        stale      TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_C2_STALE',
        healthy    TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_C3_HEALTHY',
        daily      TYPE zif_ca_ops_chk_types=>ty_sched_group VALUE 'ZT_DAILY',
        hourly     TYPE zif_ca_ops_chk_types=>ty_sched_group VALUE 'ZT_HOURLY',
        bukrs      TYPE bukrs VALUE 'ZT01',
        fresh_run  TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D1',
        old_run    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D2',
        old_start  TYPE timestampl VALUE '20200101000000.0000000',
        stale_min  TYPE i VALUE 60,
        rank_watch TYPE i VALUE 1,
        rank_error TYPE i VALUE 2,
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS one_check_per_area_slice FOR TESTING.
    METHODS stale_on_area_slice_only FOR TESTING.
    METHODS attention_flag FOR TESTING.
ENDCLASS.


CLASS ltc_counters IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CA_OPSCHECKSTATUS' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_checks TYPE STANDARD TABLE OF zca_ops_check WITH EMPTY KEY.
    DATA lt_slices TYPE STANDARD TABLE OF zi_ca_opschkslice WITH EMPTY KEY.
    DATA lt_open TYPE STANDARD TABLE OF zi_ca_opschkopen WITH EMPTY KEY.
    DATA lt_last TYPE STANDARD TABLE OF zi_ca_opschklast WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.
    DATA lt_stale TYPE STANDARD TABLE OF zi_ca_opschkstaled WITH EMPTY KEY.
    DATA lv_now TYPE timestampl.

    go_env->clear_doubles( ).
    GET TIME STAMP FIELD lv_now.
    " Flagged and healthy run in the fresh daily group, the stale check in an hourly group last run in 2020
    lt_checks = VALUE #( active = abap_true area = gc-area process_id = gc-process
                         ( check_id = gc-flagged sched_group = gc-daily bukrs_aware = abap_true )
                         ( check_id = gc-stale   sched_group = gc-hourly )
                         ( check_id = gc-healthy sched_group = gc-daily ) ).
    lt_slices = VALUE #( area = gc-area
                         ( checkid = gc-flagged )
                         ( checkid = gc-flagged companycode = gc-bukrs )
                         ( checkid = gc-stale )
                         ( checkid = gc-healthy ) ).
    lt_open = VALUE #( area = gc-area checkid = gc-flagged
                       ( openexceptions = 1 worstrank = gc-rank_watch )
                       ( companycode = gc-bukrs openexceptions = 2 worstrank = gc-rank_error ) ).
    lt_last = VALUE #( area = gc-area
                       ( variant = gc-daily  lastrunat = lv_now )
                       ( variant = gc-hourly lastrunat = gc-old_start ) ).
    lt_runs = VALUE #( area = gc-area
                       ( run_id = gc-fresh_run variant = gc-daily started_at = lv_now
                         status = zif_ca_ops_types=>gc_run_status-success rag = zif_ca_ops_types=>gc_rag-green )
                       ( run_id = gc-old_run variant = gc-hourly started_at = gc-old_start
                         status = zif_ca_ops_types=>gc_run_status-success rag = zif_ca_ops_types=>gc_rag-green ) ).
    lt_stale = VALUE #( ( language = sy-langu staleafterminutes = gc-stale_min ) ).
    go_env->insert_test_data( lt_checks ).
    go_env->insert_test_data( lt_slices ).
    go_env->insert_test_data( lt_open ).
    go_env->insert_test_data( lt_last ).
    go_env->insert_test_data( lt_runs ).
    go_env->insert_test_data( lt_stale ).
  ENDMETHOD.


  " Rule: three registered checks are three, although the flagged check has a second (company-code) slice
  METHOD one_check_per_area_slice.
    SELECT SUM( checkcount ) AS checks, SUM( flaggedcount ) AS flagged, SUM( openexceptions ) AS open_exc
      FROM zr_ca_opscheckstatus
      INTO @DATA(ls_sum).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-checks exp = 3 msg = 'One per registered check' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-flagged exp = 2 msg = 'Flagged per slice with an open exception' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-open_exc exp = 3 msg = 'Open exceptions of every slice' ).
  ENDMETHOD.


  " Rule: stale only on the area-level slice of a check whose group has no run within the threshold
  METHOD stale_on_area_slice_only.
    SELECT checkid, companycode, stalecount, isstale FROM zr_ca_opscheckstatus
      WHERE stalecount = 1
      INTO TABLE @DATA(lt_stale).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_stale ) exp = 1 msg = 'One stale check' ).
    cl_abap_unit_assert=>assert_equals( act = lt_stale[ 1 ]-checkid exp = gc-stale msg = 'The hourly check is stale' ).
    cl_abap_unit_assert=>assert_initial( act = lt_stale[ 1 ]-companycode msg = 'On the area-level slice' ).
    cl_abap_unit_assert=>assert_equals( act = lt_stale[ 1 ]-isstale exp = abap_true msg = 'Stale flag agrees' ).
  ENDMETHOD.


  " Rule: needs attention = open exception on the slice or stale; a fresh check without exceptions does not
  METHOD attention_flag.
    SELECT checkid, companycode FROM zr_ca_opscheckstatus
      WHERE isattention = @abap_true
      ORDER BY checkid, companycode
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 msg = 'Two flagged slices and the stale check' ).
    cl_abap_unit_assert=>assert_false(
        act = xsdbool( line_exists( lt_rows[ checkid = gc-healthy ] ) )
        msg = 'A fresh check without exceptions needs no attention' ).
  ENDMETHOD.

ENDCLASS.
