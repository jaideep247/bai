@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Blocked line releases'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsRelease
  provider contract transactional_query
  as projection on ZR_CD_EbsRelease
{
  key ReleaseUuid,
      ObjectKey,
      CheckCode,
      CompanyCode,
      Reason,
      Evidence,
      Status,
      RequestedBy,
      RequestedAt,
      ApprovedBy,
      ApprovedAt,
      LocalLastChangedAt,
      LastChangedAt
}
