*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_dcl_test.clas.testclasses.abap
*& Purpose:
*& Access-control tests of the company-code isolation rule on the CDS test
*& double framework: user A holds ZCA_OPS 03 for area ZT_OPS_A with BUKRS
*& ZT01 only. The exceptions app (ZC_CA_OPSEXCEPTION) and the daily control
*& review (ZC_CA_OPSCTLREVIEW) return to A the rows of ZT01 and the
*& area-level rows (blank company code) of ZT_OPS_A - never a row of ZT02 or
*& of another area. Does not prove live SAP runtime behavior.
*& VERIFY-ADT: API of the access-control double (7.58) - environment method
*& ENABLE_ACCESS_CONTROL, CL_CDS_TEST_DATA=>CREATE_ACCESS_CONTROL_DATA with
*& the roles under test and the user's authorisations as an ABAP Unit
*& authorisation set (CL_AUNIT_AUTHORITY_CHECK=>CREATE_AUTH_OBJECT_SET). If
*& the signature differs, correct this include only (nothing else uses it).
*& Modification log:
*& 2026-11-10 | Initial version (company-code isolation of findings, history and control review).
*&---------------------------------------------------------------------*
"! Test data builder: the simulated user A and the keys of the test rows
CLASS ltd_user DEFINITION FINAL FOR TESTING.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc,
        object     TYPE xuobject VALUE 'ZCA_OPS',
        area       TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        other_area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_B',
        own        TYPE bukrs VALUE 'ZT01',
        other      TYPE bukrs VALUE 'ZT02',
        run        TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000D1',
        day        TYPE d VALUE '20261110',
        control    TYPE zif_ca_ops_ctl_types=>ty_control_id VALUE 'ZT_PAYFILES',
      END OF gc.
    CONSTANTS:
      BEGIN OF gc_field,
        area     TYPE xufield VALUE 'ZCA_PARAR',
        activity TYPE xufield VALUE 'ACTVT',
        bukrs    TYPE xufield VALUE 'BUKRS',
      END OF gc_field.

    "! Access control of the role(s) under test for user A (ZCA_OPS 03, area ZT_OPS_A, BUKRS ZT01)
    CLASS-METHODS user_a
      IMPORTING
        it_roles       TYPE string_table
      RETURNING
        VALUE(ro_data) TYPE REF TO if_cds_access_control_data.
ENDCLASS.


CLASS ltd_user IMPLEMENTATION.

  METHOD user_a.
    " VERIFY-ADT: CL_AUNIT_AUTHORITY_CHECK=>CREATE_AUTH_OBJECT_SET and CL_CDS_TEST_DATA=>
    " CREATE_ACCESS_CONTROL_DATA (parameters I_ROLE_NAMES, I_AUTH_OBJECT_SET) as documented for 7.58
    DATA(lo_auth_set) = cl_aunit_authority_check=>create_auth_object_set(
      VALUE #( ( object         = gc-object
                 authorizations = VALUE #( ( VALUE #( ( fieldname   = gc_field-area
                                                        fieldvalues = VALUE #( ( lower_value = gc-area ) ) )
                                                      ( fieldname   = gc_field-activity
                                                        fieldvalues = VALUE #( ( lower_value = zif_ca_ops_auth=>gc_activity-display ) ) )
                                                      ( fieldname   = gc_field-bukrs
                                                        fieldvalues = VALUE #( ( lower_value = gc-own ) ) ) ) ) ) ) ) ).
    ro_data = cl_cds_test_data=>create_access_control_data( i_role_names      = it_roles
                                                            i_auth_object_set = lo_auth_set ).
  ENDMETHOD.

ENDCLASS.


"! ZC_CA_OPSEXCEPTION (exceptions app): own company code and area-level only
CLASS ltc_exception DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sees_own_and_area FOR TESTING.
ENDCLASS.


CLASS ltc_exception IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CA_OPSEXCEPTION' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_ca_opsexception WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " 1 ZT01, 2 ZT02, 3 area-level of ZT_OPS_A, 4 ZT01 of another area
    lt_rows = VALUE #( ( runid = ltd_user=>gc-run findingno = 1 area = ltd_user=>gc-area companycode = ltd_user=>gc-own )
                       ( runid = ltd_user=>gc-run findingno = 2 area = ltd_user=>gc-area companycode = ltd_user=>gc-other )
                       ( runid = ltd_user=>gc-run findingno = 3 area = ltd_user=>gc-area )
                       ( runid = ltd_user=>gc-run findingno = 4 area = ltd_user=>gc-other_area
                         companycode = ltd_user=>gc-own ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CA_OPSEXCEPTION` ) ) ) ).
  ENDMETHOD.


  " Rule: area authorised AND ( company code blank OR ( area, company code ) authorised )
  METHOD user_a_sees_own_and_area.
    SELECT findingno FROM zc_ca_opsexception ORDER BY findingno INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'ZT01 and area-level only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-findingno exp = 1 msg = 'Own company code' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-findingno exp = 3 msg = 'Area-level exception' ).
  ENDMETHOD.

ENDCLASS.


"! ZC_CA_OPSCTLREVIEW (daily control review): own company-code slice and area-level slice only
CLASS ltc_review DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sees_own_slices FOR TESTING.
ENDCLASS.


CLASS ltc_review IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CA_OPSCTLREVIEW' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_ca_opsctlreview WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " slices of one control and date: area-level, ZT01 (watch), ZT02 (action required, 3 open)
    lt_rows = VALUE #( ( area = ltd_user=>gc-area controlid = ltd_user=>gc-control businessdate = ltd_user=>gc-day
                         controlcount = 1 )
                       ( area = ltd_user=>gc-area controlid = ltd_user=>gc-control businessdate = ltd_user=>gc-day
                         companycode = ltd_user=>gc-own statusrank = 1 controlcount = 1 watchcount = 1 )
                       ( area = ltd_user=>gc-area controlid = ltd_user=>gc-control businessdate = ltd_user=>gc-day
                         companycode = ltd_user=>gc-other statusrank = 2 openexceptions = 3 controlcount = 1
                         actionrequiredcount = 1 ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CA_OPSCTLREVIEW` ) ) ) ).
  ENDMETHOD.


  " Rule: the counters a card sums for user A never include the slice of ZT02
  METHOD user_a_sees_own_slices.
    SELECT SUM( controlcount ) AS controls, SUM( actionrequiredcount ) AS actions, SUM( openexceptions ) AS open
      FROM zc_ca_opsctlreview INTO @DATA(ls_sum).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-controls exp = 2 msg = 'Area-level and ZT01 slice' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-actions exp = 0 msg = 'No action required of ZT02' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-open exp = 0 msg = 'No open exception of ZT02' ).
  ENDMETHOD.

ENDCLASS.
