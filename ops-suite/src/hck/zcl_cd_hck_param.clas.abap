*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_param.clas.abap
*& Purpose:
*& Pure parsing of check parameters (PARAM1-4 of ZCD_HCK_DEF): comma or
*& semicolon lists to select ranges, numbers with a safe default.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - check parameter parsing (pure)</p>
CLASS zcl_cd_hck_param DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! 'ZCD_PAYM_*, ZCD_POST_GL' -> I CP ZCD_PAYM_*, I EQ ZCD_POST_GL
    CLASS-METHODS pattern_range
      IMPORTING
        iv_list         TYPE clike
      RETURNING
        VALUE(rt_range) TYPE zif_cd_hck_types=>tt_pattern_range.

    CLASS-METHODS int
      IMPORTING
        iv_value        TYPE clike
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

ENDCLASS.



CLASS zcl_cd_hck_param IMPLEMENTATION.

  METHOD pattern_range.
    LOOP AT zcl_cd_ops_util=>split_list( iv_list ) INTO DATA(lv_token).
      lv_token = to_upper( lv_token ).
      INSERT VALUE #( sign   = 'I'
                      option = COND #( WHEN lv_token CA '*+' THEN 'CP' ELSE 'EQ' )
                      low    = lv_token ) INTO TABLE rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD int.
    rv_value = zcl_cd_ops_util=>to_decimal( iv_value   = iv_value
                                            iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
