*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_lic_types.intf.abap
*& Purpose:
*& Types and constants of the licence (docs/LICENSING.md): licensable
*& modules (config/licensing/modules.json), the module map, the payload of
*& a vendor-signed licence file (asJSON under the name LICENSE), the result
*& of the signature check, the system identity, the states of the licence
*& and of each module, the decision for one module, the vendor's trust
*& anchor, parameters (prefix LIC_, area CA_OPS), check codes and the
*& messages 351-366 of ZCA_OPS. No logic.
*& Modification log:
*& 2026-11-15 | Initial version (licensing: vendor licence above the customer's activation).
*& 2026-11-15 | Module CASHOPS (payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence types</p>
INTERFACE zif_ca_ops_lic_types
  PUBLIC.

  TYPES ty_module     TYPE c LENGTH 20.
  TYPES ty_obj_kind   TYPE c LENGTH 4.
  TYPES ty_obj_name   TYPE c LENGTH 40.
  TYPES ty_text       TYPE c LENGTH 60.
  TYPES ty_state      TYPE c LENGTH 10.
  TYPES ty_license_id TYPE c LENGTH 40.
  TYPES ty_enforce    TYPE c LENGTH 1.
  TYPES tt_module     TYPE SORTED TABLE OF ty_module WITH UNIQUE KEY table_line.

  "! Licensable modules (config/licensing/modules.json; the gates name these constants - checked by
  "! tools/licensing.py). CORE is always included and never refused.
  CONSTANTS:
    BEGIN OF gc_module,
      core           TYPE ty_module VALUE 'CORE',
      control        TYPE ty_module VALUE 'CONTROL',
      onboard        TYPE ty_module VALUE 'ONBOARD',
      jobs           TYPE ty_module VALUE 'JOBS',
      response       TYPE ty_module VALUE 'RESPONSE',
      links          TYPE ty_module VALUE 'LINKS',
      catalogue_fica TYPE ty_module VALUE 'CATALOGUE_FICA',
      catalogue_fscd TYPE ty_module VALUE 'CATALOGUE_FSCD',
      catalogue_fsri TYPE ty_module VALUE 'CATALOGUE_FSRI',
      paymodel       TYPE ty_module VALUE 'PAYMODEL',
      breaks         TYPE ty_module VALUE 'BREAKS',
      flow           TYPE ty_module VALUE 'FLOW',
      "! FI-CA cash operations: payment file lifecycle (2026-11-15)
      cashops        TYPE ty_module VALUE 'CASHOPS',
    END OF gc_module.

  "! Kinds of rows of the module map (ZCL_CA_OPS_LIC_MAP, table ZCA_OPS_LICMOD)
  CONSTANTS:
    BEGIN OF gc_kind,
      module      TYPE ty_obj_kind VALUE 'MOD',
      check_class TYPE ty_obj_kind VALUE 'CLAS',
      package     TYPE ty_obj_kind VALUE 'PKG',
      process     TYPE ty_obj_kind VALUE 'PRC',
    END OF gc_kind.

  "! One row of the module map
  TYPES:
    BEGIN OF ty_map,
      obj_kind    TYPE ty_obj_kind,
      obj_name    TYPE ty_obj_name,
      module      TYPE ty_module,
      always      TYPE abap_bool,
      seq         TYPE i,
      description TYPE ty_text,
    END OF ty_map.
  TYPES tt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.

  "! State of the installed licence
  CONSTANTS:
    BEGIN OF gc_lic_state,
      "! Signature of the vendor, bound to this installation and system, for this product version
      valid     TYPE ty_state VALUE 'VALID',
      "! No licence installed (ZCA_OPS_LIC has no active row)
      missing   TYPE ty_state VALUE 'MISSING',
      "! Signature invalid, not by the vendor's certificate, or the content is not readable
      signature TYPE ty_state VALUE 'SIGNATURE',
      "! Another installation number or system (and client)
      binding   TYPE ty_state VALUE 'BINDING',
      "! Another product version
      version   TYPE ty_state VALUE 'VERSION',
    END OF gc_lic_state.

  "! State of a module today
  CONSTANTS:
    BEGIN OF gc_state,
      "! Always included (CORE)
      included   TYPE ty_state VALUE 'INCLUDED',
      licensed   TYPE ty_state VALUE 'LICENSED',
      "! Licensed, ends within LIC_WARN_DAYS: warning
      expiring   TYPE ty_state VALUE 'EXPIRING',
      "! Ended, within the grace days of the licence: warning, still runs
      grace      TYPE ty_state VALUE 'GRACE',
      "! Ended and the grace period too: refused under enforcement X
      expired    TYPE ty_state VALUE 'EXPIRED',
      "! Not in the licence, not yet valid, or no valid licence: refused under enforcement X
      unlicensed TYPE ty_state VALUE 'UNLICENSED',
    END OF gc_state.

  "! Parameter LIC_ENFORCE: W = warn only (default of this release), X = refuse
  CONSTANTS:
    BEGIN OF gc_enforce,
      warn   TYPE ty_enforce VALUE 'W',
      refuse TYPE ty_enforce VALUE 'X',
    END OF gc_enforce.

  "! Trust anchor of the vendor (product constants, set when the vendor's certificate is issued - a change is a
  "! modification of the product, visible in its version history): the signer's subject must be SUBJECT and, when
  "! CERT_SHA256 is not blank and SSF returns the signer certificate, its SHA-256 fingerprint (hex, upper case)
  CONSTANTS:
    BEGIN OF gc_vendor,
      product     TYPE string VALUE `ZCA_OPS`,
      subject     TYPE string VALUE `CN=ZCA_OPS LICENSING`,
      cert_sha256 TYPE string VALUE ``,
    END OF gc_vendor.

  "! Format of the payload this release reads
  CONSTANTS gc_format TYPE i VALUE 1.

  "! A system the licence is bound to (client blank = every client)
  TYPES:
    BEGIN OF ty_system,
      sid    TYPE c LENGTH 3,
      client TYPE c LENGTH 3,
    END OF ty_system.
  TYPES tt_system TYPE STANDARD TABLE OF ty_system WITH EMPTY KEY.

  "! A module the licence grants (dates YYYYMMDD)
  TYPES:
    BEGIN OF ty_grant,
      code       TYPE ty_module,
      valid_from TYPE c LENGTH 8,
      valid_to   TYPE c LENGTH 8,
    END OF ty_grant.
  TYPES tt_grant TYPE STANDARD TABLE OF ty_grant WITH EMPTY KEY.

  "! The signed content of a licence file: asJSON of this structure under the name LICENSE
  "! (tools/licensing/issue_license.py writes exactly these members)
  TYPES:
    BEGIN OF ty_payload,
      format        TYPE i,
      license_id    TYPE string,
      product       TYPE string,
      customer      TYPE string,
      installations TYPE string_table,
      systems       TYPE tt_system,
      version_from  TYPE string,
      version_to    TYPE string,
      modules       TYPE tt_grant,
      grace_days    TYPE i,
      issued_at     TYPE string,
    END OF ty_payload.

  "! Result of the signature check (SSF adapter ZIF_CA_OPS_LIC_PLATFORM)
  TYPES:
    BEGIN OF ty_verified,
      "! The signature is valid and the signer certificate is trusted by the PSE
      ok          TYPE abap_bool,
      "! The signed content (enveloped signature)
      payload     TYPE xstring,
      "! Subject (distinguished name) of the signer
      signer      TYPE string,
      "! SHA-256 fingerprint of the signer certificate (hex, upper case; blank when SSF does not return it)
      cert_sha256 TYPE string,
      "! Return code / result of SSF for the message (never shown as the only evidence)
      return_code TYPE string,
    END OF ty_verified.

  "! Identity of this system
  TYPES:
    BEGIN OF ty_system_id,
      installations TYPE string_table,
      sysid         TYPE c LENGTH 8,
      client        TYPE c LENGTH 3,
      version       TYPE string,
    END OF ty_system_id.

  "! The active licence as stored (ZCA_OPS_LIC)
  TYPES:
    BEGIN OF ty_stored,
      lic_uuid     TYPE sysuuid_x16,
      license_id   TYPE ty_license_id,
      content      TYPE string,
      file_name    TYPE string,
      installed_by TYPE syuname,
      installed_at TYPE timestampl,
    END OF ty_stored.

  "! Everything the decision needs (no database, no SSF: ZCL_CA_OPS_LIC_POLICY)
  TYPES:
    BEGIN OF ty_input,
      "! A licence is installed (else MISSING)
      installed TYPE abap_bool,
      verified  TYPE ty_verified,
      "! The payload could be read (else SIGNATURE: not the vendor's format)
      readable  TYPE abap_bool,
      payload   TYPE ty_payload,
      system    TYPE ty_system_id,
      today     TYPE d,
      warn_days TYPE i,
      enforce   TYPE ty_enforce,
      map       TYPE tt_map,
    END OF ty_input.

  "! State of one module today
  TYPES:
    BEGIN OF ty_module_state,
      module     TYPE ty_module,
      state      TYPE ty_state,
      valid_from TYPE d,
      valid_to   TYPE d,
      grace_to   TYPE d,
      days_left  TYPE i,
      "! May run under the enforcement in effect
      runs       TYPE abap_bool,
      "! Runs, but the state is to be reported (expiring, grace, or not covered under W)
      warn       TYPE abap_bool,
    END OF ty_module_state.
  TYPES tt_module_state TYPE SORTED TABLE OF ty_module_state WITH UNIQUE KEY module.

  "! State of the licence and of every module of the map
  TYPES:
    BEGIN OF ty_status,
      state      TYPE ty_state,
      license_id TYPE ty_license_id,
      customer   TYPE string,
      enforce    TYPE ty_enforce,
      grace_days TYPE i,
      "! Why the licence is not VALID (SSF return code, the system's identity, the version)
      detail     TYPE string,
      modules    TYPE tt_module_state,
    END OF ty_status.

  "! Decision for one module
  TYPES:
    BEGIN OF ty_decision,
      module    TYPE ty_module,
      state     TYPE ty_state,
      lic_state TYPE ty_state,
      allowed   TYPE abap_bool,
      warn      TYPE abap_bool,
    END OF ty_decision.

  "! Catalogue package / process of a business process (ZCA_OPS_PROC-CAT_PROCESS -> ZCA_OPS_CATPRC-PKG_ID)
  TYPES:
    BEGIN OF ty_process_package,
      process_id  TYPE c LENGTH 20,
      cat_process TYPE c LENGTH 20,
      pkg_id      TYPE c LENGTH 10,
    END OF ty_process_package.
  TYPES tt_process_package TYPE STANDARD TABLE OF ty_process_package WITH EMPTY KEY.

  "! A module row of an installed licence (ZCA_OPS_LICM, display of the dashboard)
  TYPES:
    BEGIN OF ty_lic_module,
      module     TYPE ty_module,
      valid_from TYPE d,
      valid_to   TYPE d,
    END OF ty_lic_module.
  TYPES tt_lic_module TYPE STANDARD TABLE OF ty_lic_module WITH EMPTY KEY.

  "! A licence to store (install report)
  TYPES:
    BEGIN OF ty_install,
      license_id    TYPE ty_license_id,
      customer      TYPE c LENGTH 80,
      state         TYPE ty_state,
      installations TYPE c LENGTH 120,
      systems       TYPE c LENGTH 120,
      version_from  TYPE c LENGTH 10,
      version_to    TYPE c LENGTH 10,
      grace_days    TYPE i,
      issued_at     TYPE c LENGTH 14,
      signer        TYPE c LENGTH 255,
      file_name     TYPE c LENGTH 255,
      content       TYPE string,
      modules       TYPE tt_lic_module,
    END OF ty_install.

  "! Result of an installation (report ZCA_OPS_LICENSE_INSTALL)
  TYPES:
    BEGIN OF ty_install_result,
      "! The status the licence file gives on this system
      status  TYPE ty_status,
      "! What is (or, in test mode, would be) stored
      install TYPE ty_install,
      "! Stored as the active licence (VALID and not test mode)
      stored  TYPE abap_bool,
      uuid    TYPE sysuuid_x16,
    END OF ty_install_result.

  "! Parameters (area CA_OPS, prefix LIC_)
  CONSTANTS:
    BEGIN OF gc_param,
      "! W warn only (default of this release), X refuse unlicensed modules
      enforce     TYPE zif_ca_ops_types=>ty_param_name VALUE 'LIC_ENFORCE',
      "! Days before the end of a module from which it is reported as expiring
      warn_days   TYPE zif_ca_ops_types=>ty_param_name VALUE 'LIC_WARN_DAYS',
      "! PSE of the SSF application that holds the vendor's certificate (STRUST)
      ssf_profile TYPE zif_ca_ops_types=>ty_param_name VALUE 'LIC_SSF_PROFILE',
      "! Logical path / file of a licence file on the application server (transaction FILE)
      file_path   TYPE zif_ca_ops_types=>ty_param_name VALUE 'LIC_FILE_PATH',
      file_name   TYPE zif_ca_ops_types=>ty_param_name VALUE 'LIC_FILE_NAME',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_default,
      enforce     TYPE ty_enforce VALUE 'W',
      warn_days   TYPE i VALUE 30,
      ssf_profile TYPE string VALUE `SAPZCAOPS.pse`,
    END OF gc_default.

  "! Findings of the licence (check ZCL_CA_OPS_CHK_LICENSE, the runner's gate)
  CONSTANTS:
    BEGIN OF gc_code,
      refused    TYPE zif_ca_ops_types=>ty_check_code VALUE 'LICENSE_REFUSED',
      unlicensed TYPE zif_ca_ops_types=>ty_check_code VALUE 'LICENSE_UNLICENSED',
      missing    TYPE zif_ca_ops_types=>ty_check_code VALUE 'LICENSE_MISSING',
      invalid    TYPE zif_ca_ops_types=>ty_check_code VALUE 'LICENSE_INVALID',
      expiring   TYPE zif_ca_ops_types=>ty_check_code VALUE 'LICENSE_EXPIRING',
      grace      TYPE zif_ca_ops_types=>ty_check_code VALUE 'LICENSE_GRACE',
      expired    TYPE zif_ca_ops_types=>ty_check_code VALUE 'LICENSE_EXPIRED',
    END OF gc_code.

  CONSTANTS:
    BEGIN OF gc_object_type,
      license TYPE zif_ca_ops_types=>ty_object_type VALUE 'LICENSE',
      module  TYPE zif_ca_ops_types=>ty_object_type VALUE 'LICMODULE',
    END OF gc_object_type.

  CONSTANTS gc_rule_id TYPE zif_ca_ops_types=>ty_rule_id VALUE 'LICENSE'.

  "! Messages of ZCA_OPS (350, the check of the configuration app, is ZIF_CA_OPS_CFG_TYPES=>GC_MSG-LICENSE_REFUSED)
  CONSTANTS:
    BEGIN OF gc_msg,
      check_refused TYPE zif_ca_ops_types=>ty_msgno VALUE '351',
      gate_refused  TYPE zif_ca_ops_types=>ty_msgno VALUE '352',
      unlicensed    TYPE zif_ca_ops_types=>ty_msgno VALUE '353',
      missing       TYPE zif_ca_ops_types=>ty_msgno VALUE '354',
      expiring      TYPE zif_ca_ops_types=>ty_msgno VALUE '355',
      grace         TYPE zif_ca_ops_types=>ty_msgno VALUE '356',
      expired       TYPE zif_ca_ops_types=>ty_msgno VALUE '357',
      signature     TYPE zif_ca_ops_types=>ty_msgno VALUE '358',
      binding       TYPE zif_ca_ops_types=>ty_msgno VALUE '359',
      version       TYPE zif_ca_ops_types=>ty_msgno VALUE '360',
      file_invalid  TYPE zif_ca_ops_types=>ty_msgno VALUE '361',
      installed     TYPE zif_ca_ops_types=>ty_msgno VALUE '362',
      verified      TYPE zif_ca_ops_types=>ty_msgno VALUE '363',
      not_installed TYPE zif_ca_ops_types=>ty_msgno VALUE '364',
      ssf_failed    TYPE zif_ca_ops_types=>ty_msgno VALUE '365',
      file_params   TYPE zif_ca_ops_types=>ty_msgno VALUE '366',
    END OF gc_msg.

ENDINTERFACE.
