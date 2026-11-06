// Artifact: zi_cd_ebsstmtlines.ddls.asddls
// Purpose: Number of lines and posted lines (FEBEP-BELNR filled) per imported statement of
//          ZI_CD_EbsLineBase (statement date in the last 31 days). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS lines per statement'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsStmtLines
  as select from ZI_CD_EbsLineBase
{
  key Kukey,
      cast( count( * ) as abap.int4 )                                       as LineCount,
      cast( sum( case IsPosted when 'X' then 1 else 0 end ) as abap.int4 )  as PostedLineCount
}
group by
  Kukey
