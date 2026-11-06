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
  ENDMETHOD.

  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '581' iv_flow_type = 'D' ).

    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN it_febep
      WHERE ( vorgc = '581' )
      ( ls )
    ).

    ms_stats-total_count = lines( lt_f ).
    IF lt_f IS INITIAL.
      GET TIME STAMP FIELD lv_t1.
      ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.
      RETURN.
    ENDIF.

    " Build key list (ZTNUM derived from CHECT) and mapping
    TYPES: BEGIN OF ty_map,
             ztnum TYPE dfkkcr-ztnum,
             kwbtr TYPE febep-kwbtr,
             chect TYPE chect_kk,
             kukey TYPE kukey,
             esnum TYPE esnum_kk,
             belnr TYPE belnr_kk,
             gjahr TYPE gjahr,
           END OF ty_map.

    DATA lt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.
    DATA lt_ztnum TYPE SORTED TABLE OF dfkkcr-ztnum WITH UNIQUE KEY table_line.

    LOOP AT lt_f INTO DATA(ls_f) WHERE chect IS NOT INITIAL.
      DATA(lv_ztnum) = convert_to_ztnum( ls_f-chect ).
      APPEND VALUE ty_map(
        ztnum = lv_ztnum
        kwbtr = ls_f-kwbtr
        chect = ls_f-chect
        kukey = ls_f-kukey
        esnum = ls_f-esnum
        belnr = ls_f-belnr
        gjahr = ls_f-gjahr ) TO lt_map.
      INSERT lv_ztnum INTO TABLE lt_ztnum.
    ENDLOOP.

    " Prefetch DFKKCR (amount rwbtr per ztnum)
    TYPES: BEGIN OF ty_cr,
             ztnum TYPE dfkkcr-ztnum,
             rwbtr TYPE dfkkcr-rwbtr,
           END OF ty_cr.
    DATA lt_cr TYPE HASHED TABLE OF ty_cr WITH UNIQUE KEY ztnum.

    IF lt_ztnum IS NOT INITIAL.
      SELECT ztnum, rwbtr
        FROM dfkkcr
        FOR ALL ENTRIES IN @lt_ztnum
        WHERE ztnum = @lt_ztnum-table_line
        INTO TABLE @DATA(lt_cr_raw).
      lt_cr = VALUE #( FOR r IN lt_cr_raw ( ztnum = r-ztnum rwbtr = r-rwbtr ) ).
    ENDIF.

    " Compute totals
    DATA(lv_cnt_febep) = lines( lt_map ).
    DATA(lv_cnt_cr)    = lines( lt_cr ).

    DATA(lv_sum_febep) TYPE febep-kwbtr.
    lv_sum_febep = REDUCE febep-kwbtr(
      INIT s = CONV febep-kwbtr( 0 )
      FOR m IN lt_map
      NEXT s = s + m-kwbtr ).

    DATA(lv_sum_cr) TYPE dfkkcr-rwbtr.
    lv_sum_cr = REDUCE dfkkcr-rwbtr(
      INIT s = CONV dfkkcr-rwbtr( 0 )
      FOR c IN lt_cr
      NEXT s = s + c-rwbtr ).

    " Record-level mismatch detection (+ tag batch-level mismatch on each failed row)
    LOOP AT lt_map INTO DATA(ls_m).

      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_m-kukey
        esnum       = ls_m-esnum
        bai_code    = '581'
        flow_type   = 'D'
        vorgc       = '581'
        belnr       = ls_m-belnr
        gjahr       = ls_m-gjahr
        chect       = ls_m-chect
        status      = 'P'
        status_icon = '@5B@'
      ).

      DATA(lv_checks) = ``.

      READ TABLE lt_cr INTO DATA(ls_cr) WITH TABLE KEY ztnum = ls_m-ztnum.
      IF sy-subrc <> 0.
        add_failed_check( EXPORTING iv_token = 'DFKKCR_NOT_FOUND' CHANGING cv_checks = lv_checks ).
      ELSEIF ls_cr-rwbtr <> ls_m-kwbtr.
        add_failed_check( EXPORTING iv_token = 'AMOUNT_MISMATCH' CHANGING cv_checks = lv_checks ).
        ls_res-message = |FAIL: AMOUNT_MISMATCH ZTNUM={ ls_m-ztnum } FEBEP_KWBTR={ ls_m-kwbtr } DFKKCR_RWBTR={ ls_cr-rwbtr }|.
      ENDIF.

      IF lv_sum_febep <> lv_sum_cr.
        add_failed_check( EXPORTING iv_token = 'TOTAL_SUM_MISMATCH' CHANGING cv_checks = lv_checks ).
      ENDIF.
      IF lv_cnt_febep <> lv_cnt_cr.
        add_failed_check( EXPORTING iv_token = 'TOTAL_COUNT_MISMATCH' CHANGING cv_checks = lv_checks ).
      ENDIF.

      IF lv_checks IS INITIAL.
        ms_stats-passed_count += 1.
      ELSE.
        IF ls_res-message IS INITIAL.
          ls_res-message = |FAIL: { lv_checks } (FEBEP_CNT={ lv_cnt_febep } DFKKCR_CNT={ lv_cnt_cr } FEBEP_SUM={ lv_sum_febep } DFKKCR_SUM={ lv_sum_cr })|.
        ENDIF.
        mark_failed( EXPORTING iv_checks = lv_checks CHANGING cs_result = ls_res ).
        APPEND ls_res TO rt_results.
        ms_stats-failed_count += 1.
      ENDIF.

    ENDLOOP.

    " Extra DFKKCR entries not present in FEBEP mapping
    IF lv_cnt_febep <> lv_cnt_cr.
      DATA lt_febep_ztnum TYPE HASHED TABLE OF dfkkcr-ztnum WITH UNIQUE KEY table_line.
      lt_febep_ztnum = VALUE #( FOR m IN lt_map ( m-ztnum ) ).

      LOOP AT lt_cr INTO DATA(ls_extra).
        IF line_exists( lt_febep_ztnum[ table_line = ls_extra-ztnum ] ) = abap_false.
          DATA(ls_res_x) = VALUE zif_bai_validator=>ty_validation_result(
            bai_code    = '581'
            flow_type   = 'D'
            vorgc       = '581'
            status      = 'R'
            status_icon = '@5C@'
            message     = |FAIL: EXTRA_DFKKCR (ZTNUM={ ls_extra-ztnum } RWBTR={ ls_extra-rwbtr })|
          ).
          ls_res_x-failed_checks   = 'EXTRA_DFKKCR,TOTAL_COUNT_MISMATCH'.
          ls_res_x-primary_failure = derive_primary_failure( ls_res_x-failed_checks ).
          APPEND ls_res_x TO rt_results.
          ms_stats-failed_count += 1.
        ENDIF.
      ENDLOOP.
    ENDIF.

    GET TIME STAMP FIELD lv_t1.
    ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.

  ENDMETHOD.

ENDCLASS.
