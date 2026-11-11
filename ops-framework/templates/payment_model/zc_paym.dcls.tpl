// Artifact: zc_{{p}}_paym.dcls.asdcls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Read access to the payment model of the {{CONSUMER}} (service {{SERVICE}}): the framework's company-code
//          rule (ops-framework/docs/auth_zca_ops.md) - authorisation object ZCA_OPS, area of the row ({{AREA}}; the
//          exception trend: the area of the finding) and company code, ACTVT 03. A row without company code is
//          area-level: area authorised is enough. Counts and amounts of a card are summed after the DCL ($apply), so a
//          user of one company code sees the totals of that company code (plus area-level rows) only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
// VERIFY-ADT: aspect pfcg_auth on a projection view (7.58); IS INITIAL in an access condition.
@EndUserText.label: 'Payment model - read access'
@MappingRole: true
define role ZC_{{P}}_PAYM {
#for ENTITY
  grant select on {{ENTITY}}
    where ( OpsArea ) = aspect pfcg_auth( ZCA_OPS, ZCA_PARAR, ACTVT = '03' )
      and ( CompanyCode is initial
         or ( OpsArea, CompanyCode ) = aspect pfcg_auth( ZCA_OPS, ZCA_PARAR, BUKRS, ACTVT = '03' ) );
#endfor
#if RECON
  grant select on ZI_{{P}}_LedgRcCube
    where ( OpsArea ) = aspect pfcg_auth( ZCA_OPS, ZCA_PARAR, ACTVT = '03' )
      and ( CompanyCode is initial
         or ( OpsArea, CompanyCode ) = aspect pfcg_auth( ZCA_OPS, ZCA_PARAR, BUKRS, ACTVT = '03' ) );
#endif
}
