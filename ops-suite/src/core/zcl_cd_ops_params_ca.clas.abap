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
*& written once per snapshot to the application log (ZCD_OPS / PARAM) and
*& kept for get_errors( ), and the caller's default keeps the run going.
*& Modification log:
*& 2026-11-07 | Initial version (parameters moved from ZCD_OPS_PARAM to ZCA_PARAM).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - parameters over ZCA_PARAM</p>
"! Adapter ZIF_CD_OPS_PARAMS -> ZIF_CA_PARAM. get_param: BOOL via get_bool (X / blank),
"! other types via get_value; get_range: get_range (kind S) or get_list as I / EQ rows;
"! refresh_params: refresh( ). Errors: application log + get_errors( ) + caller default.
CLASS zcl_cd_ops_params_ca DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_params.

    "! Application log of parameter errors (object / subobject, SLG0)
    CONSTANTS gc_log_destination TYPE zif_cd_ops_types=>ty_alert_dest VALUE 'ZCD_OPS/PARAM'.
    "! Channel class that writes the application log
    CONSTANTS gc_log_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_OPS_CHN_APPLOG'.

    "! @parameter io_param | Reader; default: ZCL_CA_PARAM_FACTORY=>GET( ) at every read
    "! @parameter io_log   | Log channel; default: the application log channel (factory plug-in)
    METHODS constructor
      IMPORTING
        io_param TYPE REF TO zif_ca_param OPTIONAL
        io_log   TYPE REF TO zif_cd_ops_alert_channel OPTIONAL.

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
    DATA mo_log TYPE REF TO zif_cd_ops_alert_channel.
    DATA mt_errors TYPE zif_cd_ops_types=>tt_param_error.

    "! The prefix table (constants of ZIF_CD_OPS_TYPES)
    CLASS-METHODS prefix_areas
      RETURNING
        VALUE(rt_map) TYPE tt_prefix_area.

    METHODS reader
      RETURNING
        VALUE(ro_param) TYPE REF TO zif_ca_param.

    "! Keep the error (once per area / name and snapshot) and write it to the application log
    METHODS record
      IMPORTING
        iv_area  TYPE zif_ca_param_types=>ty_area
        iv_name  TYPE zif_cd_ops_types=>ty_param_name
        ix_error TYPE REF TO zcx_ca_param.

ENDCLASS.



CLASS zcl_cd_ops_params_ca IMPLEMENTATION.

  METHOD constructor.
    mo_param = io_param.
    mo_log   = io_log.
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
    DATA ls_message TYPE zif_cd_ops_types=>ty_alert_message.

    IF line_exists( mt_errors[ area = iv_area name = iv_name ] ).
      RETURN.
    ENDIF.
    INSERT VALUE #( area  = iv_area
                    name  = iv_name
                    msgno = ix_error->get_message( )-msgno
                    text  = ix_error->get_text( ) ) INTO TABLE mt_errors.

    ls_message-channel     = zif_cd_ops_types=>gc_channel-applog.
    ls_message-destination = gc_log_destination.
    ls_message-pe_area     = zif_cd_ops_types=>gc_pe_area-core.
    ls_message-severity    = zif_cd_ops_types=>gc_severity-error.
    ls_message-rule_id     = iv_name.
    ls_message-extnumber   = iv_name.
    ls_message-subject     = ix_error->get_text( ).
    ls_message-text        = ix_error->get_text( ).
    TRY.
        DATA(lo_log) = COND #( WHEN mo_log IS BOUND THEN mo_log
                               ELSE CAST zif_cd_ops_alert_channel( zcl_cd_ops_factory=>get_plugin(
                                      iv_class_name = gc_log_class
                                      iv_interface  = zif_cd_ops_types=>gc_plugin_intf-alert_channel ) ) ).
        lo_log->deliver( ls_message ).
      CATCH zcx_cd_ops_error.
        " The error stays in get_errors( ); a log that cannot be written never stops the run
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
