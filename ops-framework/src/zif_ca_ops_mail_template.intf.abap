*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_mail_template.intf.abap
*& Purpose:
*& Renderer of an alert e-mail from a template: the SAP e-mail templates
*& adapter (ZCL_CA_OPS_MAIL_TPL_SMTG) or the built-in layout
*& (ZCL_CA_OPS_MAIL_TPL_BUILTIN). A renderer fills the plain-text
*& placeholders of the template from the standard context keys
*& (ZIF_CA_OPS_TYPES=>TY_MAIL_HEADER); the table blocks stay as their tokens
*& and are put in by ZCL_CA_OPS_MAIL_COMPOSER after rendering.
*& Modification log:
*& 2026-11-10 | Initial version (alert e-mail templates, user decisions 2026-11-10).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert e-mail renderer</p>
INTERFACE zif_ca_ops_mail_template
  PUBLIC.

  "! The renderer can be used in this system (SMTG: the template API exists)
  METHODS is_available
    RETURNING
      VALUE(rv_available) TYPE abap_bool.

  "! The template exists and is active (renderer not available: abap_true - nothing to check)
  METHODS exists
    IMPORTING
      iv_template_id   TYPE zif_ca_ops_types=>ty_template_id
    RETURNING
      VALUE(rv_exists) TYPE abap_bool.

  "! Subject, HTML body and text body of the template, placeholders filled from the context
  "! @parameter iv_alert_id | key of the alert log row (data source by key, ZI_CA_OPS_ALERTMAILCTX)
  "! @raising zcx_ca_ops_error | template not found / inactive (071) or not rendered (072)
  METHODS render
    IMPORTING
      iv_template_id     TYPE zif_ca_ops_types=>ty_template_id
      is_context         TYPE zif_ca_ops_types=>ty_mail_context
      iv_alert_id        TYPE zif_ca_ops_types=>ty_run_id OPTIONAL
      iv_language        TYPE sylangu DEFAULT sy-langu
    RETURNING
      VALUE(rs_rendered) TYPE zif_ca_ops_types=>ty_mail_rendered
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
