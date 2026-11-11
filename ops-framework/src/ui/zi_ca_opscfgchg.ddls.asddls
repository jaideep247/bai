@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Processes, checks, alerting, purge targets and controls: change stamps'
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
union all
  select from zca_ops_proc
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_check
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_agg
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_tabwl
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_pmdim
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_feeder
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_jobsch
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_runbook
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_corr
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_lnklyr
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_lnkobj
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_lnkfld
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_link
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_lnkcnd
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_lnkact
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_catpkg
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_catprc
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_catstp
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_cattab
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_catdep
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_catact
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_brkacc
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_brkbkt
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_brkrul
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_brkcnd
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zca_ops_pilotbl
  {
    last_changed_at as LastChangedAt
  }
