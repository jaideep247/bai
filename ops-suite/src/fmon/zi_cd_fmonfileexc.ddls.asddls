// Artifact: zi_cd_fmonfileexc.ddls.asddls
// Purpose: Open FMON exceptions per monitored file instance (file monitoring dashboard SLA status).
//          Groups the open / assigned findings of ZCA_OPS_FINDING (area FMON, object FILE) by
//          REFERENCE = file ID in hex, which ZCL_CD_FMON_UTIL=>NEW_FINDING writes for every
//          file finding (the object key - file name, max 70 characters - repeats across
//          business dates and is not used). Read-only.
//          SLA codes follow ZCL_CD_FMON_RULES=>SLA_CODE: NO_<stage> = stage not reached and
//          overdue (breached), <stage>_LATE / FILE_LATE = reached late.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON open exceptions per file'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_FmonFileExc
  as select from zca_ops_finding
{
  key reference                                             as FileIdHex,
      cast( count( * ) as abap.int4 )                       as OpenFindingCount,
      // Breached: an SLA stage not reached in time (NO_PRISM_HANDOFF, NO_BANK_ACK, ...)
      cast( sum( case when left( check_code, 3 ) = 'NO_' then 1 else 0 end ) as abap.int4 ) as BreachedCount,
      // Late: reached, but after the window / SLA (FILE_LATE, PRISM_HANDOFF_LATE, BANK_ACK_LATE, ...).
      // VERIFY-ADT: RIGHT on CHAR ignores trailing blanks (HANA stores none)
      cast( sum( case when right( rtrim( check_code, ' ' ), 5 ) = '_LATE' then 1 else 0 end ) as abap.int4 ) as LateCount,
      // Worst severity as a rank: 4 B (block), 3 E, 2 W, 1 I
      cast( max( case severity when 'B' then 4
                               when 'E' then 3
                               when 'W' then 2
                               when 'I' then 1
                               else 0 end ) as abap.int1 )  as WorstSeverityRank
}
where area     = 'CD_FMON'
  and object_type = 'FILE'
  and reference   <> ' '
  // open exceptions only: O open, A assigned (not I information, R resolved, W waived, S superseded)
  and ( disposition = 'O' or disposition = 'A' )
group by reference
