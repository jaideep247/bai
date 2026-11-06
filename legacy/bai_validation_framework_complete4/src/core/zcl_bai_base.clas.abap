CLASS zcl_bai_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_bai_validator.

  PROTECTED SECTION.

    DATA: mo_perf_monitor TYPE REF TO zcl_bai_perf_monitor,
          mo_logger       TYPE REF TO zcl_bai_logger,
          ms_stats        TYPE zif_bai_validator=>ty_validation_stats,
          mv_bai_code     TYPE char10,
          mv_flow_type    TYPE char1.

    METHODS load_config
      IMPORTING
        iv_bai_code  TYPE char10
        iv_flow_type TYPE char1.

    METHODS convert_to_augbl
      IMPORTING
        iv_chect         TYPE chect_kk
      RETURNING
        VALUE(rv_augbl)  TYPE augbl
      RAISING
        zcx_bai_validation_error.

    METHODS convert_to_doc1r
      IMPORTING
        iv_chect         TYPE chect_kk
      RETURNING
        VALUE(rv_doc1r)  TYPE doc1r_kk
      RAISING
        zcx_bai_validation_error.

    METHODS convert_to_ztnum
      IMPORTING
        iv_chect         TYPE chect_kk
      RETURNING
        VALUE(rv_ztnum)  TYPE ztnum_kk
      RAISING
        zcx_bai_validation_error.

    METHODS validate_chect_format
      IMPORTING
        iv_chect         TYPE chect_kk
      RETURNING
        VALUE(rv_valid)  TYPE abap_bool.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_bai_base IMPLEMENTATION.


  METHOD zif_bai_validator~get_statistics.
    rs_stats = ms_stats.
  ENDMETHOD.


  METHOD load_config.

    mv_bai_code  = iv_bai_code.
    mv_flow_type = iv_flow_type.

    IF mo_perf_monitor IS NOT BOUND.
      CREATE OBJECT mo_perf_monitor.
    ENDIF.

    IF mo_logger IS NOT BOUND.
      CREATE OBJECT mo_logger.
    ENDIF.

    CLEAR ms_stats.
    ms_stats-bai_code  = iv_bai_code.
    ms_stats-flow_type = iv_flow_type.

  ENDMETHOD.


  METHOD convert_to_augbl.

    IF strlen( iv_chect ) < 10.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid   = zcx_bai_validation_error=>internal_error
          mv_text1 = |CHECT too short for AUGBL: { iv_chect }|.
    ENDIF.

    rv_augbl = iv_chect+0(10).
    SHIFT rv_augbl LEFT DELETING LEADING '0'.

  ENDMETHOD.


  METHOD convert_to_doc1r.

    IF strlen( iv_chect ) < 14.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid   = zcx_bai_validation_error=>internal_error
          mv_text1 = |CHECT too short for DOC1R: { iv_chect }|.
    ENDIF.

    rv_doc1r = iv_chect+10(4).

  ENDMETHOD.


  METHOD convert_to_ztnum.

    IF strlen( iv_chect ) < 14.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid   = zcx_bai_validation_error=>internal_error
          mv_text1 = |CHECT too short for ZTNUM: { iv_chect }|.
    ENDIF.

    rv_ztnum = iv_chect+0(14).

  ENDMETHOD.


  METHOD validate_chect_format.

    rv_valid = abap_true.

    IF iv_chect IS INITIAL.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    IF iv_chect CN '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ '.
      rv_valid = abap_false.
      RETURN.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
