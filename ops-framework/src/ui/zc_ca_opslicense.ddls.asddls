// Artifact: zc_ca_opslicense.ddls.asddls
// Purpose: Licence dashboard - the installed licences of ZCA_OPS_LIC: the active one and the history (replaced rows
//          are kept, never purged): licence ID, customer, bound installations and systems, product versions, grace
//          days, issue time, signer, who installed it and when, when it was replaced. The file itself (CONTENT) is
//          not exposed. List of service ZUI_CA_OPS_LIC. Read access: DCL ZC_CA_OPSLICENSE.
// Modification log: 2026-11-15 | Initial version (licensing).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Installed licences'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MASTER }
define view entity ZC_CA_OpsLicense
  as select from zca_ops_lic as Lic
{
  key Lic.lic_uuid                                          as LicenseUuid,
      cast( 'CA_OPS' as abap.char( 16 ) )                   as Area,
      Lic.license_id                                        as LicenseId,
      Lic.customer                                          as Customer,
      Lic.active                                            as IsActive,
      Lic.state                                             as StateAtInstall,
      Lic.installations                                     as Installations,
      Lic.systems                                           as Systems,
      Lic.version_from                                      as VersionFrom,
      Lic.version_to                                        as VersionTo,
      Lic.grace_days                                        as GraceDays,
      Lic.issued_at                                         as IssuedAt,
      Lic.signer                                            as Signer,
      Lic.file_name                                         as FileName,
      Lic.installed_by                                      as InstalledBy,
      Lic.installed_at                                      as InstalledAt,
      Lic.replaced_at                                       as ReplacedAt,
      cast( case when Lic.active = 'X' then 3 else 0 end as abap.int1 ) as ActiveCriticality
}
