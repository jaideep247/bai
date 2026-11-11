// Artifact: zi_cd_opsglitem.ddls.asddls
// Purpose: G/L document line of the entry view (BSEG) for the suite's key reads through SAP's released view
//          I_OperationalAcctgDocItem (decision D-C8: the G/L side reads released APIs) - company code, document,
//          fiscal year, line, G/L account, reference key 2 (BSEG-XREF2 = DFKKOP-AUGBL, confirmed), clearing document
//          and date, nothing else. The entry view and not the journal (I_JournalEntryItem): XREF2 is a field of the
//          entry view line, and a journal line is per ledger (and may be split) - the line count of a document stays
//          the BSEG count. Read only by document key (company code + document + fiscal year from keys in hand):
//          ZCL_CD_EBS_SAP_DAO=>GET_FI_LINES (rule R19, FI document of a statement line) and
//          ZCL_CD_OPS_TRACE_DAO=>GET_GL_CLEARING_LINES (clearing line of a payment's G/L transfer document, with the
//          XREF2 value). Never searched by XREF2 or clearing document - those reads stay on the table (no index,
//          Performance_Review.md section 14). Why a view and not ABAP SQL on I_OperationalAcctgDocItem: the released
//          view's access control (DCL) would restrict a direct ABAP SQL read to the authorizations of the user running
//          it (EBS validation and payment trace run as jobs) and a line filtered away would read as "document not
//          found"; this view has no access control of its own and is read only by the DAOs. Read-only.
// Modification log: 2026-11-11 | Initial version (decision D-C8 extended to the suite's G/L reads: replaces the BSEG
//                              | key reads of the EBS and trace DAOs).
// VERIFY-ADT (VERIFY_Suite.md V123): I_OperationalAcctgDocItem release state C1 on 7.58; elements CompanyCode,
//          AccountingDocument, FiscalYear, AccountingDocumentItem (BUZEI), GLAccount (HKONT),
//          Reference2IDByBusinessPartner (XREF2), ClearingAccountingDocument (AUGBL), ClearingDate (AUGDT); every BSEG
//          line of a document is a row of the view (no filter on line type or document status). Fallback if an element
//          is missing or named differently: rename it here only (the DAOs read this view's names); if XREF2 is not
//          exposed, GET_GL_CLEARING_LINES goes back to the table read (same SQL as before 2026-11-11) and the view
//          drops the element. PlanViz GLV-PV1 / GLV-PV4 (Performance_Review.md section 14): the document key reaches
//          the BSEG primary key (BUKRS, BELNR, GJAHR) through the view.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ops G/L entry view line (released view)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_OpsGlItem
  as select from I_OperationalAcctgDocItem as Itm
{
  key Itm.CompanyCode                                       as CompanyCode,
  key Itm.AccountingDocument                                as AccountingDocument,
  key Itm.FiscalYear                                        as FiscalYear,
  key Itm.AccountingDocumentItem                            as AccountingDocumentItem,
      Itm.GLAccount                                         as GLAccount,
      Itm.Reference2IDByBusinessPartner                     as Reference2IDByBusinessPartner,
      Itm.ClearingAccountingDocument                        as ClearingAccountingDocument,
      Itm.ClearingDate                                      as ClearingDate
}
