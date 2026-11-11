@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry links'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['LinkId']
define view entity ZC_CA_Link
  as projection on ZR_CA_Link
{
  key LinkId,
      @Consumption.hidden: true
      SingletonID,
      LayerId,
      FromObject,
      ToObject,
      Cardinality,
      Quality,
      FallbackOf,
      Replaces,
      Active,
      Owner,
      VerifyRef,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
