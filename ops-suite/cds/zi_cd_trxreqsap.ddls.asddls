// Artifact: zi_cd_trxreqsap.ddls.asddls
// Purpose: Requests of the request date window (ZI_CD_TrxReqWin) with the SUCCESS row rule
//          (ZI_CD_TrxRequest, all attempts), the number of sources of their FIN (ZI_CD_TrxFinSrc)
//          and the SAP side per company code and payment document (ZI_CD_TrxFinFlow, linked by the
//          FIN number - DFKKOP has no source field; the source attribution is the canonical outcome's
//          and AMBIGUOUS when the FIN is in two sources). One row per FIN + source + company code +
//          payment document (+ payment method, the identity of ZI_CD_TrxFinFlow); a request not
//          posted has blank company code, payment document and method.
//          ADT only (cds/). Read-only.
// Modification log: 2026-11-07 | Initial version (identity FIN + source + company code + payment).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment request with SAP side per payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxReqSap
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from    ZI_CD_TrxReqWin( P_DateFrom : $parameters.P_DateFrom,
                                     P_DateTo   : $parameters.P_DateTo ) as Win
    inner join      ZI_CD_TrxRequest as Req on  Req.FinId        = Win.FinId
                                            and Req.SourceSystem = Win.SourceSystem
    left outer join ZI_CD_TrxFinSrc  as Src on  Src.FinId = Req.FinId
    left outer join ZI_CD_TrxFinFlow as Sap on  Sap.FinId = Req.FinId
{
  key Req.FinId,
  key Req.SourceSystem,
  key coalesce( Sap.CompanyCode, ' ' )                      as CompanyCode,
  key coalesce( Sap.ClearingDoc, ' ' )                      as ClearingDoc,
  key coalesce( Sap.PaymentMethod, ' ' )                    as PaymentMethod,
      Req.RequestDate,
      Req.LastAttemptDate,
      Req.RequestOutcome,
      Req.AttemptCount,
      Req.SuccessAttempts,
      Req.ErrorAttempts,
      coalesce( Src.SourceCount, 0 )                        as SourceCount,
      case when Sap.FinId is null
           then cast( ' ' as abap_boolean )
           else cast( 'X' as abap_boolean ) end             as IsPosted,
      Sap.Direction,
      Sap.PostingDate,
      coalesce( Sap.ItemCount, 0 )                          as ItemCount,
      coalesce( Sap.HasOpenItem, 0 )                        as HasOpenItem,
      coalesce( Sap.IsReversed, 0 )                         as IsReversed,
      coalesce( Sap.IsPaid, 0 )                             as IsPaid
}
