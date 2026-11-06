CLASS zcl_bai_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_bai_validator.

    METHODS constructor.

    METHODS zif_bai_validator~get_stats FINAL.

  PROTECTED SECTION.
    DATA mo_perf_monitor TYPE REF TO zcl_bai_perf_monitor.
    DATA mo_logger       TYPE REF TO zcl_bai_logger.
    DATA ms_stats        TYPE zif_bai_validator=>ty_validation_stats.
    DATA mv_bai_code     TYPE char10.
    DATA mv_flow_type    TYPE char1.

    METHODS load_config
      IMPORTING
        iv_bai_code  TYPE char10
        iv_flow_type TYPE char1.

    " Shared helper: append token to failed_checks
    METHODS add_failed_check
      IMPORTING
        iv_token   TYPE string
      CHANGING
        cv_checks  TYPE string.

    " Shared helper: derive primary_failure from failed_checks
    METHODS derive_primary_failure
      IMPORTING
        iv_checks TYPE string
      RETURNING
        VALUE(rv_primary) TYPE string.

    METHODS mark_failed
      IMPORTING
        iv_checks  TYPE string
      CHANGING
        cs_result  TYPE zif_bai_validator=>ty_validation_result.

    METHODS mark_warning
      IMPORTING
        iv_message TYPE string
      CHANGING
        cs_result  TYPE zif_bai_validator=>ty_validation_result.

    METHODS validate_chect_format
      IMPORTING
        iv_chect        TYPE chect_kk
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS convert_to_augbl
      IMPORTING
        iv_chect        TYPE chect_kk
      RETURNING
        VALUE(rv_augbl) TYPE augbl.

    METHODS convert_to_doc1r
      IMPORTING
        iv_chect        TYPE chect_kk
      RETURNING
        VALUE(rv_doc1r) TYPE doc1r_kk.

    METHODS convert_to_ztnum
      IMPORTING
        iv_chect        TYPE chect_kk
      RETURNING
        VALUE(rv_ztnum) TYPE ztnum_kk.

ENDCLASS.

CLASS zcl_bai_base IMPLEMENTATION.

  METHOD constructor.
    CREATE OBJECT mo_perf_monitor.
    CREATE OBJECT mo_logger.
  ENDMETHOD.

  METHOD zif_bai_validator~get_stats.
    rs_stats = ms_stats.
  ENDMETHOD.

  METHOD load_config.
    mv_bai_code          = iv_bai_code.
    mv_flow_type         = iv_flow_type.
    ms_stats-bai_code    = iv_bai_code.
    ms_stats-flow_type   = iv_flow_type.
    CLEAR: ms_stats-total_count,
           ms_stats-passed_count,
           ms_stats-failed_count,
           ms_stats-warning_count,
           ms_stats-duration_ms.
  ENDMETHOD.

  METHOD add_failed_check.
    IF iv_token IS INITIAL.
      RETURN.
    ENDIF.

    IF cv_checks IS INITIAL.
      cv_checks = iv_token.
    ELSE.
      cv_checks = |{ cv_checks },{ iv_token }|.
    ENDIF.
  ENDMETHOD.

  METHOD derive_primary_failure.
    IF iv_checks IS INITIAL.
      rv_primary = ''.
      RETURN.
    ENDIF.

    " First token before comma, or whole string
    rv_primary = substring_before( val = iv_checks sub = ',' ).
    IF rv_primary IS INITIAL.
      rv_primary = iv_checks.
    ENDIF.
  ENDMETHOD.

  METHOD mark_failed.
    cs_result-status          = 'R'.
    cs_result-status_icon     = '@5C@'. " red
    cs_result-failed_checks   = iv_checks.
    cs_result-primary_failure = derive_primary_failure( iv_checks ).
    cs_result-message         = |FAIL: { iv_checks }|.
  ENDMETHOD.

  METHOD mark_warning.
    cs_result-status      = 'Y'.
    cs_result-status_icon = '@5B@'. " pending/yellow in your icon set
    cs_result-message     = iv_message.
  ENDMETHOD.

  METHOD validate_chect_format.
    rv_valid = abap_true.

    IF iv_chect IS INITIAL.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    " Alphanumeric only (adjust if your CHECT allows other chars)
    IF iv_chect CN '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
      rv_valid = abap_false.
      RETURN.
    ENDIF.
  ENDMETHOD.

  METHOD convert_to_augbl.
    DATA(lv) = CONV string( iv_chect ).
    lv = |{ lv WIDTH = 10 PAD = '0' ALIGN = RIGHT }|.
    rv_augbl = CONV augbl( lv ).
  ENDMETHOD.

  METHOD convert_to_doc1r.
    DATA(lv) = CONV string( iv_chect ).
    lv = |{ lv WIDTH = 16 PAD = '0' ALIGN = RIGHT }|.
    rv_doc1r = CONV doc1r_kk( lv ).
  ENDMETHOD.

  METHOD convert_to_ztnum.
    DATA(lv) = CONV string( iv_chect ).
    lv = |{ lv WIDTH = 20 PAD = '0' ALIGN = RIGHT }|.
    rv_ztnum = CONV ztnum_kk( lv ).
  ENDMETHOD.

ENDCLASS.
