*&---------------------------------------------------------------------*
*& Artifact: zca_ops_license_install.prog.abap
*& Purpose:
*& Installation of the vendor's licence file (docs/LICENSING.md): reads the
*& file (PEM text the vendor's tool writes) from the frontend or from the
*& application server (logical path LIC_FILE_PATH / logical file
*& LIC_FILE_NAME of transaction FILE, ZCL_CA_OPS_FILE_PATH: a file name
*& only, S_DATASET READ), verifies it on this system - signature by the
*& vendor's certificate in the PSE of LIC_SSF_PROFILE (SSF), installation
*& number, system ID and client, product version - and shows the state of
*& every module. Test mode (default) stores nothing; otherwise a VALID
*& licence becomes the active one (the previous one is kept as history) and
*& is committed, a licence that is not VALID is never stored (364).
*& Authorisation ZCA_OPS for area CA_OPS: 03 to check, 01 to install. No
*& business data is read or written.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
REPORT zca_ops_license_install.

PARAMETERS p_front RADIOBUTTON GROUP src DEFAULT 'X'.
PARAMETERS p_server RADIOBUTTON GROUP src.
PARAMETERS p_file TYPE string LOWER CASE OBLIGATORY.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    CONSTANTS gc_upload_filetype TYPE char10 VALUE 'ASC'.
    CONSTANTS gc_codepage_utf8 TYPE abap_encoding VALUE '4110'.
    CONSTANTS gc_subrc_eof TYPE i VALUE 4.

    METHODS install
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_lic_types=>ty_install_result
      RAISING
        zcx_ca_ops_error.

    "! The lines of the licence file (frontend or application server)
    METHODS read_file
      RETURNING
        VALUE(rt_lines) TYPE string_table
      RAISING
        zcx_ca_ops_error.

    METHODS read_server
      RETURNING
        VALUE(rt_lines) TYPE string_table
      RAISING
        zcx_ca_ops_error.

    "! The state of every module: one list line each
    METHODS show
      IMPORTING
        is_result TYPE zif_ca_ops_lic_types=>ty_install_result.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        DATA(ls_result) = install( ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " in background the job ends cancelled, never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    show( ls_result ).
    DATA(lv_modules) = lines( ls_result-install-modules ).
    IF ls_result-stored = abap_true.
      MESSAGE s362(zca_ops) WITH ls_result-install-license_id lv_modules ls_result-status-state.
    ELSEIF ls_result-status-state <> zif_ca_ops_lic_types=>gc_lic_state-valid.
      MESSAGE s364(zca_ops) WITH ls_result-install-license_id ls_result-status-state DISPLAY LIKE 'E'.
    ELSE.
      MESSAGE s363(zca_ops) WITH ls_result-install-license_id ls_result-status-state.
    ENDIF.
  ENDMETHOD.


  METHOD install.
    zcl_ca_ops_factory=>get_auth( )->check(
      iv_activity = COND #( WHEN p_test = abap_true THEN zif_ca_ops_auth=>gc_activity-display
                            ELSE zif_ca_ops_auth=>gc_activity-create )
      iv_area     = zif_ca_ops_types=>gc_param_area ).
    DATA(lv_content) = concat_lines_of( table = read_file( ) sep = cl_abap_char_utilities=>newline ).
    rs_result = zcl_ca_ops_factory=>get_license( )->install( iv_content   = lv_content
                                                             iv_file_name = p_file
                                                             iv_test_mode = p_test ).
    IF rs_result-stored = abap_true.
      " the licence and its history rows are one LUW of this report
      zcl_ca_ops_factory=>get_store( )->commit( ).
    ENDIF.
  ENDMETHOD.


  METHOD read_file.
    IF p_server = abap_true.
      rt_lines = read_server( ).
      RETURN.
    ENDIF.
    IF sy-batch = abap_true AND p_front = abap_true.
      " no frontend in a background job
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e361(zca_ops) WITH 'FRONTEND'.
    ENDIF.
    cl_gui_frontend_services=>gui_upload( EXPORTING  filename = p_file
                                                     filetype = gc_upload_filetype
                                                     codepage = gc_codepage_utf8
                                          CHANGING   data_tab = rt_lines
                                          EXCEPTIONS OTHERS   = 1 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e361(zca_ops) WITH 'UPLOAD'.
    ENDIF.
  ENDMETHOD.


  METHOD read_server.
    DATA lv_line TYPE string.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_path) = lo_params->get_param( zif_ca_ops_lic_types=>gc_param-file_path ).
    DATA(lv_logical) = lo_params->get_param( zif_ca_ops_lic_types=>gc_param-file_name ).
    IF lv_path IS INITIAL OR lv_logical IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e366(zca_ops) WITH zif_ca_ops_lic_types=>gc_param-file_path zif_ca_ops_lic_types=>gc_param-file_name.
    ENDIF.
    " directory traversal: a file name only, resolved in the logical path and authorised for READ
    DATA(lv_file) = zcl_ca_ops_file_path=>physical( is_logical   = VALUE #( path = CONV #( lv_path )
                                                                           file = CONV #( lv_logical ) )
                                                    iv_file_name = p_file
                                                    iv_activity  = zif_ca_ops_types=>gc_dataset_activity-read ).
    TRY.
        OPEN DATASET lv_file FOR INPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e361(zca_ops) WITH 'DATASET'.
        ENDIF.
        DO.
          CLEAR lv_line.
          READ DATASET lv_file INTO lv_line.
          DATA(lv_subrc) = sy-subrc.
          IF lv_subrc = 0 OR ( lv_subrc = gc_subrc_eof AND lv_line IS NOT INITIAL ).
            INSERT lv_line INTO TABLE rt_lines.
          ENDIF.
          IF lv_subrc <> 0.
            EXIT.
          ENDIF.
        ENDDO.
        CLOSE DATASET lv_file.
      CATCH cx_sy_file_open cx_sy_file_authority cx_sy_conversion_codepage cx_sy_file_io INTO DATA(lx_file).
        CLOSE DATASET lv_file.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e361(zca_ops) WITH 'DATASET'
          EXPORTING
            previous = lx_file.
    ENDTRY.
  ENDMETHOD.


  METHOD show.
    WRITE: / is_result-install-license_id, is_result-install-customer.
    WRITE: / is_result-status-state, is_result-status-detail, is_result-status-enforce.
    ULINE.
    WRITE: / TEXT-c01, 22 TEXT-c02, 34 TEXT-c03, 46 TEXT-c04, 58 TEXT-c05, 70 TEXT-c06, 82 TEXT-c07.
    ULINE.
    LOOP AT is_result-status-modules ASSIGNING FIELD-SYMBOL(<ls_module>).
      WRITE: / <ls_module>-module, 22 <ls_module>-state, 34 <ls_module>-valid_from, 46 <ls_module>-valid_to,
               58 <ls_module>-grace_to, 70 <ls_module>-days_left, 82 <ls_module>-runs.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
