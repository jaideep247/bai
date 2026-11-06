@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Health check suppressions'
@Metadata.allowExtensions: true
define root view entity ZC_CD_HckSuppress
  provider contract transactional_query
  as projection on ZR_CD_HckSuppress
{
  key SuppressUuid,
      CheckId,
      KeyPattern,
      CompanyCode,
      ValidFrom,
      ValidTo,
      Reason,
      Status,
      CreatedBy,
      CreatedAt,
      ApprovedBy,
      ApprovedAt,
      LocalLastChangedAt,
      LastChangedAt
}
