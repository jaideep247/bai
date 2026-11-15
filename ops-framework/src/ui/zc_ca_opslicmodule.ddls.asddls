// Artifact: zc_ca_opslicmodule.ddls.asddls
// Purpose: Licence dashboard - one row per licensable module of this release (ZCA_OPS_LICMOD, kind MOD, written at
//          the installation from the generated map ZCL_CA_OPS_LIC_MAP) with what the active licence grants
//          (ZCA_OPS_LICM): valid from / to, grace until (valid to + grace days of the licence), days left and the
//          state today - INCLUDED (CORE), LICENSED, EXPIRING (fewer days left than LIC_WARN_DAYS), GRACE, EXPIRED,
//          UNLICENSED - with its criticality (green / amber / red; a module never bought is neutral). Overview card
//          and list of service ZUI_CA_OPS_LIC. Display only: whether a module runs is decided at runtime from the
//          verified licence file (ZCL_CA_OPS_LIC_POLICY, the same rules). Read access: DCL ZC_CA_OPSLICMODULE.
// Modification log: 2026-11-15 | Initial version (licensing).
// VERIFY-ADT (V165): dats_add_days / dats_days_between with $session.system_date on 7.58; a cross join with the
//          one-row view ZI_CA_OpsLicCfg.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Licence modules'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MASTER }
define view entity ZC_CA_OpsLicModule
  as select from    zca_ops_licmod  as Modl
    cross join      ZI_CA_OpsLicCfg as Cfg
    left outer join zca_ops_licm    as Lm on  Lm.lic_uuid = Cfg.LicenseUuid
                                          and Lm.module   = Modl.module
{
      @ObjectModel.text.element: [ 'ModuleName' ]
  key Modl.module                                           as Module,
      cast( 'CA_OPS' as abap.char( 16 ) )                   as Area,
      Modl.description                                      as ModuleName,
      Modl.always                                           as IsAlwaysIncluded,
      Modl.seq                                              as Sequence,
      Cfg.LicenseId                                         as LicenseId,
      Lm.valid_from                                         as ValidFrom,
      Lm.valid_to                                           as ValidTo,
      dats_add_days( Lm.valid_to, Cfg.GraceDays, 'INITIAL' ) as GraceUntil,
      dats_days_between( $session.system_date, Lm.valid_to ) as DaysLeft,
      cast( case when Modl.always = 'X' then 'INCLUDED'
                 when Lm.module is null then 'UNLICENSED'
                 when Lm.valid_from > $session.system_date then 'UNLICENSED'
                 when Lm.valid_to >= $session.system_date
                  and dats_days_between( $session.system_date, Lm.valid_to ) < Cfg.WarnDays then 'EXPIRING'
                 when Lm.valid_to >= $session.system_date then 'LICENSED'
                 when dats_add_days( Lm.valid_to, Cfg.GraceDays, 'INITIAL' ) >= $session.system_date then 'GRACE'
                 else 'EXPIRED' end as abap.char( 10 ) )    as LicenseState,
      cast( case when Modl.always = 'X' then 3
                 when Lm.module is null then 0
                 when Lm.valid_from > $session.system_date then 0
                 when Lm.valid_to >= $session.system_date
                  and dats_days_between( $session.system_date, Lm.valid_to ) < Cfg.WarnDays then 2
                 when Lm.valid_to >= $session.system_date then 3
                 when dats_add_days( Lm.valid_to, Cfg.GraceDays, 'INITIAL' ) >= $session.system_date then 2
                 else 1 end as abap.int1 )                  as StateCriticality
}
where
  Modl.obj_kind = 'MOD'
