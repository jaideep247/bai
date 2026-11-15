// Artifact: zi_ca_opsflowglmin.ddls.asddls
// Purpose: Account flow reconciliation - first match of the journal signatures: for every signature of
//          ZI_CA_OpsFlowGlSig the lowest sequence of an active stage rule of its flow with line source G whose filled
//          criteria all hold (reference transaction, document type, debit / credit; a blank criterion matches any
//          value). Sequences are the key of the rules, so the first match is unique. A signature no rule matches has
//          no row here and goes to the row OTHER (ZI_CA_OpsFlowMove) - never hidden. Set-based on HANA over the
//          signatures (a few rows), never per journal line. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): OR of a literal comparison and a field comparison in an ON condition (7.58); MIN of a NUMC
//          column; a view with parameters passing them to its parameterised source.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: first rule of a journal line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowGlMin
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowGlSig( P_DateFrom : $parameters.P_DateFrom,
                                     P_DateTo   : $parameters.P_DateTo ) as Sig
    inner join   zca_ops_flwrul                                          as Rul
      on  Rul.area        = Sig.Area
      and Rul.flow_id     = Sig.FlowId
      and Rul.line_source = 'G'
      and Rul.active      = 'X'
      and ( Rul.ref_type     = '' or Rul.ref_type     = Sig.ReferenceType )
      and ( Rul.doc_type     = '' or Rul.doc_type     = Sig.DocumentType )
      and ( Rul.debit_credit = '' or Rul.debit_credit = Sig.DebitCredit )
{
  key Sig.Area                                              as Area,
  key Sig.FlowId                                            as FlowId,
  key Sig.FlowAccount                                       as FlowAccount,
  key Sig.Currency                                          as Currency,
  key Sig.ReferenceType                                     as ReferenceType,
  key Sig.DocumentType                                      as DocumentType,
  key Sig.DebitCredit                                       as DebitCredit,
      min( Rul.rule_seq )                                   as RuleSeq
}
group by
  Sig.Area,
  Sig.FlowId,
  Sig.FlowAccount,
  Sig.Currency,
  Sig.ReferenceType,
  Sig.DocumentType,
  Sig.DebitCredit
