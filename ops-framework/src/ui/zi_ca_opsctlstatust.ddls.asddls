// Artifact: zi_ca_opsctlstatust.ddls.asddls
// Purpose: Texts of the control status (Healthy, Watch, Action required): the fixed values of domain
//          ZCA_OPS_CTL_STATUS in the logon language - translated in SE63 like any domain, never a literal of a
//          view. Text association of the status in the review app and in the consumers' cards. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
//                   2026-11-16 | Fixed values from DD07L / DD07T by domain name (logon language, active version):
//                              | DDCDS_CUSTOMER_DOMAIN_VALUE_T returns nothing for a domain of a classic package
//                              | (reference system A4H, V27); element names unchanged.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control status - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'ControlStatus'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsCtlStatusT
  as select from dd07l as Val
    inner join   dd07t as Txt on  Txt.domname    = Val.domname
                              and Txt.as4local   = Val.as4local
                              and Txt.valpos     = Val.valpos
                              and Txt.as4vers    = Val.as4vers
                              and Txt.ddlanguage = $session.system_language
{
  key cast( Val.domvalue_l as zca_ops_ctl_status )        as ControlStatus,
      @Semantics.language: true
  key Txt.ddlanguage                                      as Language,
      @Semantics.text: true
      cast( Txt.ddtext as abap.char( 60 ) )               as StatusText
}
where
      Val.domname  = 'ZCA_OPS_CTL_STATUS'
  and Val.as4local = 'A'
