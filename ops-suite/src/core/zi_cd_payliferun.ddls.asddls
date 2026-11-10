// Artifact: zi_cd_payliferun.ddls.asddls
// Purpose: Payments of a business date for the payment lifecycle card and list of the overview page: the
//          NEWEST non-proposal DPAYH row of every payment document (DOC1R) whose run date LAUFD is in the last
//          45 days - run date = business date, live status ZZ_PAYMENT_STATUS (confirmed values ISSUED,
//          CONFIRMED, CLEARED, RETURNED, RETRIEVED, STOPPED), company code, method, house bank, amount. A
//          document paid again in a later run counts once, on the later run (anti-join on a newer run of the
//          same document, the order of ZI_CD_TrxItemPay and ZIF_CD_OPS_PAY_OUTCOME=>EVALUATE_DOCUMENTS: run
//          date, then run ID). Live from the standard table: nothing is copied. Read-only.
// Modification log: 2026-11-10 | Initial version (control center: payment lifecycle).
// Access path (Performance_Review.md section 11): a business date restricts LAUFD, the first field of the DPAYH
// key (primary index); the newer-run probe reads DPAYH by DOC1R (index VERIFY-SE11) and only run dates from
// the business date on (the window bounds both sides).
// VERIFY-SE11: DPAYH-BUKRS / PYMET / HBKID / RWBTR / WAERS (as ZI_CD_PayWorkItem and the HCK runtime DAO).
// VERIFY-ADT: comparison operators and OR in the ON condition of a left outer join (7.58), as ZI_CD_TrxItemPay.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment lifecycle - newest run per payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_PayLifeRun
  as select from    dpayh as Pay
    left outer join dpayh as Newer on  Newer.doc1r = Pay.doc1r
                                   and Newer.xvorl = ' '
                                   and Newer.laufd >= Pay.laufd
                                   and (    Newer.laufd > Pay.laufd
                                         or ( Newer.laufd = Pay.laufd and Newer.laufi > Pay.laufi ) )
{
  key Pay.laufd                                             as BusinessDate,
  key Pay.laufi                                             as RunId,
  key Pay.doc1r                                             as PaymentDocument,
      Pay.bukrs                                             as CompanyCode,
      Pay.pymet                                             as PaymentMethod,
      Pay.hbkid                                             as HouseBank,
      Pay.zz_payment_status                                 as PaymentStatus,
      Pay.waers                                             as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      abs( Pay.rwbtr )                                      as Amount
}
where
      Pay.xvorl =  ' '
  and Pay.doc1r <> ' '
  and Pay.laufd >= dats_add_days( $session.system_date, -45, 'INITIAL' )
  and Newer.doc1r is null
