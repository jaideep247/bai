// Artifact: zi_cd_returnitem.ddls.asddls
// Purpose: Basic view of returns lot items (standard DFKKRP) for the EBS validation and the
//          transaction dashboards: the payment document the return refers to (SELW1, confirmed:
//          DFKKRP-SELW1 = DFKKOP-AUGBL = FEBEP-CHECT for methods E G H I J K L), the return
//          document (OPBEL), the return reason RLGRD (user decision 2026-11-06; field seen on the
//          reference system S/4HANA 2025) and the lot status DFKKRK-STARS (lot key KEYR1, as
//          ZCL_CD_EBS_SAP_DAO=>GET_RETURN_ITEMS). The return reason is never taken from FEBEP;
//          NOC codes are never taken from DFKKRP (they are on DFKKNRP, ZI_CD_NocItem).
//          Unbounded on purpose: consumers join it from a bounded driver (bank lines of the
//          last 31 days, open items of the last 31 days) on SELW1. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation / transaction dashboards).
//                   2026-11-15 | Lot joined on its key KEYR1 (DFKKRK has no OPBEL; dictionary of the reference
//                   system S/4HANA 2025, ddic/a4h).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Returns lot item (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
// DFKKRP primary key is KEYR1 + POSRA (lot / item, reference system S/4HANA 2025); OPBEL + SELW1 are used as
// the element key here - VERIFY-SE11 uniqueness, else make KEYR1 + POSRA the element key in ADT
define view entity ZI_CD_ReturnItem
  as select from    dfkkrp as Item
    left outer join dfkkrk as Lot on Lot.keyr1 = Item.keyr1
{
  key Item.selw1                                            as PaymentDocument,
  key Item.opbel                                            as ReturnDocument,
      // DFKKRP-RLGRD (return reason; data element RLGRD_KK, seen on the reference system S/4HANA 2025)
      Item.rlgrd                                            as ReturnReason,
      Lot.stars                                             as LotStatus
}
where Item.selw1 <> ' '
