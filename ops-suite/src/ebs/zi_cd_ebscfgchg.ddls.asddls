@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS rules and mapping: change stamps'
// Union of LAST_CHANGED_AT of every table of the app: total ETag of the singleton root.
// VERIFY-ADT: UNION in CDS view entities (ABAP platform 2023).
define view entity ZI_CD_EbsCfgChg
  as select from zcd_btc_map
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_btc_rule
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ebs_rule_def
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ebs_acct
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ebs_flow_pat
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ebs_rsn_map
  {
    last_changed_at as LastChangedAt
  }
union all
  select from zcd_ebs_lookup
  {
    last_changed_at as LastChangedAt
  }
