*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_applog.clas.abap
*& Purpose:
*& Alert channel APPLOG: writes the alert to the application log (SLG1).
*& Destination 'OBJECT/SUBOBJECT', default ZCD_OPS/ALERT. Thin wrapper over the
*& BAL function payment engine areas - covered by the QA1 integration test.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | SLG1 external ID area/run/rule, BAL_LOG_REFRESH after save, partial log reported (audit A45, SLG1).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert channel application log</p>
CLASS zcl_cd_ops_chn_applog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_channel.

    CONSTANTS gc_default_object TYPE balobj_d VALUE 'ZCD_OPS'.
    CONSTANTS gc_default_subobject TYPE balsubobj VALUE 'ALERT'.

ENDCLASS.



CLASS zcl_cd_ops_chn_applog IMPLEMENTATION.

  METHOD zif_cd_ops_alert_channel~deliver.
    DATA ls_log    TYPE bal_s_log.
    DATA lv_handle TYPE balloghndl.
    DATA lv_added  TYPE i.
    DATA lt_handle TYPE bal_t_logh.
    DATA lv_object TYPE string.
    DATA lv_sub    TYPE string.

    SPLIT is_message-destination AT '/' INTO lv_object lv_sub.
    ls_log-object    = COND #( WHEN lv_object IS NOT INITIAL THEN condense( lv_object ) ELSE gc_default_object ).
    ls_log-subobject = COND #( WHEN lv_sub IS NOT INITIAL THEN condense( lv_sub ) ELSE gc_default_subobject ).
    " SLG1: external ID = payment engine area / run / rule (set by the router)
    ls_log-extnumber = COND #( WHEN is_message-extnumber IS NOT INITIAL THEN is_message-extnumber
                               ELSE is_message-rule_id ).
    ls_log-aldate    = sy-datum.
    ls_log-altime    = sy-uzeit.
    ls_log-aluser    = sy-uname.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log                 = ls_log
      IMPORTING
        e_log_handle            = lv_handle
      EXCEPTIONS
        log_header_inconsistent = 1
        OTHERS                  = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e022(zcd_ops) WITH ls_log-object ls_log-subobject.
    ENDIF.

    DATA(lv_msgty) = SWITCH symsgty( is_message-severity
                                     WHEN zif_cd_ops_types=>gc_severity-block
                                       OR zif_cd_ops_types=>gc_severity-error   THEN 'E'
                                     WHEN zif_cd_ops_types=>gc_severity-warning THEN 'W'
                                     ELSE 'I' ).
    SPLIT is_message-text AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_text).
    LOOP AT lt_text INTO DATA(lv_text).
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
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      lv_added = lv_added + 1.
    ENDLOOP.

    INSERT lv_handle INTO TABLE lt_handle.
    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle   = lt_handle
      EXCEPTIONS
        log_not_found    = 1
        save_not_allowed = 2
        numbering_error  = 3
        OTHERS           = 4.
    DATA(lv_saved) = xsdbool( sy-subrc = 0 ).
    " the saved log is released from memory: long batch runs do not grow SAPLSBAL (SLG1)
    CALL FUNCTION 'BAL_LOG_REFRESH'
      EXPORTING
        i_log_handle  = lv_handle
      EXCEPTIONS
        log_not_found = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      " nothing to release - the handle is gone already
      CLEAR lv_handle.
    ENDIF.
    IF lv_saved = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e022(zcd_ops) WITH ls_log-object ls_log-subobject.
    ENDIF.
    " A45: a log that stopped adding lines is saved but reported as partial, never as sent
    IF lv_added < lines( lt_text ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e025(zcd_ops) WITH ls_log-object ls_log-subobject lv_added lines( lt_text ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
