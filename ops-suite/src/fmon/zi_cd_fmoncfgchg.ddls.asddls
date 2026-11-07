@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'File monitoring setup: change stamps'
// Union of LAST_CHANGED_AT of every table of the app: total ETag of the singleton root.
// VERIFY-ADT: UNION in CDS view entities (ABAP platform 2023).
define view entity ZI_CD_FmonCfgChg
  as select from zcd_fmon_iface
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_sla
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_deadl
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_src
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_srcmap
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_chk
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_lotcfg
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_cal
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_fmon_tabwl
  {
    last_changed_at as LastChangedAt
  }
