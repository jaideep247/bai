CLASS zcl_bai_581_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_581_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    load_config( iv_bai_code = '581' iv_flow_type = 'D' ).
  ENDMETHOD.

  METHOD zif_bai_validator~validate.
    DATA: lv_start_ts TYPE timestampl,
          lv_end_ts   TYPE timestampl,
          lt_dfkkcr   TYPE TABLE OF dfkkcr.

    FIELD-SYMBOLS: <ls_febep> TYPE zif_bai_validator=>ty_febep_data.

    GET TIME STAMP FIELD lv_start_ts.
    ms_stats-bai_code = '581'.
    ms_stats-flow_type = 'D'.

    IF it_febep IS INITIAL.
      GET TIME STAMP FIELD lv_end_ts.
      ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
      RETURN.
    ENDIF.

    " ===== BULK PREFETCH DFKKCR =====
    SELECT * FROM dfkkcr
      FOR ALL ENTRIES IN @it_febep
      WHERE ztnum = @it_febep-chect
      INTO TABLE @lt_dfkkcr.

    " ===== VALIDATE EACH RECORD ONE-BY-ONE =====
    LOOP AT it_febep ASSIGNING <ls_febep>.

      DATA(ls_result) = VALUE zif_bai_validator=>ty_validation_result(
        kukey = <ls_febep>-kukey esnum = <ls_febep>-esnum
        bai_code = '581' vorgc = <ls_febep>-vorgc
        belnr = <ls_febep>-belnr gjahr = <ls_febep>-gjahr
        chect = <ls_febep>-chect flow_type = 'D'
        status = 'P' status_icon = '@5B@'
      ).

      DATA(lv_failed) = abap_false.
      DATA(lv_checks) = ''.
      DATA(lv_count) = 0.
      DATA(lv_sum_dfkkcr) TYPE kwbtr_kk VALUE 0.

      " ===== SUM ALL DFKKCR RECORDS FOR THIS FEBEP =====
      LOOP AT lt_dfkkcr INTO DATA(ls_dfkkcr)
        WHERE ztnum = <ls_febep>-chect.

        ADD 1 TO lv_count.
        " CORRECT: Sum RWBTR field (not KWBTR!)
        lv_sum_dfkkcr = lv_sum_dfkkcr + ls_dfkkcr-rwbtr.

      ENDLOOP.

      " ===== VALIDATION: FEBEP.KWBTR = Sum(DFKKCR.RWBTR) =====

      " Check 1: At least one DFKKCR record
      IF lv_count = 0.
        lv_checks = 'NO_DFKKCR_RECORDS'.
        lv_failed = abap_true.
      ELSE.
        " Check 2: Sum matches
        IF lv_sum_dfkkcr <> <ls_febep>-kwbtr.
          lv_checks = 'SUM_MISMATCH'.
          lv_failed = abap_true.
        ENDIF.
      ENDIF.

      " ===== FAILED-ONLY STORAGE =====
      IF lv_failed = abap_true.
        ls_result-status = 'R'.
        ls_result-status_icon = '@5C@'.
        ls_result-failed_checks = lv_checks.
        ls_result-primary_failure = lv_checks.

        ls_result-details_json = |{ "{" }"check":"SUM_VALIDATION",| &&
          |"dfkkcr_count":{ lv_count },| &&
          |"dfkkcr_sum_rwbtr":{ lv_sum_dfkkcr },| &&
          |"febep_kwbtr":{ <ls_febep>-kwbtr },| &&
          |"difference":{ <ls_febep>-kwbtr - lv_sum_dfkkcr }{ "}" }|.

        ls_result-message = |FAIL: { lv_checks } - Sum(DFKKCR.RWBTR)={ lv_sum_dfkkcr } <> FEBEP.KWBTR={ <ls_febep>-kwbtr } (Count: { lv_count })|.

        APPEND ls_result TO rt_results.
        ADD 1 TO ms_stats-failed_count.
      ELSE.
        ADD 1 TO ms_stats-passed_count.
      ENDIF.

      CLEAR: ls_result, lv_checks, lv_failed, lv_count, lv_sum_dfkkcr, ls_dfkkcr.
    ENDLOOP.

    GET TIME STAMP FIELD lv_end_ts.
    ms_stats-total_count = lines( it_febep ).
    ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
  ENDMETHOD.

ENDCLASS.
