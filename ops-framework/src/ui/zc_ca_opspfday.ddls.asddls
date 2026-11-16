// Artifact: zc_ca_opspfday.ddls.asddls
// Purpose: Payment file lifecycle - consumption view of the expected versus observed per file type and business date (list of service ZUI_CA_OPS_PAYFILE). Read access: DCL ZC_CA_OPSPFDAY.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment files expected per day'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsPfDay
  provider contract transactional_query
  as projection on ZR_CA_OpsPfDay
{
  key Area,
  key FileType,
  key BusinessDate,
      DayKind,
      Expected,
      Observed,
      Result,
      ResultCriticality,
      Reason,
      SourceAsOf,
      Watermark,
      Completeness,
      EvaluatedAt,
      LastValidResult,
      LastValidAt
}
