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
  ENDMETHOD.

  METHOD zif_bai_validator~validate.

    load_config( iv_bai_code = '168' iv_flow_type = 'D' ).

    DATA lv_t0 TYPE timestampl.
    DATA lv_t1 TYPE timestampl.
    GET TIME STAMP FIELD lv_t0.

    " Filter to relevant VORGC only
    DATA(lt_f) = VALUE zif_bai_validator=>tt_febep_data(
      FOR ls IN lt_f
      WHERE ( vorgc = '168' )
      ( ls )
    ).


    ms_stats-total_count = lines( lt_f ).
    IF lt_f IS INITIAL.
      GET TIME STAMP FIELD lv_t1.
      ms_stats-duration_ms = ( lv_t1 - lv_t0 ) / 1000.
      RETURN.
    ENDIF.

    "------------------------------------------------------------
    " Keys: OPBEL (CHECT), DOC1R (DPAYH), AUGBL (Retrieval log)
    "------------------------------------------------------------
    TYPES: BEGIN OF ty_opbel,
             opbel TYPE opbel_kk,
           END OF ty_opbel.

    DATA lt_opbel TYPE SORTED TABLE OF ty_opbel WITH UNIQUE KEY opbel.
    DATA lr_doc1r TYPE RANGE OF dpayh-doc1r.
    DATA lr_augbl TYPE RANGE OF zcd_ach_rtrv_log-augbl.

    LOOP AT lt_f INTO DATA(ls_f) WHERE chect IS NOT INITIAL.
      INSERT VALUE #( opbel = ls_f-chect ) INTO TABLE lt_opbel.

      lr_doc1r = VALUE #( BASE lr_doc1r
        ( sign = 'I' option = 'EQ' low = convert_to_doc1r( ls_f-chect ) ) ).

      lr_augbl = VALUE #( BASE lr_augbl
        ( sign = 'I' option = 'EQ' low = convert_to_augbl( ls_f-chect ) ) ).
    ENDLOOP.

    SORT lr_doc1r BY low.
    DELETE ADJACENT DUPLICATES FROM lr_doc1r COMPARING low.

    SORT lr_augbl BY low.
    DELETE ADJACENT DUPLICATES FROM lr_augbl COMPARING low.

    "------------------------------------------------------------
    " JOIN-only prefetch: DFKKRP + DFKKRK
    "------------------------------------------------------------
    TYPES: BEGIN OF ty_join,
             opbel TYPE opbel_kk,
             stars TYPE dfkkrk-stars,
           END OF ty_join.

    DATA lt_join TYPE HASHED TABLE OF ty_join WITH UNIQUE KEY opbel.

    IF lt_opbel IS NOT INITIAL.
      SELECT rp~opbel, rk~stars
        FROM dfkkrp AS rp
        INNER JOIN dfkkrk AS rk
          ON rk~opbel = rp~opbel
        FOR ALL ENTRIES IN @lt_opbel
        WHERE rp~opbel = @lt_opbel-opbel
        INTO TABLE @DATA(lt_join_raw).

      lt_join = VALUE #( FOR r IN lt_join_raw ( opbel = r-opbel stars = r-stars ) ).
    ENDIF.

    "------------------------------------------------------------
    " Prefetch DPAYH by DOC1R -> ZZPAYMENT_STATUS
    "------------------------------------------------------------
    TYPES: BEGIN OF ty_payh,
             doc1r            TYPE dpayh-doc1r,
             zzpayment_status TYPE dpayh-zzpayment_status,
           END OF ty_payh.

    DATA lt_payh TYPE HASHED TABLE OF ty_payh WITH UNIQUE KEY doc1r.

    IF lr_doc1r IS NOT INITIAL.
      SELECT doc1r, zzpayment_status
        FROM dpayh
        WHERE doc1r IN @lr_doc1r
        INTO TABLE @DATA(lt_payh_raw).

      lt_payh = VALUE #(
        FOR r IN lt_payh_raw
        ( doc1r = r-doc1r
          zzpayment_status = r-zzpayment_status )
      ).
    ENDIF.

    "------------------------------------------------------------
    " Prefetch Retrieval log by AUGBL -> ZZ_RTRV_STATUS
    "------------------------------------------------------------
    TYPES: BEGIN OF ty_rtrv,
             augbl      TYPE zcd_ach_rtrv_log-augbl,
             zz_rtrv_st TYPE zcd_ach_rtrv_log-zz_rtrv_status,
           END OF ty_rtrv.

    DATA lt_rtrv TYPE HASHED TABLE OF ty_rtrv WITH UNIQUE KEY augbl.

    IF lr_augbl IS NOT INITIAL.
      SELECT augbl, zz_rtrv_status
        FROM zcd_ach_rtrv_log
        WHERE augbl IN @lr_augbl
        INTO TABLE @DATA(lt_rtrv_raw).

      lt_rtrv = VALUE #(
        FOR r IN lt_rtrv_raw
        ( augbl      = r-augbl
          zz_rtrv_st = r-zz_rtrv_status )
      ).
    ENDIF.

    "------------------------------------------------------------
    " Validate
    "------------------------------------------------------------
    LOOP AT lt_f INTO ls_f.

      DATA(ls_res) = VALUE zif_bai_validator=>ty_validation_result(
        kukey       = ls_f-kukey
        esnum       = ls_f-esnum
        bai_code    = '168'
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
        " 1) RP+RK via JOIN
        READ TABLE lt_join INTO DATA(ls_j) WITH TABLE KEY opbel = ls_f-chect.
        IF sy-subrc <> 0.
          add_failed_check( EXPORTING iv_token = 'RP_OR_RK_MISSING' CHANGING cv_checks = lv_checks ).
        ELSEIF ls_j-stars <> '5'.
          add_failed_check( EXPORTING iv_token = 'STARS_NOT_5' CHANGING cv_checks = lv_checks ).
        ENDIF.

        " 2) DPAYH status must be RETURNED
        DATA(lv_doc1r) = convert_to_doc1r( ls_f-chect ).
        READ TABLE lt_payh INTO DATA(ls_p) WITH TABLE KEY doc1r = lv_doc1r.
        IF sy-subrc <> 0.
          add_failed_check( EXPORTING iv_token = 'DPAYH_NOT_FOUND' CHANGING cv_checks = lv_checks ).
        ELSEIF ls_p-zzpayment_status <> 'RETURNED'.
          add_failed_check( EXPORTING iv_token = 'DPAYH_NOT_RETURNED' CHANGING cv_checks = lv_checks ).
        ENDIF.

        " 3) Retrieval log must be AF
        DATA(lv_augbl) = convert_to_augbl( ls_f-chect ).
        READ TABLE lt_rtrv INTO DATA(ls_r) WITH TABLE KEY augbl = lv_augbl.
        IF sy-subrc <> 0.
          add_failed_check( EXPORTING iv_token = 'RTRV_LOG_NOT_FOUND' CHANGING cv_checks = lv_checks ).
        ELSEIF ls_r-zz_rtrv_st <> 'AF'.
          add_failed_check( EXPORTING iv_token = 'RTRV_STATUS_NOT_AF' CHANGING cv_checks = lv_checks ).
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
