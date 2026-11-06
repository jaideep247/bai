// Artifact: zi_cd_ebsstmtbase.ddls.asddls
// Purpose: Basic view of imported bank statements (standard FEBKO) with a statement date in the
//          last 31 days (bounded read) and the finding key FEB<KUKEY> that ZCL_CD_EBS_SRC_FEB gives
//          the statement (join key to ZCD_OPS_FINDING-OBJECT_KEY). Fields as ZCL_CD_EBS_FEB_DAO
//          reads them: KUKEY, BUKRS, HBKID, HKTID, AZNUM, AZDAT, WAERS (VERIFY-SE11 as there).
//          No bank account number and no balance is exposed. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS imported statement (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsStmtBase
  as select from febko
{
  key kukey                                                 as Kukey,
      // Same text as ZIF_CD_EBS_TYPES=>GC_FEB_STMT_PREFIX && |{ kukey }| (KUKEY NUMC 8, zeros kept)
      // VERIFY-ADT: CONCAT with a NUMC operand
      cast( concat( 'FEB', kukey ) as abap.char( 11 ) )     as StmtObjectKey,
      bukrs                                                 as CompanyCode,
      hbkid                                                 as HouseBank,
      // House bank account ID (short key of the account, not the account number)
      hktid                                                 as HouseBankAccount,
      aznum                                                 as StatementNo,
      azdat                                                 as StatementDate,
      waers                                                 as Currency
}
where azdat >= dats_add_days( $session.system_date, -31, 'INITIAL' )
