*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_exc_policy.clas.abap
*& Purpose:
*& Exception lifecycle rules for the exceptions app (design 6.1): assign to
*& an owner, resolve with a reason, request a waiver until a date, approve
*& it by a different user (four-eyes). Pure: no database, no clock, no user.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-10 | Moved from ZCL_CD_OPS_EXC_POLICY to the reusable framework ZCA_OPS.
*& 2026-11-10 | CAN_CLASSIFY: reason code of an open exception (values of EXC_REASON_CODES).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - exception lifecycle rules</p>
CLASS zcl_ca_ops_exc_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS can_assign
      IMPORTING
        is_state           TYPE zif_ca_ops_exc_types=>ty_state
        iv_owner           TYPE syuname
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

    CLASS-METHODS can_resolve
      IMPORTING
        is_state           TYPE zif_ca_ops_exc_types=>ty_state
        iv_reason          TYPE zif_ca_ops_exc_types=>ty_reason
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

    CLASS-METHODS can_request_waiver
      IMPORTING
        is_state           TYPE zif_ca_ops_exc_types=>ty_state
        iv_reason          TYPE zif_ca_ops_exc_types=>ty_reason
        iv_valid_to        TYPE d
        iv_today           TYPE d
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

    "! Reason code of an open exception: one of the allowed codes (comma list, case ignored)
    CLASS-METHODS can_classify
      IMPORTING
        is_state           TYPE zif_ca_ops_exc_types=>ty_state
        iv_reason_code     TYPE zif_ca_ops_exc_types=>ty_reason_code
        iv_allowed         TYPE clike
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

    "! Four-eyes: the approver must not be the requester
    CLASS-METHODS can_approve_waiver
      IMPORTING
        is_state           TYPE zif_ca_ops_exc_types=>ty_state
        iv_approver        TYPE syuname
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

    "! Open (O) or assigned (A): the only dispositions operations may act on
    CLASS-METHODS is_open
      IMPORTING
        iv_disposition TYPE zif_ca_ops_types=>ty_disposition
      RETURNING
        VALUE(rv_open) TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-METHODS refuse
      IMPORTING
        iv_msgno           TYPE symsgno
        iv_v1              TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.
ENDCLASS.



CLASS zcl_ca_ops_exc_policy IMPLEMENTATION.

  METHOD can_assign.
    IF is_open( is_state-disposition ) = abap_false.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-not_open iv_v1 = is_state-disposition ).
    ELSEIF iv_owner IS INITIAL.
      rs_decision = refuse( zif_ca_ops_exc_types=>gc_msg-owner_missing ).
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD can_resolve.
    IF is_open( is_state-disposition ) = abap_false.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-not_open iv_v1 = is_state-disposition ).
    ELSEIF iv_reason IS INITIAL.
      rs_decision = refuse( zif_ca_ops_exc_types=>gc_msg-reason_missing ).
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD can_classify.
    DATA(lv_code) = to_upper( condense( CONV string( iv_reason_code ) ) ).
    DATA(lt_allowed) = zcl_ca_ops_util=>split_list( to_upper( iv_allowed ) ).
    IF is_open( is_state-disposition ) = abap_false.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-not_open iv_v1 = is_state-disposition ).
    ELSEIF lv_code IS INITIAL OR NOT line_exists( lt_allowed[ table_line = lv_code ] ).
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-reason_code_invalid iv_v1 = iv_reason_code ).
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD can_request_waiver.
    IF is_open( is_state-disposition ) = abap_false.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-not_open iv_v1 = is_state-disposition ).
    ELSEIF is_state-waiver_req_by IS NOT INITIAL.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-request_pending iv_v1 = is_state-waiver_req_by ).
    ELSEIF iv_reason IS INITIAL.
      rs_decision = refuse( zif_ca_ops_exc_types=>gc_msg-reason_missing ).
    ELSEIF iv_valid_to < iv_today.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-date_in_past iv_v1 = |{ iv_valid_to DATE = ISO }| ).
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD can_approve_waiver.
    IF is_open( is_state-disposition ) = abap_false.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-not_open iv_v1 = is_state-disposition ).
    ELSEIF is_state-waiver_req_by IS INITIAL.
      rs_decision = refuse( zif_ca_ops_exc_types=>gc_msg-no_request ).
    ELSEIF is_state-waiver_req_by = iv_approver.
      rs_decision = refuse( iv_msgno = zif_ca_ops_exc_types=>gc_msg-same_user iv_v1 = is_state-waiver_req_by ).
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD is_open.
    rv_open = xsdbool( iv_disposition = zif_ca_ops_types=>gc_disposition-open
                    OR iv_disposition = zif_ca_ops_types=>gc_disposition-assigned ).
  ENDMETHOD.


  METHOD refuse.
    rs_decision-allowed = abap_false.
    rs_decision-msgno   = iv_msgno.
    rs_decision-v1      = iv_v1.
  ENDMETHOD.

ENDCLASS.
