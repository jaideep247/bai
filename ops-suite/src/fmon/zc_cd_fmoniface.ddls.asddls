@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interfaces'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['IfaceId']
define view entity ZC_CD_FmonIface
  as projection on ZR_CD_FmonIface
{
  key IfaceId,
      @Consumption.hidden: true
      SingletonID,
      Direction,
      FileType,
      SourceSys,
      TargetSys,
      PayMethod,
      Lob,
      BankKey,
      NamePattern,
      MinBytes,
      MaxBytes,
      AckExpected,
      AckLevel,
      Owner,
      Active,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}
