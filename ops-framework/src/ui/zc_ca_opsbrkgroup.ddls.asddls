// Artifact: zc_ca_opsbrkgroup.ddls.asddls
// Purpose: Consumption view of the clearing-account breaks (list report "Clearing account breaks", service
//          ZUI_CA_OPS_BRK): groups with the variance bucket as a column, amount per currency, age, rule and reason,
//          reconciliation key; object page with the lines (_Items). Read access: DCL ZC_CA_OPSBRKGROUP (ZCA_OPS 03 for
//          the area and the company code). Read-only; the list can be exported (Fiori elements Export to Spreadsheet).
// Modification log: 2026-11-11 | Initial version (build F: clearing-account break analysis).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Clearing account breaks'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_CA_OpsBrkGroup
  provider contract transactional_query
  as projection on ZR_CA_OpsBrkGroup
{
  key SnapshotId,
  key GroupNo,
      Area,
      @Search.defaultSearchElement: true
      AccountId,
      CompanyCode,
      GLAccount,
      Ledger,
      KeyDate,
      IsLatest,
      SnapshotStatus,
      ConfigVersion,
      @Search.defaultSearchElement: true
      Assignment,
      Currency,
      Amount,
      LineCount,
      FirstDate,
      LastDate,
      AgeDays,
      LaterAmount,
      ClearsLater,
      LaterDate,
      @ObjectModel.text.element: [ 'BucketText' ]
      Bucket,
      BucketText,
      IsExplained,
      RuleId,
      Reason,
      @Search.defaultSearchElement: true
      ReconKey,
      BucketCriticality,
      GroupCount,
      ExplainedCount,
      UnexplainedCount,
      _Items : redirected to ZC_CA_OpsBrkItem
}
