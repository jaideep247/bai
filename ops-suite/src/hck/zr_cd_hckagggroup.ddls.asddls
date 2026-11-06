@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expected groups'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckAggGroup
  as select from zcd_hck_agggrp
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      @EndUserText.label: 'Aggregate ID'
  key agg_id as AggId,
      @EndUserText.label: 'Group value'
  key group_value as GroupValue,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
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
      _HckCfgAll
}
