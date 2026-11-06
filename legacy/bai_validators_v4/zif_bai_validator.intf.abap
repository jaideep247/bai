INTERFACE zif_bai_validator
  PUBLIC.

  " Minimal FEBEP projection used by validators
  TYPES: BEGIN OF ty_febep_data,
           kukey TYPE kukey,
           esnum TYPE esnum_kk,
           vorgc TYPE vorgc,
           belnr TYPE belnr_kk,
           gjahr TYPE gjahr,
           chect TYPE chect_kk,
           betra TYPE betrw_kk,
           kwbtr TYPE febep-kwbtr,
           bewae TYPE waers,
           budat TYPE budat,
           bldat TYPE bldat,
           augbl TYPE augbl,
           valut TYPE valut,

           " Extended fields used by some validators
           xblnr TYPE xblnr,
           bstat TYPE bstat,
         END OF ty_febep_data.

  TYPES tt_febep_data TYPE STANDARD TABLE OF ty_febep_data WITH EMPTY KEY.

  " Validator result
  TYPES: BEGIN OF ty_validation_result,
           kukey            TYPE kukey,
           esnum            TYPE esnum_kk,
           bai_code         TYPE char10,
           flow_type        TYPE char1,
           vorgc            TYPE vorgc,
           belnr            TYPE belnr_kk,
           gjahr            TYPE gjahr,
           chect            TYPE chect_kk,
           status           TYPE char1,     " G=pass, R=fail, Y=warning, P=pending
           status_icon      TYPE icon_d,
           message          TYPE string,
           failed_checks    TYPE string,
           primary_failure  TYPE string,
         END OF ty_validation_result.

  TYPES tt_validation_result TYPE STANDARD TABLE OF ty_validation_result WITH EMPTY KEY.

  TYPES: BEGIN OF ty_validation_stats,
           bai_code       TYPE char10,
           flow_type      TYPE char1,
           total_count    TYPE i,
           passed_count   TYPE i,
           failed_count   TYPE i,
           warning_count  TYPE i,
           duration_ms    TYPE i,
         END OF ty_validation_stats.

  METHODS validate
    IMPORTING
      it_febep          TYPE tt_febep_data
    RETURNING
      VALUE(rt_results) TYPE tt_validation_result.

  METHODS get_stats
    RETURNING
      VALUE(rs_stats) TYPE ty_validation_stats.

ENDINTERFACE.
