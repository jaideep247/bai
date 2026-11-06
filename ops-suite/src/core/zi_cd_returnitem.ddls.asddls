// Artifact: zi_cd_returnitem.ddls.asddls
// Purpose: Basic view of returns lot items (standard DFKKRP) for the EBS validation and the
//          transaction dashboards: the payment document the return refers to (SELW1, confirmed:
//          DFKKRP-SELW1 = DFKKOP-AUGBL = FEBEP-CHECT for methods E G H I J K L), the return
//          document (OPBEL), the return reason RLGRD (user decision 2026-11-06; VERIFY-SE11 field
//          name) and the lot status DFKKRK-STARS (joined via OPBEL as ZCL_CD_EBS_SAP_DAO=>
//          GET_RETURN_ITEMS, VERIFY-DDIC there). The return reason is never taken from FEBEP;
//          NOC codes are never taken from DFKKRP (they are on DFKKNRP, ZI_CD_NocItem).
//          Unbounded on purpose: consumers join it from a bounded driver (bank lines of the
//          last 31 days, open items of the last 31 days) on SELW1. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation / transaction dashboards).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Returns lot item (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
// VERIFY-SE11: DFKKRP key fields (lot / item) - OPBEL + SELW1 are used as the element key here;
// confirm uniqueness, else add the lot key (KEYR1) and item number in ADT
define view entity ZI_CD_ReturnItem
  as select from    dfkkrp as Item
    left outer join dfkkrk as Lot on Lot.opbel = Item.opbel
{
  key Item.selw1                                            as PaymentDocument,
  key Item.opbel                                            as ReturnDocument,
      // VERIFY-SE11: DFKKRP-RLGRD (return reason)
      Item.rlgrd                                            as ReturnReason,
      Lot.stars                                             as LotStatus
}
where Item.selw1 <> ' '
