@EndUserText.label: 'File - manual status (action parameter)'
define abstract entity ZA_CD_FmonManual
{
  @EndUserText.label: 'Stage reached'
  Stage    : abap.char(20);
  @EndUserText.label: 'Reason'
  Reason   : abap.char(255);
  @EndUserText.label: 'Evidence (reference)'
  Evidence : abap.char(70);
}
