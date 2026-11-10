@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alerting, purge targets and controls: change stamps'
// Union of LAST_CHANGED_AT of every table of the app: total ETag of the singleton root.
// VERIFY-ADT: UNION in CDS view entities (ABAP platform 2023).
define view entity ZI_CA_OpsCfgChg
  as select from zca_ops_alrule
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_alchn
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_purge
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_control
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_ctlt
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_ctlchk
  {
    last_changed_at as LastChangedAt
  }
