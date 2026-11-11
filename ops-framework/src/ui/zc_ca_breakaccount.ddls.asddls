@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis clearing accounts'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'AcctId']
define view entity ZC_CA_BreakAccount
  as projection on ZR_CA_BreakAccount
{
  key Area,
  key AcctId,
      @Consumption.hidden: true
      SingletonID,
      Bukrs,
      Hkont,
      Ledger,
      ProcessId,
      LookbackDays,
      ForwardDays,
      MaxGroups,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
