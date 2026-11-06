// Artifact: zi_cd_trxfinflow.ddls.asddls
// Purpose: The SAP side of each FIN number (src/core ZR_CD_TrxFlow, open items of 31 days) in one
//          row: items, paid / settled / returned / reversed / still open reached, the clearing
//          document and cheque number (the highest when a FIN has several - the payment trace shows
//          every attempt), company code, payment method, direction. ADT only (cds/): it depends
//          on src/ views; src/ never depends on it. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions - SAP side per FIN'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxFinFlow
  as select from ZR_CD_TrxFlow
{
  key FinId,
      cast( sum( ItemCount ) as abap.int4 )                 as ItemCount,
      cast( max( PaidReachedCount ) as abap.int4 )          as IsPaid,
      cast( max( SettledReachedCount ) as abap.int4 )       as IsSettled,
      cast( max( ReturnedCount ) as abap.int4 )             as IsReturned,
      cast( max( ReversedCount ) as abap.int4 )             as IsReversed,
      cast( max( OpenCount ) as abap.int4 )                 as HasOpenItem,
      max( ClearingDoc )                                    as ClearingDoc,
      max( ChequeNo )                                       as ChequeNo,
      max( CompanyCode )                                    as CompanyCode,
      max( PaymentMethod )                                  as PaymentMethod,
      max( Direction )                                      as Direction,
      min( PostingDate )                                    as PostingDate
}
group by
  FinId
