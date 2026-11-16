*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_dcl_test.clas.testclasses.abap
*& Purpose:
*& Access-control tests of the payment file worklist (pack FICA_CASH,
*& build K) on the CDS test double framework: user A holds ZCA_OPS 03 for
*& area ZT_OPS_A with BUKRS ZT01 only. Files (ZC_CA_OPSPAYFILE), payments
*& (ZC_CA_OPSPFPAYMENT - the facet a list report exports), stage timeline
*& (ZC_CA_OPSPFMILESTONE) and evidence (ZC_CA_OPSPFEVIDENCE) return to A
*& the rows of ZT01 and the area-level rows of ZT_OPS_A - never a row of
*& ZT02 or of another area (two-user isolation, build Q). The export of a
*& list report reads the same projection, so the same rows (V317).
*& Does not prove live SAP runtime behavior.
*& VERIFY-ADT: API of the access-control double as ZCL_CA_OPS_DCL_TEST (V38).
*& Modification log:
*& 2026-11-16 | Initial version (build Q: two-user isolation of the payment file worklist).
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
        file_one   TYPE sysuuid_x16 VALUE '000000000000000000000000000000F1',
        file_two   TYPE sysuuid_x16 VALUE '000000000000000000000000000000F2',
        file_three TYPE sysuuid_x16 VALUE '000000000000000000000000000000F3',
        file_four  TYPE sysuuid_x16 VALUE '000000000000000000000000000000F4',
      END OF gc.
    CONSTANTS:
      BEGIN OF gc_field,
        area     TYPE xufield VALUE 'ZCA_PARAR',
        activity TYPE xufield VALUE 'ACTVT',
        bukrs    TYPE xufield VALUE 'BUKRS',
      END OF gc_field.

    "! Access control of the role under test for user A (ZCA_OPS 03, area ZT_OPS_A, BUKRS ZT01)
    CLASS-METHODS user_a
      IMPORTING
        it_roles       TYPE string_table
      RETURNING
        VALUE(ro_data) TYPE REF TO if_cds_access_control_data.
ENDCLASS.


CLASS ltd_user IMPLEMENTATION.

  METHOD user_a.
    " VERIFY-ADT (V38): as ZCL_CA_OPS_DCL_TEST
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


"! ZC_CA_OPSPAYFILE (payment file worklist, build K)
CLASS ltc_payfile DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sees_own_rows FOR TESTING.
ENDCLASS.


CLASS ltc_payfile IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CA_OPSPAYFILE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_ca_opspayfile WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " 1 ZT01, 2 ZT02, 3 area-level of ZT_OPS_A, 4 ZT01 of another area
    lt_rows = VALUE #( ( area = ltd_user=>gc-area fileid = ltd_user=>gc-file_one companycode = ltd_user=>gc-own )
                       ( area = ltd_user=>gc-area fileid = ltd_user=>gc-file_two companycode = ltd_user=>gc-other )
                       ( area = ltd_user=>gc-area fileid = ltd_user=>gc-file_three )
                       ( area = ltd_user=>gc-other_area fileid = ltd_user=>gc-file_four companycode = ltd_user=>gc-own ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CA_OPSPAYFILE` ) ) ) ).
  ENDMETHOD.


  " Rule: area authorised AND ( company code blank OR ( area, company code ) authorised )
  METHOD user_a_sees_own_rows.
    SELECT fileid FROM zc_ca_opspayfile ORDER BY fileid INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'ZT01 and area-level only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-fileid exp = ltd_user=>gc-file_one msg = 'Own company code' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-fileid exp = ltd_user=>gc-file_three msg = 'Area-level row' ).
  ENDMETHOD.

ENDCLASS.

"! ZC_CA_OPSPFPAYMENT (payments of a file - the export of the facet)
CLASS ltc_pf_payment DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sees_own_rows FOR TESTING.
ENDCLASS.


CLASS ltc_pf_payment IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CA_OPSPFPAYMENT' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_ca_opspfpayment WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " 1 ZT01, 2 ZT02, 3 area-level of ZT_OPS_A, 4 ZT01 of another area
    lt_rows = VALUE #( ( area = ltd_user=>gc-area paymentkey = 'F1' companycode = ltd_user=>gc-own )
                       ( area = ltd_user=>gc-area paymentkey = 'F2' companycode = ltd_user=>gc-other )
                       ( area = ltd_user=>gc-area paymentkey = 'F3' )
                       ( area = ltd_user=>gc-other_area paymentkey = 'F4' companycode = ltd_user=>gc-own ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CA_OPSPFPAYMENT` ) ) ) ).
  ENDMETHOD.


  " Rule: area authorised AND ( company code blank OR ( area, company code ) authorised )
  METHOD user_a_sees_own_rows.
    SELECT paymentkey FROM zc_ca_opspfpayment ORDER BY paymentkey INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'ZT01 and area-level only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-paymentkey exp = 'F1' msg = 'Own company code' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-paymentkey exp = 'F3' msg = 'Area-level row' ).
  ENDMETHOD.

