*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_license.clas.abap
*& Purpose:
*& The licence of the framework (ZIF_CA_OPS_LICENSE, docs/LICENSING.md):
*& reads the active licence file (ZCA_OPS_LIC through ZIF_CA_OPS_LIC_DAO),
*& verifies its signature with the vendor's certificate in the PSE of
*& LIC_SSF_PROFILE (ZIF_CA_OPS_LIC_PLATFORM, SSF) every time an instance is
*& first asked - the stored row is never trusted as stored -, reads the
*& payload (ZCL_CA_OPS_LIC_FILE), takes this system's identity, today
*& (ZCL_CA_OPS_FACTORY=>GET_CLOCK), LIC_WARN_DAYS and LIC_ENFORCE and lets
*& ZCL_CA_OPS_LIC_POLICY decide; the status is cached in the instance (one
*& instance per run: ZCL_CA_OPS_FACTORY=>GET_LICENSE). Modules of objects
*& come from the generated module map ZCL_CA_OPS_LIC_MAP (product code, not
*& configuration). The gate records a refused run (ZCL_CA_OPS_RUN_GUARD=>
*& REFUSE_LICENSE) and raises 352; installing stores a VALID licence only.
*& Never touches business data.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence</p>
CLASS zcl_ca_ops_license DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_license.

    "! @parameter io_dao      | Data access (default ZCL_CA_OPS_LIC_DAO)
    "! @parameter io_platform | SSF / system adapter (default ZCL_CA_OPS_LIC_PLATFORM)
    "! @parameter it_map      | Module map (default the generated ZCL_CA_OPS_LIC_MAP=>ROWS)
    METHODS constructor
      IMPORTING
        io_dao      TYPE REF TO zif_ca_ops_lic_dao OPTIONAL
        io_platform TYPE REF TO zif_ca_ops_lic_platform OPTIONAL
        it_map      TYPE zif_ca_ops_lic_types=>tt_map OPTIONAL.

  PRIVATE SECTION.
    "! Business processes of an area with their catalogue package (read once per area)
    TYPES:
      BEGIN OF ty_area_packages,
        area     TYPE zif_ca_ops_types=>ty_area,
        packages TYPE zif_ca_ops_lic_types=>tt_process_package,
      END OF ty_area_packages.
    TYPES tt_area_packages TYPE HASHED TABLE OF ty_area_packages WITH UNIQUE KEY area.

    DATA mo_dao TYPE REF TO zif_ca_ops_lic_dao.
    DATA mo_platform TYPE REF TO zif_ca_ops_lic_platform.
    DATA mt_map TYPE zif_ca_ops_lic_types=>tt_map.
    DATA ms_status TYPE zif_ca_ops_lic_types=>ty_status.
    DATA mv_evaluated TYPE abap_bool.
    DATA mt_area_packages TYPE tt_area_packages.

    "! What the decision needs except the file: system, today, parameters, map
    METHODS base_input
      RETURNING
        VALUE(rs_input) TYPE zif_ca_ops_lic_types=>ty_input.

    "! Signature check and payload of a licence file
    "! @raising zcx_ca_ops_error | 361 not readable, 365 SSF could not run
    METHODS read_file
      IMPORTING
        iv_content TYPE string
      CHANGING
        cs_input   TYPE zif_ca_ops_lic_types=>ty_input
      RAISING
        zcx_ca_ops_error.

    "! Module of a row of the map (blank = none)
    METHODS map_module
      IMPORTING
        iv_kind          TYPE zif_ca_ops_lic_types=>ty_obj_kind
        iv_name          TYPE clike
      RETURNING
        VALUE(rv_module) TYPE zif_ca_ops_lic_types=>ty_module.

    "! What is stored for a verified licence file
    METHODS install_row
      IMPORTING
        is_input          TYPE zif_ca_ops_lic_types=>ty_input
        is_status         TYPE zif_ca_ops_lic_types=>ty_status
        iv_content        TYPE string
        iv_file_name      TYPE clike
      RETURNING
        VALUE(rs_install) TYPE zif_ca_ops_lic_types=>ty_install.

ENDCLASS.



