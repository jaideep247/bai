@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Aggregate checks (no code)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_AggregateCheck
  as select from zca_ops_agg
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      @EndUserText.label: 'Aggregate ID (rule ID of the findings)'
  key agg_id as AggId,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Table (approved for the area)'
      tabname as Tabname,
      @EndUserText.label: 'Function (COUNT or AGE)'
      agg_func as AggFunc,
      @EndUserText.label: 'Date field (AGE counts from it)'
      date_field as DateField,
      @EndUserText.label: 'Minimum age (days)'
      min_age_days as MinAgeDays,
      @EndUserText.label: 'Window (days, 0 = none)'
      max_age_days as MaxAgeDays,
      @EndUserText.label: 'Time field (with the date field)'
      time_field as TimeField,
      @EndUserText.label: 'Company-code field (one result each)'
      bukrs_field as BukrsField,
      @EndUserText.label: 'Status field'
      status_field as StatusField,
      @EndUserText.label: 'Status operator (EQ, NE, IN)'
      status_op as StatusOp,
      @EndUserText.label: 'Status value(s)'
      status_value as StatusValue,
      @EndUserText.label: 'Condition field'
      cond_field as CondField,
      @EndUserText.label: 'Condition operator'
      cond_op as CondOp,
      @EndUserText.label: 'Condition value(s)'
      cond_value as CondValue,
      @EndUserText.label: 'Amber limit (rows or days, 0 = none)'
      amber as Amber,
      @EndUserText.label: 'Red limit (rows or days, 0 = none)'
      red as Red,
      @EndUserText.label: 'Check code of the findings'
      check_code as CheckCode,
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
