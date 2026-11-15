@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow stage rules'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_FlowStageRule
  as select from zca_ops_flwrul
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Account flow'
  key flow_id as FlowId,
      @EndUserText.label: 'Sequence (first match wins)'
  key rule_seq as RuleSeq,
      1 as SingletonID,
      @EndUserText.label: 'Rule ID'
      rule_id as RuleId,
      @EndUserText.label: 'Stage'
      stage_id as StageId,
      @EndUserText.label: 'Lines from (G journal, F FI-CA documents)'
      line_source as LineSource,
      @EndUserText.label: 'Reference transaction (AWTYP)'
      ref_type as RefType,
      @EndUserText.label: 'Document type (journal or FI-CA)'
      doc_type as DocType,
      @EndUserText.label: 'FI-CA origin key'
      origin as Origin,
      @EndUserText.label: 'FI-CA main transaction'
      main_trans as MainTrans,
      @EndUserText.label: 'FI-CA sub-transaction'
      sub_trans as SubTrans,
      @EndUserText.label: 'Debit / credit (S, H, blank = both)'
      debit_credit as DebitCredit,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Active'
      active as Active,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _OpsCfgAll
}
