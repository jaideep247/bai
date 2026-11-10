@EndUserText.label: 'Control review - sign-off (action parameter)'
define abstract entity ZA_CA_CtlReview
{
  @EndUserText.label: 'Result (blank = derived status confirmed)'
  ReviewResult : zca_ops_ctl_status;
  @EndUserText.label: 'Observation'
  Observation  : abap.char(255);
  @EndUserText.label: 'Next action'
  NextAction   : abap.char(255);
}
