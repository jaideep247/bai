*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dataset.clas.abap
*& Purpose:
*& ZIF_CD_HCK_FILE over OPEN / TRANSFER / CLOSE / DELETE DATASET (application
*& server). Thin wrapper: authorisation is checked by the caller (report).
*& Modification log:
*& 2026-11-06 | Initial version (audit A61: no truncated report export).
*& 2026-11-10 | Callers pass only a path resolved by ZCL_CA_OPS_FILE_PATH (logical path, S_DATASET).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - application server file (DATASET)</p>
CLASS zcl_cd_hck_dataset DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_file.

ENDCLASS.



CLASS zcl_cd_hck_dataset IMPLEMENTATION.

  METHOD zif_cd_hck_file~open_output.
    TRY.
        OPEN DATASET iv_file FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e316(zcd_ops) WITH iv_file.
        ENDIF.
      CATCH cx_sy_file_access_error INTO DATA(lx_file).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e316(zcd_ops) WITH iv_file
          EXPORTING
            previous = lx_file.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_hck_file~transfer.
    TRY.
        TRANSFER iv_line TO iv_file.
      CATCH cx_sy_file_access_error INTO DATA(lx_file).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e368(zcd_ops) WITH iv_file
          EXPORTING
            previous = lx_file.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_hck_file~close.
    TRY.
        CLOSE DATASET iv_file.
      CATCH cx_sy_file_access_error ##NO_HANDLER.
        " closing a file that is not open: nothing to do
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_hck_file~delete.
    TRY.
        DELETE DATASET iv_file.
      CATCH cx_sy_file_access_error ##NO_HANDLER.
        " deleting a file that does not exist: nothing to do
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
