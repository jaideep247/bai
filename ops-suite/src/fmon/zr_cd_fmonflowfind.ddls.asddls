// Artifact: zr_cd_fmonflowfind.ddls.asddls
// Purpose: Drill-down of the file monitoring dashboard: open FMON exceptions (ZCA_OPS_FINDING,
//          area FMON, object FILE, disposition O open / A assigned). File findings carry the
//          file ID in hex in REFERENCE (link to the file row); an expected file that never
//          arrived (FILE_MISSING, key <interface>/<date>) has no reference and is listed here
//          only. Work the exception in the owned-exceptions app (ZUI_CD_OPS_EXC_O4). Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
//                   2026-11-10 | Company code of the finding (company-code isolation; FMON findings are area-level -
//                                blank - as long as the interface register has no company code).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON file monitoring - open exception'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_FmonFlowFind
  as select from zca_ops_finding
{
  key run_id                                                as RunId,
  key finding_no                                            as FindingNo,
      area                                               as PaymentEngineArea,
      bukrs                                                 as CompanyCode,
      reference                                             as FileIdHex,
      object_key                                            as ObjectKey,
      group1                                                as IfaceId,
      group2                                                as PaymentMethod,
      check_code                                            as CheckCode,
      // Same rule as ZI_CD_FmonFileExc: BREACHED / LATE / OTHER
      cast( case
              when left( check_code, 3 ) = 'NO_'                    then 'BREACHED'
              when right( rtrim( check_code, ' ' ), 5 ) = '_LATE'    then 'LATE'
              else 'OTHER' end as abap.char( 12 ) )         as SlaClass,
      severity                                              as Severity,
      // UI criticality: 1 red (B, E), 2 yellow (W), 0 neutral (I)
      cast( case severity when 'B' then 1
                          when 'E' then 1
                          when 'W' then 2
                          else 0 end as abap.int1 )         as SeverityCriticality,
      disposition                                           as Disposition,
      owner                                                 as Owner,
      due_date                                              as DueDate,
      message                                               as FindingMessage,
      first_seen_at                                         as FirstSeenAt,
      occurrences                                           as Occurrences,
      created_at                                            as CreatedAt
}
where area     = 'CD_FMON'
  and object_type = 'FILE'
  and ( disposition = 'O' or disposition = 'A' )
