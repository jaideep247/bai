*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_params.clas.abap
*& Purpose:
*& Runtime parameters (ZIF_CA_OPS_PARAMS) over the global parameter framework
*& ZCA_PARAM (ZIF_CA_PARAM from ZCL_CA_PARAM_FACTORY). The area is the one
*& the caller names, else the one of the longest name prefix: the
*& framework's ALERT_ SLA_ RETENTION_ PURGE_ -> CA_OPS, a consumer's
*& prefixes added with ADD_PREFIXES; names are unchanged. A value the
*& framework resolves wins over the caller's default (single source of
*& defaults = the definition); BOOL is X or blank (a blank row = off). A
*& ZCX_CA_PARAM is never silent: it is kept once per snapshot for
*& get_errors( ) and the caller's default keeps the run going; a consumer's
*& configuration check reports it. No application log per run (SLG1 kept to
*& a minimum). CHECK_AREA validates the area of a run against ZCA_PARAM_AREA.
*& Modification log:
*& 2026-11-07 | Initial version (parameters moved to ZCA_PARAM).
*& 2026-11-07 | No SLG1 entry per run and parameter (SLG1 minimum); errors in get_errors( ).
*& 2026-11-10 | Moved from ZCL_CD_OPS_PARAMS_CA to the reusable framework ZCA_OPS: area named by the caller
*&            | or by the longest registered prefix (consumer prefixes by ADD_PREFIXES, framework prefixes
*&            | -> CA_OPS); CHECK_AREA over ZIF_CA_PARAM=>CHECK_AREA (one area register).
*& 2026-11-10 | Prefixes CONTROL_ and EXC_ read in area CA_OPS (control review, exception reason codes).
*& 2026-11-10 | Prefix CHECK_ read in area CA_OPS (check registry, freshness of the area dashboard).
*& 2026-11-11 | Prefix JOB_ read in area CA_OPS (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - parameters over ZCA_PARAM</p>
"! Adapter ZIF_CA_OPS_PARAMS -> ZIF_CA_PARAM. get_param: BOOL via get_bool (X / blank),
"! other types via get_value; get_range: get_range (kind S) or get_list as I / EQ rows;
"! refresh_params: refresh( ). Errors: get_errors( ) + caller default (no application log).
CLASS zcl_ca_ops_params DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_params.

    "! @parameter io_param | Reader; default: ZCL_CA_PARAM_FACTORY=>GET( ) at every read
    METHODS constructor
      IMPORTING
        io_param TYPE REF TO zif_ca_param OPTIONAL.

  PRIVATE SECTION.
    DATA mo_param TYPE REF TO zif_ca_param.
    DATA mt_errors TYPE zif_ca_ops_types=>tt_param_error.
    "! Name prefix -> area; the framework's prefixes first, then the consumers'
    DATA mt_prefixes TYPE zif_ca_ops_types=>tt_param_prefix.

    METHODS reader
      RETURNING
        VALUE(ro_param) TYPE REF TO zif_ca_param.

    "! The caller's area, else the area of the name prefix
    METHODS area
      IMPORTING
        iv_name        TYPE zif_ca_ops_types=>ty_param_name
        iv_area        TYPE zif_ca_ops_types=>ty_area
      RETURNING
        VALUE(rv_area) TYPE zif_ca_ops_types=>ty_area.

    "! Keep the error (once per area / name and snapshot)
    METHODS record
      IMPORTING
        iv_area  TYPE zif_ca_ops_types=>ty_area
        iv_name  TYPE zif_ca_ops_types=>ty_param_name
        ix_error TYPE REF TO zcx_ca_param.

ENDCLASS.



CLASS zcl_ca_ops_params IMPLEMENTATION.

  METHOD constructor.
    mo_param = io_param.
    mt_prefixes = VALUE #(
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-alert     area = zif_ca_ops_types=>gc_param_area )
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-sla       area = zif_ca_ops_types=>gc_param_area )
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-retention area = zif_ca_ops_types=>gc_param_area )
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-purge     area = zif_ca_ops_types=>gc_param_area )
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-control   area = zif_ca_ops_types=>gc_param_area )
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-exception area = zif_ca_ops_types=>gc_param_area )
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-check     area = zif_ca_ops_types=>gc_param_area )
      ( prefix = zif_ca_ops_types=>gc_param_area_prefix-job       area = zif_ca_ops_types=>gc_param_area ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_params~add_prefixes.
    LOOP AT it_prefixes ASSIGNING FIELD-SYMBOL(<ls_prefix>).
      IF NOT line_exists( mt_prefixes[ prefix = <ls_prefix>-prefix ] ).
        INSERT <ls_prefix> INTO TABLE mt_prefixes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_params~area_of.
    DATA lv_best TYPE i.
    rv_area = zif_ca_ops_types=>gc_param_area.
    LOOP AT mt_prefixes ASSIGNING FIELD-SYMBOL(<ls_map>).
      DATA(lv_prefix) = condense( CONV string( <ls_map>-prefix ) ).
      IF strlen( lv_prefix ) > lv_best AND find( val = iv_name sub = lv_prefix ) = 0.
        lv_best = strlen( lv_prefix ).
        rv_area = <ls_map>-area.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_params~check_area.
    TRY.
        reader( )->check_area( iv_area ).
      CATCH zcx_ca_param INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e043(zca_ops) WITH iv_area
          EXPORTING
            previous = lx_error.
    ENDTRY.
  ENDMETHOD.


  METHOD area.
    rv_area = COND #( WHEN iv_area IS NOT INITIAL THEN iv_area
                      ELSE zif_ca_ops_params~area_of( iv_name ) ).
  ENDMETHOD.


  METHOD reader.
    ro_param = COND #( WHEN mo_param IS BOUND THEN mo_param ELSE zcl_ca_param_factory=>get( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_params~refresh_params.
    reader( )->refresh( ).
    CLEAR mt_errors.
  ENDMETHOD.


  METHOD zif_ca_ops_params~get_param.
    DATA(lv_area) = area( iv_name = iv_name iv_area = iv_area ).
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


  METHOD zif_ca_ops_params~get_range.
    DATA(lv_area) = area( iv_name = iv_name iv_area = iv_area ).
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
          INSERT VALUE #( sign   = zif_ca_ops_types=>gc_range-sign_include
                          option = zif_ca_ops_types=>gc_range-option_equal
                          low    = <lv_entry> ) INTO TABLE rt_range.
        ENDLOOP.
      CATCH zcx_ca_param INTO DATA(lx_error).
        CLEAR rt_range.
        record( iv_area  = lv_area
                iv_name  = iv_name
                ix_error = lx_error ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_params~get_errors.
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
