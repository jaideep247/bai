*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pilot_dao.intf.abap
*& Purpose:
*& Data access of the pilot pack export: the metrics per day of an area
*& (CDS ZI_CA_OpsPilotDay), the share of breaks explained per account and
*& key date (CDS ZR_CA_OpsPilotBrk) and the baselines of the area's checks
*& (ZCA_OPS_PILOTBL). Read only: the interface has no write method.
*& Modification log:
*& 2026-11-11 | Initial version (build F: pilot pack).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - pilot pack data access</p>
INTERFACE zif_ca_ops_pilot_dao
  PUBLIC.

  "! Metrics per day, business process and check of an area, raised from IV_FROM to IV_TO
  METHODS days
    IMPORTING
      iv_area        TYPE zif_ca_ops_types=>ty_area
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_days) TYPE zif_ca_ops_pilot_types=>tt_day.

  "! Breaks explained per account and key date of an area (key dates from IV_FROM to IV_TO)
  METHODS breaks
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_from          TYPE d
      iv_to            TYPE d
    RETURNING
      VALUE(rt_breaks) TYPE zif_ca_ops_pilot_types=>tt_break.

  "! Previous detection times of the area's checks
  METHODS baselines
    IMPORTING
      iv_area             TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_baselines) TYPE zif_ca_ops_pilot_types=>tt_baseline.

ENDINTERFACE.
