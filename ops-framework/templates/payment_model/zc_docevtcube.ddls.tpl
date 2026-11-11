// Artifact: zc_{{p}}_docevtcube.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the {{CONSUMER}} - volumes of document changes (entity DocumentChangeCategory of
//          {{SERVICE}}): cards of the business, managers and IT support pages (reversals / resets / re-clearings by
//          source, payment type, company code, house bank and day). Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Document-change model - volumes'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_DocEvtCube
  provider contract transactional_query
  as projection on ZR_{{P}}_DocEvtCube
{
  key EventDate,
  key EventType,
  key EventSource,
  key CompanyCode,
  key Source,
  key MethodClass,
  key HouseBank,
  key Currency,
      OpsArea,
      @Aggregation.default: #SUM
      EventCount,
      @Aggregation.default: #SUM
      PaymentCount,
      @Aggregation.default: #SUM
      PaymentAmount
}
