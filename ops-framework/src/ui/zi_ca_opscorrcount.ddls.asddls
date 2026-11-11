// Artifact: zi_ca_opscorrcount.ddls.asddls
// Purpose: Open correlated children per correlation group (ZCA_OPS_FINDING-CORR_ID, role C, disposition open or
//          assigned) - the number the parent shows in the exceptions app and its alert e-mail names. The company
//          code is part of every correlation key (ZCL_CA_OPS_CORRELATOR), so a group never mixes company codes
//          and its count is protected by the parent's company-code rule (docs/auth_zca_ops.md section 3c).
//          Index CRI (CORR_ID). Counted on the database, nothing stored. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: alert correlation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Open correlated exceptions per group'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCorrCount
  as select from zca_ops_finding
{
  key corr_id                                               as CorrelationId,
      cast( count( * ) as abap.int4 )                       as OpenChildren
}
where
      corr_role = 'C'
  and(
       disposition = 'O'
    or disposition = 'A'
  )
group by
  corr_id
