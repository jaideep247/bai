@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables (all)'
define root view entity ZR_CD_OpsCfgAll
  as select from I_Language
    left outer join ZI_CD_OpsCfgChg as Chg on 0 = 0
  composition [0..*] of ZR_CD_ApprovedTable as _ApprovedTable
{
  key 1 as SingletonID,
      max( Chg.LastChangedAt ) as LastChangedAtMax,
      @EndUserText.label: 'Customizing request'
      cast( '' as trkorr ) as TransportRequestID,
      _ApprovedTable
}
where
  I_Language.Language = $session.system_language
