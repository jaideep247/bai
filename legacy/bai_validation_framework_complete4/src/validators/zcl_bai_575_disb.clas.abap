CLASS zcl_bai_575_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_575_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    load_config( iv_bai_code = '575' iv_flow_type = 'D' ).
  ENDMETHOD.

  METHOD zif_bai_validator~validate.
    DATA: lv_start_ts TYPE timestampl,
          lv_end_ts   TYPE timestampl,
          lt_bseg     TYPE TABLE OF bseg.

    FIELD-SYMBOLS: <ls_febep> TYPE zif_bai_validator=>ty_febep_data.

    GET TIME STAMP FIELD lv_start_ts.
    ms_stats-bai_code = '575'.
    ms_stats-flow_type = 'D'.

    IF it_febep IS INITIAL.
      GET TIME STAMP FIELD lv_end_ts.
      ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
      RETURN.
    ENDIF.

    " Prefetch BSEG
    SELECT * FROM bseg FOR ALL ENTRIES IN @it_febep
      WHERE augbl = @it_febep-chect+0(10) INTO TABLE @lt_bseg.

    " Validate
    LOOP AT it_febep ASSIGNING <ls_febep>.
      DATA(ls_result) = VALUE zif_bai_validator=>ty_validation_result(
        kukey = <ls_febep>-kukey esnum = <ls_febep>-esnum
        bai_code = '575' vorgc = <ls_febep>-vorgc
        belnr = <ls_febep>-belnr gjahr = <ls_febep>-gjahr
        chect = <ls_febep>-chect flow_type = 'D'
        status = 'P' status_icon = '@5B@'
      ).

      DATA(lv_failed) = abap_false.

      " Check BSEG AUGBL matches
      DATA(lv_augbl) = <ls_febep>-chect+0(10).
      READ TABLE lt_bseg INTO DATA(ls_bseg)
        WITH KEY augbl = lv_augbl.

      IF sy-subrc <> 0.
        lv_failed = abap_true.
      ELSEIF ls_bseg-augbl <> lv_augbl.
        lv_failed = abap_true.
      ENDIF.

      " Failed-only storage
      IF lv_failed = abap_true.
        ls_result-status = 'R'.
        ls_result-status_icon = '@5C@'.
        ls_result-failed_checks = 'AUGBL_MISMATCH'.
        ls_result-primary_failure = 'AUGBL_MISMATCH'.
        ls_result-message = 'FAIL: BSEG AUGBL mismatch'.
        APPEND ls_result TO rt_results.
        ADD 1 TO ms_stats-failed_count.
      ELSE.
        ADD 1 TO ms_stats-passed_count.
      ENDIF.

      CLEAR: ls_result, lv_failed, ls_bseg.
    ENDLOOP.

    GET TIME STAMP FIELD lv_end_ts.
    ms_stats-total_count = lines( it_febep ).
    ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
  ENDMETHOD.

ENDCLASS.
