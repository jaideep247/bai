// Artifact: zi_cd_opscompanycode.ddls.asddls
// Purpose: Company code of the suite's ABAP SQL reads through SAP's released view I_CompanyCode (decision D-C8: the
//          G/L and company code side reads released APIs) - company code, country and currency, nothing else (T001
//          BUKRS, LAND1, WAERS). Used where a DAO needs the country of a company code to reach the payment method
//          table TFK042Z (key LAND1 / ZLSCH: collections vs disbursements): ZCL_CD_HCK_RUNTIME_DAO (issued payments),
//          ZCL_CD_OPS_PAY_OUTCOME_DAO (versions, groups, examples, rows of the worklist), ZCL_CD_OPS_TRACE_DAO
//          (method kind). Why a view and not ABAP SQL on I_CompanyCode: these reads run in jobs (morning report,
//          5-minute snapshot); if the released view carries access control (DCL) on the release, a direct ABAP SQL
//          read would apply it to the background user and silently drop company codes - a payment would lose its
//          direction. This view has no access control of its own (a control reads every company code, as the table
//          read did) and is read only by the DAOs. CDS views of the suite join I_CompanyCode directly (the DCL of a
//          source is not inherited). Read-only.
// Modification log: 2026-11-11 | Initial version (decision D-C8 extended to the suite's G/L / company code reads:
//                              | replaces the T001 joins of the DAOs).
// VERIFY-ADT (VERIFY_Suite.md V123): I_CompanyCode release state C1 on 7.58; elements CompanyCode, Country, Currency
//          (= T001 BUKRS, LAND1, WAERS); one row per company code. If I_CompanyCode has no DCL on the release, this
//          view is still kept (one access path for the DAOs and their test doubles).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ops company code (released view)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
@VDM.viewType: #BASIC
define view entity ZI_CD_OpsCompanyCode
  as select from I_CompanyCode as Cc
{
  key Cc.CompanyCode                                        as CompanyCode,
      Cc.Country                                            as Country,
      Cc.Currency                                           as Currency
}
