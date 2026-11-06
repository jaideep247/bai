// Artifact: zi_cd_ebsstmtexc.ddls.asddls
// Purpose: Open EBS findings (O open, A assigned) per imported statement (key FEB<KUKEY>), the
//          statement's own findings and those of its lines together: counts by severity, worst
//          severity, open POSTING_INCOMPLETE (S13: posting-dependent rules not evaluated) and
//          duplicates. Drives the validation status of ZR_CD_EbsStmt. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS open findings per statement'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsStmtExc
  as select from ZI_CD_EbsFinding
{
  key StmtObjectKey,
      cast( count( * ) as abap.int4 )                                                     as OpenFindingCount,
      cast( sum( case Severity when 'B' then 1 else 0 end ) as abap.int4 )                as BlockFindingCount,
      cast( sum( case Severity when 'E' then 1 else 0 end ) as abap.int4 )                as ErrorFindingCount,
      cast( sum( case Severity when 'W' then 1 else 0 end ) as abap.int4 )                as WarningFindingCount,
      cast( sum( case IsPostingIncomplete when 'X' then 1 else 0 end ) as abap.int4 )     as PostingIncompleteCount,
      cast( sum( case IsDuplicate when 'X' then 1 else 0 end ) as abap.int4 )             as DuplicateCount,
      cast( sum( case ObjectType when 'LINE' then 1 else 0 end ) as abap.int4 )           as LineFindingCount,
      cast( max( SeverityRank ) as abap.int1 )                                            as WorstSeverityRank
}
where IsOpen        = 'X'
  and StmtObjectKey <> ' '
group by
  StmtObjectKey
