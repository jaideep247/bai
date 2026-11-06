// Artifact: zr_cd_trxpayrun.ddls.asddls
// Purpose: Payment runs and their live payment status (transactions dashboard): DPAYH rows of the
//          last 45 days (LAUFD) that carry a payment document (DOC1R), proposal runs excluded -
//          run date LAUFD, run ID LAUFI, DOC1R, ZZ_PAYMENT_STATUS (confirmed; XVORL VERIFY-SE11).
//          Chart: payments by run date and status. Drill-down target of a transaction (DOC1R =
//          clearing document). DPAYH company code, payment method and amount fields are not used
//          (VERIFY-SE11): method and amount come from the open item. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - payment run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
// VERIFY-SE11: DPAYH key - LAUFD + LAUFI + DOC1R is used as the element key (one payment document
// per run row); confirm, else add the DPAYH key fields in ADT
define root view entity ZR_CD_TrxPayRun
  as select from dpayh
{
  key laufd                                                 as RunDate,
  key laufi                                                 as RunId,
  key doc1r                                                 as PaymentDocument,
      cast( 'CORE' as abap.char( 4 ) )                      as PaymentEngineArea,
      zz_payment_status                                     as PaymentStatus,
      case when laufd = $session.system_date
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsToday,
      cast( 1 as abap.int4 )                                as PaymentCount
}
where xvorl = ' '
  and doc1r <> ' '
  and laufd >= dats_add_days( $session.system_date, -45, 'INITIAL' )
