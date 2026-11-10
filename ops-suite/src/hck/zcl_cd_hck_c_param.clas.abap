*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_param.clas.abap
*& Purpose:
*& Configuration check PARAM_INVALID: reads every parameter of the suite's
*& areas in ZCA_PARAM (CD_OPS, CD_EBS, CD_FMON, CD_HCK) through ZIF_CA_PARAM
*& - every definition of the area in the database and every delivered
*& definition (ZCL_CD_OPS_PARAM_SEED) - and reports each one the framework
*& refuses (unknown area / name, invalid value or default, mandatory value
*& missing, two rows for a single value). A bad parameter falls back to its
*& code default at run time (ZCL_CA_OPS_PARAMS) and shows here the next
*& morning at the latest.
*& Modification log:
*& 2026-11-07 | Initial version (parameters moved to ZCA_PARAM).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - invalid parameters (ZCA_PARAM)</p>
"! One PARAM_INVALID finding (E) per parameter that ZIF_CA_PARAM refuses, object key
"! area/name, message = the framework message; an area that does not exist or is
"! inactive is one finding. Metric PARAM_INVALID '*' = number of findings.
CLASS zcl_cd_hck_c_param DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'PARAM_INVALID'.
    "! Separator of area and name in the object key
    CONSTANTS gc_key_separator TYPE c LENGTH 1 VALUE '/'.

  PRIVATE SECTION.
    TYPES tt_name TYPE SORTED TABLE OF zif_ca_param_types=>ty_name WITH UNIQUE KEY table_line.

    "! Read a parameter as the suite reads it (BOOL, LIST, select-option or single value)
    METHODS read
      IMPORTING
        io_param TYPE REF TO zif_ca_param
        iv_area  TYPE zif_ca_param_types=>ty_area
        iv_name  TYPE zif_ca_param_types=>ty_name
      RAISING
        zcx_ca_param.

    METHODS finding
      IMPORTING
        iv_area           TYPE zif_ca_param_types=>ty_area
        iv_name           TYPE zif_ca_param_types=>ty_name OPTIONAL
        iv_text           TYPE string
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_cd_hck_c_param IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lt_names TYPE tt_name.

    DATA(lo_dao) = zcl_cd_hck_factory=>get_param_dao( ).
    DATA(lo_param) = zcl_ca_param_factory=>get( ).
    DATA(lt_delivered) = zcl_cd_ops_param_seed=>definitions( ).
    LOOP AT zcl_cd_ops_param_seed=>areas( ) ASSIGNING FIELD-SYMBOL(<ls_area>).
      DATA(ls_data) = lo_dao->read_area( <ls_area>-area ).
      IF ls_data-found = abap_false OR ls_data-area-active = abap_false.
        " The whole area is unreadable: one finding, not one per parameter
        INSERT finding( iv_area = <ls_area>-area
                        iv_text = zcx_ca_param=>create( VALUE #(
                                    msgid = zif_ca_param_types=>gc_msgid
                                    msgno = COND #( WHEN ls_data-found = abap_false
                                                    THEN zif_ca_param_types=>gc_msg-area_unknown
                                                    ELSE zif_ca_param_types=>gc_msg-area_inactive )
                                    v1    = <ls_area>-area ) )->get_text( ) ) INTO TABLE rs_result-findings.
        CONTINUE.
      ENDIF.
      CLEAR lt_names.
      LOOP AT ls_data-definitions ASSIGNING FIELD-SYMBOL(<ls_maintained>).
        INSERT <ls_maintained>-name INTO TABLE lt_names.
      ENDLOOP.
      LOOP AT lt_delivered ASSIGNING FIELD-SYMBOL(<ls_delivered>) WHERE area = <ls_area>-area.
        INSERT <ls_delivered>-name INTO TABLE lt_names.
      ENDLOOP.
      " the check sees the database as it is now, not the buffer of an earlier read
      lo_param->refresh( <ls_area>-area ).
      LOOP AT lt_names ASSIGNING FIELD-SYMBOL(<lv_name>).
        TRY.
            read( io_param = lo_param
                  iv_area  = <ls_area>-area
                  iv_name  = <lv_name> ).
          CATCH zcx_ca_param INTO DATA(lx_error).
            INSERT finding( iv_area = <ls_area>-area
                            iv_name = <lv_name>
                            iv_text = lx_error->get_text( ) ) INTO TABLE rs_result-findings.
        ENDTRY.
      ENDLOOP.
    ENDLOOP.
    INSERT VALUE #( metric = gc_metric
                    dim1   = zif_cd_hck_types=>gc_default_key
                    value  = lines( rs_result-findings ) ) INTO TABLE rs_result-metrics.
  ENDMETHOD.


  METHOD read.
    DATA(ls_definition) = io_param->get_definition( iv_area = iv_area
                                                    iv_name = iv_name ).
    IF ls_definition-kind = zif_ca_param_types=>gc_kind-select.
      io_param->get_range( iv_area = iv_area
                           iv_name = iv_name ).
      RETURN.
    ENDIF.
    CASE ls_definition-value_type.
      WHEN zif_ca_param_types=>gc_value_type-bool.
        io_param->get_bool( iv_area = iv_area
                            iv_name = iv_name ).
      WHEN zif_ca_param_types=>gc_value_type-list.
        io_param->get_list( iv_area = iv_area
                            iv_name = iv_name ).
      WHEN OTHERS.
        io_param->get_value( iv_area = iv_area
                             iv_name = iv_name ).
    ENDCASE.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_key = COND #( WHEN iv_name IS INITIAL THEN iv_area
                                    ELSE |{ iv_area }{ gc_key_separator }{ iv_name }| ).
    rs_finding-group1     = iv_area.
    rs_finding-check_code = zif_cd_hck_types=>gc_code-param_invalid.
    rs_finding-severity   = zif_ca_ops_types=>gc_severity-error.
    rs_finding-action     = zif_ca_ops_types=>gc_action-notify.
    rs_finding-message    = iv_text.
  ENDMETHOD.

ENDCLASS.
