@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Monitored files - manual status'
@Metadata.allowExtensions: true
define root view entity ZC_CD_FmonFile
  provider contract transactional_query
  as projection on ZR_CD_FmonFile
{
  key FileId,
      IfaceId,
      FileRef,
      Direction,
      FileName,
      BusinessDate,
      Stage,
      Outcome,
      UnprocessedCount,
      RecordCount,
      ControlTotal,
      LastEventAt,
      ChangedAt,
      ChangedBy
}
