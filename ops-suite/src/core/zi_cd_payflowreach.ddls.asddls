// Artifact: zi_cd_payflowreach.ddls.asddls
// Purpose: Process flow - payments that REACHED a stage on a business date and company code: those now in the stage
//          or in a later stage of the same source (ZR_CD_PayLifecycle: the live status counts per configured stage).
//          The live status is the current one, so "reached" counts every later status; side branches (returned,
//          retrieved, stopped) count as having passed the earlier stages. Read-only.
// Modification log: 2026-11-11 | Initial version (process flow card of the overview page).
// VERIFY-ADT: comparison operator in the ON condition of an inner join (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process flow - reached per stage'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PayFlowReach
  as select from ZR_CD_PayLifecycle as Cur
    inner join   ZR_CD_PayLifecycle as Later on  Later.BusinessDate  =  Cur.BusinessDate
                                             and Later.CompanyCode   =  Cur.CompanyCode
                                             and Later.StageSource   =  Cur.StageSource
                                             and Later.StageSequence >= Cur.StageSequence
{
  key Cur.BusinessDate,
  key Cur.CompanyCode,
  key Cur.Stage,
      Cur.StageSequence,
      cast( sum( Later.PaymentCount ) as abap.int4 )        as ReachedCount
}
group by
  Cur.BusinessDate,
  Cur.CompanyCode,
  Cur.Stage,
  Cur.StageSequence
