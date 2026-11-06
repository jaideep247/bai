@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Returns / NOC lots'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonLotCfg
  as select from zcd_fmon_lotcfg
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Interface ID'
  key iface_id as IfaceId,
      @EndUserText.label: 'Lot type'
  key lot_type as LotType,
      1 as SingletonID,
      @EndUserText.label: 'Header table'
      hdr_table as HdrTable,
      @EndUserText.label: 'Header lot field'
      hdr_lot_field as HdrLotField,
      @EndUserText.label: 'Header link field'
      hdr_link_field as HdrLinkField,
      @EndUserText.label: 'Item table'
      item_table as ItemTable,
      @EndUserText.label: 'Item lot field'
      item_lot_field as ItemLotField,
      @EndUserText.label: 'Item key field'
      item_key_field as ItemKeyField,
      @EndUserText.label: 'Item status field'
      item_status_field as ItemStatusField,
      @EndUserText.label: 'Item link field'
      item_link_field as ItemLinkField,
      @EndUserText.label: 'Link by'
      link_by as LinkBy,
      @EndUserText.label: 'Done values'
      done_values as DoneValues,
      @EndUserText.label: 'NOC SLA days'
      noc_sla_days as NocSlaDays,
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
      _FmonCfgAll
}
