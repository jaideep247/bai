*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_regen.clas.abap
*& Purpose:
*& Plug-in check FILE_REGENERATED_NOT_FAILED: a file regenerated for the
*& same payments (same interface and generation group, new name) while the
*& earlier generation did not fail - both delivered, or the earlier one still
*& in flight: a possible duplicate payment file to the bank / IRIS. Pure; the
*& failed side (replaced / regeneration missing) is ZCL_CD_FMON_CHK_REJECT.
*& Modification log:
*& 2026-11-07 | Initial version (regenerated files, user facts 2026-11-07).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring check - regenerated file, earlier not failed</p>
"! Row F_REGEN (severity from the row, seed B: critical). Runs in the 5-minute run and in the
"! instant PRISM unit (ZCL_CD_FMON_ENGINE=>RUN_EVENT): the context carries every known generation of
"! the groups of the files (ZCD_FMON_FILE index GRP). Files without a generation group (no source
"! with GROUP_FIELDS) are never reported.
CLASS zcl_cd_fmon_chk_regen DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.

  PRIVATE SECTION.
    "! File name, else reference
    CLASS-METHODS name_of
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_name) TYPE string.

ENDCLASS.



CLASS zcl_cd_fmon_chk_regen IMPLEMENTATION.

  METHOD zif_cd_fmon_check~execute.
    LOOP AT is_ctx-files ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE gen_group IS NOT INITIAL.
      DATA(ls_earlier) = zcl_cd_fmon_rules=>unfailed_predecessor( is_file        = <ls_file>
                                                                  it_generations = is_ctx-generations ).
      IF ls_earlier IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT zcl_cd_fmon_util=>new_finding(
               is_file    = <ls_file>
               is_check   = is_check
               iv_code    = zif_cd_fmon_types=>gc_check_code-regen_not_failed
               iv_message = zcl_cd_ops_util=>text(
                              iv_msgno = zif_cd_fmon_types=>gc_msg-regen_not_failed
                              iv_v1    = name_of( <ls_file> )
                              iv_v2    = name_of( ls_earlier )
                              iv_v3    = COND string( WHEN ls_earlier-outcome IS NOT INITIAL THEN ls_earlier-outcome
                                                      ELSE ls_earlier-stage ) ) ) INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD name_of.
    rv_name = COND #( WHEN is_file-file_name IS NOT INITIAL THEN is_file-file_name ELSE is_file-file_ref ).
  ENDMETHOD.

ENDCLASS.
