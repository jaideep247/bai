// Artifact: zi_cd_opsfindingcube.ddls.asddls
// Purpose: Analytical cube of findings / owned exceptions: counts, overdue counts
//          and amounts per payment engine area, category, check, severity, day. Verify annotations on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
//                   2026-11-06 | Amount aggregated per currency; MaxDaysPastDue over open past-due items (audit A47, A87).
//                   2026-11-10 | Company code of the finding (company-code isolation): one cube row per finding, so the DCL filters the
//                                findings before the analytic engine aggregates.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ops suite findings - cube'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_OpsFindingCube
  as select from ZI_CD_OpsFinding
  association [0..1] to ZI_CD_HckCheck as _Check on $projection.Group2 = _Check.CheckId
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      CompanyCode,
      Group1,
      @ObjectModel.foreignKey.association: '_Check'
      Group2,
      CheckCode,
      Severity,
      Disposition,
      Owner,
      DueDate,
      CreatedDate,
      IsOverdue,
      Currency,
      _Run.RunDate                                        as RunDate,
      _Run.IsTestMode                                     as IsTestMode,
      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )                              as FindingCount,
      @Aggregation.default: #SUM
      cast( case IsOverdue when 'X' then 1 else 0 end as abap.int4 ) as OverdueCount,
      @Aggregation.default: #SUM
      cast( case when Disposition = 'O' or Disposition = 'A' then 1 else 0 end as abap.int4 ) as OpenCount,
      // A87: 0 for items that are not open and past due (see ZI_CD_OpsFinding)
      @Aggregation.default: #MAX
      DaysPastDue                                         as MaxDaysPastDue,
      // A47: currency reference - the analytic engine never adds different currencies
      // (a mixed cell shows '*'); slice by Currency for totals
      @Semantics.amount.currencyCode: 'Currency'
      @Aggregation.default: #SUM
      Amount,
      _Check
}
