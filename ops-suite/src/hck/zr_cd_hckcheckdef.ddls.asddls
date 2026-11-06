@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Checks'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckCheckDef
  as select from zcd_hck_def
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Category'
      category as Category,
      @EndUserText.label: 'Class name'
      class_name as ClassName,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Sequence'
      seq as Seq,
      @EndUserText.label: 'Priority'
      priority as Priority,
      @EndUserText.label: 'Parameter 1'
      param1 as Param1,
      @EndUserText.label: 'Parameter 2'
      param2 as Param2,
      @EndUserText.label: 'Parameter 3'
      param3 as Param3,
      @EndUserText.label: 'Parameter 4'
      param4 as Param4,
      @EndUserText.label: 'Package size'
      package_size as PackageSize,
      @EndUserText.label: 'Timeout sec'
      timeout_sec as TimeoutSec,
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
