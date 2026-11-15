@EndUserText.label : 'Ops framework: modules of a licence'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_licm {
  key mandt    : abap.clnt not null;
  // Licence of ZCA_OPS_LIC
  key lic_uuid : sysuuid_x16 not null;
  // Licensable module (config/licensing/modules.json) the licence grants
  key module   : abap.char(20) not null;
  valid_from   : abap.dats;
  valid_to     : abap.dats;
}
// Display copy of the signed payload for the dashboard (ZC_CA_OpsLicModule); the runtime decides from the verified
// file of ZCA_OPS_LIC, never from these rows. Written only by ZCL_CA_OPS_LIC_DAO at installation.
