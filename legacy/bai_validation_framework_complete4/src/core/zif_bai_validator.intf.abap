*"* public declarations
INTERFACE zif_bai_validator
  PUBLIC.

  "! Custom FEBEP data type - only needed fields
  TYPES: BEGIN OF ty_febep_data,
           kukey TYPE kukey,
           esnum TYPE esnum_kk,
           vorgc TYPE vorgc,
           belnr TYPE belnr_kk,
           gjahr TYPE gjahr,
           chect TYPE chect_kk,
           betra TYPE betrw_kk,
           kwbtr TYPE kwbtr_kk,
           bewae TYPE waers,
           budat TYPE budat,
           bldat TYPE bldat,
           augbl TYPE augbl,
           valut TYPE valut,
         END OF ty_febep_data.

  "! Table type for FEBEP data
  TYPES: tt_febep_data TYPE STANDARD TABLE OF ty_febep_data
                       WITH EMPTY KEY.

  "! Validation result structure
  TYPES: BEGIN OF ty_validation_result,
           kukey           TYPE char12,
           esnum           TYPE char9,
           bai_code        TYPE char10,
           vorgc           TYPE char4,
           belnr           TYPE char10,
           gjahr           TYPE char4,
           chect           TYPE char20,
           flow_type       TYPE char1,
           status          TYPE char1,
           status_icon     TYPE char4,
           failed_checks   TYPE string,
           primary_failure TYPE char10,
           details_json    TYPE string,
           message         TYPE string,
           request_data    TYPE string,
           response_data   TYPE string,
           batch_id        TYPE sysuuid_x16,
           validated_on    TYPE datum,
           validated_at    TYPE uzeit,
           validated_by    TYPE syuname,
         END OF ty_validation_result.

  "! Table type for validation results
  TYPES: tt_validation_result TYPE STANDARD TABLE OF ty_validation_result
                               WITH EMPTY KEY.

  "! Validation statistics
  TYPES: BEGIN OF ty_validation_stats,
           bai_code      TYPE char10,
           flow_type     TYPE char1,
           total_count   TYPE i,
           passed_count  TYPE i,
           failed_count  TYPE i,
           warning_count TYPE i,
           duration_ms   TYPE int8,
         END OF ty_validation_stats.

  "! Validate FEBEP records
  METHODS validate
    IMPORTING
      it_febep             TYPE tt_febep_data
      iv_batch_id          TYPE sysuuid_x16 OPTIONAL
    RETURNING
      VALUE(rt_results)    TYPE tt_validation_result
    RAISING
      zcx_bai_validation_error.

  "! Get validation statistics
  METHODS get_statistics
    RETURNING
      VALUE(rs_stats) TYPE ty_validation_stats.

ENDINTERFACE.
