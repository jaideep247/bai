// Artifact: zi_ca_opscovstatet.ddls.asddls
// Purpose: Texts of the monitor coverage state of a registered check (ran, licence warning, impaired, not run,
//          refused, disabled): the fixed values of domain ZCA_OPS_COV_STATE in the logon language from DD07L / DD07T
//          (active version) - translated in SE63 like any domain, never a literal of a view (build O,
//          docs/EVALUATION_AND_COVERAGE.md). Read-only.
// Modification log: 2026-11-16 | Initial version (build O: evaluation state, delivery confirmation, coverage).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitor coverage state - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'CoverageState'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsCovStateT
  as select from dd07l as Val
    inner join   dd07t as Txt on  Txt.domname    = Val.domname
                              and Txt.as4local   = Val.as4local
                              and Txt.valpos     = Val.valpos
                              and Txt.as4vers    = Val.as4vers
                              and Txt.ddlanguage = $session.system_language
{
  key cast( Val.domvalue_l as zca_ops_cov_state )     as CoverageState,
      @Semantics.language: true
  key Txt.ddlanguage                                      as Language,
      @Semantics.text: true
      cast( Txt.ddtext as abap.char( 60 ) )               as CoverageStateText
}
where
      Val.domname  = 'ZCA_OPS_COV_STATE'
  and Val.as4local = 'A'
