*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_release_dao.intf.abap
*& Purpose:
*& Repository of blocked-line releases for the posting gate: approved
*& releases of a set of line keys.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - release repository</p>
INTERFACE zif_cd_ebs_release_dao
  PUBLIC.

  "! Approved releases (status A) of the given line keys
  METHODS get_approved
    IMPORTING
      it_object_keys     TYPE zif_cd_ops_types=>tt_object_key
    RETURNING
      VALUE(rt_releases) TYPE zif_cd_ebs_release_types=>tt_release.

ENDINTERFACE.
