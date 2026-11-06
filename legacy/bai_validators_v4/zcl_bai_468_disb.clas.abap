CLASS zcl_bai_468_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_468_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.


  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '468' iv_flow_type = 'D' ).
    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN lt_f
      WHERE ( vorgc = '468' )
      ( ls )
    ).


    ms_stats-total_count = lines( lt_f ).
    IF lt_f IS INITIAL.
      GET TIME STAMP FIELD lv_t1.
      ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.
      RETURN.
    ENDIF.

    DATA lr_augbl TYPE RANGE OF zcd_ach_rtrv_log-augbl.
    LOOP AT lt_f INTO DATA(ls_f) WHERE chect IS NOT INITIAL.
      lr_augbl = VALUE #( BASE lr_augbl ( sign = 'I' option = 'EQ' low = convert_to_augbl( ls_f-chect ) ) ).
    ENDLOOP.
    SORT lr_augbl BY low.
    DELETE ADJACENT DUPLICATES FROM lr_augbl COMPARING low.

    TYPES: BEGIN OF ty_log,
             augbl TYPE zcd_ach_rtrv_log-augbl,
             stat  TYPE zcd_ach_rtrv_log-zzretrieval_status,
           END OF ty_log.
    DATA lt_log TYPE HASHED TABLE OF ty_log WITH UNIQUE KEY augbl.

    IF lr_augbl IS NOT INITIAL.
      SELECT augbl, zzretrieval_status
        FROM zcd_ach_rtrv_log
        WHERE augbl IN @lr_augbl
        INTO TABLE @DATA(lt_log_raw).
      lt_log = VALUE #( FOR r IN lt_log_raw ( augbl = r-augbl stat = r-zzretrieval_status ) ).
    ENDIF.

    LOOP AT lt_f INTO ls_f.
      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '468'
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
        DATA(lv_augbl) = convert_to_augbl( ls_f-chect ).
        READ TABLE lt_log INTO DATA(ls_log) WITH TABLE KEY augbl = lv_augbl.
        IF sy-subrc <> 0.
          add_failed_check( EXPORTING iv_token = 'RETR_LOG_NOT_FOUND' CHANGING cv_checks = lv_checks ).
        ELSEIF ls_log-stat <> 'AF'.
          add_failed_check( EXPORTING iv_token = 'RETR_STATUS_NOT_AF' CHANGING cv_checks = lv_checks ).
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
