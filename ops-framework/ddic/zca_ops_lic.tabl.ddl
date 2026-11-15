@EndUserText.label : 'Ops framework: installed licences'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_lic {
  key mandt     : abap.clnt not null;
  // One installed vendor licence file (report ZCA_OPS_LICENSE_INSTALL); written only by ZCL_CA_OPS_LIC_DAO
  key lic_uuid  : sysuuid_x16 not null;
  license_id    : abap.char(40);
  customer      : abap.char(80);
  // X = the active licence (one at a time); the rows before it are history (REPLACED_AT)
  active        : abap_boolean;
  // State when installed (VALID - only valid licences are stored); the runtime verifies CONTENT again every run
  state         : abap.char(10);
  // Installation numbers and systems (SID/client) the licence is bound to, comma lists (display)
  installations : abap.char(120);
  systems       : abap.char(120);
  version_from  : abap.char(10);
  version_to    : abap.char(10);
  grace_days    : abap.int4;
  issued_at     : abap.char(14);
  // Subject of the signer certificate as SSF reported it
  signer        : abap.char(255);
  file_name     : abap.char(255);
  // The licence file as installed (PEM text of the PKCS#7 signed data): the only content the runtime trusts, after
  // its signature check
  content       : abap.string(0);
  installed_by  : syuname;
  installed_at  : timestampl;
  replaced_at   : timestampl;
}
// Read by ZCL_CA_OPS_LIC_DAO and the dashboard ZI_CA_OpsLicCfg / ZC_CA_OpsLicense. Never purged (licence history).
