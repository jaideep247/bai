*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_alert_section.intf.abap
*& Purpose:
*& Plug-in of a consumer for its own section of the alert message: the
*& findings it owns are shown in its own table (HTML and text) instead of
*& the general findings table, and it may put an impact-first subject on a
*& finding-level message. Configured by class name in parameter
*& ALERT_SECTION_CLASS (area CA_OPS; blank = no section); created by the
*& alert router through ZCL_CA_OPS_FACTORY=>GET_PLUGIN and handed to the
*& alert policy. Pure logic: no database, no delivery.
*& Modification log:
*& 2026-11-10 | Initial version (framework ZCA_OPS: the consumer-specific table of the alert message,
*&            | formerly called by the alert policy directly, is a plug-in).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert message section</p>
"! A consumer's own table in the alert message for the findings it owns.
INTERFACE zif_ca_ops_alert_section
  PUBLIC.

  "! The finding belongs to this section (shown here, not in the general table)
  METHODS owns
    IMPORTING
      is_finding     TYPE zif_ca_ops_types=>ty_finding
    RETURNING
      VALUE(rv_owns) TYPE abap_bool.

  "! Subject of a finding-level message whose findings include owned ones (blank = the general subject)
  "! @parameter it_findings | the owned findings of the message
  METHODS subject
    IMPORTING
      it_findings       TYPE zif_ca_ops_types=>tt_finding
      iv_area           TYPE zif_ca_ops_types=>ty_area
      iv_severity       TYPE zif_ca_ops_types=>ty_severity
    RETURNING
      VALUE(rv_subject) TYPE zif_ca_ops_types=>ty_message.

  "! HTML of the section (escaped by the section; blank = nothing to show)
  METHODS html
    IMPORTING
      it_findings    TYPE zif_ca_ops_types=>tt_finding
    RETURNING
      VALUE(rv_html) TYPE string.

  "! Text version of the section (blank = nothing to show)
  METHODS text
    IMPORTING
      it_findings    TYPE zif_ca_ops_types=>tt_finding
    RETURNING
      VALUE(rv_text) TYPE string.

ENDINTERFACE.
