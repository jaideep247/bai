// Artifact: zr_cd_ebsstmt.ddls.asddls
// Purpose: Root of the EBS validation dashboard (analytical list page, OData V4,
//          docs/Dashboard_EBS_Validation.md): one row per imported bank statement (FEBKO) of the
//          last 31 days with house bank, house bank account ID, company code, statement date and
//          number, lines and posted lines, the open findings of the statement and its lines, the
//          validation status and the "as of" of the last completed EBS run on every row.
//          Validation status (worst first): BLOCKED (open B), ERROR (open E), POSTING_INCOMPLETE
//          (open S13 - posting-dependent rules not evaluated), WARNING (open W), NO_FINDINGS.
//          Drill-down: statement -> lines -> findings. Read-only: no behaviour definition.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation dashboard - statement'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
// VERIFY-ADT: CROSS JOIN with the one-row as-of view in a root view entity (as ZR_CD_FmonFlow)
define root view entity ZR_CD_EbsStmt
  as select from    ZI_CD_EbsStmtBase  as Stmt
    left outer join ZI_CD_EbsStmtLines as Lines on Lines.Kukey = Stmt.Kukey
    left outer join ZI_CD_EbsStmtExc   as Exc   on Exc.StmtObjectKey = Stmt.StmtObjectKey
    cross join      ZR_CD_EbsAsOf      as AsOf
  association [0..*] to ZR_CD_EbsLine as _Lines    on  $projection.Kukey = _Lines.Kukey
  association [0..*] to ZR_CD_EbsFind as _Findings on  $projection.StmtObjectKey = _Findings.StmtObjectKey
                                                   and _Findings.IsOpen          = 'X'
{
  key Stmt.Kukey,
      Stmt.StmtObjectKey,
      cast( 'EBS' as abap.char( 4 ) )                       as PaymentEngineArea,
      Stmt.CompanyCode,
      Stmt.HouseBank,
      Stmt.HouseBankAccount,
      Stmt.GlAccount,
      Stmt.StatementNo,
      Stmt.StatementDate,
      Stmt.Currency,
      case when Stmt.StatementDate = $session.system_date
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsToday,
      cast( case
              when Exc.BlockFindingCount > 0      then 'BLOCKED'
              when Exc.ErrorFindingCount > 0      then 'ERROR'
              when Exc.PostingIncompleteCount > 0 then 'POSTING_INCOMPLETE'
              when Exc.WarningFindingCount > 0    then 'WARNING'
              else 'NO_FINDINGS' end as abap.char( 20 ) )   as ValidationStatus,
      cast( case
              when Exc.BlockFindingCount > 0      then 1
              when Exc.ErrorFindingCount > 0      then 1
              when Exc.PostingIncompleteCount > 0 then 2
              when Exc.WarningFindingCount > 0    then 2
              else 3 end as abap.int1 )                     as ValidationCriticality,
      // Worst open severity: B, E, W, I; blank = no open finding
      cast( case Exc.WorstSeverityRank
              when 4 then 'B'
              when 3 then 'E'
              when 2 then 'W'
              when 1 then 'I'
              else ' ' end as abap.char( 1 ) )              as WorstSeverity,
      // ---------------------------------------------------------------- validation as of
      AsOf.AsOfAt,
      AsOf.RunId                                            as AsOfRunId,
      AsOf.AgeMinutes                                       as MonitorAgeMinutes,
      AsOf.IsStale                                          as MonitorIsStale,
      AsOf.StaleCriticality                                 as MonitorCriticality,
      // ---------------------------------------------------------------- measures
      cast( 1 as abap.int4 )                                as StatementCount,
      cast( coalesce( Lines.LineCount, 0 ) as abap.int4 )   as LineCount,
      cast( coalesce( Lines.PostedLineCount, 0 ) as abap.int4 ) as PostedLineCount,
      cast( coalesce( Exc.OpenFindingCount, 0 ) as abap.int4 )  as OpenFindingCount,
      cast( coalesce( Exc.BlockFindingCount, 0 ) as abap.int4 ) as BlockFindingCount,
      cast( coalesce( Exc.ErrorFindingCount, 0 ) as abap.int4 ) as ErrorFindingCount,
      cast( coalesce( Exc.WarningFindingCount, 0 ) as abap.int4 ) as WarningFindingCount,
      cast( coalesce( Exc.LineFindingCount, 0 ) as abap.int4 )  as LineFindingCount,
      cast( coalesce( Exc.DuplicateCount, 0 ) as abap.int4 )    as DuplicateCount,
      cast( case when Exc.PostingIncompleteCount > 0 then 1 else 0 end as abap.int4 ) as PostingIncompleteStmtCount,
      cast( case when Exc.OpenFindingCount is null then 1 else 0 end as abap.int4 )   as NoFindingStmtCount,
      _Lines,
      _Findings
}
