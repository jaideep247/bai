*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lic_dao.clas.abap
*& Purpose:
*& Data access of the licence (ZIF_CA_OPS_LIC_DAO): reads the active
*& licence of ZCA_OPS_LIC (the stored file is verified again at every run,
*& never trusted as stored), the catalogue package of a catalogue process
*& and of the business processes of an area (ZCA_OPS_PROC, ZCA_OPS_CATPRC);
*& the installation of a verified licence: the previous active licence is
*& kept as history (not active, REPLACED_AT), the new one is inserted with
*& its module rows (ZCA_OPS_LICM) and the module catalogue of this release
*& is written for the dashboard (ZCA_OPS_LICMOD, replaced as a whole). The
*& only class that writes these tables; the caller commits. No business
*& table is read or written.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence data access</p>
CLASS zcl_ca_ops_lic_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_lic_dao.

ENDCLASS.



CLASS zcl_ca_ops_lic_dao IMPLEMENTATION.

  METHOD zif_ca_ops_lic_dao~get_active.
    " one active licence; should two be active after a manual change, the latest installed decides
    DATA lt_active TYPE STANDARD TABLE OF zif_ca_ops_lic_types=>ty_stored WITH EMPTY KEY.
    SELECT lic_uuid, license_id, content, file_name, installed_by, installed_at
      FROM zca_ops_lic
      WHERE active = @abap_true
      ORDER BY installed_at DESCENDING, lic_uuid DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_active
      UP TO 1 ROWS.
    rs_stored = VALUE #( lt_active[ 1 ] OPTIONAL ).
  ENDMETHOD.


  METHOD zif_ca_ops_lic_dao~get_process_packages.
    SELECT proc~process_id, proc~cat_process, cat~pkg_id
      FROM zca_ops_proc AS proc
        LEFT OUTER JOIN zca_ops_catprc AS cat ON cat~process_id = proc~cat_process
      WHERE proc~area        =  @iv_area
        AND proc~cat_process <> @space
      ORDER BY proc~process_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_packages.
  ENDMETHOD.


  METHOD zif_ca_ops_lic_dao~get_cat_package.
    DATA(lv_process) = CONV zif_ca_ops_lic_types=>ty_process_package-cat_process( iv_cat_process ).
    SELECT SINGLE pkg_id
      FROM zca_ops_catprc
      WHERE process_id = @lv_process
      INTO @rv_pkg_id.
  ENDMETHOD.


  METHOD zif_ca_ops_lic_dao~install.
    DATA lt_modules TYPE STANDARD TABLE OF zca_ops_licm WITH EMPTY KEY.
    DATA lt_catalogue TYPE STANDARD TABLE OF zca_ops_licmod WITH EMPTY KEY.

    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e001(zca_ops)
          EXPORTING
            previous = lx_uuid.
    ENDTRY.
    " history: the licence installed before stays, not active
    UPDATE zca_ops_lic SET active = @abap_false, replaced_at = @iv_now WHERE active = @abap_true.

    DATA(ls_licence) = VALUE zca_ops_lic( lic_uuid      = rv_uuid
                                          license_id    = is_install-license_id
                                          customer      = is_install-customer
                                          active        = abap_true
                                          state         = is_install-state
                                          installations = is_install-installations
                                          systems       = is_install-systems
                                          version_from  = is_install-version_from
                                          version_to    = is_install-version_to
                                          grace_days    = is_install-grace_days
                                          issued_at     = is_install-issued_at
                                          signer        = is_install-signer
                                          file_name     = is_install-file_name
                                          content       = is_install-content
                                          installed_by  = sy-uname
                                          installed_at  = iv_now ).
    INSERT zca_ops_lic FROM @ls_licence.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_LIC'.
    ENDIF.

    lt_modules = VALUE #( FOR ls_module IN is_install-modules
                          ( lic_uuid   = rv_uuid
                            module     = ls_module-module
                            valid_from = ls_module-valid_from
                            valid_to   = ls_module-valid_to ) ).
    IF lt_modules IS NOT INITIAL.
      INSERT zca_ops_licm FROM TABLE @lt_modules.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e010(zca_ops) WITH 'ZCA_OPS_LICM'.
      ENDIF.
    ENDIF.

    " the module catalogue of this release for the dashboard (the runtime reads ZCL_CA_OPS_LIC_MAP, never this)
    DELETE FROM zca_ops_licmod WHERE obj_kind <> @space.
    lt_catalogue = VALUE #( FOR ls_map IN it_map
                            ( obj_kind    = ls_map-obj_kind
                              obj_name    = ls_map-obj_name
                              module      = ls_map-module
                              always      = ls_map-always
                              seq         = ls_map-seq
                              description = ls_map-description ) ).
    IF lt_catalogue IS NOT INITIAL.
      INSERT zca_ops_licmod FROM TABLE @lt_catalogue.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e010(zca_ops) WITH 'ZCA_OPS_LICMOD'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