CLASS zcl_ca_ops_license IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_lic_dao( ) ).
    mo_platform = COND #( WHEN io_platform IS BOUND THEN io_platform ELSE NEW zcl_ca_ops_lic_platform( ) ).
    mt_map = COND #( WHEN it_map IS NOT INITIAL THEN it_map ELSE zcl_ca_ops_lic_map=>rows( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_license~status.
    IF mv_evaluated = abap_false.
      DATA(ls_input) = base_input( ).
      DATA(ls_stored) = mo_dao->get_active( ).
      ls_input-installed = xsdbool( ls_stored-lic_uuid IS NOT INITIAL ).
      IF ls_input-installed = abap_true.
        TRY.
            read_file( EXPORTING iv_content = ls_stored-content
                       CHANGING  cs_input   = ls_input ).
          CATCH zcx_ca_ops_error INTO DATA(lx_error).
            " a stored file that cannot be verified is not the vendor's licence (state SIGNATURE)
            CLEAR: ls_input-verified-ok, ls_input-readable.
            ls_input-verified-return_code = lx_error->get_text( ).
        ENDTRY.
      ENDIF.
      ms_status = zcl_ca_ops_lic_policy=>evaluate( ls_input ).
      mv_evaluated = abap_true.
    ENDIF.
    rs_status = ms_status.
  ENDMETHOD.


  METHOD zif_ca_ops_license~decide.
    rs_decision = zcl_ca_ops_lic_policy=>decide( is_status = zif_ca_ops_license~status( )
                                                 iv_module = iv_module ).
  ENDMETHOD.


  METHOD zif_ca_ops_license~module_of_class.
    rv_module = map_module( iv_kind = zif_ca_ops_lic_types=>gc_kind-check_class
                            iv_name = iv_class ).
  ENDMETHOD.


  METHOD zif_ca_ops_license~module_of_package.
    rv_module = map_module( iv_kind = zif_ca_ops_lic_types=>gc_kind-package
                            iv_name = iv_pkg_id ).
  ENDMETHOD.


  METHOD zif_ca_ops_license~module_of_cat_process.
    IF iv_cat_process IS INITIAL.
      RETURN.
    ENDIF.
    " a process licensed on its own first, else the module of its package
    rv_module = map_module( iv_kind = zif_ca_ops_lic_types=>gc_kind-process
                            iv_name = iv_cat_process ).
    IF rv_module IS INITIAL.
      rv_module = zif_ca_ops_license~module_of_package( mo_dao->get_cat_package( iv_cat_process ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_license~modules_of_check.
    DATA(lv_class_module) = zif_ca_ops_license~module_of_class( is_check-class_name ).
    IF lv_class_module IS NOT INITIAL AND lv_class_module <> zif_ca_ops_lic_types=>gc_module-core.
      INSERT lv_class_module INTO TABLE rt_modules.
    ENDIF.
    IF is_check-process_id IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE mt_area_packages ASSIGNING FIELD-SYMBOL(<ls_area>) WITH TABLE KEY area = is_check-area.
    IF sy-subrc <> 0.
      INSERT VALUE #( area     = is_check-area
                      packages = mo_dao->get_process_packages( is_check-area ) )
        INTO TABLE mt_area_packages ASSIGNING <ls_area>.
    ENDIF.
    READ TABLE <ls_area>-packages ASSIGNING FIELD-SYMBOL(<ls_package>) WITH KEY process_id = is_check-process_id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_process_module) = map_module( iv_kind = zif_ca_ops_lic_types=>gc_kind-process
                                          iv_name = <ls_package>-cat_process ).
    IF lv_process_module IS INITIAL.
      lv_process_module = zif_ca_ops_license~module_of_package( <ls_package>-pkg_id ).
    ENDIF.
    IF lv_process_module IS NOT INITIAL AND lv_process_module <> zif_ca_ops_lic_types=>gc_module-core.
      INSERT lv_process_module INTO TABLE rt_modules.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_license~gate.
    rs_decision = zif_ca_ops_license~decide( iv_module ).
    IF rs_decision-allowed = abap_true.
      RETURN.
    ENDIF.
    " visible: an aborted, red run of the area with one LICENSE_REFUSED finding, alerted
    zcl_ca_ops_run_guard=>refuse_license( iv_area     = iv_area
                                          is_decision = rs_decision
                                          iv_entry    = iv_entry ).
    RAISE EXCEPTION TYPE zcx_ca_ops_error
      MESSAGE e352(zca_ops) WITH iv_entry iv_module rs_decision-state.
  ENDMETHOD.


  METHOD zif_ca_ops_license~install.
    DATA(ls_input) = base_input( ).
    ls_input-installed = abap_true.
    read_file( EXPORTING iv_content = iv_content
               CHANGING  cs_input   = ls_input ).
    rs_result-status = zcl_ca_ops_lic_policy=>evaluate( ls_input ).
    rs_result-install = install_row( is_input     = ls_input
                                     is_status    = rs_result-status
                                     iv_content   = iv_content
                                     iv_file_name = iv_file_name ).
    IF iv_test_mode = abap_true OR rs_result-status-state <> zif_ca_ops_lic_types=>gc_lic_state-valid.
      RETURN.
    ENDIF.
    rs_result-uuid = mo_dao->install( is_install = rs_result-install
                                      it_map     = mt_map
                                      iv_now     = zcl_ca_ops_factory=>get_clock( )->now( ) ).
    rs_result-stored = abap_true.
    " the next question of this instance reads the new licence
    CLEAR: mv_evaluated, ms_status.
  ENDMETHOD.


  METHOD base_input.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    rs_input-today     = zcl_ca_ops_factory=>get_clock( )->today( ).
    rs_input-system    = mo_platform->system( ).
    rs_input-map       = mt_map.
    rs_input-warn_days = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                     iv_name    = zif_ca_ops_lic_types=>gc_param-warn_days
                                                     iv_default = zif_ca_ops_lic_types=>gc_default-warn_days ).
    rs_input-enforce   = to_upper( lo_params->get_param( iv_name    = zif_ca_ops_lic_types=>gc_param-enforce
                                                         iv_default = CONV #( zif_ca_ops_lic_types=>gc_default-enforce ) ) ).
  ENDMETHOD.


  METHOD read_file.
    DATA(lv_profile) = zcl_ca_ops_factory=>get_params( )->get_param(
                         iv_name    = zif_ca_ops_lic_types=>gc_param-ssf_profile
                         iv_default = zif_ca_ops_lic_types=>gc_default-ssf_profile ).
    cs_input-verified = mo_platform->verify( iv_signed  = zcl_ca_ops_lic_file=>der_of( iv_content )
                                             iv_profile = lv_profile ).
    IF cs_input-verified-ok = abap_false.
      RETURN.
    ENDIF.
    TRY.
        cs_input-payload  = zcl_ca_ops_lic_file=>payload_of( cs_input-verified-payload ).
        cs_input-readable = abap_true.
      CATCH zcx_ca_ops_error INTO DATA(lx_payload).
        " signed, but not the vendor's payload format: state SIGNATURE
        cs_input-verified-return_code = lx_payload->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD map_module.
    DATA(lv_name) = to_upper( condense( CONV string( iv_name ) ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE mt_map ASSIGNING FIELD-SYMBOL(<ls_map>) WITH KEY obj_kind = iv_kind obj_name = lv_name.
    IF sy-subrc = 0.
      rv_module = <ls_map>-module.
    ENDIF.
  ENDMETHOD.


  METHOD install_row.
    DATA lt_systems TYPE string_table.
    LOOP AT is_input-payload-systems ASSIGNING FIELD-SYMBOL(<ls_system>).
      INSERT condense( |{ <ls_system>-sid }/{ <ls_system>-client }| ) INTO TABLE lt_systems.
    ENDLOOP.
    rs_install = VALUE #( license_id    = is_input-payload-license_id
                          customer      = is_input-payload-customer
                          state         = is_status-state
                          installations = concat_lines_of( table = is_input-payload-installations sep = `,` )
                          systems       = concat_lines_of( table = lt_systems sep = `,` )
                          version_from  = is_input-payload-version_from
                          version_to    = is_input-payload-version_to
                          grace_days    = is_input-payload-grace_days
                          issued_at     = is_input-payload-issued_at
                          signer        = is_input-verified-signer
                          file_name     = iv_file_name
                          content       = iv_content
                          modules       = VALUE #( FOR ls_grant IN is_input-payload-modules
                                                   ( module     = ls_grant-code
                                                     valid_from = zcl_ca_ops_lic_policy=>to_date( ls_grant-valid_from )
                                                     valid_to   = zcl_ca_ops_lic_policy=>to_date( ls_grant-valid_to ) ) ) ).
  ENDMETHOD.

ENDCLASS.
