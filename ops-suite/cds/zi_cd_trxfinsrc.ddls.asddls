// Artifact: zi_cd_trxfinsrc.ddls.asddls
// Purpose: Number of sources of a FIN number in the request log, by the rule of the canonical
//          evaluator ZIF_CD_OPS_PAY_OUTCOME=>SOURCES_OF: the sources with a SUCCESS row, else every
//          source of the FIN. More than one = the request funnel shows AMBIGUOUS for each of them
//          (also before payment, when no outcome version exists yet) - never one picked. CDS cannot
//          call the evaluator: the rule is mirrored here and proven equal by the shared fixture
//          FIN_TWO_SOURCES (ZCL_CD_OPS_PAY_FIXTURE) in the evaluator and request-side tests.
//          ADT only (cds/). Read-only.
// Modification log: 2026-11-07 | Initial version (ambiguous source attribution).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sources of a FIN number'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxFinSrc
  as select from ZI_CD_TrxRequest
{
  key FinId,
      cast( case
              when sum( case when SuccessAttempts > 0 then 1 else 0 end ) > 0
                then sum( case when SuccessAttempts > 0 then 1 else 0 end )
              else count( * ) end as abap.int4 )            as SourceCount
}
group by
  FinId
