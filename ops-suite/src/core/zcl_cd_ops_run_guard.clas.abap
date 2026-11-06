*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_run_guard.clas.abap
*& Purpose:
*& What a run does when the run lock is held by another run: nothing is
*& validated or persisted; the result is an aborted, red run with one
*& RUN_LOCKED finding (message 040), dispatched once through the alert router
*& (rule pattern RUN_LOCKED) so the job owner is told. Reports recognise it
*& with was_refused( ).
*& Modification log:
*& 2026-11-06 | Initial version (run lock).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - refused run (run lock held)</p>
CLASS zcl_cd_ops_run_guard DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS gc_check_code TYPE zif_cd_ops_types=>ty_check_code VALUE 'RUN_LOCKED'.
    CONSTANTS gc_object_type TYPE zif_cd_ops_types=>ty_object_type VALUE 'RUN'.

    TYPES:
      BEGIN OF ty_refusal,
        run      TYPE zif_cd_ops_types=>ty_run,
        findings TYPE zif_cd_ops_types=>tt_finding,
      END OF ty_refusal.

    "! Build the refused run and alert it (alert failures are swallowed: the
    "! refusal is still returned to the caller and shown by the report)
    CLASS-METHODS refuse
      IMPORTING
        iv_module         TYPE zif_cd_ops_types=>ty_module
        iv_variant        TYPE zif_cd_ops_types=>ty_variant
        iv_holder         TYPE syuname
      RETURNING
        VALUE(rs_refusal) TYPE ty_refusal.

    CLASS-METHODS was_refused
      IMPORTING
        it_findings       TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rv_refused) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ops_run_guard IMPLEMENTATION.

  METHOD refuse.
    DATA lv_text TYPE zif_cd_ops_types=>ty_message.

    MESSAGE e040(zcd_ops) WITH iv_module iv_variant iv_holder INTO lv_text.

    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    TRY.
        rs_refusal-run-run_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        " The refusal is still reported; only the alert log loses its run reference
        CLEAR rs_refusal-run-run_id.
    ENDTRY.
    rs_refusal-run-module        = iv_module.
    rs_refusal-run-variant       = iv_variant.
    rs_refusal-run-started_at    = lv_now.
    rs_refusal-run-ended_at      = lv_now.
    rs_refusal-run-status        = zif_cd_ops_types=>gc_run_status-aborted.
    rs_refusal-run-rag           = zif_cd_ops_types=>gc_rag-red.
    rs_refusal-run-finding_count = 1.
    rs_refusal-run-message       = lv_text.
    rs_refusal-run-created_by    = sy-uname.

    INSERT VALUE #( object_type = gc_object_type
                    object_key  = |{ iv_module }/{ iv_variant }|
                    group1      = iv_module
                    rule_id     = 'LOCK'
                    check_code  = gc_check_code
                    severity    = zif_cd_ops_types=>gc_severity-error
                    action      = zif_cd_ops_types=>gc_action-notify
                    reference   = iv_holder
                    message     = lv_text ) INTO TABLE rs_refusal-findings.

    TRY.
        zcl_cd_ops_factory=>get_alert( )->dispatch( is_run      = rs_refusal-run
                                                    it_findings = rs_refusal-findings ).
      CATCH zcx_cd_ops_error ##NO_HANDLER.
        " Alert configuration unreadable: the report still shows message 040
    ENDTRY.
  ENDMETHOD.


  METHOD was_refused.
    rv_refused = xsdbool( line_exists( it_findings[ check_code = gc_check_code ] ) ).
  ENDMETHOD.

ENDCLASS.
