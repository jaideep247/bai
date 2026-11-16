*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chn_applog.clas.abap
*& Purpose:
*& Alert channel APPLOG: writes the alert to the application log (SLG1).
*& Destination 'OBJECT/SUBOBJECT', default ZCA_OPS/ALERT. Thin wrapper over the
*& BAL function modules; each call sits in a test seam (BAL_CREATE, BAL_ADD,
*& BAL_SAVE, BAL_REFRESH), so the own test include proves the error handling;
*& the BAL database write is covered by the QA1 integration test.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | SLG1 external ID area/run/rule, BAL_LOG_REFRESH after save, partial log reported (audit A45, SLG1).
*& 2026-11-06 | Test seams around the four BAL calls; return codes kept in locals (coverage gap closure).
*& 2026-11-10 | Own messages for create (800) and save (801) failures, each with the return code.
*& 2026-11-10 | Moved from the first consumer to the reusable framework ZCA_OPS.
*& 2026-11-16 | Delivery confirmation (build O): the application log is delivered on write - CONFIRM answers D for
*&            | a submitted alert (BAL_DB_SAVE succeeded), F for a partly written one; DELIVERY_REF = the SLG1
*&            | external ID of the last log written.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert channel application log</p>
CLASS zcl_ca_ops_chn_applog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_channel.

    CONSTANTS gc_default_object TYPE balobj_d VALUE 'ZCA_OPS'.
    CONSTANTS gc_default_subobject TYPE balsubobj VALUE 'ALERT'.

  PRIVATE SECTION.
    "! SLG1 external ID of the last log written by DELIVER
    DATA mv_extnumber TYPE balnrext.

ENDCLASS.



CLASS zcl_ca_ops_chn_applog IMPLEMENTATION.

  METHOD zif_ca_ops_alert_channel~deliver.
    DATA ls_log    TYPE bal_s_log.
    DATA lv_handle TYPE balloghndl.
    DATA lv_added  TYPE i.
    DATA lt_handle TYPE bal_t_logh.
    DATA lv_object TYPE string.
    DATA lv_sub    TYPE string.
    DATA lv_subrc  TYPE sysubrc.
    DATA lv_save_subrc TYPE sysubrc.

    SPLIT is_message-destination AT '/' INTO lv_object lv_sub.
    ls_log-object    = COND #( WHEN lv_object IS NOT INITIAL THEN condense( lv_object ) ELSE gc_default_object ).
    ls_log-subobject = COND #( WHEN lv_sub IS NOT INITIAL THEN condense( lv_sub ) ELSE gc_default_subobject ).
    " SLG1: external ID = area / run / rule (set by the router)
    ls_log-extnumber = COND #( WHEN is_message-extnumber IS NOT INITIAL THEN is_message-extnumber
                               ELSE is_message-rule_id ).
    ls_log-aldate    = sy-datum.
    ls_log-altime    = sy-uzeit.
    ls_log-aluser    = sy-uname.

    TEST-SEAM bal_create.
      CALL FUNCTION 'BAL_LOG_CREATE'
        EXPORTING
          i_s_log                 = ls_log
        IMPORTING
          e_log_handle            = lv_handle
        EXCEPTIONS
          log_header_inconsistent = 1
          OTHERS                  = 2.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e800(zca_ops) WITH ls_log-object ls_log-subobject lv_subrc.
    ENDIF.

    DATA(lv_msgty) = SWITCH symsgty( is_message-severity
                                     WHEN zif_ca_ops_types=>gc_severity-block
                                       OR zif_ca_ops_types=>gc_severity-error   THEN 'E'
                                     WHEN zif_ca_ops_types=>gc_severity-warning THEN 'W'
                                     ELSE 'I' ).
    SPLIT is_message-text AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_text).
    LOOP AT lt_text INTO DATA(lv_text).
      TEST-SEAM bal_add.
        CALL FUNCTION 'BAL_LOG_MSG_ADD_FREE_TEXT'
          EXPORTING
            i_log_handle     = lv_handle
            i_msgty          = lv_msgty
            i_text           = CONV char200( lv_text )
          EXCEPTIONS
            log_not_found    = 1
            msg_inconsistent = 2
            log_is_full      = 3
            OTHERS           = 4.
        lv_subrc = sy-subrc.
      END-TEST-SEAM.
      IF lv_subrc <> 0.
        EXIT.
      ENDIF.
      lv_added = lv_added + 1.
    ENDLOOP.

    INSERT lv_handle INTO TABLE lt_handle.
    TEST-SEAM bal_save.
      CALL FUNCTION 'BAL_DB_SAVE'
        EXPORTING
          i_t_log_handle   = lt_handle
        EXCEPTIONS
          log_not_found    = 1
          save_not_allowed = 2
          numbering_error  = 3
          OTHERS           = 4.
      lv_save_subrc = sy-subrc.
    END-TEST-SEAM.
    " the saved log is released from memory: long batch runs do not grow SAPLSBAL (SLG1)
    TEST-SEAM bal_refresh.
      CALL FUNCTION 'BAL_LOG_REFRESH'
        EXPORTING
          i_log_handle  = lv_handle
        EXCEPTIONS
          log_not_found = 1
          OTHERS        = 2.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0.
      " nothing to release - the handle is gone already
      CLEAR lv_handle.
    ENDIF.
    IF lv_save_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e801(zca_ops) WITH ls_log-object ls_log-subobject lv_save_subrc.
    ENDIF.
    mv_extnumber = ls_log-extnumber.
    " A45: a log that stopped adding lines is saved but reported as partial, never as sent
    IF lv_added < lines( lt_text ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e025(zca_ops) WITH ls_log-object ls_log-subobject lv_added lines( lt_text ).
    ENDIF.
  ENDMETHOD.



  METHOD zif_ca_ops_alert_channel~delivery_ref.
    rv_ref = mv_extnumber.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_channel~confirm.
    " delivered on write: BAL_DB_SAVE succeeded when the router recorded the alert as submitted
    rs_delivery = VALUE #( state        = COND #( WHEN is_log-status = zif_ca_ops_types=>gc_alert_status-sent
                                                  THEN zif_ca_ops_eval_types=>gc_dlv-delivered
                                                  ELSE zif_ca_ops_eval_types=>gc_dlv-failed )
                           delivered_at = COND #( WHEN is_log-status = zif_ca_ops_types=>gc_alert_status-sent
                                                  THEN is_log-sent_at )
                           info         = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-applog_written
                                                                 iv_v1    = is_log-dlv_ref
                                                                 iv_v2    = is_log-status ) ).
  ENDMETHOD.

ENDCLASS.
