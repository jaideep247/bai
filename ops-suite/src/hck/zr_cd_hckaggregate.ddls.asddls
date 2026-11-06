@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Generic aggregates'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckAggregate
  as select from zcd_hck_agg
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      @EndUserText.label: 'Aggregate ID'
  key agg_id as AggId,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Table'
      tabname as Tabname,
      @EndUserText.label: 'Aggregate function'
      agg_func as AggFunc,
      @EndUserText.label: 'Sum field'
      sum_field as SumField,
      @EndUserText.label: 'Date field'
      date_field as DateField,
      @EndUserText.label: 'Date mode'
      date_mode as DateMode,
      @EndUserText.label: 'Age days minimum'
      age_days_min as AgeDaysMin,
      @EndUserText.label: 'Group field'
      group_field as GroupField,
      @EndUserText.label: 'Condition 1 field'
      cond1_field as Cond1Field,
      @EndUserText.label: 'Condition 1 operator'
      cond1_op as Cond1Op,
      @EndUserText.label: 'Condition 1 value'
      cond1_value as Cond1Value,
      @EndUserText.label: 'Condition 2 field'
      cond2_field as Cond2Field,
      @EndUserText.label: 'Condition 2 operator'
      cond2_op as Cond2Op,
      @EndUserText.label: 'Condition 2 value'
      cond2_value as Cond2Value,
      @EndUserText.label: 'Condition 3 field'
      cond3_field as Cond3Field,
      @EndUserText.label: 'Condition 3 operator'
      cond3_op as Cond3Op,
      @EndUserText.label: 'Condition 3 value'
      cond3_value as Cond3Value,
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
