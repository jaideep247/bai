@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank transaction codes'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Scheme', 'BtcCode', 'BankKey', 'FlowType']
define view entity ZC_CD_BtcMap
  as projection on ZR_CD_BtcMap
{
  key Scheme,
  key BtcCode,
  key BankKey,
  key FlowType,
      @Consumption.hidden: true
      SingletonID,
      Category,
      RuleGroup,
      ExpCdi,
      PayMethod,
      PostingRule,
      RetReason,
      ActionCode,
      Active,
      Description,
      Disposition,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _EbsCfgAll : redirected to parent ZC_CD_EbsCfgAll
}
