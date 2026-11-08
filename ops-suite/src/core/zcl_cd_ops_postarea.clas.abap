*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea.clas.abap
*& Purpose:
*& Reader of the FI-CA customer posting areas (ZIF_CD_OPS_POSTAREA): the
*& posting area of a purpose, the application area and the chart of
*& accounts come from ZCA_PARAM (POSTAREA_*), the entries from the
*& repository (TFK033D) - one read per purpose and instance; the factory
*& keeps one instance per run. FIND applies the FQC0 rule: a candidate
*& matches every key exactly or by '*'; the candidate with an exact value
*& in the first key (from KEY01) where the candidates differ wins, so an
*& exact key beats '*' and the most specific entry from the left wins
*& (VERIFY in DV1 against FQC0 / FKK_ACCOUNT_DETERMINE, Release_Readiness).
*& No SQL here.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting area reader</p>
CLASS zcl_cd_ops_postarea DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_cd_ops_postarea_factory.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_postarea.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cache,
        purpose TYPE zif_cd_ops_postarea_types=>ty_purpose,
        entries TYPE zif_cd_ops_postarea_types=>tt_entry,
      END OF ty_cache.
    TYPES tt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY purpose.

    "! Entries already read in this run, per purpose
    DATA mt_cache TYPE tt_cache.

    "! Rank of a candidate: per key 'X' exact, ' ' generic; blank when it does not apply.
    "! The highest rank wins (character comparison from KEY01 on).
    METHODS rank
      IMPORTING
        is_keys        TYPE zif_cd_ops_postarea_types=>ty_keys
        is_entry       TYPE zif_cd_ops_postarea_types=>ty_entry
      RETURNING
        VALUE(rv_rank) TYPE string.

ENDCLASS.



CLASS zcl_cd_ops_postarea IMPLEMENTATION.

  METHOD zif_cd_ops_postarea~area.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    rv_area = SWITCH #( iv_purpose
      WHEN zif_cd_ops_postarea_types=>gc_purpose-reason
        THEN lo_params->get_param( iv_name    = zif_cd_ops_postarea_types=>gc_param-reason
                                   iv_default = zif_cd_ops_postarea_types=>gc_param_default-reason )
      WHEN zif_cd_ops_postarea_types=>gc_purpose-pm_class
        THEN lo_params->get_param( iv_name    = zif_cd_ops_postarea_types=>gc_param-pm_class
                                   iv_default = zif_cd_ops_postarea_types=>gc_param_default-pm_class )
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_map
        THEN lo_params->get_param( iv_name    = zif_cd_ops_postarea_types=>gc_param-btc_map
                                   iv_default = zif_cd_ops_postarea_types=>gc_param_default-btc_map )
      WHEN zif_cd_ops_postarea_types=>gc_purpose-btc_role
        THEN lo_params->get_param( iv_name    = zif_cd_ops_postarea_types=>gc_param-btc_role
                                   iv_default = zif_cd_ops_postarea_types=>gc_param_default-btc_role ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_postarea~entries.
    READ TABLE mt_cache ASSIGNING FIELD-SYMBOL(<ls_cache>) WITH TABLE KEY purpose = iv_purpose.
    IF sy-subrc = 0.
      rt_entries = <ls_cache>-entries.
      RETURN.
    ENDIF.
    DATA(lv_area) = zif_cd_ops_postarea~area( iv_purpose ).
    " An unknown purpose or a blank parameter names no posting area: nothing is read
    IF lv_area IS NOT INITIAL.
      DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
      rt_entries = zcl_cd_ops_postarea_factory=>get_dao( )->read_entries(
                     iv_applk = CONV #( lo_params->get_param(
                                          iv_name    = zif_cd_ops_postarea_types=>gc_param-applk
                                          iv_default = zif_cd_ops_postarea_types=>gc_param_default-applk ) )
                     iv_area  = lv_area
                     iv_ktopl = CONV #( lo_params->get_param( zif_cd_ops_postarea_types=>gc_param-ktopl ) ) ).
    ENDIF.
    INSERT VALUE #( purpose = iv_purpose entries = rt_entries ) INTO TABLE mt_cache.
  ENDMETHOD.


  METHOD zif_cd_ops_postarea~find.
    DATA lv_best TYPE string.
    LOOP AT zif_cd_ops_postarea~entries( iv_purpose ) ASSIGNING FIELD-SYMBOL(<ls_entry>).
      DATA(lv_rank) = rank( is_keys = is_keys is_entry = <ls_entry> ).
      IF lv_rank IS NOT INITIAL AND ( rs_entry IS INITIAL OR lv_rank > lv_best ).
        rs_entry = <ls_entry>.
        lv_best  = lv_rank.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD rank.
    DO zif_cd_ops_postarea_types=>gc_key_count TIMES.
      ASSIGN COMPONENT sy-index OF STRUCTURE is_keys TO FIELD-SYMBOL(<lv_key>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      ASSIGN COMPONENT sy-index OF STRUCTURE is_entry TO FIELD-SYMBOL(<lv_entry_key>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      CASE <lv_entry_key>.
        WHEN <lv_key>.
          rv_rank = |{ rv_rank }{ abap_true }|.
        WHEN zif_cd_ops_postarea_types=>gc_generic.
          rv_rank = |{ rv_rank }{ zif_cd_ops_postarea_types=>gc_generic }|.
        WHEN OTHERS.
          CLEAR rv_rank.
          RETURN.
      ENDCASE.
    ENDDO.
  ENDMETHOD.

ENDCLASS.
