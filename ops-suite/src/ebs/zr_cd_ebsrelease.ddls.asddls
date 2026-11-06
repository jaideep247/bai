@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Blocked line releases'
@Metadata.ignorePropagatedAnnotations: true
// EBS blocked-line release (design 6.2): request by one user, approval by a second
define root view entity ZR_CD_EbsRelease
  as select from zcd_ebs_release
{
      @EndUserText.label: 'Release ID'
  key release_uuid          as ReleaseUuid,
      @EndUserText.label: 'Line (statement/line)'
      object_key            as ObjectKey,
      @EndUserText.label: 'Check released'
      check_code            as CheckCode,
      @EndUserText.label: 'Company code'
      bukrs                 as CompanyCode,
      @EndUserText.label: 'Reason'
      reason                as Reason,
      @EndUserText.label: 'Evidence'
      evidence              as Evidence,
      @EndUserText.label: 'Status'
      status                as Status,
      @EndUserText.label: 'Requested by'
      requested_by          as RequestedBy,
      @EndUserText.label: 'Requested at'
      requested_at          as RequestedAt,
      @EndUserText.label: 'Decided by'
      approved_by           as ApprovedBy,
      @EndUserText.label: 'Decided at'
      approved_at           as ApprovedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at       as LastChangedAt
}
