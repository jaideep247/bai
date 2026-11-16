@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Parameter kind (value help)'
@ObjectModel.resultSet.sizeCategory: #XS
@Metadata.ignorePropagatedAnnotations: true
// Fixed values of domain ZCA_PARAM_KIND from DD07L, texts from DD07T in the logon language (active version).
// Modification log: 2026-11-16 | DD07L / DD07T instead of DDCDS_CUSTOMER_DOMAIN_VALUE_T, which returns nothing for a
//                              | domain of a classic package (reference system A4H, A15); element names unchanged.
define view entity ZI_CA_ParamKindVH
  as select from    dd07l as Val
    left outer join dd07t as Txt on  Txt.domname    = Val.domname
                                 and Txt.as4local   = Val.as4local
                                 and Txt.valpos     = Val.valpos
                                 and Txt.as4vers    = Val.as4vers
                                 and Txt.ddlanguage = $session.system_language
{
      @ObjectModel.text.element: ['Description']
  key Val.domvalue_l as Kind,
      @Semantics.text: true
      Txt.ddtext     as Description
}
where
      Val.domname  = 'ZCA_PARAM_KIND'
  and Val.as4local = 'A'
