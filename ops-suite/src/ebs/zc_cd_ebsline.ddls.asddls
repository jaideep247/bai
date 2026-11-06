// Artifact: zc_cd_ebsline.ddls.asddls
// Purpose: Consumption view of the statement lines (service ZUI_CD_EBS_DASH): drill-down from the statement,
//          chart "lines by BAI code", drill-down to the open findings and the returns / NOC
//          lot items of the line.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCD_PE_AREA = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation dashboard - line'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsLine
  provider contract transactional_query
  as projection on ZR_CD_EbsLine
{
  key Kukey,
  key Esnum,
      StmtObjectKey,
      LineObjectKey,
      PaymentEngineArea,
      CompanyCode,
      HouseBank,
      HouseBankAccount,
      GlAccount,
      StatementNo,
      StatementDate,
      BaiCode,
      PostingRule,
      DebitCreditInd,
      // Totals per BAI code / debit-credit / currency: summed per group; the currency is part of
      // every group (amount semantics), so different currencies are never added together
      @Aggregation.default: #SUM
      Amount,
      Currency,
      BookingDate,
      ValueDate,
      BankReference,
      BankRefNorm,
      Xblnr,
      PostingDocument,
      PostingYear,
      IsPosted,
      ValidationStatus,
      ValidationCriticality,
      @Aggregation.default: #SUM
      LineCount,
      @Aggregation.default: #SUM
      PostedLineCount,
      @Aggregation.default: #SUM
      LineWithFindingCount,
      @Aggregation.default: #SUM
      OpenFindingCount,
      @Aggregation.default: #SUM
      DuplicateCount,
      @Aggregation.default: #SUM
      UnmappedCodeCount,
      _Findings : redirected to ZC_CD_EbsFind,
      _ReturnsNoc : redirected to ZC_CD_EbsRetNoc
}
