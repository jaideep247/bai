*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_eval_period.clas.abap
*& Purpose:
*& Delivered period-close calendar (ZIF_CA_OPS_EVAL_PERIOD): the closed
*& accounting periods of parameter EVAL_PERIOD_CLOSED (area CA_OPS), a
*& comma list of AREA:YYYYMM (the area) or AREA:BUKRS:YYYYMM (one company
*& code); area * = every area. A scope with company codes is closed when
*& each of them is (an area entry closes all); blank list = the area entry.
*& Nothing configured = no period closed. A site's own calendar named in
*& EVAL_PERIOD_SOURCE (ZIF_CA_OPS_EVAL_PERIOD, checked by RTTI) answers
*& instead; a calendar that cannot be created leaves the period open (the
*& result keeps its class). Reads parameters only.
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - period close from parameters</p>
CLASS zcl_ca_ops_eval_period DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_eval_period.

    "! The rule on a given list (the entries of EVAL_PERIOD_CLOSED): pure, for the tests and the runner
    CLASS-METHODS closed_in
      IMPORTING
        it_entries       TYPE string_table
        iv_area          TYPE zif_ca_ops_types=>ty_area
        iv_period        TYPE zif_ca_ops_eval_types=>ty_period
        iv_bukrs_list    TYPE zif_ca_ops_eval_types=>ty_bukrs_list OPTIONAL
      RETURNING
        VALUE(rv_closed) TYPE abap_bool.

  PRIVATE SECTION.
    "! This class: named in EVAL_PERIOD_SOURCE it is the parameter list (no hand-over to itself)
    CONSTANTS gc_self TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_OPS_EVAL_PERIOD'.

    "! An entry closes the period for the area (iv_bukrs blank) or for the company code
    CLASS-METHODS entry_closes
      IMPORTING
        iv_entry         TYPE string
        iv_area          TYPE zif_ca_ops_types=>ty_area
        iv_period        TYPE zif_ca_ops_eval_types=>ty_period
        iv_bukrs         TYPE clike
      RETURNING
        VALUE(rv_closes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_ca_ops_eval_period IMPLEMENTATION.

  METHOD zif_ca_ops_eval_period~is_closed.
    DATA lo_site TYPE REF TO zif_ca_ops_eval_period.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_class) = CONV zif_ca_ops_types=>ty_class_name( to_upper( condense(
                       lo_params->get_param( zif_ca_ops_eval_types=>gc_param-period_source ) ) ) ).
    IF lv_class IS NOT INITIAL AND lv_class <> gc_self.
      TRY.
          lo_site = CAST zif_ca_ops_eval_period( zcl_ca_ops_factory=>get_plugin(
                      iv_class_name = lv_class
                      iv_interface  = zif_ca_ops_eval_types=>gc_plugin_intf-period_source ) ).
          rv_closed = lo_site->is_closed( iv_area = iv_area iv_period = iv_period iv_bukrs_list = iv_bukrs_list ).
        CATCH zcx_ca_ops_error cx_sy_move_cast_error.
          rv_closed = abap_false.
      ENDTRY.
      RETURN.
    ENDIF.
    DATA(lv_list) = lo_params->get_param(
                      iv_name    = zif_ca_ops_eval_types=>gc_param-period_closed
                      iv_default = `` ).
    rv_closed = closed_in( it_entries    = zcl_ca_ops_util=>split_list( lv_list )
                           iv_area       = iv_area
                           iv_period     = iv_period
                           iv_bukrs_list = iv_bukrs_list ).
  ENDMETHOD.


  METHOD closed_in.
    IF it_entries IS INITIAL OR iv_period IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_bukrs) = zcl_ca_ops_util=>split_list( iv_bukrs_list ).
    IF lt_bukrs IS INITIAL.
      LOOP AT it_entries INTO DATA(lv_entry).
        IF entry_closes( iv_entry = lv_entry iv_area = iv_area iv_period = iv_period iv_bukrs = '' ) = abap_true.
          rv_closed = abap_true.
          RETURN.
        ENDIF.
      ENDLOOP.
      RETURN.
    ENDIF.
    " every company code of the scope must be closed (by its own entry or by the area's)
    LOOP AT lt_bukrs INTO DATA(lv_bukrs).
      DATA(lv_this) = abap_false.
      LOOP AT it_entries INTO lv_entry.
        IF entry_closes( iv_entry = lv_entry iv_area = iv_area iv_period = iv_period iv_bukrs = lv_bukrs ) = abap_true.
          lv_this = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_this = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
    rv_closed = abap_true.
  ENDMETHOD.


  METHOD entry_closes.
    SPLIT to_upper( condense( iv_entry ) ) AT zif_ca_ops_eval_types=>gc_entry_separator INTO TABLE DATA(lt_parts).
    DATA(lv_area) = to_upper( condense( CONV string( iv_area ) ) ).
    CASE lines( lt_parts ).
      WHEN 2.
        " AREA:YYYYMM closes the period for the area and every company code of it
        rv_closes = xsdbool( ( lt_parts[ 1 ] = lv_area OR lt_parts[ 1 ] = zif_ca_ops_eval_types=>gc_any_area )
                             AND lt_parts[ 2 ] = iv_period ).
      WHEN 3.
        " AREA:BUKRS:YYYYMM closes it for that company code only
        rv_closes = xsdbool( iv_bukrs IS NOT INITIAL
                             AND ( lt_parts[ 1 ] = lv_area OR lt_parts[ 1 ] = zif_ca_ops_eval_types=>gc_any_area )
                             AND lt_parts[ 2 ] = to_upper( condense( CONV string( iv_bukrs ) ) )
                             AND lt_parts[ 3 ] = iv_period ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
