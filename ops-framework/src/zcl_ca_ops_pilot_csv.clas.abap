*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pilot_csv.clas.abap
*& Purpose:
*& CSV of the pilot pack export (docs/PILOT_PACK.md section 5): one header
*& line and one line per record of each kind - DAY (exceptions raised,
*& assigned, resolved, false positives and their rate, the averages of the
*& minutes to detect, of the baseline, to assign and to resolve, detections
*& earlier than the baseline), BREAK (breaks, explained, unexplained, share
*& explained per account and key date) and BASELINE (the previous detection
*& time of a check and its source). Rates and averages divide the summed
*& figures by their counts (never an average of averages); a figure without
*& a count is blank, never 0. Fields with the separator or a quote are
*& quoted. Figures only - no amount, no account number, no business key.
*& Pure: no database, no file.
*& Modification log:
*& 2026-11-11 | Initial version (build F: pilot pack).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - pilot pack CSV</p>
CLASS zcl_ca_ops_pilot_csv DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! The lines of the export: DAY, BREAK and BASELINE records, each kind after its header line
    CLASS-METHODS lines
      IMPORTING
        it_days         TYPE zif_ca_ops_pilot_types=>tt_day
        it_breaks       TYPE zif_ca_ops_pilot_types=>tt_break
        it_baselines    TYPE zif_ca_ops_pilot_types=>tt_baseline
      RETURNING
        VALUE(rt_lines) TYPE string_table.

    "! A quotient with one decimal (factor 100 = a percentage); blank when the divisor is 0
    CLASS-METHODS ratio
      IMPORTING
        iv_value        TYPE numeric
        iv_count        TYPE i
        iv_factor       TYPE i DEFAULT 1
      RETURNING
        VALUE(rv_ratio) TYPE string.

    "! A field as written: quoted (quotes doubled) when it holds the separator or a quote
    CLASS-METHODS field
      IMPORTING
        iv_value        TYPE clike
      RETURNING
        VALUE(rv_field) TYPE string.

  PRIVATE SECTION.
    CLASS-METHODS line
      IMPORTING
        it_fields      TYPE string_table
      RETURNING
        VALUE(rv_line) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_pilot_csv IMPLEMENTATION.

  METHOD lines.
    INSERT zif_ca_ops_pilot_types=>gc_header_day INTO TABLE rt_lines.
    LOOP AT it_days ASSIGNING FIELD-SYMBOL(<ls_day>).
      INSERT line( VALUE #( ( zif_ca_ops_pilot_types=>gc_record-day )
                            ( |{ <ls_day>-raiseddate }| )
                            ( field( <ls_day>-area ) )
                            ( field( <ls_day>-processid ) )
                            ( field( <ls_day>-checkid ) )
                            ( |{ <ls_day>-raisedcount }| )
                            ( |{ <ls_day>-assignedcount }| )
                            ( |{ <ls_day>-resolvedcount }| )
                            ( |{ <ls_day>-falsepositivecount }| )
                            ( ratio( iv_value  = <ls_day>-falsepositivecount
                                     iv_count  = <ls_day>-resolvedcount
                                     iv_factor = 100 ) )
                            ( |{ <ls_day>-detectknowncount }| )
                            ( ratio( iv_value = <ls_day>-minutestodetect iv_count = <ls_day>-detectknowncount ) )
                            ( |{ <ls_day>-baselineknowncount }| )
                            ( ratio( iv_value = <ls_day>-baselineminutes iv_count = <ls_day>-baselineknowncount ) )
                            ( |{ <ls_day>-earliercount }| )
                            ( ratio( iv_value = <ls_day>-minutestoassign iv_count = <ls_day>-assignedcount ) )
                            ( ratio( iv_value = <ls_day>-minutestoresolve iv_count = <ls_day>-resolvedcount ) ) ) )
             INTO TABLE rt_lines.
    ENDLOOP.
    INSERT zif_ca_ops_pilot_types=>gc_header_break INTO TABLE rt_lines.
    LOOP AT it_breaks ASSIGNING FIELD-SYMBOL(<ls_break>).
      INSERT line( VALUE #( ( zif_ca_ops_pilot_types=>gc_record-break )
                            ( |{ <ls_break>-keydate }| )
                            ( field( <ls_break>-area ) )
                            ( field( <ls_break>-accountid ) )
                            ( field( <ls_break>-companycode ) )
                            ( |{ <ls_break>-groupcount }| )
                            ( |{ <ls_break>-explainedcount }| )
                            ( |{ <ls_break>-unexplainedcount }| )
                            ( ratio( iv_value  = <ls_break>-explainedcount
                                     iv_count  = <ls_break>-groupcount
                                     iv_factor = 100 ) ) ) )
             INTO TABLE rt_lines.
    ENDLOOP.
    INSERT zif_ca_ops_pilot_types=>gc_header_baseline INTO TABLE rt_lines.
    LOOP AT it_baselines ASSIGNING FIELD-SYMBOL(<ls_baseline>).
      INSERT line( VALUE #( ( zif_ca_ops_pilot_types=>gc_record-baseline )
                            ( field( <ls_baseline>-area ) )
                            ( field( <ls_baseline>-check_id ) )
                            ( |{ <ls_baseline>-baseline_min }| )
                            ( field( <ls_baseline>-source ) ) ) )
             INTO TABLE rt_lines.
    ENDLOOP.
  ENDMETHOD.


  METHOD ratio.
    DATA lv_ratio TYPE p LENGTH 12 DECIMALS 1.
    IF iv_count = 0.
      RETURN.
    ENDIF.
    lv_ratio = iv_value * iv_factor / iv_count.
    rv_ratio = |{ lv_ratio }|.
  ENDMETHOD.


  METHOD field.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    IF lv_value CS zif_ca_ops_pilot_types=>gc_separator OR lv_value CS zif_ca_ops_pilot_types=>gc_quote.
      rv_field = zif_ca_ops_pilot_types=>gc_quote
              && replace( val  = lv_value
                          sub  = zif_ca_ops_pilot_types=>gc_quote
                          with = zif_ca_ops_pilot_types=>gc_quote && zif_ca_ops_pilot_types=>gc_quote
                          occ  = 0 )
              && zif_ca_ops_pilot_types=>gc_quote.
    ELSE.
      rv_field = lv_value.
    ENDIF.
  ENDMETHOD.


  METHOD line.
    rv_line = concat_lines_of( table = it_fields sep = zif_ca_ops_pilot_types=>gc_separator ).
  ENDMETHOD.

ENDCLASS.
