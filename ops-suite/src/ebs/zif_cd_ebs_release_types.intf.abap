*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_release_types.intf.abap
*& Purpose:
*& Types and constants of the blocked-line release (design 6.2): release
*& rows (ZCD_EBS_RELEASE), statuses and messages.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - blocked-line release types</p>
INTERFACE zif_cd_ebs_release_types
  PUBLIC.

  TYPES ty_status TYPE c LENGTH 1.

  CONSTANTS:
    BEGIN OF gc_status,
      requested TYPE ty_status VALUE 'R',
      approved  TYPE ty_status VALUE 'A',
      rejected  TYPE ty_status VALUE 'X',
    END OF gc_status.

  TYPES:
    BEGIN OF ty_release,
      release_uuid TYPE sysuuid_x16,
      object_key   TYPE zif_cd_ops_types=>ty_object_key,
      check_code   TYPE zif_cd_ops_types=>ty_check_code,
      reason       TYPE zif_cd_ops_exc_types=>ty_reason,
      status       TYPE ty_status,
      requested_by TYPE syuname,
      approved_by  TYPE syuname,
    END OF ty_release.
  TYPES tt_release TYPE STANDARD TABLE OF ty_release WITH EMPTY KEY.

  "! ZCD_OPS messages of the release (EBS range)
  CONSTANTS:
    BEGIN OF gc_msg,
      not_requested TYPE symsgno VALUE '160',
      key_missing   TYPE symsgno VALUE '161',
      "! core message: four-eyes
      same_user     TYPE symsgno VALUE '063',
      "! core message: reason required
      no_reason     TYPE symsgno VALUE '062',
    END OF gc_msg.

ENDINTERFACE.
