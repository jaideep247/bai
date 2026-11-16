*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ma_calendar.clas.abap
*& Purpose:
*& Business calendar of the expected runs for a site with the FI-CA Cash
*& Operations pack (ZIF_CA_OPS_XRUN_CALENDAR, parameter XRUN_CALENDAR_
*& CLASS): answers through the cash checks' factory calendar (ZIF_CA_OPS_
*& CASH_DAO=>WORKING_DAY - the one calendar handling of the pack, not a
*& second copy of its function call). A calendar that cannot answer
*& raises: the day is then unknown, never a holiday. Read only.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA mass activities - business calendar of expected runs</p>
CLASS zcl_ca_ops_ma_calendar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_xrun_calendar.

ENDCLASS.



CLASS zcl_ca_ops_ma_calendar IMPLEMENTATION.

  METHOD zif_ca_ops_xrun_calendar~is_business_day.
    rv_business = zcl_ca_ops_cash_factory=>get_dao( )->working_day( iv_date     = iv_date
                                                                     iv_calendar = iv_calendar_id ).
  ENDMETHOD.

ENDCLASS.
