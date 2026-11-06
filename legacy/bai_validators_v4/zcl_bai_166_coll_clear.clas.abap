CLASS zcl_bai_166_coll_clear DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_166_coll_clear IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.


  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '166' iv_flow_type = 'C' ).
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

    TYPES: BEGIN OF ty_key,
             bukrs TYPE bukrs,
             belnr TYPE bseg-belnr,
             gjahr TYPE bseg-gjahr,
           END OF ty_key.
    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY bukrs belnr gjahr.

    lt_keys = VALUE #(
      FOR ls IN lt_f
      WHERE ( belnr IS NOT INITIAL AND gjahr IS NOT INITIAL )
      ( bukrs = '1000' belnr = ls-belnr gjahr = ls-gjahr )
    ).

    TYPES: BEGIN OF ty_bseg,
             bukrs TYPE bukrs,
             belnr TYPE bseg-belnr,
             gjahr TYPE bseg-gjahr,
             augbl TYPE bseg-augbl,
           END OF ty_bseg.
    DATA lt_bseg TYPE HASHED TABLE OF ty_bseg WITH UNIQUE KEY bukrs belnr gjahr.

    IF lt_keys IS NOT INITIAL.
      SELECT bukrs, belnr, gjahr, augbl
        FROM bseg
        FOR ALL ENTRIES IN @lt_keys
        WHERE bukrs = @lt_keys-bukrs
          AND belnr = @lt_keys-belnr
          AND gjahr = @lt_keys-gjahr
        INTO TABLE @DATA(lt_bseg_raw).
      lt_bseg = lt_bseg_raw.
    ENDIF.

    LOOP AT lt_f INTO DATA(ls_f).
      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '166'
        flow_type   = 'C'
        vorgc       = ls_f-vorgc
        belnr       = ls_f-belnr
        gjahr       = ls_f-gjahr
        chect       = ls_f-chect
        status      = 'P'
        status_icon = '@5B@'
      ).

      DATA(lv_checks) = ``.
      READ TABLE lt_bseg INTO DATA(ls_bseg) WITH TABLE KEY bukrs = '1000' belnr = ls_f-belnr gjahr = ls_f-gjahr.
      IF sy-subrc <> 0.
        add_failed_check( EXPORTING iv_token = 'BSEG_NOT_FOUND' CHANGING cv_checks = lv_checks ).
      ELSEIF ls_bseg-augbl IS INITIAL.
        add_failed_check( EXPORTING iv_token = 'AUGBL_INITIAL' CHANGING cv_checks = lv_checks ).
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
