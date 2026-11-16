// Artifact: zi_ca_opsevalstatet.ddls.asddls
// Purpose: Texts of the evaluation state of a check run (OK, valid zero volume, not expected, period closed, source
//          stale, not evaluated, findings, partly evaluated): the fixed values of domain ZCA_OPS_EVAL_STATE in the
//          logon language from DD07L / DD07T (active version) - translated in SE63 like any domain, never a literal
//          of a view (build O, docs/EVALUATION_AND_COVERAGE.md). Read-only.
// Modification log: 2026-11-16 | Initial version (build O: evaluation state, delivery confirmation, coverage).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Evaluation state - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'EvaluationState'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsEvalStateT
  as select from dd07l as Val
    inner join   dd07t as Txt on  Txt.domname    = Val.domname
                              and Txt.as4local   = Val.as4local
                              and Txt.valpos     = Val.valpos
                              and Txt.as4vers    = Val.as4vers
                              and Txt.ddlanguage = $session.system_language
{
  key cast( Val.domvalue_l as zca_ops_eval_state )    as EvaluationState,
      @Semantics.language: true
  key Txt.ddlanguage                                      as Language,
      @Semantics.text: true
      cast( Txt.ddtext as abap.char( 60 ) )               as EvaluationStateText
}
where
      Val.domname  = 'ZCA_OPS_EVAL_STATE'
  and Val.as4local = 'A'
