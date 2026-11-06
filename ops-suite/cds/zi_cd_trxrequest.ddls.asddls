// Artifact: zi_cd_trxrequest.ddls.asddls
// Purpose: One row per payment request (FIN number + source) of the last 31 days with the SUCCESS
//          row rule applied: processed = at least one attempt with ZZ_STATUS SUCCESS, whatever
//          COUNTER a later failed attempt has (a failed retry written after the success never
//          downgrades the request); errored = no SUCCESS attempt and at least one failure value;
//          pending = neither. Attempts and first request date. ADT only (cds/). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment request (SUCCESS row rule)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxRequest
  as select from ZI_CD_TrxReqLog
{
  key FinId,
  key SourceSystem,
      cast( count( * ) as abap.int4 )                                             as AttemptCount,
      cast( sum( case IsSuccess when 'X' then 1 else 0 end ) as abap.int4 )       as SuccessAttempts,
      cast( sum( case IsError when 'X' then 1 else 0 end ) as abap.int4 )         as ErrorAttempts,
      cast( sum( case IsCancelled when 'X' then 1 else 0 end ) as abap.int4 )     as CancelledAttempts,
      min( RequestDate )                                                          as RequestDate,
      cast( case
              when sum( case IsSuccess when 'X' then 1 else 0 end ) > 0 then 'PROCESSED'
              when sum( case IsError when 'X' then 1 else 0 end ) > 0   then 'ERRORED'
              else 'PENDING' end as abap.char( 10 ) )                             as RequestOutcome
}
group by
  FinId,
  SourceSystem
