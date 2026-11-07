*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_params_mem.clas.abap
*& Purpose:
*& In-memory runtime parameters (ZIF_CD_OPS_PARAMS) with exactly the read
*& semantics of ZCL_CD_OPS_STORE over ZCD_OPS_PARAM: the name is the exact key
*& (as PARAM_NAME, CHAR 30), the value is kept as the table keeps it (CHAR 255,
*& longer values cut) and read condensed; a missing or blank value returns the
*& default; get_range splits the comma / semicolon list into I / EQ rows.
*& The shared parameter fake of the unit tests (injected with
*& ZCL_CD_OPS_INJECTOR=>INJECT_PARAMS or used by a store double), and safe in
*& production code (no database, no side effects). It does not take the per-run
*& snapshot of the store: a value set is visible at once.
*& Modification log:
*& 2026-11-07 | Initial version (shared parameter fake, ZIF_CD_OPS_PARAMS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - in-memory runtime parameters</p>
"! In-memory ZIF_CD_OPS_PARAMS with the read semantics of ZCL_CD_OPS_STORE: exact name,
"! value kept as CHAR 255 and read condensed, blank or missing = default.
CLASS zcl_cd_ops_params_mem DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_params.

    "! Optionally maintained parameters (name / value rows, as in ZCD_OPS_PARAM)
    METHODS constructor
      IMPORTING
        it_params TYPE zif_cd_ops_types=>tt_kv OPTIONAL.

    "! Maintain a parameter (overwrites an existing value); returns the instance for chaining
    METHODS set
      IMPORTING
        iv_name        TYPE zif_cd_ops_types=>ty_param_name
        iv_value       TYPE clike
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_cd_ops_params_mem.

    "! Maintain several parameters at once (name / value rows)
    METHODS set_all
      IMPORTING
        it_params TYPE zif_cd_ops_types=>tt_kv.

    "! Remove one parameter (as if its ZCD_OPS_PARAM row were deleted)
    METHODS remove
      IMPORTING
        iv_name TYPE zif_cd_ops_types=>ty_param_name.

    "! Every parameter as maintained (not condensed)
    METHODS get_all
      RETURNING
        VALUE(rt_params) TYPE zif_cd_ops_types=>tt_kv.

    "! Calls of refresh_params since creation (a run takes one snapshot, audit A64)
    METHODS refresh_count
      RETURNING
        VALUE(rv_count) TYPE i.

  PRIVATE SECTION.
    DATA mt_params TYPE zif_cd_ops_types=>tt_kv.
    DATA mv_refresh_count TYPE i.

ENDCLASS.



CLASS zcl_cd_ops_params_mem IMPLEMENTATION.

  METHOD constructor.
    set_all( it_params ).
  ENDMETHOD.


  METHOD set.
    DATA(ls_param) = VALUE zif_cd_ops_types=>ty_kv( name  = iv_name
                                                    value = iv_value ).
    DELETE TABLE mt_params WITH TABLE KEY name = iv_name.
    INSERT ls_param INTO TABLE mt_params.
    ro_self = me.
  ENDMETHOD.


  METHOD set_all.
    LOOP AT it_params ASSIGNING FIELD-SYMBOL(<ls_param>).
      set( iv_name = <ls_param>-name iv_value = <ls_param>-value ).
    ENDLOOP.
  ENDMETHOD.


  METHOD remove.
    DELETE TABLE mt_params WITH TABLE KEY name = iv_name.
  ENDMETHOD.


  METHOD get_all.
    rt_params = mt_params.
  ENDMETHOD.


  METHOD refresh_count.
    rv_count = mv_refresh_count.
  ENDMETHOD.


  METHOD zif_cd_ops_params~refresh_params.
    mv_refresh_count = mv_refresh_count + 1.
  ENDMETHOD.


  METHOD zif_cd_ops_params~get_param.
    " Same rule as ZCL_CD_OPS_STORE: a maintained, non-blank value condensed, else the default
    READ TABLE mt_params ASSIGNING FIELD-SYMBOL(<ls_param>) WITH TABLE KEY name = iv_name.
    IF sy-subrc = 0 AND <ls_param>-value IS NOT INITIAL.
      rv_value = condense( CONV string( <ls_param>-value ) ).
    ELSE.
      rv_value = iv_default.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_params~get_range.
    LOOP AT zcl_cd_ops_util=>split_list( zif_cd_ops_params~get_param( iv_name ) ) ASSIGNING FIELD-SYMBOL(<lv_value>).
      INSERT VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                      option = zif_cd_ops_types=>gc_range-option_equal
                      low    = <lv_value> ) INTO TABLE rt_range.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
