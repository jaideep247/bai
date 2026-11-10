@EndUserText.label: 'Exception - classification (action parameter)'
define abstract entity ZA_CA_ExcClassify
{
  @EndUserText.label: 'Reason code (parameter EXC_REASON_CODES)'
  ReasonCode : abap.char(12);
  @EndUserText.label: 'Note'
  Reason     : abap.char(255);
}
