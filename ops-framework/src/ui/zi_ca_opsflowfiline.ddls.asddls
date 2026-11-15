// Artifact: zi_ca_opsflowfiline.ddls.asddls
// Purpose: Account flow reconciliation - the lines of the FI-CA documents on a subledger-posted account (line source
//          F). FI-CA reaches the general ledger only summarised per reconciliation key (G/L transfer, reference
//          transaction FKKSU): the stage of a posting is not visible in the journal, it is a property of the FI-CA
//          document - its document type and origin key (DFKKKO) and the main / sub-transaction of the business partner
//          item. Three branches, signed as the journal (debit +, debit / credit S / H by the sign): P business partner items posted (DFKKOP, posting
//          date of the item, the item's own document), C business partner items cleared (DFKKOP with a clearing
//          document: the clearing date, the clearing document's type and origin - a payment run, a returns lot, a
//          reversal - and the amount reversed), K G/L items of the FI-CA documents (DFKKOPK: the subledger's other
//          accounts, e.g. clearing or clarification accounts FI-CA posts to). No released view covers these tables
//          on the target release: a direct table read, the clean-core exception the repository already documents.
//          Not filtered here: ZI_CA_OpsFlowFiSig restricts company code, account range and posting window (HANA pushes
//          the predicates into each branch). Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
//                   2026-11-15 | Comment: fields seen in the table definitions (V146).
// VERIFY-SE11 (V146): the sign of DFKKOPK-BETRW (debit +) and of DFKKOP-BETRW (signed as the receivable); a partial
//          clearing splits the item (the cleared part carries AUGBL) - otherwise branch C over-counts. Seen in the
//          landscape's table definitions (2026-11-15): DFKKKO-BLART / HERKF / WAERS / BUDAT, DFKKOP-AUGDT / BUKRS /
//          HKONT / WAERS / BETRW / BUDAT / AUGBL / HVORG / TVORG, DFKKOPK-BUKRS / HKONT / BETRW (no currency field:
//          the currency of the G/L items is DFKKKO-WAERS). VERIFY-ADT: a standard FI-CA CDS view for documents and items on
//          S/4HANA 2023 (none is confirmed in the repository; when one is C1 released, the branches move to it).
//          UNION ALL of typed literals (V112). PlanViz FLOW-PV3: DFKKOP / DFKKOPK by company code and account, the
//          clearing branch by clearing date - an index on (BUKRS, HKONT, AUGDT) may be needed.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: FI-CA document lines'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowFiLine
  as select from dfkkop as Op
    inner join   dfkkko as Ko on Ko.opbel = Op.opbel
{
  key cast( 'P' as abap.char( 1 ) )                         as LineKind,
  key Op.opbel                                              as FicaDocument,
      Op.bukrs                                              as CompanyCode,
      Op.hkont                                              as GLAccount,
      cast( Op.waers as abap.char( 5 ) )                    as Currency,
      Op.budat                                              as PostingDate,
      cast( Ko.blart as abap.char( 2 ) )                    as DocumentType,
      cast( Ko.herkf as abap.char( 2 ) )                    as Origin,
      cast( Op.hvorg as abap.char( 4 ) )                    as MainTransaction,
      cast( Op.tvorg as abap.char( 4 ) )                    as SubTransaction,
      cast( case when Op.betrw < 0 then 'H' else 'S' end as abap.char( 1 ) ) as DebitCredit,
      cast( Op.betrw as abap.dec( 23, 2 ) )                 as Amount
}
union all
  select from  dfkkop as Op
    inner join dfkkko as Ko on Ko.opbel = Op.augbl
{
  key cast( 'C' as abap.char( 1 ) )                         as LineKind,
  key Op.augbl                                              as FicaDocument,
      Op.bukrs                                              as CompanyCode,
      Op.hkont                                              as GLAccount,
      cast( Op.waers as abap.char( 5 ) )                    as Currency,
      Op.augdt                                              as PostingDate,
      cast( Ko.blart as abap.char( 2 ) )                    as DocumentType,
      cast( Ko.herkf as abap.char( 2 ) )                    as Origin,
      cast( Op.hvorg as abap.char( 4 ) )                    as MainTransaction,
      cast( Op.tvorg as abap.char( 4 ) )                    as SubTransaction,
      cast( case when Op.betrw < 0 then 'S' else 'H' end as abap.char( 1 ) ) as DebitCredit,
      cast( cast( Op.betrw as abap.dec( 23, 2 ) ) * -1 as abap.dec( 23, 2 ) ) as Amount
}
where
  Op.augbl <> ''
union all
  select from  dfkkopk as Gl
    inner join dfkkko  as Ko on Ko.opbel = Gl.opbel
{
  key cast( 'K' as abap.char( 1 ) )                         as LineKind,
  key Gl.opbel                                              as FicaDocument,
      Gl.bukrs                                              as CompanyCode,
      Gl.hkont                                              as GLAccount,
      cast( Ko.waers as abap.char( 5 ) )                    as Currency,
      Ko.budat                                              as PostingDate,
      cast( Ko.blart as abap.char( 2 ) )                    as DocumentType,
      cast( Ko.herkf as abap.char( 2 ) )                    as Origin,
      cast( '' as abap.char( 4 ) )                          as MainTransaction,
      cast( '' as abap.char( 4 ) )                          as SubTransaction,
      cast( case when Gl.betrw < 0 then 'H' else 'S' end as abap.char( 1 ) ) as DebitCredit,
      cast( Gl.betrw as abap.dec( 23, 2 ) )                 as Amount
}
