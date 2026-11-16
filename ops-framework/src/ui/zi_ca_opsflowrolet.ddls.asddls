// Artifact: zi_ca_opsflowrolet.ddls.asddls
// Purpose: Account flow reconciliation - roles of an account: fixed values of domain ZCA_OPS_FLOW_ROLE with their
//          texts in the logon language (DD07L / DD07T, as ZI_CA_OpsReopenT) - the text of AccountRole in
//          the cube and the cards. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
//                   2026-11-16 | Fixed values from DD07L / DD07T by domain name (logon language, active version):
//                              | DDCDS_CUSTOMER_DOMAIN_VALUE_T returns nothing for a domain of a classic package
//                              | (reference system A4H, V27); element names unchanged.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow role - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'AccountRole'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsFlowRoleT
  as select from dd07l as Val
    inner join   dd07t as Txt on  Txt.domname    = Val.domname
                              and Txt.as4local   = Val.as4local
                              and Txt.valpos     = Val.valpos
                              and Txt.as4vers    = Val.as4vers
                              and Txt.ddlanguage = $session.system_language
{
  key cast( Val.domvalue_l as zca_ops_flow_role )         as AccountRole,
      @Semantics.language: true
  key Txt.ddlanguage                                      as Language,
      @Semantics.text: true
      cast( Txt.ddtext as abap.char( 60 ) )               as AccountRoleText
}
where
      Val.domname  = 'ZCA_OPS_FLOW_ROLE'
  and Val.as4local = 'A'
