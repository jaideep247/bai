*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_file_path.clas.abap
*& Purpose:
*& The only way the suite turns a user's file name into an application
*& server path (no directory traversal): the user enters a file name only
*& (no '/', '\' or '..'); the directory comes from a logical path of
*& transaction FILE (FILE_GET_NAME_USING_PATH), the result is validated
*& against the logical file name of the purpose (FILE_VALIDATE_NAME), and
*& S_DATASET is checked explicitly for the activity (AUTHORITY_CHECK_DATASET,
*& READ for the EBS input file, WRITE for the morning report export). The
*& logical names are constants (ZIF_CD_OPS_TYPES=>GC_LOGICAL_FILE), created
*& in FILE as a setup step (Implementation_Order.md). Each SAP call sits in a
*& test seam (FILE_NAME, FILE_VALIDATE, FILE_AUTH); results in locals.
*& Modification log:
*& 2026-11-10 | Initial version (directory traversal: logical paths only).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - file name to logical path (FILE)</p>
CLASS zcl_cd_ops_file_path DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Physical path of iv_file_name in the logical path of the purpose, validated and
    "! authorised (S_DATASET) for iv_activity (READ / WRITE)
    "! @raising zcx_cd_ops_error | 808 name with a path part, 807 not resolved / not valid, 809 no S_DATASET
    CLASS-METHODS physical
      IMPORTING
        is_logical       TYPE zif_cd_ops_types=>ty_logical_file
        iv_file_name     TYPE clike
        iv_activity      TYPE zif_cd_ops_types=>ty_dataset_activity
      RETURNING
        VALUE(rv_path)   TYPE string
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    "! Characters and sequences that would leave the logical path
    CONSTANTS:
      BEGIN OF gc_forbidden,
        slash     TYPE string VALUE `/`,
        backslash TYPE string VALUE `\`,
        parent    TYPE string VALUE `..`,
      END OF gc_forbidden.

ENDCLASS.



CLASS zcl_cd_ops_file_path IMPLEMENTATION.

  METHOD physical.
    " VERIFY-ADT: FILE_GET_NAME_USING_PATH returns FILE_NAME_WITH_PATH as C - length 1024 here
    DATA lv_physical TYPE c LENGTH 1024.
    DATA lv_subrc TYPE sysubrc.

    DATA(lv_name) = condense( CONV string( iv_file_name ) ).
    IF lv_name IS INITIAL
       OR lv_name CS gc_forbidden-slash
       OR lv_name CS gc_forbidden-backslash
       OR lv_name CS gc_forbidden-parent.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e808(zcd_ops) WITH iv_file_name.
    ENDIF.

    TEST-SEAM file_name.
      CALL FUNCTION 'FILE_GET_NAME_USING_PATH'
        EXPORTING
          logical_path               = is_logical-path
          file_name                  = lv_name
        IMPORTING
          file_name_with_path        = lv_physical
        EXCEPTIONS
          path_not_found             = 1
          missing_parameter          = 2
          operating_system_not_found = 3
          file_system_not_found      = 4
          OTHERS                     = 5.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0 OR lv_physical IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e807(zcd_ops) WITH is_logical-path lv_name.
    ENDIF.

    TEST-SEAM file_validate.
      CALL FUNCTION 'FILE_VALIDATE_NAME'
        EXPORTING
          logical_filename           = is_logical-file
        CHANGING
          physical_filename          = lv_physical
        EXCEPTIONS
          logical_filename_not_found = 1
          validation_failed          = 2
          OTHERS                     = 3.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e807(zcd_ops) WITH is_logical-file lv_name.
    ENDIF.

    TEST-SEAM file_auth.
      CALL FUNCTION 'AUTHORITY_CHECK_DATASET'
        EXPORTING
          program          = sy-cprog
          activity         = iv_activity
          filename         = CONV authb-filename( lv_physical )
        EXCEPTIONS
          no_authority     = 1
          activity_unknown = 2
          OTHERS           = 3.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e809(zcd_ops) WITH lv_name iv_activity.
    ENDIF.
    rv_path = condense( CONV string( lv_physical ) ).
  ENDMETHOD.

ENDCLASS.
