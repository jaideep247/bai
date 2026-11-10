*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_ops_policy.clas.abap
*& Purpose:
*& File-monitoring operations rules, pure: a manual status (design 6.4) needs
*& a reason and a transition ZCL_CD_FMON_STATUS would make itself; a PRISM
*& payment request handled manually (6.5, record only) needs the request,
*& a handling reference and a reason.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - operations rules (manual, PRISM)</p>
CLASS zcl_cd_fmon_ops_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF gc_msg,
        not_allowed TYPE symsgno VALUE '230',
        incomplete  TYPE symsgno VALUE '232',
        "! core message: reason required
        no_reason   TYPE symsgno VALUE '062',
      END OF gc_msg.

    CLASS-METHODS check_manual
      IMPORTING
        iv_stage           TYPE zif_cd_fmon_types=>ty_stage
        iv_reason          TYPE zif_ca_ops_exc_types=>ty_reason
        is_file            TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

    CLASS-METHODS check_handled
      IMPORTING
        iv_request_ref     TYPE zif_cd_fmon_types=>ty_file_ref
        iv_reference       TYPE zif_ca_ops_exc_types=>ty_reference
        iv_reason          TYPE zif_ca_ops_exc_types=>ty_reason
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.
ENDCLASS.



CLASS zcl_cd_fmon_ops_policy IMPLEMENTATION.

  METHOD check_manual.
    IF iv_reason IS INITIAL.
      rs_decision-msgno = gc_msg-no_reason.
    ELSEIF zcl_cd_fmon_status=>manual_allowed( iv_stage = iv_stage is_file = is_file ) = abap_false.
      rs_decision-msgno = gc_msg-not_allowed.
      rs_decision-v1    = iv_stage.
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD check_handled.
    IF iv_request_ref IS INITIAL OR iv_reference IS INITIAL OR iv_reason IS INITIAL.
      rs_decision-msgno = gc_msg-incomplete.
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
