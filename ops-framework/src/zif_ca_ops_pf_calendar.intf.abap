*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_calendar.intf.abap
*& Purpose:
*& Business calendar of the payment file lifecycle (role CALENDAR):
*& whether a date is a business day of a calendar and the n-th business
*& day after a date - deadlines with a day offset, the business date of a
*& file generated on a holiday or after the overnight cut-off, the days a
*& file is expected. Delivered: ZCL_CA_OPS_PF_CALENDAR (SAP factory
*& calendar); a site may plug its own (its bank's holiday table).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file business calendar</p>
INTERFACE zif_ca_ops_pf_calendar
  PUBLIC.

  INTERFACES zif_ca_ops_pf_adapter.

  "! The date is a business day of the calendar
  "! @raising zcx_ca_ops_error | 393 the calendar cannot answer for the date
  METHODS is_business_day
    IMPORTING
      iv_calendar_id     TYPE zif_ca_ops_exc_contract=>ty_calendar_id
      iv_date            TYPE d
    RETURNING
      VALUE(rv_business) TYPE abap_bool
    RAISING
      zcx_ca_ops_error.

  "! The business day iv_days business days after iv_date (0 = iv_date when it is one, else the next)
  "! @raising zcx_ca_ops_error | 393 the calendar cannot answer for the date
  METHODS add_business_days
    IMPORTING
      iv_calendar_id TYPE zif_ca_ops_exc_contract=>ty_calendar_id
      iv_date        TYPE d
      iv_days        TYPE i
    RETURNING
      VALUE(rv_date) TYPE d
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
