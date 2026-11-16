@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank transaction codes (typed ZBTM)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Version', 'Scheme', 'Code', 'Family', 'SubFamily', 'Bank', 'Flow']
define view entity ZC_CD_MapBtcCode
  as projection on ZR_CD_MapBtcCode
{
  key Version,
  key Scheme,
  key Code,
  key Family,
  key SubFamily,
  key Bank,
  key Flow,
      @Consumption.hidden: true
      SingletonID,
      Category,
      RuleGroup,
      ExpCdi,
      PayMethod,
      PostingRule,
      ActionCode,
      Disposition,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}
