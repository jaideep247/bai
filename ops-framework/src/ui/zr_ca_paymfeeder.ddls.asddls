@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Feeder systems of the payment model'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PaymFeeder
  as select from zca_ops_feeder
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Feeder system (source value)'
  key feeder as Feeder,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Deep link (https URL, placeholder {REF})'
      url_template as UrlTemplate,
      @EndUserText.label: 'Feeder reference shown in full (not sensitive)'
      ref_visible as RefVisible,
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
