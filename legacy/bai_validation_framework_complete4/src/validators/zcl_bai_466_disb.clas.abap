CLASS zcl_bai_466_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_466_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    load_config( iv_bai_code = '466' iv_flow_type = 'D' ).
  ENDMETHOD.

  METHOD zif_bai_validator~validate.
    DATA: lv_start_ts TYPE timestampl,
          lv_end_ts   TYPE timestampl,
          lt_dfkkrp   TYPE TABLE OF dfkkrp,
          lt_dfkkrk   TYPE TABLE OF dfkkrk.

    FIELD-SYMBOLS: <ls_febep> TYPE zif_bai_validator=>ty_febep_data.

    GET TIME STAMP FIELD lv_start_ts.
    ms_stats-bai_code = '466'.
    ms_stats-flow_type = 'D'.

    IF it_febep IS INITIAL.
      GET TIME STAMP FIELD lv_end_ts.
      ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
      RETURN.
    ENDIF.

    " Prefetch tables
    SELECT * FROM dfkkrp FOR ALL ENTRIES IN @it_febep
      WHERE selw1 = @it_febep-chect INTO TABLE @lt_dfkkrp.

    SELECT * FROM dfkkrk FOR ALL ENTRIES IN @it_febep
      WHERE opbel = @it_febep-chect INTO TABLE @lt_dfkkrk.

    " Validate
    LOOP AT it_febep ASSIGNING <ls_febep>.
      DATA(ls_result) = VALUE zif_bai_validator=>ty_validation_result(
        kukey = <ls_febep>-kukey esnum = <ls_febep>-esnum
        bai_code = '466' vorgc = <ls_febep>-vorgc
        belnr = <ls_febep>-belnr gjahr = <ls_febep>-gjahr
        chect = <ls_febep>-chect flow_type = 'D'
        status = 'P' status_icon = '@5B@'
      ).

      DATA(lv_failed) = abap_false.
      DATA(lv_checks) = ''.

      " Check DFKKRP AUGST=9
      READ TABLE lt_dfkkrp INTO DATA(ls_dfkkrp)
        WITH KEY selw1 = <ls_febep>-chect.
      IF sy-subrc = 0.
        IF ls_dfkkrp-augst <> '9'.
          lv_checks = 'AUGST_NOT_9'.
          lv_failed = abap_true.
        ENDIF.
      ELSE.
        lv_checks = 'RP_NOT_FOUND'.
        lv_failed = abap_true.
      ENDIF.

      " Check DFKKRK STARS=5
      READ TABLE lt_dfkkrk INTO DATA(ls_dfkkrk)
        WITH KEY opbel = <ls_febep>-chect.
      IF sy-subrc = 0.
        IF ls_dfkkrk-stars <> '5'.
          IF lv_checks IS NOT INITIAL.
            lv_checks = |{ lv_checks },STARS_NOT_5|.
          ELSE.
            lv_checks = 'STARS_NOT_5'.
          ENDIF.
          lv_failed = abap_true.
        ENDIF.
      ENDIF.

      " Failed-only storage
      IF lv_failed = abap_true.
        ls_result-status = 'R'.
        ls_result-status_icon = '@5C@'.
        ls_result-failed_checks = lv_checks.
        SPLIT lv_checks AT ',' INTO TABLE DATA(lt_fail).
        READ TABLE lt_fail INDEX 1 INTO DATA(lv_primary).
        ls_result-primary_failure = lv_primary.
        ls_result-message = |FAIL: { lv_checks }|.
        APPEND ls_result TO rt_results.
        ADD 1 TO ms_stats-failed_count.
      ELSE.
        ADD 1 TO ms_stats-passed_count.
      ENDIF.

      CLEAR: ls_result, lv_checks, lv_failed, ls_dfkkrp, ls_dfkkrk.
    ENDLOOP.

    GET TIME STAMP FIELD lv_end_ts.
    ms_stats-total_count = lines( it_febep ).
    ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
  ENDMETHOD.

ENDCLASS.
