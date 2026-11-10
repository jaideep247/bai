@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reconciliation clearing account sets'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckReconSet
  as select from zcd_hck_rcset
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Set ID'
  key set_id as SetId,
      1 as SingletonID,
      @EndUserText.label: 'Kind'
      kind as Kind,
      @EndUserText.label: 'Side'
      side as Side,
      @EndUserText.label: 'Company code'
      bukrs as Bukrs,
      @EndUserText.label: 'Hkont'
      hkont as Hkont,
      @EndUserText.label: 'Waers'
      waers as Waers,
      @EndUserText.label: 'House bank'
      hbkid as Hbkid,
      @EndUserText.label: 'Account ID'
      hktid as Hktid,
      @EndUserText.label: 'Invert bank sign (leg mapping)'
      invert_bank as InvertBank,
      @EndUserText.label: 'Compare bank with G/L'
      leg_bank as LegBank,
      @EndUserText.label: 'Compare G/L with payment engine control total'
      leg_fica as LegFica,
      @EndUserText.label: 'Tolerance'
      tolerance as Tolerance,
      @EndUserText.label: 'Tolerance set'
      tolerance_set as ToleranceSet,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Active'
      active as Active,
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
