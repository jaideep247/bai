CLASS zcl_bai_execution_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS execute_validation
      IMPORTING
        iv_date_from     TYPE datum
        iv_date_to       TYPE datum
        iv_chunk_size    TYPE i DEFAULT 10000
      EXPORTING
        ev_batch_id      TYPE sysuuid_x16
        ev_total_records TYPE i
        ev_total_failed  TYPE i
      RAISING
        zcx_bai_validation_error
        zcx_bai_db_error.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_bai_execution_service IMPLEMENTATION.


  METHOD execute_validation.

    DATA: lo_mass_validator TYPE REF TO zcl_bai_mass_validator.

    " Create mass validator
    CREATE OBJECT lo_mass_validator
      EXPORTING
        iv_chunk_size = iv_chunk_size.

    " Load active validators
    lo_mass_validator->load_all_active_validators( ).

    " Execute
    lo_mass_validator->run_validation(
      EXPORTING
        iv_febep_date_from = iv_date_from
        iv_febep_date_to   = iv_date_to
      IMPORTING
        ev_batch_id        = ev_batch_id
        ev_total_records   = ev_total_records
        ev_total_failed    = ev_total_failed
    ).

  ENDMETHOD.


ENDCLASS.
