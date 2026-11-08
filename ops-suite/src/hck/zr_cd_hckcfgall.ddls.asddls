@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Health check setup (all)'
define root view entity ZR_CD_HckCfgAll
  as select from I_Language
    left outer join ZI_CD_HckCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CD_HckCheckDef as _HckCheckDef
  composition [0..*] of ZR_CD_HckThreshold as _HckThreshold
  composition [0..*] of ZR_CD_HckAggregate as _HckAggregate
  composition [0..*] of ZR_CD_JobCycle as _JobCycle
  composition [0..*] of ZR_CD_JobStep as _JobStep
  composition [0..*] of ZR_CD_HckClrRule as _HckClrRule
  composition [0..*] of ZR_CD_HckSeqOutcome as _HckSeqOutcome
  composition [0..*] of ZR_CD_HckReconSet as _HckReconSet
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _HckCheckDef,
      _HckThreshold,
      _HckAggregate,
      _JobCycle,
      _JobStep,
      _HckClrRule,
      _HckSeqOutcome,
      _HckReconSet
}
where
  I_Language.Language = $session.system_language
