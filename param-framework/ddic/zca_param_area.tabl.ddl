// Parameter areas: one row per team / application area that owns parameters.
// Delivery class C (customizing), table logging on (SCU3), fully buffered.
// Maintained in SM30 / SPRO (view cluster ZCA_PARAM_VC); history in SCU3 and the customizing requests.
@EndUserText.label : 'Parameter framework: areas'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_param_area {
  key client            : abap.clnt not null;
  key area              : zca_param_area_id not null;
  description           : zca_param_descr;
  owner_team            : zca_param_owner;
  active                : zca_param_active;
}
