*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_xrun_calendar.intf.abap
*& Purpose:
*& Business calendar of the configured plan of expected runs (docs/
*& EXPECTED_RUNS_AND_MASS_ACTIVITIES.md section 2.2): is a date a day the
*& calendar of a scheduler row (ZCA_OPS_JOBSCH-CALENDAR_ID) expects runs?
*& Parameter XRUN_CALENDAR_CLASS names the class (interface checked by
*& RTTI). The core delivers no factory calendar reader of its own: blank
*& = the weekdays of the row only. The FI-CA Cash Operations pack delivers
*& ZCL_CA_OPS_MA_CALENDAR, which answers through the cash checks' factory
*& calendar (one calendar handling, not a second copy). Read only.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - expected runs business calendar</p>
INTERFACE zif_ca_ops_xrun_calendar
  PUBLIC.

  "! X = the calendar expects runs on the date
  "! @raising zcx_ca_ops_error | the calendar cannot answer for the date (the day is then unknown, never a holiday)
  METHODS is_business_day
    IMPORTING
      iv_calendar_id     TYPE zif_ca_ops_exc_contract=>ty_calendar_id
      iv_date            TYPE d
    RETURNING
      VALUE(rv_business) TYPE abap_bool
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
