*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_dcl_test.clas.testclasses.abap
*& Purpose:
*& Access-control tests of the company-code isolation rule of the suite's
*& roles on the CDS test double framework: user A holds ZCA_OPS 03 for the
*& areas CD_EBS / CD_FMON / CD_HCK / CD_OPS with BUKRS US01 only. The
*& critical exceptions of the overview page (ZC_CD_OPSCRITEXC, role
*& ZC_CD_OPSOVERVIEW) and the EBS run slices (ZC_CD_EBSRUN, role
*& ZC_CD_EBSDASH) return to A the rows of US01 and the area-level rows -
*& never a row, count or sum of US02. Does not prove live SAP runtime
*& behavior.
*& VERIFY-ADT: API of the access-control double (7.58) - environment method
*& ENABLE_ACCESS_CONTROL, CL_CDS_TEST_DATA=>CREATE_ACCESS_CONTROL_DATA with
*& the roles under test and the user's authorisations as an ABAP Unit
*& authorisation set (CL_AUNIT_AUTHORITY_CHECK=>CREATE_AUTH_OBJECT_SET). If
*& the signature differs, correct this include only (nothing else uses it).
*& Modification log:
*& 2026-11-10 | Initial version (company-code isolation of the dashboards and the overview page).
*&---------------------------------------------------------------------*
"! Test data builder: the simulated user A (DV1 / QA1 test script user A) and the keys of the test rows
CLASS ltd_user DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc,
        object TYPE xuobject VALUE 'ZCA_OPS',
        own    TYPE bukrs VALUE 'US01',
        other  TYPE bukrs VALUE 'US02',
        run    TYPE zif_ca_ops_types=>ty_run_id VALUE 'D0000000000000000000000000000021',
      END OF gc.
    CONSTANTS:
      BEGIN OF gc_field,
        area     TYPE xufield VALUE 'ZCA_PARAR',
        activity TYPE xufield VALUE 'ACTVT',
        bukrs    TYPE xufield VALUE 'BUKRS',
      END OF gc_field.

    "! Access control of the role(s) under test for user A (ZCA_OPS 03, the suite's areas, BUKRS US01)
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
                                                        fieldvalues = VALUE #( ( lower_value = zif_cd_ops_types=>gc_pe_area-ebs )
                                                                               ( lower_value = zif_cd_ops_types=>gc_pe_area-file_monitor )
                                                                               ( lower_value = zif_cd_ops_types=>gc_pe_area-health_check )
                                                                               ( lower_value = zif_cd_ops_types=>gc_pe_area-core ) ) )
                                                      ( fieldname   = gc_field-activity
                                                        fieldvalues = VALUE #( ( lower_value = zif_ca_ops_auth=>gc_activity-display ) ) )
                                                      ( fieldname   = gc_field-bukrs
                                                        fieldvalues = VALUE #( ( lower_value = gc-own ) ) ) ) ) ) ) ) ).
    ro_data = cl_cds_test_data=>create_access_control_data( i_role_names      = it_roles
                                                            i_auth_object_set = lo_auth_set ).
  ENDMETHOD.

ENDCLASS.


"! ZC_CD_OPSCRITEXC (overview list card "open critical exceptions"): own company code and area-level only
CLASS ltc_critical DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sees_own_and_area FOR TESTING.
ENDCLASS.


CLASS ltc_critical IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CD_OPSCRITEXC' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_cd_opscritexc WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " 1 EBS US01, 2 EBS US02, 3 FMON area-level, 4 HCK US02
    lt_rows = VALUE #( ( runid = ltd_user=>gc-run findingno = 1 paymentenginearea = zif_cd_ops_types=>gc_pe_area-ebs
                         companycode = ltd_user=>gc-own exceptioncount = 1 )
                       ( runid = ltd_user=>gc-run findingno = 2 paymentenginearea = zif_cd_ops_types=>gc_pe_area-ebs
                         companycode = ltd_user=>gc-other exceptioncount = 1 )
                       ( runid = ltd_user=>gc-run findingno = 3 paymentenginearea = zif_cd_ops_types=>gc_pe_area-file_monitor
                         exceptioncount = 1 )
                       ( runid = ltd_user=>gc-run findingno = 4 paymentenginearea = zif_cd_ops_types=>gc_pe_area-health_check
                         companycode = ltd_user=>gc-other exceptioncount = 1 ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CD_OPSOVERVIEW` ) ) ) ).
  ENDMETHOD.


  " Rule: rows and the card's count never include US02 - the count is a sum over the rows A may read
  METHOD user_a_sees_own_and_area.
    SELECT findingno FROM zc_cd_opscritexc ORDER BY findingno INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'US01 and area-level only' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-findingno exp = 1 msg = 'Own company code' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-findingno exp = 3 msg = 'Area-level exception' ).
    SELECT SUM( exceptioncount ) FROM zc_cd_opscritexc INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 2 msg = 'Card count of A' ).
  ENDMETHOD.

ENDCLASS.


"! ZC_CD_EBSRUN (EBS run history): the run's counters once, the findings of US01, never those of US02
CLASS ltc_ebs_run DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS user_a_sums_own_slices FOR TESTING.
ENDCLASS.


CLASS ltc_ebs_run IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZC_CD_EBSRUN' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zr_cd_ebsrun WITH EMPTY KEY.
    go_env->clear_doubles( ).
    " one run: area-level slice (20 lines, 1 run finding), US01 slice (2 findings), US02 slice (5 findings)
    lt_rows = VALUE #( ( runid = ltd_user=>gc-run paymentenginearea = zif_cd_ops_types=>gc_pe_area-ebs
                         runcount = 1 linecount = 20 findingcount = 1 )
                       ( runid = ltd_user=>gc-run companycode = ltd_user=>gc-own
                         paymentenginearea = zif_cd_ops_types=>gc_pe_area-ebs findingcount = 2 )
                       ( runid = ltd_user=>gc-run companycode = ltd_user=>gc-other
                         paymentenginearea = zif_cd_ops_types=>gc_pe_area-ebs findingcount = 5 ) ).
    go_env->insert_test_data( lt_rows ).
    go_env->enable_access_control( ltd_user=>user_a( VALUE #( ( `ZC_CD_EBSDASH` ) ) ) ).
  ENDMETHOD.


  " Rule: the analytical list's sum for A = run counters once + area-level and US01 findings
  METHOD user_a_sums_own_slices.
    SELECT SINGLE SUM( runcount ) AS runs, SUM( linecount ) AS lines, SUM( findingcount ) AS findings
      FROM zc_cd_ebsrun INTO @DATA(ls_sum).
    cl_abap_unit_assert=>assert_subrc( exp = 0 act = sy-subrc msg = 'The sum must be read' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-runs exp = 1 msg = 'The run counted once' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-lines exp = 20 msg = 'Line counters of the run' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-findings exp = 3 msg = 'Area-level and US01 findings only' ).
  ENDMETHOD.

ENDCLASS.
