CLASS zcl_bai_255_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_255_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.


  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '255' iv_flow_type = 'D' ).
    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN lt_f
      WHERE ( vorgc = '255' )
      ( ls )
    ).


    ms_stats-total_count = lines( lt_f ).
    IF lt_f IS INITIAL.
      GET TIME STAMP FIELD lv_t1.
      ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.
      RETURN.
    ENDIF.

    DATA lr_ztnum TYPE RANGE OF dfkkcr-ztnum.
    LOOP AT lt_f INTO DATA(ls_f) WHERE chect IS NOT INITIAL.
      lr_ztnum = VALUE #( BASE lr_ztnum ( sign = 'I' option = 'EQ' low = convert_to_ztnum( ls_f-chect ) ) ).
    ENDLOOP.
    SORT lr_ztnum BY low.
    DELETE ADJACENT DUPLICATES FROM lr_ztnum COMPARING low.

    TYPES: BEGIN OF ty_cr,
             ztnum    TYPE dfkkcr-ztnum,
             crstatus TYPE dfkkcr-crstatus,
           END OF ty_cr.
    DATA lt_cr TYPE HASHED TABLE OF ty_cr WITH UNIQUE KEY ztnum.

    IF lr_ztnum IS NOT INITIAL.
      SELECT ztnum, crstatus
        FROM dfkkcr
        WHERE ztnum IN @lr_ztnum
        INTO TABLE @DATA(lt_cr_raw).
      lt_cr = VALUE #( FOR r IN lt_cr_raw ( ztnum = r-ztnum crstatus = r-crstatus ) ).
    ENDIF.

    LOOP AT lt_f INTO ls_f.

      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '255'
        flow_type   = 'D'
        vorgc       = ls_f-vorgc
        belnr       = ls_f-belnr
        gjahr       = ls_f-gjahr
        chect       = ls_f-chect
        status      = 'P'
        status_icon = '@5B@'
      ).

      DATA(lv_checks) = ``.

      IF ls_f-chect IS INITIAL.
        add_failed_check( EXPORTING iv_token = 'CHECT_EMPTY' CHANGING cv_checks = lv_checks ).
      ELSE.
        DATA(lv_ztnum) = convert_to_ztnum( ls_f-chect ).
        READ TABLE lt_cr INTO DATA(ls_cr) WITH TABLE KEY ztnum = lv_ztnum.
        IF sy-subrc <> 0.
          add_failed_check( EXPORTING iv_token = 'DFKKCR_NOT_FOUND' CHANGING cv_checks = lv_checks ).
        ELSEIF ls_cr-crstatus = '99'.
          add_failed_check( EXPORTING iv_token = 'DFKKCR_CANCELLED_99' CHANGING cv_checks = lv_checks ).
        ENDIF.
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
