*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pilot_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the pilot pack data access on doubles of the CDS views
*& ZI_CA_OpsPilotDay / ZR_CA_OpsPilotBrk and of ZCA_OPS_PILOTBL: the rows of
*& the area and date range only, in order. Does not prove live SAP runtime
*& behavior. VERIFY-ADT: CDS view entities as OSQL doubles (7.58).
*& Modification log:
*& 2026-11-11 | Initial version (build F: pilot pack).
*&---------------------------------------------------------------------*
CLASS ltc_pilot_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_pilot_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS area_and_range_only FOR TESTING.
ENDCLASS.


CLASS ltc_pilot_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZI_CA_OPSPILOTDAY' )
                                                                            ( 'ZR_CA_OPSPILOTBRK' )
                                                                            ( 'ZCA_OPS_PILOTBL' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_days TYPE STANDARD TABLE OF zi_ca_opspilotday WITH EMPTY KEY.
    DATA lt_breaks TYPE STANDARD TABLE OF zr_ca_opspilotbrk WITH EMPTY KEY.
    DATA lt_baselines TYPE STANDARD TABLE OF zca_ops_pilotbl WITH EMPTY KEY.
    DATA ls_day TYPE zi_ca_opspilotday.
    DATA ls_break TYPE zr_ca_opspilotbrk.
    DATA ls_baseline TYPE zca_ops_pilotbl.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_pilot_dao( ).
    ls_day-raiseddate  = '20261101'.
    ls_day-area        = 'ZT_OPS_A'.
    ls_day-checkid     = 'ZT_CHECK'.
    ls_day-raisedcount = 3.
    INSERT ls_day INTO TABLE lt_days.
    ls_day-raiseddate  = '20260901'.
    INSERT ls_day INTO TABLE lt_days.
    ls_day-raiseddate  = '20261101'.
    ls_day-area        = 'ZT_OPS_B'.
    INSERT ls_day INTO TABLE lt_days.
    ls_break-area       = 'ZT_OPS_A'.
    ls_break-accountid  = 'ZT_CLEARING'.
    ls_break-keydate    = '20261031'.
    ls_break-groupcount = 5.
    INSERT ls_break INTO TABLE lt_breaks.
    ls_baseline-area         = 'ZT_OPS_A'.
    ls_baseline-check_id     = 'ZT_CHECK'.
    ls_baseline-baseline_min = 1440.
    INSERT ls_baseline INTO TABLE lt_baselines.
    go_env->insert_test_data( lt_days ).
    go_env->insert_test_data( lt_breaks ).
    go_env->insert_test_data( lt_baselines ).
  ENDMETHOD.


  " Rule: the rows of the area and of the date range only
  METHOD area_and_range_only.
    TRY.
        DATA(lt_days) = mo_cut->days( iv_area = 'ZT_OPS_A' iv_from = '20261001' iv_to = '20261110' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 1 msg = 'One day of the area in range' ).
        cl_abap_unit_assert=>assert_equals( act = lt_days[ 1 ]-raisedcount exp = 3 msg = 'Its figures' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->breaks( iv_area = 'ZT_OPS_A' iv_from = '20261001'
                                                                         iv_to   = '20261110' ) )
                                            exp = 1 msg = 'Breaks of the range' ).
        DATA(lt_baselines) = mo_cut->baselines( 'ZT_OPS_A' ).
        cl_abap_unit_assert=>assert_equals( act = lt_baselines[ 1 ]-baseline_min exp = 1440
                                            msg = 'Baseline of the check' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
