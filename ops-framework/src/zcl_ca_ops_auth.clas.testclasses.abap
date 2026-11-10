*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_auth.clas.testclasses.abap
*& Purpose:
*& Unit tests of the ZCA_OPS authorisation wrapper through its test seams:
*& area-wide check without company code, company-code check with one, and
*& check( ) raising message 041 when refused. The kernel AUTHORITY-CHECK is
*& replaced by TEST-INJECTION; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-07 | Company-code test uses activity 02 (activity 43 removed, read-only scope).
*& 2026-11-10 | may_read_table through test seam AUTH_TABLE (S_TABU_NAM 03).
*& 2026-11-10 | Moved from ZCL_CD_OPS_AUTH to the reusable framework ZCA_OPS (test include).
*&---------------------------------------------------------------------*
CLASS ltc_auth DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_bukrs TYPE bukrs VALUE 'US01'.
    CONSTANTS gc_msgno_refused TYPE symsgno VALUE '041'.

    TYPES:
      BEGIN OF ty_flags,
        area_allowed  TYPE abap_bool,
        bukrs_allowed TYPE abap_bool,
      END OF ty_flags.

    DATA mo_cut TYPE REF TO zif_ca_ops_auth.

    METHODS setup.
    METHODS teardown.
    METHODS no_bukrs_uses_area_check FOR TESTING.
    METHODS bukrs_uses_bukrs_check FOR TESTING.
    METHODS refused_check_raises_041 FOR TESTING.
    METHODS allowed_check_passes FOR TESTING.
    METHODS table_display_decides FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
ENDCLASS.


CLASS ltc_auth IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_ca_ops_auth( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " The two seams answer differently, so the result shows which check ran
  METHOD configure_scenario.
    IF is_flags-area_allowed = abap_true.
      TEST-INJECTION auth_area.
        rv_allowed = abap_true.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION auth_area.
        rv_allowed = abap_false.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-bukrs_allowed = abap_true.
      TEST-INJECTION auth_bukrs.
        rv_allowed = abap_true.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION auth_bukrs.
        rv_allowed = abap_false.
      END-TEST-INJECTION.
    ENDIF.
  ENDMETHOD.


  " Rule: without company code the object is checked area-wide (BUKRS as DUMMY)
  METHOD no_bukrs_uses_area_check.
    TRY.
        configure_scenario( VALUE #( area_allowed = abap_true ) ).
        cl_abap_unit_assert=>assert_true(
          act = mo_cut->is_allowed( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                    iv_area  = zcl_ca_ops_param_seed=>gc_test_area-first )
          msg = 'Area-wide check decides without company code' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: with a company code the company-code check decides
  METHOD bukrs_uses_bukrs_check.
    TRY.
        configure_scenario( VALUE #( area_allowed = abap_true ) ).
        cl_abap_unit_assert=>assert_false(
          act = mo_cut->is_allowed( iv_activity = zif_ca_ops_auth=>gc_activity-change
                                    iv_area  = zcl_ca_ops_param_seed=>gc_test_area-first
                                    iv_bukrs    = gc_bukrs )
          msg = 'Company-code check decides with company code' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a refused check raises message 041 - a caller can never ignore it
  METHOD refused_check_raises_041.
    configure_scenario( VALUE #( ) ).
    TRY.
        mo_cut->check( iv_activity = zif_ca_ops_auth=>gc_activity-change
                       iv_area  = zcl_ca_ops_param_seed=>gc_test_area-first ).
        cl_abap_unit_assert=>fail( msg = 'Refused check must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_refused
                                            msg = 'Refusal is message 041' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an allowed check returns without exception
  METHOD allowed_check_passes.
    TRY.
        configure_scenario( VALUE #( bukrs_allowed = abap_true ) ).
        mo_cut->check( iv_activity = zif_ca_ops_auth=>gc_activity-display
                       iv_area  = zcl_ca_ops_param_seed=>gc_test_area-first
                       iv_bukrs    = gc_bukrs ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Allowed check passes' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: S_TABU_NAM display decides whether a configured table is read
  METHOD table_display_decides.
    TEST-INJECTION auth_table.
      rv_allowed = abap_false.
    END-TEST-INJECTION.
    cl_abap_unit_assert=>assert_false( act = mo_cut->may_read_table( 'T000' )
                                       msg = 'Without S_TABU_NAM 03 the table is not read' ).
  ENDMETHOD.

ENDCLASS.
