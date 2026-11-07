// Artifact: zi_cd_trxreqwin.ddls.asddls
// Purpose: The requests (FIN number + source) with at least one attempt on the chosen request
//          date(s) - any day within the 400-day retention. The window selects requests; it never
//          removes an attempt from the SUCCESS row rule (ZI_CD_TrxRequest judges every attempt of a
//          selected request, also a SUCCESS attempt older than the window). ADT only (cds/).
//          Read-only.
// Modification log: 2026-11-07 | Initial version (review defect: window after the SUCCESS rule).
// VERIFY-SE11: request date field (ZI_CD_TrxReqLog placeholder zz_created_on); index for the window.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment requests of a request date window'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxReqWin
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select distinct from ZI_CD_TrxReqLog
{
  key FinId,
  key SourceSystem
}
where RequestDate between $parameters.P_DateFrom and $parameters.P_DateTo
  and RequestDate >= dats_add_days( $session.system_date, -400, 'INITIAL' )
