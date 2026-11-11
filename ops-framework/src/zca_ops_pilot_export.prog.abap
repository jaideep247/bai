*&---------------------------------------------------------------------*
*& Artifact: zca_ops_pilot_export.prog.abap
*& Purpose:
*& Pilot pack export (docs/PILOT_PACK.md section 5): the pilot metrics of
*& an area for a date range - per day, business process and check, the
*& share of breaks explained and the baselines - as one CSV file on the
*& application server, in the logical path of PILOT_EXPORT_PATH / logical
*& file PILOT_EXPORT_FILE (transaction FILE; ZCL_CA_OPS_FILE_PATH: a file
*& name only, S_DATASET checked). Complete or nothing: the content is
*& written to <file>.tmp first, the target only after that succeeded, and a
*& failure leaves no partial file. Figures only - no amount, no account
*& number, no business key leaves the system. Authorisation ZCA_OPS 03 for
*& the area. Read only towards every table.
*& Modification log:
*& 2026-11-11 | Initial version (build F: pilot pack).
*&---------------------------------------------------------------------*
REPORT zca_ops_pilot_export.

PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area OBLIGATORY.
PARAMETERS p_from TYPE d.
PARAMETERS p_to TYPE d.
PARAMETERS p_file TYPE string LOWER CASE OBLIGATORY.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    CONSTANTS gc_temp_suffix TYPE string VALUE `.tmp`.

    METHODS export
      RETURNING
        VALUE(rv_lines) TYPE i
      RAISING
        zcx_ca_ops_error.

    "! The physical file of the logical path and file of the parameters
    METHODS target
      RETURNING
        VALUE(rv_path) TYPE string
      RAISING
        zcx_ca_ops_error.

    "! Write every line to the file, closed afterwards
    METHODS write_all
      IMPORTING
        iv_file  TYPE string
        it_lines TYPE string_table
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        DATA(lv_lines) = export( ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    IF lv_lines = 0.
      MESSAGE s301(zca_ops) WITH p_area p_from p_to.
    ELSE.
      MESSAGE s300(zca_ops) WITH p_area p_from p_to lv_lines.
    ENDIF.
  ENDMETHOD.


  METHOD export.
    zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-display
                                            iv_area     = p_area ).
    DATA(lv_to) = COND d( WHEN p_to IS INITIAL THEN zcl_ca_ops_factory=>get_clock( )->today( ) ELSE p_to ).
    DATA(lv_from) = p_from.
    IF lv_from IS INITIAL.
      lv_from = lv_to - zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                                    iv_name    = zif_ca_ops_pilot_types=>gc_param-window_days
                                                    iv_default = zif_ca_ops_pilot_types=>gc_default-window_days ).
    ENDIF.
    p_from = lv_from.
    p_to = lv_to.
    DATA(lo_dao) = NEW zcl_ca_ops_pilot_dao( ).
    DATA(lt_days) = lo_dao->zif_ca_ops_pilot_dao~days( iv_area = p_area iv_from = lv_from iv_to = lv_to ).
    DATA(lt_breaks) = lo_dao->zif_ca_ops_pilot_dao~breaks( iv_area = p_area iv_from = lv_from iv_to = lv_to ).
    IF lt_days IS INITIAL AND lt_breaks IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_lines) = zcl_ca_ops_pilot_csv=>lines( it_days      = lt_days
                                                  it_breaks    = lt_breaks
                                                  it_baselines = lo_dao->zif_ca_ops_pilot_dao~baselines( p_area ) ).
    DATA(lv_file) = target( ).
    DATA(lv_temp) = lv_file && gc_temp_suffix.
    DATA(lv_target_opened) = abap_false.
    TRY.
        write_all( iv_file = lv_temp it_lines = lt_lines ).
        lv_target_opened = abap_true.
        write_all( iv_file = lv_file it_lines = lt_lines ).
      CATCH zcx_ca_ops_error INTO DATA(lx_write).
        DELETE DATASET lv_temp.
        IF lv_target_opened = abap_true.
          " the target was being replaced: never leave it truncated
          DELETE DATASET lv_file.
        ENDIF.
        RAISE EXCEPTION lx_write.
    ENDTRY.
    DELETE DATASET lv_temp.
    rv_lines = lines( lt_lines ).
  ENDMETHOD.


  METHOD target.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_path) = lo_params->get_param( zif_ca_ops_pilot_types=>gc_param-export_path ).
    DATA(lv_logical) = lo_params->get_param( zif_ca_ops_pilot_types=>gc_param-export_file ).
    IF lv_path IS INITIAL OR lv_logical IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e302(zca_ops) WITH zif_ca_ops_pilot_types=>gc_param-export_path
                                   zif_ca_ops_pilot_types=>gc_param-export_file.
    ENDIF.
    rv_path = zcl_ca_ops_file_path=>physical( is_logical   = VALUE #( path = CONV #( lv_path )
                                                                      file = CONV #( lv_logical ) )
                                              iv_file_name = p_file
                                              iv_activity  = zif_ca_ops_types=>gc_dataset_activity-write ).
  ENDMETHOD.


  METHOD write_all.
    TRY.
        OPEN DATASET iv_file FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_ca_ops_error
            MESSAGE e303(zca_ops) WITH p_file.
        ENDIF.
        LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<lv_line>).
          TRANSFER <lv_line> TO iv_file.
        ENDLOOP.
        CLOSE DATASET iv_file.
      CATCH cx_sy_file_access_error INTO DATA(lx_file).
        CLOSE DATASET iv_file.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e303(zca_ops) WITH p_file
          EXPORTING
            previous = lx_file.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
