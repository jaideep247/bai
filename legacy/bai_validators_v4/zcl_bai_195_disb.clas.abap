CLASS zcl_bai_195_disb DEFINITION
  PUBLIC
  INHERITING FROM zcl_bai_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS zif_bai_validator~validate REDEFINITION.
ENDCLASS.

CLASS zcl_bai_195_disb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
  ENDMETHOD.

  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '195' iv_flow_type = 'D' ).

    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN it_febep
      WHERE ( vorgc = '195' )
      ( ls )
    ).

    ms_stats-total_count = lines( lt_f ).
    IF lt_f IS INITIAL.
      GET TIME STAMP FIELD lv_t1.
      ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.
      RETURN.
    ENDIF.

    "------------------------------------------------------------
    " Prefetch DPAYH by DOC1R (DOC1R is 24, CHECT is 13)
    "------------------------------------------------------------
    DATA lr_doc1r TYPE RANGE OF dpayh-doc1r.

    LOOP AT lt_f INTO DATA(ls_f) WHERE chect IS NOT INITIAL.
      lr_doc1r = VALUE #( BASE lr_doc1r
        ( sign = 'I' option = 'EQ' low = convert_to_doc1r( ls_f-chect ) ) ).
    ENDLOOP.

    SORT lr_doc1r BY low.
    DELETE ADJACENT DUPLICATES FROM lr_doc1r COMPARING low.

    TYPES: BEGIN OF ty_payh,
             doc1r TYPE dpayh-doc1r,
           END OF ty_payh.

    DATA lt_payh TYPE HASHED TABLE OF ty_payh WITH UNIQUE KEY doc1r.

    IF lr_doc1r IS NOT INITIAL.
      SELECT doc1r
        FROM dpayh
        WHERE doc1r IN @lr_doc1r
        INTO TABLE @DATA(lt_payh_raw).

      lt_payh = VALUE #( FOR r IN lt_payh_raw ( doc1r = r-doc1r ) ).
    ENDIF.

    "------------------------------------------------------------
    " Validate
    "------------------------------------------------------------
    LOOP AT lt_f INTO ls_f.

      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '195'
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
        DATA(lv_doc1r) = convert_to_doc1r( ls_f-chect ).
        IF line_exists( lt_payh[ doc1r = lv_doc1r ] ) = abap_false.
          add_failed_check( EXPORTING iv_token = 'DPAYH_NOT_FOUND' CHANGING cv_checks = lv_checks ).
        ENDIF.
      ENDIF.

      IF lv_checks IS INITIAL.
        ms_stats-passed_count += 1.
      ELSE.
        mark_failed( EXPORTING iv_checks = lv_checks CHANGING cs_result = ls_res ).
        IF ls_res-message IS INITIAL.
          ls_res-message = |FAIL: { lv_checks }|.
        ENDIF.
        APPEND ls_res TO rt_results.
        ms_stats-failed_count += 1.
      ENDIF.

    ENDLOOP.

    GET TIME STAMP FIELD lv_t1.
    ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.

  ENDMETHOD.

ENDCLASS.
