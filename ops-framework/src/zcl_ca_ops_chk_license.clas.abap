*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_license.clas.abap
*& Purpose:
*& Registered check of the licence (module CORE, never refused; registry
*& row CA_OPS / LICENSE, group MORNING): the state of the installed licence
*& as owned exceptions with an SLA, so the existing alert rules route them
*& and they resolve themselves once the licence is renewed (complete check,
*& reconcile by check). No licence installed (354), a licence that is not
*& the vendor's, of another system or another product version (358-360):
*& one finding; per licensed module that ends within LIC_WARN_DAYS (355),
*& is in its grace period (356) or expired after it (357): one finding.
*& Severity W while LIC_ENFORCE = W; E for what is refused under X. A
*& module the licence never granted is no finding (nothing was bought).
*& Reads only through ZIF_CA_OPS_LICENSE.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence state check</p>
CLASS zcl_ca_ops_chk_license DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    "! Object key of the licence when none is installed
    CONSTANTS gc_no_licence TYPE zif_ca_ops_types=>ty_object_key VALUE 'NONE'.

    "! Finding of the licence itself (missing or not valid)
    METHODS licence_finding
      IMPORTING
        is_status         TYPE zif_ca_ops_lic_types=>ty_status
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Finding of one module that ends soon, is in grace or expired (initial when none is due)
    METHODS module_finding
      IMPORTING
        is_status         TYPE zif_ca_ops_lic_types=>ty_status
        is_module         TYPE zif_ca_ops_lic_types=>ty_module_state
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! W while the enforcement is warn only, E where the module (or every module) is refused
    CLASS-METHODS severity
      IMPORTING
        is_status           TYPE zif_ca_ops_lic_types=>ty_status
        iv_refused         TYPE abap_bool
      RETURNING
        VALUE(rv_severity) TYPE zif_ca_ops_types=>ty_severity.

ENDCLASS.



CLASS zcl_ca_ops_chk_license IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA(ls_status) = zcl_ca_ops_factory=>get_license( )->status( ).
    rs_result-item_count = lines( ls_status-modules ).
    IF ls_status-state <> zif_ca_ops_lic_types=>gc_lic_state-valid.
      INSERT licence_finding( ls_status ) INTO TABLE rs_result-findings.
      RETURN.
    ENDIF.
    LOOP AT ls_status-modules ASSIGNING FIELD-SYMBOL(<ls_module>).
      DATA(ls_finding) = module_finding( is_status = ls_status
                                         is_module = <ls_module> ).
      IF ls_finding IS NOT INITIAL.
        INSERT ls_finding INTO TABLE rs_result-findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD licence_finding.
    rs_finding = VALUE #( object_type = zif_ca_ops_lic_types=>gc_object_type-license
                          object_key  = COND #( WHEN is_status-license_id IS INITIAL THEN gc_no_licence
                                                ELSE is_status-license_id )
                          rule_id     = zif_ca_ops_lic_types=>gc_rule_id
                          severity    = severity( is_status  = is_status
                                                  iv_refused = abap_true )
                          action      = zif_ca_ops_types=>gc_action-exception
                          reference   = is_status-state ).
    CASE is_status-state.
      WHEN zif_ca_ops_lic_types=>gc_lic_state-missing.
        rs_finding-check_code = zif_ca_ops_lic_types=>gc_code-missing.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_lic_types=>gc_msg-missing ).
      WHEN zif_ca_ops_lic_types=>gc_lic_state-binding.
        rs_finding-check_code = zif_ca_ops_lic_types=>gc_code-invalid.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_lic_types=>gc_msg-binding
                                                       iv_v1    = is_status-license_id
                                                       iv_v2    = is_status-detail ).
      WHEN zif_ca_ops_lic_types=>gc_lic_state-version.
        rs_finding-check_code = zif_ca_ops_lic_types=>gc_code-invalid.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_lic_types=>gc_msg-version
                                                       iv_v1    = is_status-license_id
                                                       iv_v2    = is_status-detail ).
      WHEN OTHERS.
        rs_finding-check_code = zif_ca_ops_lic_types=>gc_code-invalid.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_lic_types=>gc_msg-signature
                                                       iv_v1    = is_status-license_id
                                                       iv_v2    = is_status-detail ).
    ENDCASE.
  ENDMETHOD.


  METHOD module_finding.
    DATA lv_msgno TYPE zif_ca_ops_types=>ty_msgno.
    DATA lv_code TYPE zif_ca_ops_types=>ty_check_code.
    DATA lv_v4 TYPE string.

    CASE is_module-state.
      WHEN zif_ca_ops_lic_types=>gc_state-expiring.
        lv_msgno = zif_ca_ops_lic_types=>gc_msg-expiring.
        lv_code  = zif_ca_ops_lic_types=>gc_code-expiring.
        lv_v4    = |{ is_module-days_left }|.
      WHEN zif_ca_ops_lic_types=>gc_state-grace.
        lv_msgno = zif_ca_ops_lic_types=>gc_msg-grace.
        lv_code  = zif_ca_ops_lic_types=>gc_code-grace.
        lv_v4    = |{ is_module-grace_to DATE = ISO }|.
      WHEN zif_ca_ops_lic_types=>gc_state-expired.
        lv_msgno = zif_ca_ops_lic_types=>gc_msg-expired.
        lv_code  = zif_ca_ops_lic_types=>gc_code-expired.
        lv_v4    = |{ is_module-grace_to DATE = ISO }|.
      WHEN OTHERS.
        " included, licensed, or never granted: nothing to report
        RETURN.
    ENDCASE.
    rs_finding = VALUE #( object_type = zif_ca_ops_lic_types=>gc_object_type-module
                          object_key  = is_module-module
                          rule_id     = zif_ca_ops_lic_types=>gc_rule_id
                          check_code  = lv_code
                          severity    = severity( is_status  = is_status
                                                  iv_refused = xsdbool( is_module-runs = abap_false ) )
                          action      = zif_ca_ops_types=>gc_action-exception
                          reference   = is_status-license_id
                          business_date = is_module-valid_to
                          message     = zcl_ca_ops_util=>text( iv_msgno = lv_msgno
                                                               iv_v1    = is_module-module
                                                               iv_v2    = is_status-license_id
                                                               iv_v3    = |{ is_module-valid_to DATE = ISO }|
                                                               iv_v4    = lv_v4 ) ).
  ENDMETHOD.


  METHOD severity.
    rv_severity = COND #( WHEN iv_refused = abap_true
                               AND is_status-enforce = zif_ca_ops_lic_types=>gc_enforce-refuse
                          THEN zif_ca_ops_types=>gc_severity-error
                          ELSE zif_ca_ops_types=>gc_severity-warning ).
  ENDMETHOD.

ENDCLASS.
