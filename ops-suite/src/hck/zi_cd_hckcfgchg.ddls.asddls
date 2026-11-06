@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Health check setup: change stamps'
// Union of LAST_CHANGED_AT of every table of the app: total ETag of the singleton root.
// VERIFY-ADT: UNION in CDS view entities (ABAP platform 2023).
define view entity ZI_CD_HckCfgChg
  as select from zcd_hck_def
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_thresh
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_agg
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_drift
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_tabwl
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_job_cycle
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_job_step
  {
    last_changed_at as LastChangedAt
  }
