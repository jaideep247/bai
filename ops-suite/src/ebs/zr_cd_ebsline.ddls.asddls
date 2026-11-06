// Artifact: zr_cd_ebsline.ddls.asddls
// Purpose: Drill-down of the EBS validation dashboard: the lines (FEBEP) of the imported statements
//          of the last 31 days with house bank, BAI / transaction code, posting rule, amount,
//          booking date, bank reference, posting document, the open findings of the line and its
//          validation status (BLOCKED, ERROR, WARNING, NO_FINDINGS). Also the base of the chart
//          "lines by BAI code". Drill-down: line -> findings, line -> returns / NOC lot items
//          (reason from DFKKRP-RLGRD / DFKKNRP-FLGRD, never from FEBEP). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation dashboard - line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
define root view entity ZR_CD_EbsLine
  as select from    ZI_CD_EbsLineBase as Line
    left outer join ZI_CD_EbsLineExc  as Exc on Exc.LineObjectKey = Line.LineObjectKey
  association [0..*] to ZR_CD_EbsFind as _Findings on  $projection.LineObjectKey = _Findings.LineObjectKey
                                                   and _Findings.IsOpen          = 'X'
  association [0..*] to ZR_CD_EbsRetNoc as _ReturnsNoc on  $projection.Kukey = _ReturnsNoc.Kukey
                                                       and $projection.Esnum = _ReturnsNoc.Esnum
{
  key Line.Kukey,
  key Line.Esnum,
      Line.StmtObjectKey,
      Line.LineObjectKey,
      cast( 'EBS' as abap.char( 4 ) )                       as PaymentEngineArea,
      Line.CompanyCode,
      Line.HouseBank,
      Line.HouseBankAccount,
      Line.StatementNo,
      Line.StatementDate,
      Line.BaiCode,
      Line.PostingRule,
      Line.DebitCreditInd,
      @Semantics.amount.currencyCode: 'Currency'
      Line.Amount,
      Line.Currency,
      Line.BookingDate,
      Line.ValueDate,
      Line.BankReference,
      Line.Xblnr,
      Line.PostingDocument,
      Line.PostingYear,
      Line.IsPosted,
      cast( case
              when Exc.BlockFindingCount > 0   then 'BLOCKED'
              when Exc.ErrorFindingCount > 0   then 'ERROR'
              when Exc.WarningFindingCount > 0 then 'WARNING'
              else 'NO_FINDINGS' end as abap.char( 20 ) )   as ValidationStatus,
      cast( case
              when Exc.BlockFindingCount > 0   then 1
              when Exc.ErrorFindingCount > 0   then 1
              when Exc.WarningFindingCount > 0 then 2
              else 3 end as abap.int1 )                     as ValidationCriticality,
      cast( 1 as abap.int4 )                                as LineCount,
      cast( case Line.IsPosted when 'X' then 1 else 0 end as abap.int4 ) as PostedLineCount,
      cast( case when Exc.OpenFindingCount > 0 then 1 else 0 end as abap.int4 ) as LineWithFindingCount,
      cast( coalesce( Exc.OpenFindingCount, 0 ) as abap.int4 )  as OpenFindingCount,
      cast( coalesce( Exc.DuplicateCount, 0 ) as abap.int4 )    as DuplicateCount,
      cast( coalesce( Exc.UnmappedCodeCount, 0 ) as abap.int4 ) as UnmappedCodeCount,
      _Findings,
      _ReturnsNoc
}
