@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Lookups (rule R21)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['LookupId']
define view entity ZC_CD_EbsLookup
  as projection on ZR_CD_EbsLookup
{
  key LookupId,
      @Consumption.hidden: true
      SingletonID,
      TableName,
      KeyField,
      KeyKind,
      KeyLength,
      StatusField,
      AllowedValues,
      NotFoundCode,
      StatusCode,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _EbsCfgAll : redirected to parent ZC_CD_EbsCfgAll
}
