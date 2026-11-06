@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'House bank accounts'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HouseBankAcct
  as select from zcd_ebs_acct
  association to parent ZR_CD_EbsCfgAll as _EbsCfgAll on $projection.SingletonID = _EbsCfgAll.SingletonID
{
      @EndUserText.label: 'Company code'
  key bukrs as Bukrs,
      @EndUserText.label: 'House bank'
  key hbkid as Hbkid,
      @EndUserText.label: 'Account ID'
  key hktid as Hktid,
      1 as SingletonID,
      @EndUserText.label: 'Account number'
      account_no as AccountNo,
      @EndUserText.label: 'Bank key (blank = all banks)'
      bank_key as BankKey,
      @EndUserText.label: 'Format'
      format as Format,
      @EndUserText.label: 'Flow default'
      flow_default as FlowDefault,
      @EndUserText.label: 'Currency'
      currency as Currency,
      @EndUserText.label: 'G/L account'
      gl_account as GlAccount,
      @EndUserText.label: 'Active'
      active as Active,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _EbsCfgAll
}