ENDCLASS.

"! ZC_CA_OPSPFMILESTONE (stage timeline of a file)
CLASS ltc_pf_milestone DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sees_own_rows FOR TESTING.
ENDCLASS.


CLASS ltc_pf_milestone IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CA_OPSPFMILESTONE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_ca_opspfmilestone WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " 1 ZT01, 2 ZT02, 3 area-level of ZT_OPS_A, 4 ZT01 of another area
    lt_rows = VALUE #( ( area = ltd_user=>gc-area fileid = ltd_user=>gc-file_one companycode = ltd_user=>gc-own )
                       ( area = ltd_user=>gc-area fileid = ltd_user=>gc-file_two companycode = ltd_user=>gc-other )
                       ( area = ltd_user=>gc-area fileid = ltd_user=>gc-file_three )
                       ( area = ltd_user=>gc-other_area fileid = ltd_user=>gc-file_four companycode = ltd_user=>gc-own ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CA_OPSPFMILESTONE` ) ) ) ).
  ENDMETHOD.


  " Rule: area authorised AND ( company code blank OR ( area, company code ) authorised )
  METHOD user_a_sees_own_rows.
    SELECT fileid FROM zc_ca_opspfmilestone ORDER BY fileid INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'ZT01 and area-level only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-fileid exp = ltd_user=>gc-file_one msg = 'Own company code' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-fileid exp = ltd_user=>gc-file_three msg = 'Area-level row' ).
  ENDMETHOD.

ENDCLASS.

"! ZC_CA_OPSPFEVIDENCE (evidence of a file)
CLASS ltc_pf_evidence DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sees_own_rows FOR TESTING.
ENDCLASS.


CLASS ltc_pf_evidence IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CA_OPSPFEVIDENCE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_ca_opspfevidence WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " 1 ZT01, 2 ZT02, 3 area-level of ZT_OPS_A, 4 ZT01 of another area
    lt_rows = VALUE #( ( area = ltd_user=>gc-area eventkey = 'F1' companycode = ltd_user=>gc-own )
                       ( area = ltd_user=>gc-area eventkey = 'F2' companycode = ltd_user=>gc-other )
                       ( area = ltd_user=>gc-area eventkey = 'F3' )
                       ( area = ltd_user=>gc-other_area eventkey = 'F4' companycode = ltd_user=>gc-own ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CA_OPSPFEVIDENCE` ) ) ) ).
  ENDMETHOD.


  " Rule: area authorised AND ( company code blank OR ( area, company code ) authorised )
  METHOD user_a_sees_own_rows.
    SELECT eventkey FROM zc_ca_opspfevidence ORDER BY eventkey INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'ZT01 and area-level only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-eventkey exp = 'F1' msg = 'Own company code' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-eventkey exp = 'F3' msg = 'Area-level row' ).
  ENDMETHOD.

ENDCLASS.
