// Artifact: zi_ca_opsflowmove.ddls.asddls
// Purpose: Account flow reconciliation - movement of the flow accounts in the window by stage: the journal signatures
//          (ZI_CA_OpsFlowGlSig) and the FI-CA signatures (ZI_CA_OpsFlowFiSig), each with the stage of its first
//          matching rule (ZI_CA_OpsFlowGlMin / ZI_CA_OpsFlowFiMin) or OTHER, the rule, and the amount split into debit
//          and credit (both positive). Movement = the lines of the account's own source: for a journal account (G) the
//          journal lines; for a subledger-posted account (F) the FI-CA lines plus its direct G/L postings (bank
//          statement, manual: journal lines that are not the G/L transfer) - its G/L transfer lines (reference
//          transaction FKKSU, the summarised FI-CA postings) are IsMemo = X, shown as reached G/L and never added to
//          the movement (they would count the subledger twice). Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): UNION ALL of two branches with parameters, COALESCE of a CHAR 20 column with a literal, left outer
//          join on a NUMC key from a grouped view.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: movement by stage'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowMove
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from    ZI_CA_OpsFlowGlSig( P_DateFrom : $parameters.P_DateFrom,
                                        P_DateTo   : $parameters.P_DateTo ) as Sig
    left outer join ZI_CA_OpsFlowGlMin( P_DateFrom : $parameters.P_DateFrom,
                                        P_DateTo   : $parameters.P_DateTo ) as Mn  on  Mn.Area          = Sig.Area
                                                                                   and Mn.FlowId        = Sig.FlowId
                                                                                   and Mn.FlowAccount   = Sig.FlowAccount
                                                                                   and Mn.Currency      = Sig.Currency
                                                                                   and Mn.ReferenceType = Sig.ReferenceType
                                                                                   and Mn.DocumentType  = Sig.DocumentType
                                                                                   and Mn.DebitCredit   = Sig.DebitCredit
    left outer join zca_ops_flwrul                                          as Rul on  Rul.area     = Mn.Area
                                                                                   and Rul.flow_id  = Mn.FlowId
                                                                                   and Rul.rule_seq = Mn.RuleSeq
{
  key Sig.Area                                              as Area,
  key Sig.FlowId                                            as FlowId,
  key Sig.FlowAccount                                       as FlowAccount,
  key Sig.Currency                                          as Currency,
  key cast( coalesce( Rul.stage_id, 'OTHER' ) as abap.char( 20 ) ) as StageId,
  key cast( 'G' as abap.char( 1 ) )                         as LineSource,
  key cast( Sig.ReferenceType as abap.char( 5 ) )           as ReferenceType,
  key cast( Sig.DocumentType as abap.char( 2 ) )            as DocumentType,
  key cast( '' as abap.char( 2 ) )                          as Origin,
  key cast( '' as abap.char( 4 ) )                          as MainTransaction,
  key cast( '' as abap.char( 4 ) )                          as SubTransaction,
  key cast( Sig.DebitCredit as abap.char( 1 ) )             as DebitCredit,
      cast( coalesce( Rul.rule_id, '' ) as abap.char( 20 ) ) as RuleId,
      cast( case when Sig.LineSource = 'F' and Sig.ReferenceType = 'FKKSU' then 'X' else ' ' end as abap_boolean )
                                                            as IsMemo,
      cast( case when Sig.Amount > 0 then Sig.Amount else 0 end as abap.dec( 23, 2 ) ) as DebitAmount,
      cast( case when Sig.Amount < 0 then Sig.Amount * -1 else 0 end as abap.dec( 23, 2 ) ) as CreditAmount,
      Sig.Amount                                            as NetAmount,
      Sig.LineCount                                         as LineCount
}
union all
  select from       ZI_CA_OpsFlowFiSig( P_DateFrom : $parameters.P_DateFrom,
                                        P_DateTo   : $parameters.P_DateTo ) as Sig
    left outer join ZI_CA_OpsFlowFiMin( P_DateFrom : $parameters.P_DateFrom,
                                        P_DateTo   : $parameters.P_DateTo ) as Mn  on  Mn.Area            = Sig.Area
                                                                                   and Mn.FlowId          = Sig.FlowId
                                                                                   and Mn.FlowAccount     = Sig.FlowAccount
                                                                                   and Mn.Currency        = Sig.Currency
                                                                                   and Mn.DocumentType    = Sig.DocumentType
                                                                                   and Mn.Origin          = Sig.Origin
                                                                                   and Mn.MainTransaction = Sig.MainTransaction
                                                                                   and Mn.SubTransaction  = Sig.SubTransaction
                                                                                   and Mn.DebitCredit     = Sig.DebitCredit
    left outer join zca_ops_flwrul                                          as Rul on  Rul.area     = Mn.Area
                                                                                   and Rul.flow_id  = Mn.FlowId
                                                                                   and Rul.rule_seq = Mn.RuleSeq
{
  key Sig.Area                                              as Area,
  key Sig.FlowId                                            as FlowId,
  key Sig.FlowAccount                                       as FlowAccount,
  key Sig.Currency                                          as Currency,
  key cast( coalesce( Rul.stage_id, 'OTHER' ) as abap.char( 20 ) ) as StageId,
  key cast( 'F' as abap.char( 1 ) )                         as LineSource,
  key cast( '' as abap.char( 5 ) )                          as ReferenceType,
  key Sig.DocumentType                                      as DocumentType,
  key Sig.Origin                                            as Origin,
  key Sig.MainTransaction                                   as MainTransaction,
  key Sig.SubTransaction                                    as SubTransaction,
  key Sig.DebitCredit                                       as DebitCredit,
      cast( coalesce( Rul.rule_id, '' ) as abap.char( 20 ) ) as RuleId,
      cast( ' ' as abap_boolean )                           as IsMemo,
      cast( case when Sig.Amount > 0 then Sig.Amount else 0 end as abap.dec( 23, 2 ) ) as DebitAmount,
      cast( case when Sig.Amount < 0 then Sig.Amount * -1 else 0 end as abap.dec( 23, 2 ) ) as CreditAmount,
      Sig.Amount                                            as NetAmount,
      Sig.LineCount                                         as LineCount
}
