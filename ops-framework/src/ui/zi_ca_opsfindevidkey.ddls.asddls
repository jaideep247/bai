// Artifact: zi_ca_opsfindevidkey.ddls.asddls
// Purpose: Exception contract - the company code of an evidence key (ZCA_OPS_FINDING-EVID_KEY is SHA-1 of area, check,
//          object key and company code, so every finding of a key has the same company code): lets the evidence rows
//          (ZC_CA_OpsFindEvidence) carry the company-code isolation of their finding. Read-only.
// Modification log: 2026-11-15 | Initial version (build K: exception contract).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company code of an evidence key'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFindEvidKey
  as select from zca_ops_finding as Fnd
{
  key Fnd.area                                              as Area,
  key Fnd.evid_key                                          as EvidenceKey,
  key Fnd.bukrs                                             as CompanyCode
}
where
  Fnd.evid_key <> ' '
group by
  Fnd.area,
  Fnd.evid_key,
  Fnd.bukrs
