*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_budget.clas.abap
*& Purpose:
*& Time budget of a running check (audit A18): a synchronous ABAP check cannot be
*& interrupted, so checks that work in items ask between items whether the budget
*& from the engine (deadline in the context) is used up, and stop with a finding.
*& Modification log:
*& 2026-11-06 | Initial version (audit A18: time budget per check).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - time budget of a running check</p>
CLASS zcl_cd_hck_budget DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Deadline set and passed (clock from the core factory)
    CLASS-METHODS exhausted
      IMPORTING
        is_context       TYPE zif_cd_hck_types=>ty_context
      RETURNING
        VALUE(rv_passed) TYPE abap_bool.

    "! Finding written when a check stops early
    CLASS-METHODS stop_finding
      IMPORTING
        iv_check_id       TYPE zif_cd_hck_types=>ty_check_id
        iv_done           TYPE i
        iv_total          TYPE i
        is_context        TYPE zif_cd_hck_types=>ty_context
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_cd_hck_budget IMPLEMENTATION.

  METHOD exhausted.
    IF is_context-deadline IS INITIAL.
      RETURN.
    ENDIF.
    rv_passed = xsdbool( zcl_cd_ops_factory=>get_clock( )->now( ) > is_context-deadline ).
  ENDMETHOD.


  METHOD stop_finding.
    rs_finding-object_key = iv_check_id.
    rs_finding-check_code = zif_cd_hck_types=>gc_code-budget_exhausted.
    rs_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
    rs_finding-action     = zif_cd_ops_types=>gc_action-notify.
    rs_finding-message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-budget_exhausted
                                                   iv_v1    = iv_check_id
                                                   iv_v2    = iv_done
                                                   iv_v3    = iv_total
                                                   iv_v4    = is_context-budget_sec ).
  ENDMETHOD.

ENDCLASS.
