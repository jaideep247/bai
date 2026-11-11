*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_downtime.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the planned downtime API on a doubled ZCA_OPS_DTWIN: windows of
*& an area by time (overlap, ended windows left out), approved only or all, the
*& question "is this planned?" for a finding and a period, the area-wide window.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: planned downtime).
*&---------------------------------------------------------------------*
CLASS ltc_downtime DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        other     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_B',
        wide      TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000D1',
        bank      TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000D2',
        pending   TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000D3',
        ended     TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000D4',
        foreign   TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000D5',
        from_utc  TYPE timestampl VALUE '20261111220000.0000000',
        to_utc    TYPE timestampl VALUE '20261112020000.0000000',
        inside    TYPE timestampl VALUE '20261111230000.0000000',
        earlier   TYPE timestampl VALUE '20261111180000.0000000',
        approver  TYPE syuname VALUE 'ZT_APPROVER',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_downtime.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS approved_windows_of_area    FOR TESTING.
    METHODS pending_for_overlap_check   FOR TESTING.
    METHODS finding_of_bank_is_planned  FOR TESTING.
    METHODS area_wide_window_found      FOR TESTING.
ENDCLASS.


CLASS ltc_downtime IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_DTWIN' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_dtwin WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_dtwin.
    go_env->clear_doubles( ).
    ls_row-area        = gc-area.
    ls_row-from_utc    = gc-from_utc.
    ls_row-to_utc      = gc-to_utc.
    ls_row-approved_by = gc-approver.
    " area-wide, approved
    ls_row-window_id = gc-wide.
    INSERT ls_row INTO TABLE lt_rows.
    " one bank, approved
    ls_row-window_id     = gc-bank.
    ls_row-group_pattern = 'BANK_A.*'.
    INSERT ls_row INTO TABLE lt_rows.
    " awaiting approval
    ls_row-window_id = gc-pending.
    CLEAR ls_row-approved_by.
    INSERT ls_row INTO TABLE lt_rows.
    " ended before the period
    ls_row-window_id   = gc-ended.
    ls_row-approved_by = gc-approver.
    ls_row-from_utc    = '20261111100000.0000000'.
    ls_row-to_utc      = '20261111120000.0000000'.
    INSERT ls_row INTO TABLE lt_rows.
    " another area
    ls_row-window_id = gc-foreign.
    ls_row-area      = gc-other.
    ls_row-from_utc  = gc-from_utc.
    ls_row-to_utc    = gc-to_utc.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
    mo_cut = NEW zcl_ca_ops_downtime( ).
  ENDMETHOD.


  " Rule: the approved windows of the area that overlap the time - not another area's, not an ended one
  METHOD approved_windows_of_area.
    TRY.
        DATA(lt_windows) = mo_cut->windows( iv_area = gc-area iv_from = gc-inside iv_to = gc-inside ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_windows ) exp = 2 msg = 'Area-wide and bank window' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_windows[ window_id = gc-pending ] ) )
                                           msg = 'A window awaiting approval takes no effect' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the overlap check of the app also sees windows awaiting approval
  METHOD pending_for_overlap_check.
    TRY.
        DATA(lt_windows) = mo_cut->windows( iv_area = gc-area iv_from = gc-earlier iv_to = gc-to_utc
                                            iv_approved_only = abap_false ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_windows[ window_id = gc-pending ] ) )
                                          msg = 'The pending window is listed' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_windows[ window_id = gc-ended ] ) )
                                           msg = 'A window that ended before the period is not' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: is this planned? - a finding of the bank at a time inside the window
  METHOD finding_of_bank_is_planned.
    TRY.
        DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
        ls_finding-check_code = 'NO_BANK_ACK'.
        ls_finding-group1     = 'BANK_A_ACK'.
        cl_abap_unit_assert=>assert_not_initial( act = mo_cut->planned( iv_area    = gc-area
                                                                        is_finding = ls_finding
                                                                        iv_from    = gc-inside )
                                                 msg = 'Planned inside the window' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->planned( iv_area    = gc-other
                                                                    is_finding = ls_finding
                                                                    iv_from    = gc-earlier )
                                             msg = 'Not planned before the window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the area-wide window (no pattern) holds back run-level alerts
  METHOD area_wide_window_found.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->area_planned( iv_area = gc-area iv_at = gc-inside )
                                            exp = gc-wide
                                            msg = 'The window without pattern' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->area_planned( iv_area = gc-area iv_at = gc-earlier )
                                             msg = 'None before the window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
