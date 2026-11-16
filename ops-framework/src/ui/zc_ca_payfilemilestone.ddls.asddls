@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file milestones'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FileType', 'Milestone']
define view entity ZC_CA_PayFileMilestone
  as projection on ZR_CA_PayFileMilestone
{
  key Area,
  key FileType,
  key Milestone,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Required,
      DueKind,
      DueTime,
      DayOffset,
      Basis,
      OffsetMin,
      GraceMin,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}
