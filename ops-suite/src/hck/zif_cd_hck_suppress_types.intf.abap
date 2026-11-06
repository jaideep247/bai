*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_suppress_types.intf.abap
*& Purpose:
*& Types and constants of the health-check suppression (design 6.3):
*& suppression rows (ZCD_HCK_SUPPRESS), statuses and messages.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - suppression types</p>
INTERFACE zif_cd_hck_suppress_types
  PUBLIC.

  TYPES ty_status TYPE c LENGTH 1.

  CONSTANTS:
    BEGIN OF gc_status,
      active    TYPE ty_status VALUE 'A',
      requested TYPE ty_status VALUE 'R',
    END OF gc_status.

  "! Longest suppression without a second user (days), parameter HCK_SUPPRESS_MAX_DAYS
  CONSTANTS gc_default_max_days TYPE i VALUE 7.

  TYPES:
    BEGIN OF ty_suppression,
      suppress_uuid TYPE sysuuid_x16,
      check_id      TYPE zif_cd_hck_types=>ty_check_id,
      key_pattern   TYPE zif_cd_ops_types=>ty_object_key,
      bukrs         TYPE c LENGTH 4,
      valid_from    TYPE d,
      valid_to      TYPE d,
      status        TYPE ty_status,
      created_by    TYPE syuname,
    END OF ty_suppression.
  TYPES tt_suppression TYPE STANDARD TABLE OF ty_suppression WITH EMPTY KEY.

  CONSTANTS:
    BEGIN OF gc_msg,
      period_invalid TYPE symsgno VALUE '320',
      not_requested  TYPE symsgno VALUE '321',
      check_missing  TYPE symsgno VALUE '322',
      "! core messages
      same_user      TYPE symsgno VALUE '063',
      no_reason      TYPE symsgno VALUE '062',
    END OF gc_msg.

ENDINTERFACE.
