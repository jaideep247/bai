@EndUserText.label: 'Exception - waiver request (action parameter)'
define abstract entity ZA_CA_ExcWaiver
{
  @EndUserText.label: 'Reason'
  Reason  : abap.char(255);
  @EndUserText.label: 'Waived until'
  ValidTo : abap.dats;
}
