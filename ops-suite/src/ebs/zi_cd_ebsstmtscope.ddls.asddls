// Artifact: zi_cd_ebsstmtscope.ddls.asddls
// Purpose: Payment engine account scope per imported statement of the last 31 days (user decision
//          2026-11-06): number of lines, number of lines whose XBLNR account is not an active payment
//          engine account (blank or unparseable XBLNR included), the account and its G/L account. A
//          statement is in scope when it has lines and OutOfScopeLineCount = 0 (ZI_CD_EbsStmtBase);
//          a statement without lines has no row here and is therefore out of scope, as in
//          ZCL_CD_EBS_PE_SCOPE. Read-only.
// Modification log: 2026-11-06 | Initial version (payment engine account scope from XBLNR).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS statement payment engine scope'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsStmtScope
  as select from    ZI_CD_EbsLineAcct as Line
    left outer join ZI_CD_EbsPeAcct   as Pe on Pe.PeAccount = Line.PeAccount
{
  key Line.Kukey                                                                        as Kukey,
      cast( count( * ) as abap.int4 )                                                   as LineCount,
      cast( sum( case when Pe.PeAccount is null then 1 else 0 end ) as abap.int4 )      as OutOfScopeLineCount,
      // One account per statement expected; PeAccountCount > 1 shows a statement over several
      cast( count( distinct Line.PeAccount ) as abap.int4 )                            as PeAccountCount,
      max( Line.PeAccount )                                                             as PeAccount,
      max( Pe.GlAccount )                                                               as GlAccount
}
group by
  Line.Kukey
