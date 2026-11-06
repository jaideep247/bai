@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank transaction codes'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_BtcMap
  as select from zcd_btc_map
  association to parent ZR_CD_EbsCfgAll as _EbsCfgAll on $projection.SingletonID = _EbsCfgAll.SingletonID
{
      @EndUserText.label: 'Scheme'
  key scheme as Scheme,
      @EndUserText.label: 'BTC code'
  key btc_code as BtcCode,
      @EndUserText.label: 'Bank key (blank = all banks)'
  key bank_key as BankKey,
      @EndUserText.label: 'Flow (D/C/*)'
  key flow_type as FlowType,
      1 as SingletonID,
      @EndUserText.label: 'Category'
      category as Category,
      @EndUserText.label: 'Rule group'
      rule_group as RuleGroup,
      @EndUserText.label: 'Expected direction'
      exp_cdi as ExpCdi,
      @EndUserText.label: 'Payment method'
      pay_method as PayMethod,
      @EndUserText.label: 'Posting rule'
      posting_rule as PostingRule,
      @EndUserText.label: 'Return reason'
      ret_reason as RetReason,
      @EndUserText.label: 'Action'
      action as ActionCode,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Disposition'
      disposition as Disposition,
      @EndUserText.label: 'Changed by (SM30)'
      changed_by as ChangedBy,
      @EndUserText.label: 'Changed at (SM30)'
      changed_at as ChangedAt,
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
