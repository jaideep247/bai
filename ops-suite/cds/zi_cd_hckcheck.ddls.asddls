// Artifact: zi_cd_hckcheck.ddls.asddls
// Purpose: Dimension of health checks (ZCD_HCK_DEF): text, category and priority
//          for findings and metric cubes. Verify annotations on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Health check (dimension)'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #DIMENSION
@ObjectModel.representativeKey: 'CheckId'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckCheck
  as select from zcd_hck_def
{
  key check_id                                            as CheckId,
      @Semantics.text: true
      description                                         as CheckText,
      category                                            as Category,
      priority                                            as Priority,
      class_name                                          as ClassName,
      active                                              as IsActive
}
