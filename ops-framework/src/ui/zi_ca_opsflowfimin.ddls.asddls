// Artifact: zi_ca_opsflowfimin.ddls.asddls
// Purpose: Account flow reconciliation - first match of the FI-CA signatures: for every signature of
//          ZI_CA_OpsFlowFiSig the lowest sequence of an active stage rule of its flow with line source F whose filled
//          criteria all hold (FI-CA document type, origin key, main transaction, sub-transaction, debit / credit; a
//          blank criterion matches any value). A signature no rule matches goes to the row OTHER. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): as ZI_CA_OpsFlowGlMin (OR in an ON condition, MIN of a NUMC column).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: first rule of an FI-CA line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowFiMin
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowFiSig( P_DateFrom : $parameters.P_DateFrom,
                                     P_DateTo   : $parameters.P_DateTo ) as Sig
    inner join   zca_ops_flwrul                                          as Rul
      on  Rul.area        = Sig.Area
      and Rul.flow_id     = Sig.FlowId
      and Rul.line_source = 'F'
      and Rul.active      = 'X'
      and ( Rul.doc_type     = '' or Rul.doc_type     = Sig.DocumentType )
      and ( Rul.origin       = '' or Rul.origin       = Sig.Origin )
      and ( Rul.main_trans   = '' or Rul.main_trans   = Sig.MainTransaction )
      and ( Rul.sub_trans    = '' or Rul.sub_trans    = Sig.SubTransaction )
      and ( Rul.debit_credit = '' or Rul.debit_credit = Sig.DebitCredit )
{
  key Sig.Area                                              as Area,
  key Sig.FlowId                                            as FlowId,
  key Sig.FlowAccount                                       as FlowAccount,
  key Sig.Currency                                          as Currency,
  key Sig.DocumentType                                      as DocumentType,
  key Sig.Origin                                            as Origin,
  key Sig.MainTransaction                                   as MainTransaction,
  key Sig.SubTransaction                                    as SubTransaction,
  key Sig.DebitCredit                                       as DebitCredit,
      min( Rul.rule_seq )                                   as RuleSeq
}
group by
  Sig.Area,
  Sig.FlowId,
  Sig.FlowAccount,
  Sig.Currency,
  Sig.DocumentType,
  Sig.Origin,
  Sig.MainTransaction,
  Sig.SubTransaction,
  Sig.DebitCredit
