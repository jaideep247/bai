// Artifact: zc_cd_docevtcube.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the ops suite - volumes of document changes (entity DocumentChangeCategory of
//          ZUI_CD_PAYM): cards of the business, managers and IT support pages (reversals / resets / re-clearings by
//          source, payment type, company code, house bank and day). Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Document-change model - volumes'
@Metadata.allowExtensions: true
define root view entity ZC_CD_DocEvtCube
  provider contract transactional_query
  as projection on ZR_CD_DocEvtCube
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
