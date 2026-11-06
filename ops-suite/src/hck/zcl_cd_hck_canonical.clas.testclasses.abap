*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_canonical.clas.testclasses.abap
*& Purpose:
*& Unit tests of the canonical row serialization used by the drift hash;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (audit A57).
*&---------------------------------------------------------------------*
CLASS ltc_canonical DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_row,
        first  TYPE c LENGTH 10,
        second TYPE c LENGTH 10,
      END OF ty_row.

    METHODS separator_values_differ FOR TESTING.
    METHODS same_row_same_text FOR TESTING.
    METHODS field_is_length_prefixed FOR TESTING.

ENDCLASS.



CLASS ltc_canonical IMPLEMENTATION.

  " Audit A57: A|B,C and A,B|C must not serialize (and hash) alike
  METHOD separator_values_differ.
    DATA ls_one TYPE ty_row.
    DATA ls_two TYPE ty_row.
    TRY.
        ls_one-first  = 'A|B'.
        ls_one-second = 'C'.
        ls_two-first  = 'A'.
        ls_two-second = 'B|C'.
        cl_abap_unit_assert=>assert_differs( act = zcl_cd_hck_canonical=>row( ls_one )
                                             exp = zcl_cd_hck_canonical=>row( ls_two )
                                             msg = 'Values containing the separator must not collide' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The serialization is deterministic
  METHOD same_row_same_text.
    DATA ls_one TYPE ty_row.
    DATA ls_two TYPE ty_row.
    TRY.
        ls_one-first  = 'X'.
        ls_one-second = 'Y'.
        ls_two = ls_one.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_canonical=>row( ls_one )
                                            exp = zcl_cd_hck_canonical=>row( ls_two )
                                            msg = 'Equal rows must give equal text' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A field is <type kind>:<length>:<value>;
  METHOD field_is_length_prefixed.
    DATA lv_value TYPE c LENGTH 10.
    TRY.
        lv_value = 'A|B'.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_canonical=>field( lv_value )
                                            exp = `C:3:A|B;`
                                            msg = 'Type kind, length and value expected' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
