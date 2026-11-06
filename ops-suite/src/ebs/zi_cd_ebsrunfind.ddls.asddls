// Artifact: zi_cd_ebsrunfind.ddls.asddls
// Purpose: Findings of each EBS run (ZI_CD_EbsFinding) aggregated per run ID for the run list and
//          the KPI of the EBS validation dashboard: findings by severity, POSTING_INCOMPLETE (S13)
//          statements, duplicates, unmapped bank transaction codes, statements and lines with
//          findings. Information findings are counted separately (never a problem). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS findings per run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsRunFind
  as select from ZI_CD_EbsFinding
{
  key RunId,
      cast( count( * ) as abap.int4 )                                                     as FindingCount,
      cast( sum( case Severity when 'B' then 1 else 0 end ) as abap.int4 )                as BlockFindingCount,
      cast( sum( case Severity when 'E' then 1 else 0 end ) as abap.int4 )                as ErrorFindingCount,
      cast( sum( case Severity when 'W' then 1 else 0 end ) as abap.int4 )                as WarningFindingCount,
      cast( sum( case Severity when 'I' then 1 else 0 end ) as abap.int4 )                as InfoFindingCount,
      cast( sum( case IsPostingIncomplete when 'X' then 1 else 0 end ) as abap.int4 )     as PostingIncompleteCount,
      cast( sum( case IsDuplicate when 'X' then 1 else 0 end ) as abap.int4 )             as DuplicateCount,
      cast( sum( case CheckCode when 'UNMAPPED_BTC' then 1 else 0 end ) as abap.int4 )    as UnmappedCodeCount,
      // VERIFY-ADT: COUNT( DISTINCT ) in a view entity on 7.58. The blank key of run / file
      // findings is one distinct value - subtracted when present
      cast( count( distinct StmtObjectKey )
            - max( case StmtObjectKey when ' ' then 1 else 0 end ) as abap.int4 )          as StatementsWithFindings,
      cast( count( distinct LineObjectKey )
            - max( case LineObjectKey when ' ' then 1 else 0 end ) as abap.int4 )          as LinesWithFindings
}
group by
  RunId
