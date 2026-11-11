@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables and payment stages: change stamps'
// Union of LAST_CHANGED_AT of every table of the app: total ETag of the singleton root.
// VERIFY-ADT: UNION in CDS view entities (ABAP platform 2023).
define view entity ZI_CD_OpsCfgChg
  as select from zcd_ops_tabwl
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ops_paystage
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ops_svc
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ops_svcmap
  {
    last_changed_at as LastChangedAt
  }
