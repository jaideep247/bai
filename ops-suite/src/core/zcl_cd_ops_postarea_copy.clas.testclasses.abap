*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_copy.clas.testclasses.abap
*& Purpose:
*& Application tests of the copy from a posting area into a typed mapping
*& version with the in-memory mappings ZCL_CD_OPS_POSTAREA_MEM and the
*& delivered parameters: statuses (COPY, TOO_LONG, VERSION_USED), the ZBTM
*& disposition POSTED, the written rows read back through the reader with
*& source T give the same entries as the posting area with source P. Does
*& not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (written before the class; migration step of the typed tables).
*&---------------------------------------------------------------------*
CLASS ltc_copy DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        rsn_area TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZRSN',
        btm_area TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTM',
        v1       TYPE zif_cd_ops_postarea_types=>ty_version VALUE '0001',
        v2       TYPE zif_cd_ops_postarea_types=>ty_version VALUE '0002',
      END OF gc_test.

    DATA mo_mem    TYPE REF TO zcl_cd_ops_postarea_mem.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.

    METHODS plan_copies_every_entry   FOR TESTING.
    METHODS too_long_left_out         FOR TESTING.
    METHODS used_version_copies_none  FOR TESTING.
    METHODS btc_map_disposition_posted FOR TESTING.
    METHODS written_same_as_source_p  FOR TESTING.
ENDCLASS.


CLASS ltc_copy IMPLEMENTATION.

  METHOD setup.
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    mo_mem = NEW #( ).
    zcl_cd_ops_postarea_injector=>inject_dao( mo_mem ).
    mo_mem->add( iv_area = gc_test-rsn_area iv_keys = `R01` iv_results = `R1/` ).
    mo_mem->add( iv_area = gc_test-rsn_area iv_keys = `C01` iv_results = `/X` ).
    mo_mem->add( iv_area = gc_test-rsn_area iv_keys = `*` iv_results = `RZ/` ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_postarea_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_mem, mo_params.
  ENDMETHOD.


  " Rule: every stored entry of the posting area is planned (status COPY), test mode writes nothing
  METHOD plan_copies_every_entry.
    TRY.
        DATA(lt_rows) = zcl_cd_ops_postarea_copy=>plan( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                        iv_version = gc_test-v1 ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_copy=>count(
                                                    it_rows   = lt_rows
                                                    iv_status = zif_cd_ops_postarea_types=>gc_copy-copy )
                                            exp = 3 msg = 'Three entries to copy' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_mem->zif_cd_ops_pamap_dao~read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                           iv_version = gc_test-v1 )
          msg = 'The plan writes nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a value longer than the typed column (ZRSN reason 4) is left out (TOO_LONG), never truncated
  METHOD too_long_left_out.
    TRY.
        mo_mem->add( iv_area = gc_test-rsn_area iv_keys = `R0123` iv_results = `R1/` ).
        DATA(lt_rows) = zcl_cd_ops_postarea_copy=>plan( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                        iv_version = gc_test-v1 ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_copy=>count(
                                                    it_rows   = lt_rows
                                                    iv_status = zif_cd_ops_postarea_types=>gc_copy-too_long )
                                            exp = 1 msg = 'R0123 does not fit CHAR 4' ).
        zcl_cd_ops_postarea_copy=>write( EXPORTING iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                   iv_version = gc_test-v1
                                         CHANGING  ct_rows    = lt_rows ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( mo_mem->zif_cd_ops_pamap_dao~read_entries( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                                  iv_version = gc_test-v1 ) )
          exp = 3 msg = 'Only the rows that fit are written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a version that already has rows is never extended - nothing is copied
  METHOD used_version_copies_none.
    TRY.
        mo_mem->add_typed( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason iv_keys = `R01` iv_results = `R1/` ).
        DATA(lt_rows) = zcl_cd_ops_postarea_copy=>plan( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                        iv_version = gc_test-v1 ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_copy=>count(
                                                    it_rows   = lt_rows
                                                    iv_status = zif_cd_ops_postarea_types=>gc_copy-version_used )
                                            exp = 3 msg = 'Every entry: version used' ).
        zcl_cd_ops_postarea_copy=>write( EXPORTING iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                   iv_version = gc_test-v1
                                         IMPORTING er_rows    = DATA(lr_rows)
                                         CHANGING  ct_rows    = lt_rows ).
        cl_abap_unit_assert=>assert_not_bound( act = lr_rows msg = 'Nothing written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (user decision 2026-11-15): ZBTM rows state their disposition - an FQC0 entry (no 7th result)
  " was posted as usual, so it is copied as POSTED
  METHOD btc_map_disposition_posted.
    TRY.
        mo_mem->add( iv_area = gc_test-btm_area iv_keys = `BAI2/495///*/*` iv_results = `W01//D/WIRE//AUTO_POST` ).
        DATA(lt_rows) = zcl_cd_ops_postarea_copy=>plan( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                                                        iv_version = gc_test-v1 ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-fun07 exp = CONV string( zif_cd_ebs_types=>gc_disposition-posted )
                                            msg = 'Disposition POSTED' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status exp = zif_cd_ops_postarea_types=>gc_copy-copy
                                            msg = 'Copied although ZBTM is never read from a posting area' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: after the copy, the reader with source T and the new version gives the entries of source P
  METHOD written_same_as_source_p.
    TRY.
        DATA(lo_reader) = zcl_cd_ops_postarea_factory=>get_reader( ).
        DATA(lt_source_p) = lo_reader->entries( zif_cd_ops_postarea_types=>gc_purpose-reason ).
        DATA(lt_rows) = zcl_cd_ops_postarea_copy=>plan( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                        iv_version = gc_test-v2 ).
        zcl_cd_ops_postarea_copy=>write( EXPORTING iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                                                   iv_version = gc_test-v2
                                         CHANGING  ct_rows    = lt_rows ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_postarea_copy=>count(
                                                    it_rows   = lt_rows
                                                    iv_status = zif_cd_ops_postarea_types=>gc_copy-written )
                                            exp = 3 msg = 'Three rows written' ).
        mo_params->set( iv_name  = zif_cd_ops_postarea_types=>gc_param-source_reason
                        iv_value = zif_cd_ops_postarea_types=>gc_source-typed ).
        mo_params->set( iv_name = zif_cd_ops_postarea_types=>gc_param-version_reason iv_value = '2' ).
        zcl_cd_ops_postarea_injector=>renew_reader( ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ops_postarea_factory=>get_reader( )->entries( zif_cd_ops_postarea_types=>gc_purpose-reason )
          exp = lt_source_p
          msg = 'Source T, version 2: the same entries as source P' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
