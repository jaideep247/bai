// Artifact: zi_cd_trxrequest.ddls.asddls
// Purpose: One row per payment request (FIN number + source) with the SUCCESS row rule applied to
//          ALL its attempts: processed = at least one attempt with ZZ_STATUS SUCCESS, whatever
//          COUNTER a later failed attempt has (a failed retry written after the success never
//          downgrades the request) and however old the SUCCESS attempt is; errored = no SUCCESS
//          attempt and at least one failure value; pending = neither. Attempts, first and last
//          request date. The date window comes after this rule (ZI_CD_TrxReqWin). ADT only (cds/).
//          Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
//                   2026-11-07 | Every attempt (no window before the rule); last attempt date.
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
      max( RequestDate )                                                          as LastAttemptDate,
      cast( case
              when sum( case IsSuccess when 'X' then 1 else 0 end ) > 0 then 'PROCESSED'
              when sum( case IsError when 'X' then 1 else 0 end ) > 0   then 'ERRORED'
              else 'PENDING' end as abap.char( 10 ) )                             as RequestOutcome
}
group by
  FinId,
  SourceSystem
