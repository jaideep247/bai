// Artifact: zc_cd_ebsasof.ddls.asddls
// Purpose: Consumption view of the EBS validation "as of" (header KPI and the "stale
//          validation" tile, service ZUI_CD_EBS_DASH): last completed EBS run, age, stale flag.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCA_PARAR = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation as of'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsAsOf
  provider contract transactional_query
  as projection on ZR_CD_EbsAsOf
{
  key PaymentEngineArea,
      RunId,
      RunVariant,
      AsOfAt,
      RunStartedAt,
      RunStatus,
      RunRag,
      RunLineCount,
      RunFindingCount,
      AgeMinutes,
      StaleAfterMinutes,
      IsStale,
      StaleCriticality
}
