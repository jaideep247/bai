*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_svc_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS unit tests (cl_cds_test_environment) of the service health score and
*& the process flow: a problem raised by two runs counts once, the score of a
*& company-code slice adds the area-level points and never another company
*& code's, a stale monitor costs points on the current day only, stuck and
*& drop per stage of the process flow.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (service health and process flow cards).
*&---------------------------------------------------------------------*
"! ZI_CD_SVCOBJ: one problem per object key - a finding raised again by a later run (superseded) counts once
CLASS ltc_service_problem DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        service TYPE c LENGTH 12 VALUE 'DISBURSE',
        day     TYPE d VALUE '20261110',
        area    TYPE c LENGTH 16 VALUE 'CD_FMON',
        code    TYPE c LENGTH 30 VALUE 'F_LATE',
        key     TYPE c LENGTH 70 VALUE 'IFACE1/20261110',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS raised_twice_counts_once FOR TESTING.
ENDCLASS.


CLASS ltc_service_problem IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_CD_SVCOBJ' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_finds TYPE STANDARD TABLE OF zi_cd_svcfind WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " the same late file raised by the 08:00 run (superseded, 5 points) and the 09:00 run (open, 15 points)
    lt_finds = VALUE #( ( service = gc-service matchfield = 'AREA' runid = '000000000000000000000000000000A1'
                          findingno = 1 businessdate = gc-day area = gc-area checkcode = gc-code objectkey = gc-key
                          points = 5 )
                        ( service = gc-service matchfield = 'AREA' runid = '000000000000000000000000000000A2'
                          findingno = 1 businessdate = gc-day area = gc-area checkcode = gc-code objectkey = gc-key
                          points = 15 ) ).
    go_env->insert_test_data( lt_finds ).
  ENDMETHOD.


  METHOD raised_twice_counts_once.
    TRY.
        SELECT service, objectkey, points FROM zi_cd_svcobj ORDER BY service, objectkey INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One problem, not two' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-points exp = 15 msg = 'Highest points of the problem' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_SVCHEALTH: score per slice = 100 - (area-level + own company code points + stale points of today)
CLASS ltc_service_score DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        service TYPE c LENGTH 12 VALUE 'DISBURSE',
        day     TYPE d VALUE '20261110',
        bukrs_a TYPE c LENGTH 4 VALUE 'ZT01',
        bukrs_b TYPE c LENGTH 4 VALUE 'ZT02',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS slice_adds_area_level FOR TESTING.
    METHODS stale_costs_points_today FOR TESTING.
ENDCLASS.


CLASS ltc_service_score IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_SVCHEALTH' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_services TYPE STANDARD TABLE OF zcd_ops_svc WITH EMPTY KEY.
    DATA lt_slices TYPE STANDARD TABLE OF zi_cd_svcslice WITH EMPTY KEY.
    DATA lt_points TYPE STANDARD TABLE OF zi_cd_svcpts WITH EMPTY KEY.
    DATA lt_days TYPE STANDARD TABLE OF zi_ca_opsbusday WITH EMPTY KEY.
    DATA lt_stale TYPE STANDARD TABLE OF zi_cd_svcstales WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_services = VALUE #( ( service = gc-service label = 'Disbursements' seq = 20 weight_b = 25 weight_e = 15
                             weight_w = 5 stale_points = 20 green_min = 90 amber_min = 70 active = abap_true ) ).
    lt_slices = VALUE #( ( service = gc-service businessdate = gc-day )
                         ( service = gc-service businessdate = gc-day companycode = gc-bukrs_a )
                         ( service = gc-service businessdate = gc-day companycode = gc-bukrs_b ) ).
    " area-level 5 points (one warning), ZT01 30 points (two errors), ZT02 15 points (one error)
    lt_points = VALUE #( ( service = gc-service businessdate = gc-day points = 5 problems = 1 )
                         ( service = gc-service businessdate = gc-day companycode = gc-bukrs_a points = 30 problems = 2 )
                         ( service = gc-service businessdate = gc-day companycode = gc-bukrs_b points = 15 problems = 1 ) ).
    lt_days = VALUE #( ( businessdate = gc-day iscurrentday = abap_true ) ).
    lt_stale = VALUE #( ( service = gc-service stalepoints = 20 stalemonitors = 1 ) ).
    go_env->insert_test_data( lt_services ).
    go_env->insert_test_data( lt_slices ).
    go_env->insert_test_data( lt_points ).
    go_env->insert_test_data( lt_days ).
    go_env->insert_test_data( lt_stale ).
  ENDMETHOD.


  METHOD slice_adds_area_level.
    TRY.
        SELECT companycode, score, openproblems, scorecriticality FROM zr_cd_svchealth
          WHERE service = @gc-service ORDER BY companycode INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 msg = 'Area-level slice and two company codes' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-score exp = 45
                                            msg = 'ZT01: 100 - 5 area-level - 30 own - 20 stale' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-openproblems exp = 3 msg = 'ZT01: 1 area-level + 2 own' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-score exp = 60
                                            msg = 'ZT02 never pays for ZT01: 100 - 5 - 15 - 20' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-scorecriticality exp = 1 msg = 'Below 70: critical' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD stale_costs_points_today.
    TRY.
        SELECT score, stalemonitors, scorecriticality FROM zr_cd_svchealth
          WHERE service = @gc-service AND companycode = @space ORDER BY service INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-score exp = 75
                                            msg = 'Area-level: 100 - 5 - 20 for the stale monitor' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-stalemonitors exp = 1 msg = 'One stale monitor' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-scorecriticality exp = 2 msg = '70 to 89: watch' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_PAYFLOW: stuck beyond the expected days of the stage, drop from the previous stage
