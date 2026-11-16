// Artifact: zi_ca_opscashjrnl.ddls.asddls
// Purpose: G/L document header of the FI-CA cash checks through SAP's released view I_JournalEntry (rule D-C8: the
//          G/L side reads released APIs) - company code, fiscal year, document, reference type and key (BKPF AWTYP /
//          AWKEY), posting date and the reverse document, nothing else. Read by ZCL_CA_OPS_CASH_DAO only: a
//          reconciliation key closed in FI-CA without an unreversed G/L document of the transfer reference type, the
//          key and the company code is a G/L transfer gap (check ZCL_CA_OPS_CHK_CASH_GLKEY). Why a view and not ABAP
//          SQL on I_JournalEntry: the released view's access control would restrict a background read to the
//          authorizations of the user running it, and a G/L document filtered away would be reported as a gap; this
//          view has no access control of its own and is not exposed by any service. Read-only.
// Modification log: 2026-11-15 | Initial version (build N: FI-CA cash coverage).
// VERIFY-ADT (V110, V229): I_JournalEntry release state C1 on 7.58; elements CompanyCode, FiscalYear,
//          AccountingDocument, ReferenceDocumentType (AWTYP), OriginalReferenceDocument (the full AWKEY), PostingDate,
//          ReverseDocument (STBLG). PlanViz CASH-PV6: the reference type + key + company code predicate reaches the
//          header's reference index (AWTYP + AWKEY) through the view.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI-CA cash: G/L document header'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCashJrnl
  as select from I_JournalEntry as Doc
{
  key Doc.CompanyCode               as CompanyCode,
  key Doc.FiscalYear                as FiscalYear,
  key Doc.AccountingDocument        as AccountingDocument,
      Doc.ReferenceDocumentType     as ReferenceDocumentType,
      Doc.OriginalReferenceDocument as OriginalReferenceDocument,
      Doc.PostingDate               as PostingDate,
      Doc.ReverseDocument           as ReverseDocument
}
