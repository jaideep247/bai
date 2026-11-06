// Artifact: zi_cd_hckfinding.ddls.asddls
// Purpose: Basic view of morning report findings (ZCD_OPS_FINDING, area HCK, OBJECT_TYPE CHECK:
//          GROUP1 = category A-E, GROUP2 = check id, OBJECT_KEY = <check>/<metric>/<DIM1>,
//          REFERENCE = DIM2 for metric findings, HCK_MORNING_REPORT.md section 6) for the health
//          check dashboard: every open / assigned finding plus every finding created in the last
//          31 days (bounded read), with the severity rank and the warm-up flag (BASELINE_WARMUP,
//          information, A102). Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check finding (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckFinding
  as select from zcd_ops_finding
{
  key run_id                                                as RunId,
  key finding_no                                            as FindingNo,
      cast( 'HCK' as abap.char( 4 ) )                       as PaymentEngineArea,
      // Check id (CHAR 20 in ZCD_HCK_DEF) from GROUP2 (CHAR 35). VERIFY-ADT: CHAR cast to a shorter length
      cast( group2 as abap.char( 20 ) )                     as CheckId,
      cast( group1 as abap.char( 1 ) )                      as Category,
      object_key                                            as ObjectKey,
      reference                                             as Reference,
      check_code                                            as CheckCode,
      severity                                              as Severity,
      cast( case severity when 'B' then 4
                          when 'E' then 3
                          when 'W' then 2
                          when 'I' then 1
                          else 0 end as abap.int1 )         as SeverityRank,
      cast( case severity when 'B' then 1
                          when 'E' then 1
                          when 'W' then 2
                          else 0 end as abap.int1 )         as SeverityCriticality,
      case when check_code = 'BASELINE_WARMUP'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsWarmup,
      message                                               as FindingMessage,
      disposition                                           as Disposition,
      case when disposition = 'O' or disposition = 'A'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsOpen,
      owner                                                 as Owner,
      due_date                                              as DueDate,
      first_seen_at                                         as FirstSeenAt,
      occurrences                                           as Occurrences,
      created_at                                            as CreatedAt,
      tstmp_to_dats( cast( created_at as timestamp ), 'UTC', $session.client, 'NULL' ) as CreatedDate
}
where pe_area     = 'HCK'
  and object_type = 'CHECK'
  and ( disposition = 'O' or disposition = 'A'
     or tstmp_to_dats( cast( created_at as timestamp ), 'UTC', $session.client, 'NULL' )
        >= dats_add_days( $session.system_date, -31, 'INITIAL' ) )
