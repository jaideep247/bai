// Artifact: zi_cd_payworksrc.ddls.asddls
// Purpose: Request source of a payment document that has a current worklist row (ZCD_PAY_OUTCOME by AUGBL,
//          index DOC): the source of its payment request (one value; MAX when the document paid requests of
//          several sources, the count tells) - shown in the payments list of the overview page. A payment
//          that ended clean has no worklist row and no source here (the payment trace finds it). Read-only.
// Modification log: 2026-11-10 | Initial version (control center: payment lifecycle list).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment lifecycle - request source'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PayWorkSrc
  as select from ZI_CD_PayOutcome
{
  key ClearingDoc,
      max( SourceSystem )                                   as SourceSystem,
      cast( count( * ) as abap.int4 )                       as WorklistRows
}
where
      ValidTo     =  99991231235959
  and ClearingDoc <> ' '
group by
  ClearingDoc
