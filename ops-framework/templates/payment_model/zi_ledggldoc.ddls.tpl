// Artifact: zi_{{p}}_ledggldoc.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - the G/L documents of a subledger batch key: BKPF of the same company code
//          whose reference type is {{GL_REFTYPE}} and whose reference key is the batch's G/L reference key (adapter
//          ZI_{{P}}_LedgBatch) - the BKPF index on reference type + key, never a search of the journal. A reversed G/L
//          document (or a reversal document of the same reference) is listed with IsReversed; the totals leave it out.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
// VERIFY-SE11: BKPF AWTYP / AWKEY index; BKPF STBLG / STJAH (reversal), BLART, BUDAT, CPUDT, CPUTM.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - G/L documents of a batch key'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_LedgGlDoc
  as select distinct from ZI_{{P}}_LedgBatch as Bat
    inner join            bkpf               as Doc on  Doc.awtyp = '{{GL_REFTYPE}}'
                                                    and Doc.awkey = Bat.GlReferenceKey
                                                    and Doc.bukrs = Bat.CompanyCode
{
  key Bat.BatchKey,
  key Bat.CompanyCode,
  key Doc.gjahr                                             as FiscalYear,
  key Doc.belnr                                             as GlDocument,
      Bat.GlReferenceKey,
      Doc.blart                                             as DocumentType,
      Doc.budat                                             as PostingDate,
      Doc.cpudt                                             as EntryDate,
      Doc.cputm                                             as EntryTime,
      Doc.stblg                                             as ReversalDocument,
      Doc.stjah                                             as ReversalYear,
      cast( case when Doc.stblg = '' then ' ' else 'X' end as abap_boolean ) as IsReversed
}
