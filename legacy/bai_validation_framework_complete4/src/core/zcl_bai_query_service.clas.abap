CLASS zcl_bai_query_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS get_failed_records
      IMPORTING
        iv_batch_id       TYPE sysuuid_x16
      RETURNING
        VALUE(rt_results) TYPE zif_bai_validator=>tt_validation_result
      RAISING
        zcx_bai_db_error.

    CLASS-METHODS get_batch_summary
      IMPORTING
        iv_batch_id      TYPE sysuuid_x16
      RETURNING
        VALUE(rt_summary) TYPE TABLE OF zbai_validation_summary
      RAISING
        zcx_bai_db_error.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_bai_query_service IMPLEMENTATION.


  METHOD get_failed_records.

    DATA: lo_db_layer TYPE REF TO zcl_bai_db_layer.

    CREATE OBJECT lo_db_layer.

    rt_results = lo_db_layer->get_failed_records(
      iv_batch_id = iv_batch_id
    ).

  ENDMETHOD.


  METHOD get_batch_summary.

    SELECT *
      FROM zbai_validation_summary
      WHERE batch_id = @iv_batch_id
      INTO TABLE @rt_summary.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_db_error
        EXPORTING
          textid   = zcx_bai_db_error=>select_failed
          mv_table = 'ZBAI_VALIDATION_SUMMARY'.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
