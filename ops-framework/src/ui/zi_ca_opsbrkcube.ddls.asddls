// Artifact: zi_ca_opsbrkcube.ddls.asddls
// Purpose: Clearing-account break analysis - analytical cube (embedded analytics: Analysis for Office,
//          multidimensional reports, the pilot pack): snapshot group x area x account x company code x key date x
//          bucket x currency with the measures amount, groups, lines, explained / unexplained groups and the oldest age.
//          The currency is a dimension: amounts are summed per currency only, never across. Rows of ZR_CA_OpsBrkGroup;
//          read access: DCL ZI_CA_OPSBRKCUBE (ZCA_OPS 03 for the area and the company code). Query: ZC_CA_OpsBrkQry.
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
// VERIFY-ADT: @Analytics.dataCategory #CUBE over a root view entity with joins (7.58), #MAX aggregation of AgeDays,
//             currency as dimension of DEC measures (no @Semantics.amount on DEC) - as the ledger model cube (V136).
// Extension point BRK_GROUP (2026-11-15, build H; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          passes the elements of the base view on; a customer adds its own elements with extend view entity from its package,
//          never by changing this view.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Clearing account breaks - cube'
@Analytics.dataCategory: #CUBE
@VDM.viewType: #COMPOSITE
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: false
@AbapCatalog.extensibility.dataSources: [ 'Grp' ]
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define view entity ZI_CA_OpsBrkCube
  as select from ZR_CA_OpsBrkGroup as Grp
{
  key Grp.SnapshotId,
  key Grp.GroupNo,
      Grp.Area,
      Grp.AccountId,
      Grp.CompanyCode,
      Grp.GLAccount,
      Grp.KeyDate,
      Grp.IsLatest,
      Grp.Bucket,
      Grp.BucketText,
      Grp.IsExplained,
      Grp.RuleId,
      Grp.Currency,
      @Aggregation.default: #SUM
      Grp.Amount,
      @Aggregation.default: #SUM
      Grp.GroupCount,
      @Aggregation.default: #SUM
      Grp.LineCount,
      @Aggregation.default: #SUM
      Grp.ExplainedCount,
      @Aggregation.default: #SUM
      Grp.UnexplainedCount,
      @Aggregation.default: #MAX
      Grp.AgeDays
}
