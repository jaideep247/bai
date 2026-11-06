*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_calendar.intf.abap
*& Purpose:
*& Factory calendar seam (banking days). The implementation is the only
*& place that calls the standard factory calendar function payment engine areas.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A41: age basis (strictly after receipt / next working day).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - factory calendar (banking days)</p>
INTERFACE zif_cd_fmon_calendar
  PUBLIC.

  METHODS is_working_day
    IMPORTING
      iv_date           TYPE d
      iv_calendar_id    TYPE zif_cd_fmon_types=>ty_fcal_id
    RETURNING
      VALUE(rv_working) TYPE abap_bool
    RAISING
      zcx_cd_ops_error.

  "! iv_date is the last working day of its month
  METHODS is_month_end
    IMPORTING
      iv_date             TYPE d
      iv_calendar_id      TYPE zif_cd_fmon_types=>ty_fcal_id
    RETURNING
      VALUE(rv_month_end) TYPE abap_bool
    RAISING
      zcx_cd_ops_error.

  "! Banking days elapsed from iv_from (receipt) to iv_to; never negative.
  "! iv_basis A (default) = working days strictly after receipt (a non-working receipt
  "! day counts from the previous working day); N = from the next working day (audit A41)
  METHODS working_days_between
    IMPORTING
      iv_from        TYPE d
      iv_to          TYPE d
      iv_calendar_id TYPE zif_cd_fmon_types=>ty_fcal_id
      iv_basis       TYPE zif_cd_fmon_types=>ty_age_basis OPTIONAL
    RETURNING
      VALUE(rv_days) TYPE i
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
