// Artifact: zi_cd_ebslineexc.ddls.asddls
// Purpose: Open EBS findings (O open, A assigned) per statement line (OBJECT_KEY FEB<KUKEY>/<ESNUM>):
//          counts by severity, worst severity, duplicates, unmapped bank transaction code. Drives
//          the validation status of ZR_CD_EbsLine. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS open findings per line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsLineExc
  as select from ZI_CD_EbsFinding
{
  key LineObjectKey,
      cast( count( * ) as abap.int4 )                                                     as OpenFindingCount,
      cast( sum( case Severity when 'B' then 1 else 0 end ) as abap.int4 )                as BlockFindingCount,
      cast( sum( case Severity when 'E' then 1 else 0 end ) as abap.int4 )                as ErrorFindingCount,
      cast( sum( case Severity when 'W' then 1 else 0 end ) as abap.int4 )                as WarningFindingCount,
      cast( sum( case IsDuplicate when 'X' then 1 else 0 end ) as abap.int4 )             as DuplicateCount,
      cast( sum( case CheckCode when 'UNMAPPED_BTC' then 1 else 0 end ) as abap.int4 )    as UnmappedCodeCount,
      cast( max( SeverityRank ) as abap.int1 )                                            as WorstSeverityRank
}
where IsOpen     = 'X'
  and ObjectType = 'LINE'
group by
  LineObjectKey
