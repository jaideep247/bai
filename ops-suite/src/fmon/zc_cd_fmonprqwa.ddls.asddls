@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PRISM payment requests handled manually'
@Metadata.allowExtensions: true
define root view entity ZC_CD_FmonPrqWa
  provider contract transactional_query
  as projection on ZR_CD_FmonPrqWa
{
  key WaUuid,
      RequestRef,
      Source,
      Reference,
      Reason,
      Status,
      HandledBy,
      HandledAt,
      LocalLastChangedAt,
      LastChangedAt
}
