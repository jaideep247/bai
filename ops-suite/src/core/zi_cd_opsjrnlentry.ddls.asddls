// Artifact: zi_cd_opsjrnlentry.ddls.asddls
// Purpose: G/L document header of the suite's ABAP SQL reads through SAP's released view I_JournalEntry (decision
//          D-C8: the G/L side reads released APIs) - company code, fiscal year, document, reference type and key
//          (BKPF AWTYP / AWKEY), posting date, entry date / time (CPUDT / CPUTM) and the reverse document (STBLG),
//          nothing else. Read by the reference of a payment engine G/L transfer (reference type FKKSU + FIKEY + company
//          code): ZCL_CD_HCK_DAO (A_GL_TRANSFER / A_DOC_CHANGE: reconciliation keys without an unreversed G/L
//          document) and ZCL_CD_OPS_TRACE_DAO (G/L documents of a payment's FIKEY) - the predicate of the ledger
//          model's ZI_CD_LedgGlDoc, so the gap check, the trace and the batch key status read one source. Why a view
//          and not ABAP SQL on I_JournalEntry: the released view's access control (DCL) would restrict a direct ABAP
//          SQL read to the authorizations of the user running it (the background user of the morning report), and a
//          G/L document filtered away would be reported as a transfer gap; this view has no access control of its own
//          and is read only by the DAOs. Read-only.
// Modification log: 2026-11-11 | Initial version (decision D-C8 extended to the suite's G/L reads: replaces the BKPF
//                              | reads by reference of the DAOs).
// VERIFY-ADT (VERIFY_Suite.md V123; elements as framework VERIFY.md V110): I_JournalEntry release state C1 on 7.58;
//          elements CompanyCode, FiscalYear, AccountingDocument, ReferenceDocumentType (AWTYP),
//          OriginalReferenceDocument (the full AWKEY), PostingDate, AccountingDocumentCreationDate (CPUDT), CreationTime
//          (CPUTM), ReverseDocument (STBLG); every BKPF row is a row of the view (no filter on document status).
//          PlanViz GLV-PV2 / GLV-PV3 (Performance_Review.md section 14): the reference type + key + company code
//          predicate reaches the header's reference index (AWTYP + AWKEY) through the view.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ops G/L document header (released view)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_OpsJrnlEntry
  as select from I_JournalEntry as Doc
{
  key Doc.CompanyCode                                       as CompanyCode,
  key Doc.FiscalYear                                        as FiscalYear,
  key Doc.AccountingDocument                                as AccountingDocument,
      Doc.ReferenceDocumentType                             as ReferenceDocumentType,
      Doc.OriginalReferenceDocument                         as OriginalReferenceDocument,
      Doc.PostingDate                                       as PostingDate,
      Doc.AccountingDocumentCreationDate                    as AccountingDocumentCreationDate,
      Doc.CreationTime                                      as CreationTime,
      Doc.ReverseDocument                                   as ReverseDocument
}
