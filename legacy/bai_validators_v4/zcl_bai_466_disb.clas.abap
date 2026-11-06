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
  ENDMETHOD.


  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '466' iv_flow_type = 'D' ).
    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN lt_f
      WHERE ( vorgc = '466' )
      ( ls )
    ).


    ms_stats-total_count = lines( lt_f ).
    IF lt_f IS INITIAL.
      GET TIME STAMP FIELD lv_t1.
      ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_key,
             belnr TYPE bseg-belnr,
             gjahr TYPE bseg-gjahr,
           END OF ty_key.
    DATA lt_keys TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY belnr gjahr.

    lt_keys = VALUE #(
      FOR ls IN lt_f
      WHERE ( belnr IS NOT INITIAL AND gjahr IS NOT INITIAL )
      ( belnr = ls-belnr gjahr = ls-gjahr )
    ).

    DATA lt_bseg TYPE HASHED TABLE OF ty_key WITH UNIQUE KEY belnr gjahr.

    IF lt_keys IS NOT INITIAL.
      SELECT belnr, gjahr
        FROM bseg
        FOR ALL ENTRIES IN @lt_keys
        WHERE belnr = @lt_keys-belnr
          AND gjahr = @lt_keys-gjahr
        INTO TABLE @DATA(lt_bseg_raw).
      lt_bseg = CORRESPONDING #( lt_bseg_raw ).
    ENDIF.

    LOOP AT lt_f INTO DATA(ls_f).
      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '466'
        flow_type   = 'D'
        vorgc       = ls_f-vorgc
        belnr       = ls_f-belnr
        gjahr       = ls_f-gjahr
        chect       = ls_f-chect
        status      = 'P'
        status_icon = '@5B@'
      ).

      DATA(lv_checks) = ``.
      IF ls_f-belnr IS INITIAL OR ls_f-gjahr IS INITIAL.
        add_failed_check( EXPORTING iv_token = 'MISSING_BELNR_GJAHR' CHANGING cv_checks = lv_checks ).
      ELSEIF line_exists( lt_bseg[ belnr = ls_f-belnr gjahr = ls_f-gjahr ] ) = abap_false.
        add_failed_check( EXPORTING iv_token = 'BSEG_NOT_FOUND' CHANGING cv_checks = lv_checks ).
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
