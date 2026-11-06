// Artifact: zi_cd_nocitem.ddls.asddls
// Purpose: Basic view of NOC (notification of change) lot items (standard DFKKNRP) for the EBS
//          validation and the transaction dashboards: lot KEYN1 and item POSNA (confirmed keys),
//          INFOF (CHAR 50, confirmed) holding the payment document AUGBL or the payment reference,
//          and the NOC reason FLGRD (user decision 2026-11-06; VERIFY-SE11 field name).
//          PaymentRefNorm = INFOF without leading zeros and blanks - consumers compare it with the
//          equally normalised payment document / bank reference. INFOF is not a key and has no
//          known index (VERIFY-SE11): consumers join from a bounded driver only. NOC codes come
//          from here, never from DFKKRP. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation / transaction dashboards).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'NOC lot item (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_NocItem
  as select from dfkknrp
{
  key keyn1                                                 as NocLot,
  key posna                                                 as NocItem,
      infof                                                 as PaymentRef,
      // VERIFY-ADT: LTRIM on CHAR 50 (leading zeros), result compared with LTRIM( AUGBL / CHECT )
      cast( ltrim( ltrim( infof, ' ' ), '0' ) as abap.char( 50 ) ) as PaymentRefNorm,
      // VERIFY-SE11: DFKKNRP-FLGRD (NOC reason)
      flgrd                                                 as NocReason
}
where infof <> ' '
