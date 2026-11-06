// Artifact: zi_cd_ebsstmtbase.ddls.asddls
// Purpose: Basic view of imported bank statements (standard FEBKO) with a statement date in the
//          last 31 days (bounded read) and the finding key FEB<KUKEY> that ZCL_CD_EBS_SRC_FEB gives
//          the statement (join key to ZCD_OPS_FINDING-OBJECT_KEY). Fields as ZCL_CD_EBS_FEB_DAO
//          reads them: KUKEY, BUKRS, HBKID, HKTID, AZNUM, AZDAT, WAERS (VERIFY-SE11 as there).
//          Only payment engine accounts: inner join to the active house bank accounts maintained in
//          ZCD_EBS_ACCT (EBS configuration app), which also gives the bank G/L account; statements
//          of other accounts never appear. No bank account number and no balance is exposed. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
//                   2026-11-06 | Payment engine accounts only (ZCD_EBS_ACCT, active) and their G/L account.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS imported statement (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsStmtBase
  as select from febko
    inner join   zcd_ebs_acct as Acct on  Acct.bukrs  = febko.bukrs
                                     and Acct.hbkid  = febko.hbkid
                                     and Acct.hktid  = febko.hktid
                                     and Acct.active = 'X'
{
  key febko.kukey                                           as Kukey,
      // Same text as ZIF_CD_EBS_TYPES=>GC_FEB_STMT_PREFIX && |{ kukey }| (KUKEY NUMC 8, zeros kept)
      // VERIFY-ADT: CONCAT with a NUMC operand
      cast( concat( 'FEB', febko.kukey ) as abap.char( 11 ) ) as StmtObjectKey,
      febko.bukrs                                           as CompanyCode,
      febko.hbkid                                           as HouseBank,
      // House bank account ID (short key of the account, not the account number)
      febko.hktid                                           as HouseBankAccount,
      // Bank G/L account of the payment engine account (ZCD_EBS_ACCT, as rule R18 uses it)
      Acct.gl_account                                       as GlAccount,
      febko.aznum                                           as StatementNo,
      febko.azdat                                           as StatementDate,
      febko.waers                                           as Currency
}
where febko.azdat >= dats_add_days( $session.system_date, -31, 'INITIAL' )
