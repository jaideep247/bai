@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment lifecycle stages'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_PayStage
  as select from zcd_ops_paystage
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Stage'
  key stage as Stage,
      1 as SingletonID,
      @EndUserText.label: 'Sequence'
      seq as Seq,
      @EndUserText.label: 'Label of the stage'
      label as Label,
      @EndUserText.label: 'Counted from (PAYRUN / REQUEST)'
      source as Source,
      @EndUserText.label: 'Payment status (PAYRUN) / worklist outcome or stage (REQUEST)'
      match_value as MatchValue,
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
      _OpsCfgAll
}
