@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'File monitoring setup (all)'
define root view entity ZR_CD_FmonCfgAll
  as select from I_Language
    left outer join ZI_CD_FmonCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CD_FmonIface as _FmonIface
  composition [0..*] of ZR_CD_FmonSla as _FmonSla
  composition [0..*] of ZR_CD_FmonDeadline as _FmonDeadline
  composition [0..*] of ZR_CD_FmonSource as _FmonSource
  composition [0..*] of ZR_CD_FmonSourceMap as _FmonSourceMap
  composition [0..*] of ZR_CD_FmonCheck as _FmonCheck
  composition [0..*] of ZR_CD_FmonLotCfg as _FmonLotCfg
  composition [0..*] of ZR_CD_FmonCalendar as _FmonCalendar
  composition [0..*] of ZR_CD_FmonTableAllow as _FmonTableAllow
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _FmonIface,
      _FmonSla,
      _FmonDeadline,
      _FmonSource,
      _FmonSourceMap,
      _FmonCheck,
      _FmonLotCfg,
      _FmonCalendar,
      _FmonTableAllow
}
where
  I_Language.Language = $session.system_language
