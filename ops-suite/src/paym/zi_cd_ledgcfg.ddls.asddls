// Artifact: zi_cd_ledgcfg.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - the ledger whose journal lines every ledger view reads: parameter
//          EBS_GL_LEDGER of area CD_EBS of the parameter framework - the maintained value, else the
//          definition default, else the delivered '0L' (the leading ledger). One row (the area register
//          row of the area). CDS cannot call the parameter API, so the view reads the parameter framework's tables with
//          the API's resolution, read-only - the consumer's checks read the same parameter through the API, so the
//          drill-down and the stored results use one ledger.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
// VERIFY-ADT: coalesce over a CASE of CHAR fields, cast to CHAR 2 (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - ledger of the journal reads'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CD_LedgCfg
  as select from    zca_param_area as Area
    left outer join zca_param_def  as Def on  Def.area = Area.area
                                          and Def.name = 'EBS_GL_LEDGER'
    left outer join zca_param_val  as Val on  Val.area = Def.area
                                          and Val.name = Def.name
                                          and Val.numb = 1
{
  key cast( coalesce( case when Val.low is null or Val.low = '' then Def.default_value else Val.low end,
                      '0L' ) as abap.char( 2 ) ) as Ledger
}
where Area.area = 'CD_EBS'
