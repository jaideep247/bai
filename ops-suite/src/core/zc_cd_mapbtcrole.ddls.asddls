@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank code roles (typed ZBTR)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Version', 'Usage', 'Scope', 'Scheme', 'Code', 'Family', 'SubFamily']
define view entity ZC_CD_MapBtcRole
  as projection on ZR_CD_MapBtcRole
{
  key Version,
  key Usage,
  key Scope,
  key Scheme,
  key Code,
  key Family,
  key SubFamily,
      @Consumption.hidden: true
      SingletonID,
      Role,
      CompareAmount,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}
