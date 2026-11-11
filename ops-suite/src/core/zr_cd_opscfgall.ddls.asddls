@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables and payment stages (all)'
define root view entity ZR_CD_OpsCfgAll
  as select from I_Language
    left outer join ZI_CD_OpsCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CD_ApprovedTable as _ApprovedTable
  composition [0..*] of ZR_CD_PayStage as _PayStage
  composition [0..*] of ZR_CD_Service as _Service
  composition [0..*] of ZR_CD_ServiceMap as _ServiceMap
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _ApprovedTable,
      _PayStage,
      _Service,
      _ServiceMap
}
where
  I_Language.Language = $session.system_language
