*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_util.clas.testclasses.abap
*& Purpose:
*& Unit tests for the file-reference normalisation of ZCL_CD_FMON_UTIL
*& (audit A100): a canonical name longer than the correlation key keeps its
*& identity through a digest. Domain level, no doubles. Does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (audit A100).
*& 2026-11-06 | Modern-syntax sweep: caught exception lx_error.
*&---------------------------------------------------------------------*
CLASS ltc_normalize_ref DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_short TYPE string VALUE ` ach_pnc_20261102_01 `.
    CONSTANTS gc_tail_a TYPE string VALUE `_PART_A.TXT`.
    CONSTANTS gc_tail_b TYPE string VALUE `_PART_B.TXT`.

    METHODS short_ref_is_canonical FOR TESTING.
    METHODS long_names_stay_distinct FOR TESTING.
    METHODS same_long_name_same_ref FOR TESTING.
    METHODS digest_ref_fits_the_key FOR TESTING.
    METHODS long_name_ref_is_digest FOR TESTING.

    "! A 75-character file name whose first 70 characters are identical for every tail
    METHODS long_name
      IMPORTING
        iv_tail        TYPE string
      RETURNING
        VALUE(rv_name) TYPE string.
ENDCLASS.


CLASS ltc_normalize_ref IMPLEMENTATION.

  METHOD long_name.
    rv_name = |ACH_PNC_{ repeat( val = `9` occ = 64 ) }{ iv_tail }|.
  ENDMETHOD.


  " A reference that fits the key is only condensed and upper-cased
  METHOD short_ref_is_canonical.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_util=>normalize_ref( gc_short )
                                            exp = 'ACH_PNC_20261102_01'
                                            msg = 'A short reference must stay readable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A100: two names that differ only after character 70 are two files
  METHOD long_names_stay_distinct.
    TRY.
        cl_abap_unit_assert=>assert_differs( act = zcl_cd_fmon_util=>normalize_ref( long_name( gc_tail_a ) )
                                             exp = zcl_cd_fmon_util=>normalize_ref( long_name( gc_tail_b ) )
                                             msg = 'Names differing after character 70 must not share a reference' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The same long name always yields the same reference (same file instance)
  METHOD same_long_name_same_ref.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_fmon_util=>normalize_ref( long_name( gc_tail_a ) )
                                            exp = zcl_cd_fmon_util=>normalize_ref( to_lower( long_name( gc_tail_a ) ) )
                                            msg = 'The same long name must give the same reference' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The digest reference fits the 70-character correlation key exactly
  METHOD digest_ref_fits_the_key.
    TRY.
        DATA(lv_ref) = zcl_cd_fmon_util=>normalize_ref( long_name( gc_tail_a ) ).
        cl_abap_unit_assert=>assert_equals( act = strlen( lv_ref )
                                            exp = zif_cd_fmon_types=>gc_ref_digest-width
                                            msg = 'A digest reference must use the full key width' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A digest reference is recognisable, so the engine can verify the full name
  METHOD long_name_ref_is_digest.
    TRY.
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_fmon_util=>is_digest_ref( zcl_cd_fmon_util=>normalize_ref( long_name( gc_tail_a ) ) )
          msg = 'A long-name reference must be marked as a digest' ).
        cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_util=>is_digest_ref( zcl_cd_fmon_util=>normalize_ref( gc_short ) )
                                           msg = 'A short reference is not a digest' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
