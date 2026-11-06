// Artifact: zi_cd_ebsstmtbase.ddls.asddls
// Purpose: Basic view of imported bank statements (standard FEBKO) with a statement date in the
//          last 31 days (bounded read) and the finding key FEB<KUKEY> that ZCL_CD_EBS_SRC_FEB gives
//          the statement (join key to ZCD_OPS_FINDING-OBJECT_KEY). Fields as ZCL_CD_EBS_FEB_DAO
//          reads them: KUKEY, BUKRS, HBKID, HKTID, AZNUM, AZDAT, WAERS (VERIFY-SE11 as there).
//          Only payment engine statements (user decision 2026-11-06): every line's FEBEP-XBLNR
//          carries an active payment engine account of ZCD_EBS_ACCT (EBS configuration app) and
//          the statement has at least one line (ZI_CD_EbsStmtScope) - the same scope as the
//          validation run (ZCL_CD_EBS_PE_SCOPE). The matched account gives the payment engine account
//          and the bank G/L account. No balance is exposed. Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
//                   2026-11-06 | Payment engine accounts only (ZCD_EBS_ACCT, active) and their G/L account.
//                   2026-11-06 | Scope from FEBEP-XBLNR (every line a payment engine account) instead of
//                              | the house bank account; payment engine account on the statement.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS imported statement (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsStmtBase
  as select from febko
    inner join   ZI_CD_EbsStmtScope as Scope on Scope.Kukey = febko.kukey
{
  key febko.kukey                                           as Kukey,
      // Same text as ZIF_CD_EBS_TYPES=>GC_FEB_STMT_PREFIX && |{ kukey }| (KUKEY NUMC 8, zeros kept)
      // VERIFY-ADT: CONCAT with a NUMC operand
      cast( concat( 'FEB', febko.kukey ) as abap.char( 11 ) ) as StmtObjectKey,
      febko.bukrs                                           as CompanyCode,
      febko.hbkid                                           as HouseBank,
      // House bank account ID (short key of the account, not the account number)
      febko.hktid                                           as HouseBankAccount,
      // Payment engine account of the lines (FEBEP-XBLNR, one per statement expected)
      Scope.PeAccount                                       as PeAccount,
      // Bank G/L account of the payment engine account (ZCD_EBS_ACCT, as rule R18 uses it)
      Scope.GlAccount                                       as GlAccount,
      febko.aznum                                           as StatementNo,
      febko.azdat                                           as StatementDate,
      febko.waers                                           as Currency
}
where febko.azdat               >= dats_add_days( $session.system_date, -31, 'INITIAL' )
  and Scope.OutOfScopeLineCount =  0
