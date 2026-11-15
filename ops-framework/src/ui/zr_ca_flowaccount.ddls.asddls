@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow accounts by role'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_FlowAccount
  as select from zca_ops_flwacc
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Account flow'
  key flow_id as FlowId,
      @EndUserText.label: 'Account (column of the dashboard)'
  key flow_acct as FlowAcct,
      1 as SingletonID,
      @EndUserText.label: 'Role (RECEIVABLE, PAYABLE, OUTSIDE, CLEARING, ...)'
      role as Role,
      @EndUserText.label: 'Company code'
      bukrs as Bukrs,
      @EndUserText.label: 'Currency (blank = every currency)'
      currency as Currency,
      @EndUserText.label: 'G/L account (or first of a range)'
      hkont_from as HkontFrom,
      @EndUserText.label: 'Last G/L account of the range (blank = one)'
      hkont_to as HkontTo,
      @EndUserText.label: 'Lines from (G journal, F FI-CA documents)'
      line_source as LineSource,
      @EndUserText.label: 'Display order'
      seq as Seq,
      @EndUserText.label: 'Accounted for by class (blank = not evaluated)'
      eval_class as EvalClass,
      @EndUserText.label: 'Tile (TRANSIT, CLARIFY, OPEN, BANK)'
      eval_category as EvalCategory,
      @EndUserText.label: 'Description'
      description as Description,
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
