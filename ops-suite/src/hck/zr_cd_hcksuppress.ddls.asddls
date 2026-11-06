@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Health check suppressions'
@Metadata.ignorePropagatedAnnotations: true
// Health-check suppression (design 6.3): known findings muted until a date
define root view entity ZR_CD_HckSuppress
  as select from zcd_hck_suppress
{
      @EndUserText.label: 'Suppression ID'
  key suppress_uuid         as SuppressUuid,
      @EndUserText.label: 'Check'
      check_id              as CheckId,
      @EndUserText.label: 'Object pattern (blank = all)'
      key_pattern           as KeyPattern,
      @EndUserText.label: 'Company code (blank = all)'
      bukrs                 as CompanyCode,
      @EndUserText.label: 'Valid from'
      valid_from            as ValidFrom,
      @EndUserText.label: 'Valid to'
      valid_to              as ValidTo,
      @EndUserText.label: 'Reason'
      reason                as Reason,
      @EndUserText.label: 'Status'
      status                as Status,
      @EndUserText.label: 'Created by'
      created_by            as CreatedBy,
      @EndUserText.label: 'Created at'
      created_at            as CreatedAt,
      @EndUserText.label: 'Approved by'
      approved_by           as ApprovedBy,
      @EndUserText.label: 'Approved at'
      approved_at           as ApprovedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at       as LastChangedAt
}
