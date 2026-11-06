*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_reject.clas.testclasses.abap
*& Purpose:
*& Pure unit tests of the reject check: parameter OUTCOME=PRISM_FAILED reports
*& only PRISM failures; without it NACK / FAILED as before. Static ABAP Unit
*& only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API: check row F_PRFAIL).
*&---------------------------------------------------------------------*
CLASS ltc_reject DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA ms_ctx TYPE zif_cd_fmon_types=>ty_check_ctx.

    METHODS setup.

    METHODS act
      IMPORTING
        iv_params       TYPE zif_cd_fmon_types=>ty_params OPTIONAL
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        zcx_cd_ops_error.

    METHODS add_file
      IMPORTING
        iv_name    TYPE zif_cd_fmon_types=>ty_file_name
        iv_outcome TYPE zif_cd_fmon_types=>ty_stage.

    METHODS prism_param_only_prism FOR TESTING.
    METHODS default_ignores_prism_failed FOR TESTING.

ENDCLASS.


CLASS ltc_reject IMPLEMENTATION.

  METHOD setup.
    CLEAR ms_ctx.
    add_file( iv_name = 'ACH_PNC_1' iv_outcome = zif_cd_fmon_types=>gc_stage-prism_failed ).
    add_file( iv_name = 'ACH_PNC_2' iv_outcome = zif_cd_fmon_types=>gc_stage-nack ).
    add_file( iv_name = 'ACH_RET_3' iv_outcome = zif_cd_fmon_types=>gc_stage-failed ).
  ENDMETHOD.


  METHOD add_file.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    ls_file-file_name = iv_name.
    ls_file-outcome   = iv_outcome.
    ls_file-stage     = iv_outcome.
    INSERT ls_file INTO TABLE ms_ctx-files.
  ENDMETHOD.


  METHOD act.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id = 'F_REJECT'.
    ls_check-params   = iv_params.
    DATA(lt_findings) = NEW zcl_cd_fmon_chk_reject( )->zif_cd_fmon_check~execute( is_ctx   = ms_ctx
                                                                                 is_check = ls_check ).
    LOOP AT lt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      INSERT |{ <ls_finding>-check_code }:{ <ls_finding>-object_key }| INTO TABLE rt_codes.
    ENDLOOP.
    SORT rt_codes.
  ENDMETHOD.


  " Rule: OUTCOME=PRISM_FAILED reports exactly the files PRISM could not process or deliver.
  METHOD prism_param_only_prism.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = act( 'OUTCOME=PRISM_FAILED' )
                                            exp = VALUE string_table( ( `PRISM_FAILED:ACH_PNC_1` ) )
                                            msg = 'Only the PRISM failure must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without the parameter the check is unchanged (NACK, FAILED) - no duplicate PRISM finding.
  METHOD default_ignores_prism_failed.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = VALUE string_table( ( `FILE_FAILED:ACH_RET_3` ) ( `NACK:ACH_PNC_2` ) )
                                            msg = 'NACK and FAILED as before' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
