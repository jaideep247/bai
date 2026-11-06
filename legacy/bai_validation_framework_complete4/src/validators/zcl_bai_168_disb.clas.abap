CLASS zcl_bai_168_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_168_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    load_config( iv_bai_code = '168' iv_flow_type = 'D' ).
  ENDMETHOD.

  METHOD zif_bai_validator~validate.
    DATA: lv_start_ts TYPE timestampl,
          lv_end_ts   TYPE timestampl,
          lt_dfkkrp   TYPE TABLE OF dfkkrp,
          lt_dfkkrk   TYPE TABLE OF dfkkrk,
          lt_dpayh    TYPE TABLE OF dpayh,
          lt_rtrv_log TYPE TABLE OF zcd_ach_rtrv_log.

    FIELD-SYMBOLS: <ls_febep> TYPE zif_bai_validator=>ty_febep_data.

    GET TIME STAMP FIELD lv_start_ts.
    ms_stats-bai_code = '168'.
    ms_stats-flow_type = 'D'.

    IF it_febep IS INITIAL.
      GET TIME STAMP FIELD lv_end_ts.
      ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
      RETURN.
    ENDIF.

    " Bulk prefetch all tables
    SELECT * FROM dfkkrp FOR ALL ENTRIES IN @it_febep
      WHERE selw1 = @it_febep-chect INTO TABLE @lt_dfkkrp.

    SELECT * FROM dfkkrk FOR ALL ENTRIES IN @it_febep
      WHERE opbel = @it_febep-chect INTO TABLE @lt_dfkkrk.

    SELECT * FROM dpayh FOR ALL ENTRIES IN @it_febep
      WHERE laufd = @it_febep-chect+0(8)
        AND laufi = @it_febep-chect+8(5) INTO TABLE @lt_dpayh.

    SELECT * FROM zcd_ach_rtrv_log FOR ALL ENTRIES IN @it_febep
      WHERE reference_number = @it_febep-chect INTO TABLE @lt_rtrv_log.

    " Validate
    LOOP AT it_febep ASSIGNING <ls_febep>.
      DATA(ls_result) = VALUE zif_bai_validator=>ty_validation_result(
        kukey = <ls_febep>-kukey esnum = <ls_febep>-esnum
        bai_code = '168' vorgc = <ls_febep>-vorgc
        belnr = <ls_febep>-belnr gjahr = <ls_febep>-gjahr
        chect = <ls_febep>-chect flow_type = 'D'
        status = 'P' status_icon = '@5B@'
      ).

      DATA(lv_failed) = abap_false.
      DATA(lv_checks) = ''.

      " Check 1: DFKKRP
      READ TABLE lt_dfkkrp TRANSPORTING NO FIELDS
        WITH KEY selw1 = <ls_febep>-chect.
      IF sy-subrc <> 0.
        lv_checks = 'RP'.
        lv_failed = abap_true.
      ENDIF.

      " Check 2: DFKKRK STARS=5
      READ TABLE lt_dfkkrk INTO DATA(ls_dfkkrk)
        WITH KEY opbel = <ls_febep>-chect.
      IF sy-subrc = 0.
        IF ls_dfkkrk-stars <> '5'.
          IF lv_checks IS NOT INITIAL.
            lv_checks = |{ lv_checks },STARS|.
          ELSE.
            lv_checks = 'STARS'.
          ENDIF.
          lv_failed = abap_true.
        ENDIF.
      ENDIF.

      " Check 3: DPAYH status
      READ TABLE lt_dpayh INTO DATA(ls_dpayh)
        WITH KEY laufd = <ls_febep>-chect+0(8)
                 laufi = <ls_febep>-chect+8(5).
      IF sy-subrc = 0.
        IF ls_dpayh-stapa <> 'RETURNED'.
          IF lv_checks IS NOT INITIAL.
            lv_checks = |{ lv_checks },DPAYH|.
          ELSE.
            lv_checks = 'DPAYH'.
          ENDIF.
          lv_failed = abap_true.
        ENDIF.
      ENDIF.

      " Check 4: Retrieval log
      READ TABLE lt_rtrv_log INTO DATA(ls_rtrv)
        WITH KEY reference_number = <ls_febep>-chect.
      IF sy-subrc = 0.
        IF ls_rtrv-zzretrieval_status <> 'AF'.
          IF lv_checks IS NOT INITIAL.
            lv_checks = |{ lv_checks },RTRV|.
          ELSE.
            lv_checks = 'RTRV'.
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

      CLEAR: ls_result, lv_checks, lv_failed, ls_dfkkrk, ls_dpayh, ls_rtrv.
    ENDLOOP.

    GET TIME STAMP FIELD lv_end_ts.
    ms_stats-total_count = lines( it_febep ).
    ms_stats-duration_ms = ( lv_end_ts - lv_start_ts ) / 1000.
  ENDMETHOD.

ENDCLASS.
