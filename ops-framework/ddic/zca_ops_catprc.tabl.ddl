@EndUserText.label : 'Ops framework: process catalogue processes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_catprc {
  key mandt      : abap.clnt not null;
  // Catalogue process: one SAP standard process (or a customer's own); starts with the prefix of its package
  key process_id : abap.char(20) not null;
  pkg_id         : abap.char(10);
  description    : abap.char(60);
  // SAP component of the process (e.g. FI-CA, FS-CD, FI-BL, BC) - text, no logic
  component      : abap.char(10);
  // Dashboard card the process feeds (PAYMENTS, RECEIVABLES, DUNNING, INVOICING, ACCOUNTING, INSURANCE, ...)
  dash_card      : abap.char(20);
  // Business owner role (a role name, never a person) and the typical schedule (text)
  owner_role     : abap.char(40);
  schedule       : abap.char(60);
  // Delivered default when no activation row of ZCA_OPS_CATACT decides (product rows: blank, except a baseline
  // process every system runs - background jobs)
  dflt_active    : abap_boolean;
  // C confirmed, V a name of the definition is still a VERIFY item (VERIFY_REF)
  evidence       : abap.char(1);
  verify_ref     : abap.char(20);
  seq            : abap.int4;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Monitoring of a catalogue process: the business processes of ZCA_OPS_PROC with CAT_PROCESS = PROCESS_ID and
// their checks (ZCA_OPS_CHECK). Effective activation: ZI_CA_OpsCatProcEff / ZCL_CA_OPS_CATALOG.
