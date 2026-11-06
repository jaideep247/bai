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
  ENDMETHOD.


  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '575' iv_flow_type = 'D' ).
    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN lt_f
      WHERE ( vorgc = '575' )
      ( ls )
    ).


    ms_stats-total_count = lines( lt_f ).

    LOOP AT lt_f INTO DATA(ls_f).
      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '575'
        flow_type   = 'D'
        vorgc       = ls_f-vorgc
        belnr       = ls_f-belnr
        gjahr       = ls_f-gjahr
        chect       = ls_f-chect
        status      = 'P'
        status_icon = '@5B@'
      ).

      IF ls_f-belnr IS INITIAL.
        ms_stats-passed_count += 1.
      ELSE.
        mark_failed( EXPORTING iv_checks = 'BELNR_NOT_EMPTY' CHANGING cs_result = ls_res ).
        APPEND ls_res TO rt_results.
        ms_stats-failed_count += 1.
      ENDIF.
    ENDLOOP.

    GET TIME STAMP FIELD lv_t1.
    ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.

  ENDMETHOD.
ENDCLASS.
