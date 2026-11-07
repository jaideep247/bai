*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_exc_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the exception repository: only open / assigned exceptions
*& are found, resolve closes them and writes a history row each.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-07 | Resolve test uses history action MANUAL (RELEASE removed, read-only scope).
*&---------------------------------------------------------------------*
CLASS ltc_exc_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        run_id TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000AB',
        key    TYPE zif_cd_ops_types=>ty_object_key VALUE 'S0001/1',
        code   TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNMAPPED_BTC',
        user   TYPE syuname VALUE 'APPROVER',
        at     TYPE timestampl VALUE '20261106090000.0000000',
        reason TYPE zif_cd_ops_exc_types=>ty_reason VALUE 'Released after bank confirmation',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_exc_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS add_finding
      IMPORTING
        iv_finding_no  TYPE i
        iv_disposition TYPE zif_cd_ops_types=>ty_disposition.

    METHODS find_open_skips_closed       FOR TESTING.
    METHODS resolve_closes_with_history  FOR TESTING.
ENDCLASS.


CLASS ltc_exc_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_OPS_FINDING' ) ( 'ZCD_OPS_EXC_HIST' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_exc_dao( ).
  ENDMETHOD.


  METHOD add_finding.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ops_finding.
    ls_row-run_id      = gc_test-run_id.
    ls_row-finding_no  = iv_finding_no.
    ls_row-pe_area      = zif_cd_ops_types=>gc_pe_area-ebs.
    ls_row-object_type = 'LINE'.
    ls_row-object_key  = gc_test-key.
    ls_row-check_code  = gc_test-code.
    ls_row-severity    = zif_cd_ops_types=>gc_severity-block.
    ls_row-disposition = iv_disposition.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Rule: only open and assigned exceptions are found - resolved and superseded rows are history
  METHOD find_open_skips_closed.
    TRY.
        add_finding( iv_finding_no = 1 iv_disposition = zif_cd_ops_types=>gc_disposition-open ).
        add_finding( iv_finding_no = 2 iv_disposition = zif_cd_ops_types=>gc_disposition-assigned ).
        add_finding( iv_finding_no = 3 iv_disposition = zif_cd_ops_types=>gc_disposition-resolved ).
        add_finding( iv_finding_no = 4 iv_disposition = zif_cd_ops_types=>gc_disposition-superseded ).
        DATA(lt_keys) = mo_cut->find_open( iv_pe_area     = zif_cd_ops_types=>gc_pe_area-ebs
                                           iv_object_key = gc_test-key
                                           iv_check_code = gc_test-code ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_keys ) exp = 2
                                            msg = 'Exactly the open and the assigned exception must be found' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: resolving sets R with user, time and reason, and leaves one history row
  METHOD resolve_closes_with_history.
    DATA lt_keys TYPE zif_cd_ops_exc_types=>tt_exc_key.
    DATA ls_key TYPE zif_cd_ops_exc_types=>ty_exc_key.
    TRY.
        add_finding( iv_finding_no = 1 iv_disposition = zif_cd_ops_types=>gc_disposition-open ).
        ls_key-run_id     = gc_test-run_id.
        ls_key-finding_no = 1.
        INSERT ls_key INTO TABLE lt_keys.
        mo_cut->resolve( it_keys      = lt_keys
                         iv_action    = zif_cd_ops_exc_types=>gc_action-manual
                         iv_reason    = gc_test-reason
                         iv_reference = 'PRQ-1'
                         iv_user      = gc_test-user
                         iv_at        = gc_test-at ).
        SELECT SINGLE disposition, resolved_by, resolution
          FROM zcd_ops_finding
          WHERE run_id = @gc_test-run_id AND finding_no = 1
          INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 act = sy-subrc msg = 'The exception must still exist' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-disposition exp = zif_cd_ops_types=>gc_disposition-resolved
                                            msg = 'The exception must be resolved' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-resolved_by exp = gc_test-user msg = 'Resolver must be recorded' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-resolution exp = gc_test-reason msg = 'Reason must be recorded' ).
        SELECT action, from_disp, to_disp, reference
          FROM zcd_ops_exc_hist
          WHERE run_id = @gc_test-run_id AND finding_no = 1
          ORDER BY created_at
          INTO TABLE @DATA(lt_hist).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_hist ) exp = 1 msg = 'One history row per action' ).
        cl_abap_unit_assert=>assert_equals( act = lt_hist[ 1 ]-action exp = zif_cd_ops_exc_types=>gc_action-manual
                                            msg = 'The history row must name the action' ).
        cl_abap_unit_assert=>assert_equals( act = lt_hist[ 1 ]-from_disp exp = zif_cd_ops_types=>gc_disposition-open
                                            msg = 'The history row must keep the previous disposition' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
