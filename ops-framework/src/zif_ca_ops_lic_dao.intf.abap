*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_lic_dao.intf.abap
*& Purpose:
*& Data access of the licence: the active licence (ZCA_OPS_LIC), the
*& catalogue package of a catalogue process and of the business processes
*& of an area (ZCA_OPS_PROC -> ZCA_OPS_CATPRC), and the installation of a
*& new licence (the previous one is kept as history, the module rows and
*& the module catalogue of the dashboard are written - ZCA_OPS_LICM,
*& ZCA_OPS_LICMOD). Only ZCL_CA_OPS_LIC_DAO writes these tables; nothing
*& else of the framework or of business data is written.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence data access</p>
INTERFACE zif_ca_ops_lic_dao
  PUBLIC.

  "! The active licence (initial when none is installed)
  METHODS get_active
    RETURNING
      VALUE(rs_stored) TYPE zif_ca_ops_lic_types=>ty_stored.

  "! Business processes of an area that monitor a catalogue process, with that process's package
  METHODS get_process_packages
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_packages) TYPE zif_ca_ops_lic_types=>tt_process_package.

  "! Package of a catalogue process (blank = unknown process)
  METHODS get_cat_package
    IMPORTING
      iv_cat_process   TYPE clike
    RETURNING
      VALUE(rv_pkg_id) TYPE zif_ca_ops_lic_types=>ty_process_package-pkg_id.

  "! Store a verified licence as the active one: the previous active row is kept (REPLACED_AT, not active), the
  "! module rows of the new licence and the module catalogue of the dashboard are written. The caller commits.
  "! @raising zcx_ca_ops_error | 010 / 011 insert or update failed
  METHODS install
    IMPORTING
      is_install       TYPE zif_ca_ops_lic_types=>ty_install
      it_map           TYPE zif_ca_ops_lic_types=>tt_map
      iv_now           TYPE timestampl
    RETURNING
      VALUE(rv_uuid)   TYPE sysuuid_x16
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
