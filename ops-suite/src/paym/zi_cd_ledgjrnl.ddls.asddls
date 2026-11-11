// Artifact: zi_cd_ledgjrnl.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - journal lines of the universal journal (ACDOCA) in the ledger of
//          ZI_CD_LedgCfg with every accounting attribute a reconciler needs on one row: ledger, company code, fiscal
//          year / period, document / line, document type, posting / document / entry date and time (BKPF), G/L account
//          and its text (SKAT in the chart of accounts of the company code, T001), posting key (BSEG line of the
//          journal line), debit / credit, amounts in transaction / company code / group currency each with its own
//          currency, assignment, item text, clearing document / date, profit center, segment, business area, cost
//          center, reference type / key, reversal (BKPF-STBLG, ACDOCA reversal flags). No WHERE: every consumer reads
//          it by the journal's primary key from keys in hand (company code, fiscal year, document of a G/L reference
//          read on BKPF) or by account and posting date of a reconciled account (the aggregated access path) - the
//          journal is never searched by a reference or a text. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
// VERIFY-SE11 (journal fields, documented in the consumer's VERIFY list): ACDOCA RLDNR, RBUKRS, GJAHR, BELNR, DOCLN,
//          BUZEI (= BSEG-BUZEI of the same document), POPER, RACCT, DRCRK, WSL / RWCUR, HSL / RHCUR, KSL / RKCUR, ZUONR,
//          SGTXT, AUGBL, AUGDT, PRCTR, SEGMENT, RBUSA, RCNTR, BUDAT, BLDAT, BLART, XREVERSING, XREVERSED; BKPF CPUDT,
//          CPUTM, AWTYP, AWKEY, STBLG, STJAH; BSEG BSCHL; T001 KTOPL; SKAT TXT50.
// VERIFY-ADT: left outer join on BSEG by BUZEI (a journal line without entry view line has no posting key).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - journal line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgJrnl
  as select from    acdoca          as Jrn
    inner join      ZI_CD_LedgCfg as Cfg on  Cfg.Ledger = Jrn.rldnr
    inner join      bkpf            as Doc on  Doc.bukrs = Jrn.rbukrs
                                           and Doc.belnr = Jrn.belnr
                                           and Doc.gjahr = Jrn.gjahr
    left outer join bseg            as Itm on  Itm.bukrs = Jrn.rbukrs
                                           and Itm.belnr = Jrn.belnr
                                           and Itm.gjahr = Jrn.gjahr
                                           and Itm.buzei = Jrn.buzei
    left outer join t001            as Cc  on  Cc.bukrs = Jrn.rbukrs
    left outer join skat            as Acc on  Acc.spras = $session.system_language
                                           and Acc.ktopl = Cc.ktopl
                                           and Acc.saknr = Jrn.racct
{
  key Jrn.rldnr                                             as Ledger,
  key Jrn.rbukrs                                            as CompanyCode,
  key Jrn.gjahr                                             as FiscalYear,
  key Jrn.belnr                                             as GlDocument,
  key Jrn.docln                                             as JournalLine,
      Jrn.buzei                                             as GlLineItem,
      Jrn.poper                                             as FiscalPeriod,
      Doc.blart                                             as DocumentType,
      Jrn.budat                                             as PostingDate,
      Doc.bldat                                             as DocumentDate,
      Doc.cpudt                                             as EntryDate,
      Doc.cputm                                             as EntryTime,
      Jrn.racct                                             as GlAccount,
      Acc.txt50                                             as GlAccountText,
      Itm.bschl                                             as PostingKey,
      Jrn.drcrk                                             as DebitCredit,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      Jrn.wsl                                               as AmountInTransCurrency,
      Jrn.rwcur                                             as TransactionCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      Jrn.hsl                                               as AmountInCompanyCurrency,
      Jrn.rhcur                                             as CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'GroupCurrency'
      Jrn.ksl                                               as AmountInGroupCurrency,
      Jrn.rkcur                                             as GroupCurrency,
      Jrn.zuonr                                             as Assignment,
      Jrn.sgtxt                                             as ItemText,
      Jrn.augbl                                             as ClearingDocument,
      Jrn.augdt                                             as ClearingDate,
      Jrn.prctr                                             as ProfitCenter,
      Jrn.segment                                           as Segment,
      Jrn.rbusa                                             as BusinessArea,
      Jrn.rcntr                                             as CostCenter,
      Doc.awtyp                                             as ReferenceType,
      Doc.awkey                                             as ReferenceKey,
      Doc.stblg                                             as ReversalDocument,
      Doc.stjah                                             as ReversalYear,
      // a line of a reversed document or of a reversal document is no transfer of the batch key any more
      cast( case when Doc.stblg <> '' or Jrn.xreversing = 'X' or Jrn.xreversed = 'X'
                 then 'X' else ' ' end as abap_boolean )    as IsReversal
}
