*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_release_dao.clas.abap
*& Purpose:
*& Reads approved blocked-line releases (ZCD_EBS_RELEASE, status A) for the
*& posting gate of ZCL_CD_EBS_ENGINE. Read only.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - release repository</p>
CLASS zcl_cd_ebs_release_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_release_dao.
ENDCLASS.



CLASS zcl_cd_ebs_release_dao IMPLEMENTATION.

  METHOD zif_cd_ebs_release_dao~get_approved.
    CHECK it_object_keys IS NOT INITIAL.
    " index ZCD_EBS_RELEASE~OBJ
    SELECT release_uuid, object_key, check_code, reason, status, requested_by, approved_by
      FROM zcd_ebs_release
      FOR ALL ENTRIES IN @it_object_keys
      WHERE object_key = @it_object_keys-table_line
        AND status     = @zif_cd_ebs_release_types=>gc_status-approved
      INTO CORRESPONDING FIELDS OF TABLE @rt_releases.
  ENDMETHOD.

ENDCLASS.
