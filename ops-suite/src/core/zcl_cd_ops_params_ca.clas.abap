*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_params_ca.clas.abap
*& Purpose:
*& The suite's runtime parameters (ZIF_CD_OPS_PARAMS) over the global
*& parameter framework ZCA_PARAM (ZIF_CA_PARAM from ZCL_CA_PARAM_FACTORY).
*& The area comes from the name prefix (ALERT_ SLA_ RETENTION_ PURGE_
*& TRACE_ -> CD_OPS, EBS_ -> CD_EBS, FMON_ -> CD_FMON, HCK_ -> CD_HCK);
*& names are unchanged. A value the framework resolves wins over the
*& caller's default (single source of defaults = the definition); BOOL is
*& X or blank (a blank row = off). A ZCX_CA_PARAM is never silent: it is
*& kept once per snapshot for get_errors( ) and the caller's default keeps
*& the run going; the morning check PARAM_INVALID reports it once a day.
*& No application log per run (SLG1 kept to a minimum, user 2026-11-07).
*& Modification log:
*& 2026-11-07 | Initial version (parameters moved from ZCD_OPS_PARAM to ZCA_PARAM).
*& 2026-11-07 | No SLG1 entry per run and parameter (SLG1 minimum); errors in get_errors( ) and PARAM_INVALID.
*& 2026-11-07 | Prefix PAYOUT_ -> CD_OPS (payment outcome snapshot parameters).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - parameters over ZCA_PARAM</p>
"! Adapter ZIF_CD_OPS_PARAMS -> ZIF_CA_PARAM. get_param: BOOL via get_bool (X / blank),
"! other types via get_value; get_range: get_range (kind S) or get_list as I / EQ rows;
"! refresh_params: refresh( ). Errors: get_errors( ) + caller default (no application log).
CLASS zcl_cd_ops_params_ca DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_params.

    "! @parameter io_param | Reader; default: ZCL_CA_PARAM_FACTORY=>GET( ) at every read
    METHODS constructor
      IMPORTING
        io_param TYPE REF TO zif_ca_param OPTIONAL.

    "! Area of a parameter in ZCA_PARAM, from its name prefix; CD_OPS when no prefix fits
    "! (the framework then reports the name as not defined)
    CLASS-METHODS area_of
      IMPORTING
        iv_name        TYPE zif_cd_ops_types=>ty_param_name
      RETURNING
        VALUE(rv_area) TYPE zif_ca_param_types=>ty_area.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_prefix_area,
        prefix TYPE zif_cd_ops_types=>ty_param_name,
        area   TYPE zif_ca_param_types=>ty_area,
      END OF ty_prefix_area.
    TYPES tt_prefix_area TYPE STANDARD TABLE OF ty_prefix_area WITH EMPTY KEY.

    DATA mo_param TYPE REF TO zif_ca_param.
    DATA mt_errors TYPE zif_cd_ops_types=>tt_param_error.

    "! The prefix table (constants of ZIF_CD_OPS_TYPES)
    CLASS-METHODS prefix_areas
      RETURNING
        VALUE(rt_map) TYPE tt_prefix_area.

    METHODS reader
      RETURNING
        VALUE(ro_param) TYPE REF TO zif_ca_param.

    "! Keep the error (once per area / name and snapshot)
    METHODS record
      IMPORTING
        iv_area  TYPE zif_ca_param_types=>ty_area
        iv_name  TYPE zif_cd_ops_types=>ty_param_name
        ix_error TYPE REF TO zcx_ca_param.

ENDCLASS.



CLASS zcl_cd_ops_params_ca IMPLEMENTATION.

  METHOD constructor.
    mo_param = io_param.
  ENDMETHOD.


  METHOD area_of.
    rv_area = zif_cd_ops_types=>gc_param_area-ops.
    LOOP AT prefix_areas( ) ASSIGNING FIELD-SYMBOL(<ls_map>).
      IF find( val = iv_name sub = condense( <ls_map>-prefix ) ) = 0.
        rv_area = <ls_map>-area.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD prefix_areas.
    rt_map = VALUE #( ( prefix = zif_cd_ops_types=>gc_param_area_prefix-alert     area = zif_cd_ops_types=>gc_param_area-ops )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-sla       area = zif_cd_ops_types=>gc_param_area-ops )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-retention area = zif_cd_ops_types=>gc_param_area-ops )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-purge     area = zif_cd_ops_types=>gc_param_area-ops )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-trace     area = zif_cd_ops_types=>gc_param_area-ops )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-payout    area = zif_cd_ops_types=>gc_param_area-ops )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-ebs       area = zif_cd_ops_types=>gc_param_area-ebs )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-fmon      area = zif_cd_ops_types=>gc_param_area-fmon )
                      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-hck       area = zif_cd_ops_types=>gc_param_area-hck ) ).
  ENDMETHOD.


  METHOD reader.
    ro_param = COND #( WHEN mo_param IS BOUND THEN mo_param ELSE zcl_ca_param_factory=>get( ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_params~refresh_params.
    reader( )->refresh( ).
    CLEAR mt_errors.
  ENDMETHOD.


  METHOD zif_cd_ops_params~get_param.
    DATA(lv_area) = area_of( iv_name ).
    TRY.
        DATA(lo_param) = reader( ).
        IF lo_param->get_definition( iv_area = lv_area
                                     iv_name = iv_name )-value_type = zif_ca_param_types=>gc_value_type-bool.
          " A flag is resolved by the framework: row X = on, row blank = off, no row = definition default
          rv_value = COND #( WHEN lo_param->get_bool( iv_area = lv_area
                                                      iv_name = iv_name ) = abap_true
                             THEN zif_ca_param_types=>gc_true ).
          RETURN.
        ENDIF.
        rv_value = condense( lo_param->get_value( iv_area = lv_area
                                                  iv_name = iv_name ) ).
      CATCH zcx_ca_param INTO DATA(lx_error).
        record( iv_area  = lv_area
                iv_name  = iv_name
                ix_error = lx_error ).
    ENDTRY.
    " Nothing resolved (no row, no definition default) or not readable: the caller's default
    IF rv_value IS INITIAL.
      rv_value = iv_default.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_params~get_range.
    DATA(lv_area) = area_of( iv_name ).
    TRY.
        DATA(lo_param) = reader( ).
        IF lo_param->get_definition( iv_area = lv_area
                                     iv_name = iv_name )-kind = zif_ca_param_types=>gc_kind-select.
          rt_range = CORRESPONDING #( lo_param->get_range( iv_area = lv_area
                                                           iv_name = iv_name ) ).
          RETURN.
        ENDIF.
        LOOP AT lo_param->get_list( iv_area = lv_area
                                    iv_name = iv_name ) ASSIGNING FIELD-SYMBOL(<lv_entry>).
          INSERT VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                          option = zif_cd_ops_types=>gc_range-option_equal
                          low    = <lv_entry> ) INTO TABLE rt_range.
        ENDLOOP.
      CATCH zcx_ca_param INTO DATA(lx_error).
        CLEAR rt_range.
        record( iv_area  = lv_area
                iv_name  = iv_name
                ix_error = lx_error ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_ops_params~get_errors.
    rt_errors = mt_errors.
  ENDMETHOD.


  METHOD record.
    IF line_exists( mt_errors[ area = iv_area name = iv_name ] ).
      RETURN.
    ENDIF.
    INSERT VALUE #( area  = iv_area
                    name  = iv_name
                    msgno = ix_error->get_message( )-msgno
                    text  = ix_error->get_text( ) ) INTO TABLE mt_errors.
  ENDMETHOD.

ENDCLASS.