CLASS ltc_flow DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        bukrs  TYPE c LENGTH 4 VALUE 'ZT01',
        payrun TYPE c LENGTH 10 VALUE 'PAYRUN',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS stuck_and_drop_per_stage FOR TESTING.
ENDCLASS.


CLASS ltc_flow IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_PAYFLOW' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_life TYPE STANDARD TABLE OF zr_cd_paylifecycle WITH EMPTY KEY.
    DATA lt_stages TYPE STANDARD TABLE OF zcd_ops_paystage WITH EMPTY KEY.
    DATA lt_reach TYPE STANDARD TABLE OF zi_cd_payflowreach WITH EMPTY KEY.
    DATA lt_prev TYPE STANDARD TABLE OF zi_cd_paystageprev WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " payments of 5 days ago: 100 still ISSUED (1 day expected - stuck), 900 CONFIRMED (4 days - stuck), 9000 CLEARED
    DATA(lv_day) = CONV d( sy-datum - 5 ).
    lt_stages = VALUE #( ( stage = 'ISSUED' seq = 40 source = gc-payrun active = abap_true stuck_days = 1 )
                         ( stage = 'CONFIRMED' seq = 50 source = gc-payrun active = abap_true stuck_days = 4 )
                         ( stage = 'CLEARED' seq = 60 source = gc-payrun active = abap_true ) ).
    lt_life = VALUE #( ( businessdate = lv_day companycode = gc-bukrs stage = 'ISSUED' stagesequence = 40
                         stagesource = gc-payrun paymentcount = 100 )
                       ( businessdate = lv_day companycode = gc-bukrs stage = 'CONFIRMED' stagesequence = 50
                         stagesource = gc-payrun paymentcount = 900 )
                       ( businessdate = lv_day companycode = gc-bukrs stage = 'CLEARED' stagesequence = 60
                         stagesource = gc-payrun paymentcount = 9000 ) ).
    lt_reach = VALUE #( ( businessdate = lv_day companycode = gc-bukrs stage = 'ISSUED' stagesequence = 40
                          reachedcount = 10000 )
                        ( businessdate = lv_day companycode = gc-bukrs stage = 'CONFIRMED' stagesequence = 50
                          reachedcount = 9900 )
                        ( businessdate = lv_day companycode = gc-bukrs stage = 'CLEARED' stagesequence = 60
                          reachedcount = 9000 ) ).
    lt_prev = VALUE #( ( stage = 'CONFIRMED' prevsequence = 40 ) ( stage = 'CLEARED' prevsequence = 50 ) ).
    go_env->insert_test_data( lt_stages ).
    go_env->insert_test_data( lt_life ).
    go_env->insert_test_data( lt_reach ).
    go_env->insert_test_data( lt_prev ).
  ENDMETHOD.


  METHOD stuck_and_drop_per_stage.
    TRY.
        SELECT stage, stuckcount, dropcount, flowcriticality FROM zr_cd_payflow
          ORDER BY stagesequence INTO TABLE @DATA(lt_rows).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 msg = 'Three stages' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-stuckcount exp = 100 msg = 'ISSUED 5 days > 1: stuck' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-flowcriticality exp = 1
                                            msg = 'More than twice the expected time: critical' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-dropcount exp = 0 msg = 'First stage has no drop' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-stuckcount exp = 900 msg = 'CONFIRMED 5 days > 4: stuck' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-flowcriticality exp = 2 msg = 'Stuck, not twice: watch' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-dropcount exp = 100
                                            msg = 'Reached ISSUED 10000, CONFIRMED 9900: 100 dropped' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-stuckcount exp = 0 msg = 'Final stage never stuck' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 3 ]-flowcriticality exp = 0 msg = 'No expected time: neutral' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
