@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS rules and mapping (all)'
define root view entity ZR_CD_EbsCfgAll
  as select from I_Language
    left outer join ZI_CD_EbsCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CD_BtcRule as _BtcRule
  composition [0..*] of ZR_CD_RuleDef as _RuleDef
  composition [0..*] of ZR_CD_HouseBankAcct as _HouseBankAcct
  composition [0..*] of ZR_CD_FlowPattern as _FlowPattern
  composition [0..*] of ZR_CD_EbsLookup as _EbsLookup
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _BtcRule,
      _RuleDef,
      _HouseBankAcct,
      _FlowPattern,
      _EbsLookup
}
where
  I_Language.Language = $session.system_language
