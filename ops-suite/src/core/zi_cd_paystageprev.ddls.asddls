// Artifact: zi_cd_paystageprev.ddls.asddls
// Purpose: Process flow - the previous active stage of every active payment lifecycle stage of the same source
//          (ZCD_OPS_PAYSTAGE, order SEQ): the stage the flow card measures the drop from. The first stage of a source
//          has no row. Read-only.
// Modification log: 2026-11-11 | Initial version (process flow card of the overview page).
// VERIFY-ADT: comparison operator in the ON condition of an inner join (7.58), as ZI_CD_PayLifeRun.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process flow - previous stage'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CD_PayStagePrev
  as select from zcd_ops_paystage as Stage
    inner join   zcd_ops_paystage as Prev on  Prev.source = Stage.source
                                          and Prev.active = 'X'
                                          and Prev.seq    < Stage.seq
{
  key Stage.stage                                           as Stage,
      max( Prev.seq )                                       as PrevSequence
}
where
  Stage.active = 'X'
group by
  Stage.stage
