// Artifact: zi_{{p}}_ledgrckey.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - the group-days of the group reconciliation: every business date x
//          company code x G/L account x currency that any leg has (journal, subledger, stored result, bank lines) -
//          UNION removes duplicates, so a day with only one leg still appears (a missing leg is visible as empty).
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
// VERIFY-ADT: UNION (distinct) of view entities with a SELECT DISTINCT first branch (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - reconciliation group-days'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_{{P}}_LedgRcKey
  as select distinct from ZI_{{P}}_LedgAcctDay
{
  key CompanyCode,
  key GlAccount,
  key Currency,
  key PostingDate                                           as BusinessDate
}
union select from ZI_{{P}}_LedgSubDay
{
  key CompanyCode,
  key GlAccount,
  key Currency,
  key PostingDate                                           as BusinessDate
}
#if RESULT
union select from ZI_{{P}}_LedgRcRes
{
  key CompanyCode,
  key GlAccount,
  key Currency,
  key BusinessDate
}
#endif
#if BANK
union select from ZI_{{P}}_LedgBankDay
{
  key CompanyCode,
  key GlAccount,
  key Currency,
  key BookingDate                                           as BusinessDate
}
#endif
