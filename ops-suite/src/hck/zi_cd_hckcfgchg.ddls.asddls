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
  select from zcd_hck_agggrp
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
union all
  select from zcd_hck_pmclass
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_pmbank
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_clrrule
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_evset
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_btcrole
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_seqout
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_hck_rcset
  {
    last_changed_at as LastChangedAt
  }
