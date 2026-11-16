// Artifact: zi_ca_opsreopent.ddls.asddls
// Purpose: Texts of the reason a control sign-off was reopened (new finding, severity, amount, configuration
//          version, worse status): the fixed values of domain ZCA_OPS_REOPEN in the logon language - translated in SE63
//          like any domain. Text association of the reason in the review app. Read-only.
// Modification log: 2026-11-11 | Initial version (explainable, versioned results).
//                   2026-11-16 | Fixed values from DD07L / DD07T by domain name (logon language, active version):
//                              | DDCDS_CUSTOMER_DOMAIN_VALUE_T returns nothing for a domain of a classic package
//                              | (reference system A4H, V27); element names unchanged.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reopen reason - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'ReopenReason'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsReopenT
  as select from dd07l as Val
    inner join   dd07t as Txt on  Txt.domname    = Val.domname
                              and Txt.as4local   = Val.as4local
                              and Txt.valpos     = Val.valpos
                              and Txt.as4vers    = Val.as4vers
                              and Txt.ddlanguage = $session.system_language
{
  key cast( Val.domvalue_l as zca_ops_reopen )            as ReopenReason,
      @Semantics.language: true
  key Txt.ddlanguage                                      as Language,
      @Semantics.text: true
      cast( Txt.ddtext as abap.char( 60 ) )               as ReopenText
}
where
      Val.domname  = 'ZCA_OPS_REOPEN'
  and Val.as4local = 'A'
