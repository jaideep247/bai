@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Health check setup (all)'
define root view entity ZR_CD_HckCfgAll
  as select from I_Language
    left outer join ZI_CD_HckCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CD_HckCheckDef as _HckCheckDef
  composition [0..*] of ZR_CD_HckThreshold as _HckThreshold
  composition [0..*] of ZR_CD_HckAggregate as _HckAggregate
  composition [0..*] of ZR_CD_HckAggGroup as _HckAggGroup
  composition [0..*] of ZR_CD_HckDriftTable as _HckDriftTable
  composition [0..*] of ZR_CD_HckWhitelist as _HckWhitelist
  composition [0..*] of ZR_CD_JobCycle as _JobCycle
  composition [0..*] of ZR_CD_JobStep as _JobStep
  composition [0..*] of ZR_CD_HckPmClass as _HckPmClass
  composition [0..*] of ZR_CD_HckPmBank as _HckPmBank
  composition [0..*] of ZR_CD_HckClrRule as _HckClrRule
  composition [0..*] of ZR_CD_HckEvidenceSet as _HckEvidenceSet
  composition [0..*] of ZR_CD_HckBtcRole as _HckBtcRole
  composition [0..*] of ZR_CD_HckSeqOutcome as _HckSeqOutcome
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _HckCheckDef,
      _HckThreshold,
      _HckAggregate,
      _HckAggGroup,
      _HckDriftTable,
      _HckWhitelist,
      _JobCycle,
      _JobStep,
      _HckPmClass,
      _HckPmBank,
      _HckClrRule,
      _HckEvidenceSet,
      _HckBtcRole,
      _HckSeqOutcome
}
where
  I_Language.Language = $session.system_language
