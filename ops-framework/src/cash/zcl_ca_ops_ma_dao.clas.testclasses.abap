*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ma_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the mass activity data access on doubles of ZCA_OPS_MAACT
*& and FKKMAKO: only the active activities of the area; dunning notices
*& counted and their balance summed per run date, run ID and currency in
*& the window - two currencies never summed. Values are test values, not
*& SAP facts (VERIFY V301). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
CLASS ltc_ma_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A'.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_ma_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS active_activities_of_area FOR TESTING RAISING zcx_ca_ops_error.
    METHODS notices_per_run_currency  FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_ma_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_MAACT' ) ( 'FKKMAKO' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_ma_dao( ).
  ENDMETHOD.


  " Rule: active rows of the area only
  METHOD active_activities_of_area.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_maact WITH EMPTY KEY.
    lt_rows = VALUE #( ( area = gc_area act_id = 'PAYRUN' aktyp = 'ZPAY' job_pattern = 'ZT_FPY1_.*'
                         output_kind = 'PAYDOC' active = abap_true )
                       ( area = gc_area act_id = 'DUNNING' aktyp = 'ZDUN' job_pattern = 'ZT_DUN_.*'
                         output_kind = 'DUNNING' )
                       ( area = 'ZT_OPS_B' act_id = 'PAYRUN' aktyp = 'ZPAY' active = abap_true ) ).
    go_env->insert_test_data( lt_rows ).

    DATA(lt_activities) = mo_cut->activities( gc_area ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_activities ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_activities[ 1 ]-act_id exp = 'PAYRUN' ).
    cl_abap_unit_assert=>assert_equals( act = lt_activities[ 1 ]-output_kind exp = 'PAYDOC' ).
  ENDMETHOD.


  " Rule: one row per run date, run ID and currency in the window; count and the sum of the dunning balance
  METHOD notices_per_run_currency.
    DATA lt_rows TYPE STANDARD TABLE OF fkkmako WITH EMPTY KEY.
    lt_rows = VALUE #( ( laufd = '20261112' laufi = 'DUN01' gpart = 'ZT_BP1' vkont = 'ZT_CA1' mazae = '000001'
                         waers = 'EUR' msalm = '100.00' )
                       ( laufd = '20261112' laufi = 'DUN01' gpart = 'ZT_BP2' vkont = 'ZT_CA2' mazae = '000001'
                         waers = 'EUR' msalm = '50.00' )
                       ( laufd = '20261112' laufi = 'DUN01' gpart = 'ZT_BP3' vkont = 'ZT_CA3' mazae = '000001'
                         waers = 'USD' msalm = '70.00' )
                       ( laufd = '20261001' laufi = 'DUN09' gpart = 'ZT_BP1' vkont = 'ZT_CA1' mazae = '000001'
                         waers = 'EUR' msalm = '9.00' ) ).
    go_env->insert_test_data( lt_rows ).

    DATA(lt_sums) = mo_cut->dunning_notices( iv_from = '20261110' iv_to = '20261116' iv_max = 100 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_sums ) exp = 2 ).
    DATA(ls_eur) = lt_sums[ currency = 'EUR' ].
    cl_abap_unit_assert=>assert_equals( act = ls_eur-item_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_eur-amount exp = '150.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_sums[ currency = 'USD' ]-amount exp = '70.00' ).
  ENDMETHOD.

ENDCLASS.
