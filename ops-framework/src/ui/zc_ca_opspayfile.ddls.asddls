// Artifact: zc_ca_opspayfile.ddls.asddls
// Purpose: Consumption view of the payment file worklist (list report "Payment files", service ZUI_CA_OPS_PAYFILE): one
//          row per file and currency with the stage reached, next milestone, state, payments, amount with its currency,
//          payments without a known amount, duplicate exposure, deadline and minutes overdue, owner, age and the
//          evaluation; object page with the affected payments, the stage timeline and the evidence (navigation to the
//          exceptions app, the job app and a payment trace by intent). Read access: DCL ZC_CA_OPSPAYFILE (ZCA_OPS 03 for
//          the area and the company code). Read-only; exportable.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
// Extension point PAYFILE (2026-11-15; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          passes the elements of the base view on; a customer adds its own elements with extend view entity from its package,
//          never by changing this view.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment files'
@Metadata.allowExtensions: true
@Search.searchable: true
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: false
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define root view entity ZC_CA_OpsPayFile
  provider contract transactional_query
  as projection on ZR_CA_OpsPayFile
{
  key Area,
  key FileId,
  key Currency,
      FileType,
      FileTypeName,
      @Search.defaultSearchElement: true
      NativeKey,
      ObjectKey,
      CompanyCode,
      SourceId,
      RunDate,
      @Search.defaultSearchElement: true
      RunId,
      PaymentMethod,
      HouseBank,
      HouseBankAccount,
      BusinessDate,
      GeneratedAt,
      JobName,
      JobCount,
      StageReached,
      NextMilestone,
      State,
      StateCriticality,
      DeadlineAt,
      OverdueMinutes,
      CalendarId,
      AgeDays,
      PaymentCount,
      Amount,
      UnknownCount,
      DuplicateCount,
      DuplicateAmount,
      FilePaymentCount,
      PaymentsCut,
      AckLevel,
      AckConflict,
      PaymentsRejected,
      PaymentsUnanswered,
      LateMilestone,
      LateMinutes,
      EvaluationState,
      EvaluationReason,
      EvaluatedAt,
      LastValidAt,
      LastValidState,
      PredecessorId,
      PredecessorKey,
      TicketReference,
      ProcessId,
      ProcessOwner,
      @EndUserText.label: 'Open exceptions'
      _OpenExc.OpenExceptions  as OpenExceptions,
      @EndUserText.label: 'Exception (check code)'
      _OpenExc.CheckCode       as ExceptionCode,
      @EndUserText.label: 'Responsible user'
      _OpenExc.ResponsibleUser as ResponsibleUser,
      @EndUserText.label: 'Responsible team'
      _OpenExc.ResponsibleTeam as ResponsibleTeam,
      @EndUserText.label: 'Assigned to'
      _OpenExc.AssignedTo      as AssignedTo,
      _Payments   : redirected to ZC_CA_OpsPfPayment,
      _Milestones : redirected to ZC_CA_OpsPfMilestone,
      _Evidence   : redirected to ZC_CA_OpsPfEvidence
}
