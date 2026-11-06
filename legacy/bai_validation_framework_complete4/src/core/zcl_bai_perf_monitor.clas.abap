CLASS zcl_bai_perf_monitor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS start_timer
      IMPORTING
        iv_name TYPE string.

    METHODS stop_timer
      IMPORTING
        iv_name TYPE string
      RETURNING
        VALUE(rv_duration_ms) TYPE int8.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_timer,
             name  TYPE string,
             start TYPE timestampl,
             stop  TYPE timestampl,
           END OF ty_timer.

    DATA: mt_timers TYPE HASHED TABLE OF ty_timer
                    WITH UNIQUE KEY name.

ENDCLASS.



CLASS zcl_bai_perf_monitor IMPLEMENTATION.


  METHOD start_timer.

    DATA: ls_timer TYPE ty_timer.

    GET TIME STAMP FIELD ls_timer-start.
    ls_timer-name = iv_name.

    INSERT ls_timer INTO TABLE mt_timers.

  ENDMETHOD.


  METHOD stop_timer.

    DATA: ls_timer TYPE ty_timer.

    READ TABLE mt_timers INTO ls_timer
      WITH TABLE KEY name = iv_name.

    IF sy-subrc = 0.
      GET TIME STAMP FIELD ls_timer-stop.
      rv_duration_ms = ( ls_timer-stop - ls_timer-start ) / 1000.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
