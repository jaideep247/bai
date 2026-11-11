// Artifact: zi_cd_ledgrccube.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - analytical cube of the group reconciliation (embedded analytics: Analysis
//          for Office, multidimensional reports, KPI tiles): business date x company code x G/L account x currency
//          with the measures subledger, journal transfers, other journal postings, live difference, batch keys and
//          journal lines (summed per currency - the currency is a dimension, never summed across). Rows of
//          ZR_CD_LedgRecon; read access: DCL ZC_CD_PAYM (company code). Query: ZC_CD_LedgRcQry.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
// VERIFY-ADT: @Analytics.dataCategory #CUBE over a root view entity with joins (7.58); currency as dimension of DEC
//             measures (no @Semantics.amount on DEC).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - reconciliation cube'
@Analytics.dataCategory: #CUBE
@VDM.viewType: #COMPOSITE
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgRcCube
  as select from ZR_CD_LedgRecon as Rc
{
  key Rc.BusinessDate,
  key Rc.CompanyCode,
  key Rc.GlAccount,
  key Rc.Currency,
      Rc.OpsArea,
      Rc.AccountKind,
      @Aggregation.default: #SUM
      Rc.SubledgerAmount,
      @Aggregation.default: #SUM
      Rc.JournalTransferAmount,
      @Aggregation.default: #SUM
      Rc.JournalOtherAmount,
      @Aggregation.default: #SUM
      Rc.LiveDifference,
      @Aggregation.default: #SUM
      Rc.BatchCount,
      @Aggregation.default: #SUM
      Rc.JournalLineCount,
      @Aggregation.default: #SUM
      Rc.GroupDayCount
}
