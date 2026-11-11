@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model dimension texts'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PaymDimText
  as select from zca_ops_pmdim
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Language'
  key langu as Langu,
      @EndUserText.label: 'Dimension of the payment model'
  key dimension as Dimension,
      @EndUserText.label: 'Value (as the adapter delivers it)'
  key dim_value as DimValue,
      1 as SingletonID,
      @EndUserText.label: 'Text on cards'
      text as Text,
      @EndUserText.label: 'Display order'
      seq as Seq,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _OpsCfgAll
}
