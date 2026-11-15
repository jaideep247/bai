*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_license.intf.abap
*& Purpose:
*& Public API of the licence (docs/LICENSING.md): the state of the
*& installed vendor-signed licence and of every licensable module today,
*& the decision for one module under the enforcement LIC_ENFORCE (W warn
*& only, X refuse; CORE never refused), the modules a registered check
*& needs (its class, the catalogue package of its business process), the
*& gate of a module's entry point (a refused run is recorded and raised)
*& and the installation of a licence file (verified first). Obtained from
*& ZCL_CA_OPS_FACTORY=>GET_LICENSE (a new instance per call: the licence is
*& verified once per instance - once per run). Never touches business data.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence API</p>
INTERFACE zif_ca_ops_license
  PUBLIC.

  "! State of the licence and of every module of the module map today (verified once per instance)
  METHODS status
    RETURNING
      VALUE(rs_status) TYPE zif_ca_ops_lic_types=>ty_status.

  "! Decision for one module: allowed = abap_false only under LIC_ENFORCE = X for a module that is neither
  "! included, licensed, expiring nor in grace; an unknown module is treated as not licensed, CORE never refused
  METHODS decide
    IMPORTING
      iv_module          TYPE zif_ca_ops_lic_types=>ty_module
    RETURNING
      VALUE(rs_decision) TYPE zif_ca_ops_lic_types=>ty_decision.

  "! Module of a registered check class (blank = none: the class needs no module of its own)
  METHODS module_of_class
    IMPORTING
      iv_class         TYPE clike
    RETURNING
      VALUE(rv_module) TYPE zif_ca_ops_lic_types=>ty_module.

  "! Module of a catalogue process: the process's own module, else its package's (blank = none or unknown)
  METHODS module_of_cat_process
    IMPORTING
      iv_cat_process   TYPE clike
    RETURNING
      VALUE(rv_module) TYPE zif_ca_ops_lic_types=>ty_module.

  "! Module of a catalogue package (blank = unknown package: a customer layer needs no module)
  METHODS module_of_package
    IMPORTING
      iv_pkg_id        TYPE clike
    RETURNING
      VALUE(rv_module) TYPE zif_ca_ops_lic_types=>ty_module.

  "! The modules a registered check of an area needs: the module of its class and the module of the catalogue
  "! process its business process monitors (ZCA_OPS_PROC-CAT_PROCESS); empty = CORE only
  METHODS modules_of_check
    IMPORTING
      is_check          TYPE zif_ca_ops_chk_types=>ty_check
    RETURNING
      VALUE(rt_modules) TYPE zif_ca_ops_lic_types=>tt_module.

  "! Gate of a module's entry point (a report, an engine, an action). Allowed: returns the decision (warn = the
  "! caller logs message 353). Refused: the refusal is recorded as an aborted run of the area with one finding
  "! LICENSE_REFUSED (ZCL_CA_OPS_RUN_GUARD=>REFUSE_LICENSE, alerted) and message 352 is raised
  "! @parameter iv_entry | Name of the entry point for the message (report, class or action)
  "! @raising zcx_ca_ops_error | 352 the module is refused under LIC_ENFORCE = X
  METHODS gate
    IMPORTING
      iv_module          TYPE zif_ca_ops_lic_types=>ty_module
      iv_area            TYPE zif_ca_ops_types=>ty_area
      iv_entry           TYPE clike
    RETURNING
      VALUE(rs_decision) TYPE zif_ca_ops_lic_types=>ty_decision
    RAISING
      zcx_ca_ops_error.

  "! Verify a licence file (PEM or Base64 text of the signed data) on this system and, unless in test mode, store it
  "! as the active licence when its state is VALID (the previous licence is kept as history; the caller commits).
  "! A licence that is not VALID is never stored: rs_result-stored = abap_false and the status says why.
  "! @raising zcx_ca_ops_error | 361 the file is not readable, 365 the signature check could not run, 010 store
  METHODS install
    IMPORTING
      iv_content       TYPE string
      iv_file_name     TYPE clike OPTIONAL
      iv_test_mode     TYPE abap_bool DEFAULT abap_true
    RETURNING
      VALUE(rs_result) TYPE zif_ca_ops_lic_types=>ty_install_result
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
