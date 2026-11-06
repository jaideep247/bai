CLASS zcl_bai_166_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_166_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.


  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '166' iv_flow_type = 'D' ).
    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN lt_f
      WHERE ( vorgc = '166' )
      ( ls )
    ).


    ms_stats-total_count = lines( lt_f ).
    IF lt_f IS INITIAL.
      GET TIME STAMP FIELD lv_t1.
      ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.
      RETURN.
    ENDIF.

    " Build unique OPBEL list
    TYPES: BEGIN OF ty_opbel, opbel TYPE opbel_kk, END OF ty_opbel.
    DATA lt_opbel TYPE STANDARD TABLE OF ty_opbel WITH EMPTY KEY.

    LOOP AT lt_f INTO DATA(ls_f) WHERE chect IS NOT INITIAL.
      APPEND VALUE #( opbel = ls_f-chect ) TO lt_opbel.
    ENDLOOP.
    SORT lt_opbel BY opbel.
    DELETE ADJACENT DUPLICATES FROM lt_opbel COMPARING opbel.

    " Prefetch minimal
    DATA lt_rp TYPE HASHED TABLE OF dfkkrp WITH UNIQUE KEY opbel.
    DATA lt_rk TYPE HASHED TABLE OF dfkkrk WITH UNIQUE KEY opbel.

    IF lt_opbel IS NOT INITIAL.
      SELECT opbel FROM dfkkrp
        FOR ALL ENTRIES IN @lt_opbel
        WHERE opbel = @lt_opbel-opbel
        INTO TABLE @DATA(lt_rp_raw).
      lt_rp = CORRESPONDING #( lt_rp_raw ).

      SELECT opbel, stars FROM dfkkrk
        FOR ALL ENTRIES IN @lt_opbel
        WHERE opbel = @lt_opbel-opbel
        INTO TABLE @DATA(lt_rk_raw).
      lt_rk = CORRESPONDING #( lt_rk_raw ).
    ENDIF.

    LOOP AT lt_f INTO ls_f.

      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '166'
        flow_type   = 'D'
        vorgc       = ls_f-vorgc
        belnr       = ls_f-belnr
        gjahr       = ls_f-gjahr
        chect       = ls_f-chect
        status      = 'P'
        status_icon = '@5B@'
      ).

      DATA(lv_checks) = ``.

      IF validate_chect_format( ls_f-chect ) = abap_false.
        add_failed_check( EXPORTING iv_token = 'CHECT_FORMAT' CHANGING cv_checks = lv_checks ).
      ENDIF.

      READ TABLE lt_rp TRANSPORTING NO FIELDS WITH TABLE KEY opbel = ls_f-chect.
      IF sy-subrc <> 0.
        add_failed_check( EXPORTING iv_token = 'RP_NOT_FOUND' CHANGING cv_checks = lv_checks ).
      ENDIF.

      READ TABLE lt_rk INTO DATA(ls_rk) WITH TABLE KEY opbel = ls_f-chect.
      IF sy-subrc = 0 AND ls_rk-stars <> '5'.
        add_failed_check( EXPORTING iv_token = 'STARS_NOT_5' CHANGING cv_checks = lv_checks ).
      ENDIF.

      IF lv_checks IS INITIAL.
        ms_stats-passed_count += 1.
      ELSE.
        mark_failed( EXPORTING iv_checks = lv_checks CHANGING cs_result = ls_res ).
        APPEND ls_res TO rt_results.
        ms_stats-failed_count += 1.
      ENDIF.

    ENDLOOP.

    GET TIME STAMP FIELD lv_t1.
    ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.

  ENDMETHOD.
ENDCLASS.
