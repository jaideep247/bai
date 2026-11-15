@EndUserText.label : 'Ops framework: licence module catalogue'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_licmod {
  key mandt    : abap.clnt not null;
  // MOD module, CLAS registered check class, PKG catalogue package, PRC catalogue process
  key obj_kind : abap.char(4) not null;
  key obj_name : abap.char(40) not null;
  module       : abap.char(20);
  // X = always included, never refused (CORE)
  always       : abap_boolean;
  seq          : abap.int4;
  description  : abap.char(60);
}
// The module map of this release (generated class ZCL_CA_OPS_LIC_MAP), written at every licence installation for the
// dashboard (ZC_CA_OpsLicModule). The runtime reads the generated class, never this table.
