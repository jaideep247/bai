*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_ack_alert.clas.abap
*& Purpose:
*& Evidence of a file whose bank ACK is missing or late (user request
*& 2026-11-10), from what file monitoring already holds - no copy into a
*& new table: identity (file name and reference, interface, bank, house
*& bank / account and payment run from the generation group split by the
*& source's GROUP_FIELDS), content (payment method, payments = RECORD_COUNT,
*& amount = CONTROL_TOTAL with currency; else the payment run totals of
*& DPAYH; else unknown, never 0), timing (generated, sent to PRISM,
*& delivered to the bank, ACK due, overdue by, in FMON_TIME_ZONE), ACK level
*& and the earlier file of a regenerated one. Writes the labelled detail
*& block (ZCL_CD_OPS_ACK_MAIL=>LINE) the finding's DETAILS and the alert
*& e-mail show. Pure logic: no database; the engine reads the fallback.
*& Modification log:
*& 2026-11-10 | Initial version (missing bank ACK alert, user request 2026-11-10).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - missing bank ACK evidence</p>
CLASS zcl_cd_fmon_ack_alert DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Everything known about one file of a missing / late ACK finding
    TYPES:
      BEGIN OF ty_input,
        file          TYPE zif_cd_fmon_types=>ty_file,
        iface         TYPE zif_cd_fmon_types=>ty_iface,
        run_key       TYPE zif_cd_fmon_types=>ty_payrun_key,
        "! Payment run totals (fallback); PAYMENTS = 0 = not found
        total         TYPE zif_cd_fmon_types=>ty_payrun_total,
        "! Currency of the control total (FMON_DEFAULT_CURRENCY)
        currency      TYPE zif_ca_ops_types=>ty_currency,
        time_zone     TYPE zif_cd_fmon_types=>ty_time_zone,
        generated_at  TYPE timestampl,
        sent_at       TYPE timestampl,
        delivered_at  TYPE timestampl,
        "! X = the finding is about the timing (ACK due / overdue shown)
        timing        TYPE abap_bool,
        ack_due       TYPE timestampl,
        overdue_min   TYPE i,
        earlier_file  TYPE zif_cd_fmon_types=>ty_file_name,
      END OF ty_input.

    TYPES:
      BEGIN OF ty_block,
        text         TYPE string,
        amount       TYPE zif_ca_ops_types=>ty_amount,
        currency     TYPE zif_ca_ops_types=>ty_currency,
        amount_known TYPE abap_bool,
      END OF ty_block.

    "! Codes about one file: no / late ACK (SLA of stage ACK_RECEIVED), ACK count / amount mismatch
    CLASS-METHODS is_ack_code
      IMPORTING
        iv_code       TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rv_ack) TYPE abap_bool.

    "! A missed stage deadline (interface and day) whose stage is ACK_RECEIVED
    CLASS-METHODS is_ack_deadline
      IMPORTING
        is_finding    TYPE zif_ca_ops_types=>ty_finding
      RETURNING
        VALUE(rv_ack) TYPE abap_bool.

    "! The detail line of a missed deadline naming its stage (written by the deadline check)
    CLASS-METHODS missed_stage_line
      IMPORTING
        iv_stage       TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rv_line) TYPE string.

    "! Payment run of a file: the generation group split by the GROUP_FIELDS names (LAUFD, LAUFI,
    "! HBKID, HKTID); a part that is missing, or a group key shortened to a digest, stays blank
    CLASS-METHODS run_key
      IMPORTING
        iv_gen_group    TYPE zif_cd_fmon_types=>ty_file_ref
        iv_group_fields TYPE zif_cd_fmon_types=>ty_field_list
      RETURNING
        VALUE(rs_key)   TYPE zif_cd_fmon_types=>ty_payrun_key.

    "! The file's own counts are not known (RECORD_COUNT or CONTROL_TOTAL not delivered)
    CLASS-METHODS needs_fallback
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rv_need) TYPE abap_bool.

    "! Payment run totals of the key (house bank blank: every house bank of the run, one currency)
    CLASS-METHODS total_for
      IMPORTING
        it_totals       TYPE zif_cd_fmon_types=>tt_payrun_total
        is_key          TYPE zif_cd_fmon_types=>ty_payrun_key
      RETURNING
        VALUE(rs_total) TYPE zif_cd_fmon_types=>ty_payrun_total.

    "! Labelled detail block of the file and the amount it stands for
    CLASS-METHODS block
      IMPORTING
        is_input        TYPE ty_input
      RETURNING
        VALUE(rs_block) TYPE ty_block.

  PRIVATE SECTION.
    CONSTANTS gc_part_separator TYPE string VALUE `/`.
    CONSTANTS gc_field_separator TYPE string VALUE `,`.
    CONSTANTS gc_minutes_per_hour TYPE i VALUE 60.
    CONSTANTS gc_date_length TYPE i VALUE 8.
    CONSTANTS gc_digits TYPE string VALUE `0123456789`.

    CLASS-METHODS time_text
      IMPORTING
        iv_timestamp   TYPE timestampl
        iv_time_zone   TYPE zif_cd_fmon_types=>ty_time_zone
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS unknown
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_fmon_ack_alert IMPLEMENTATION.

  METHOD is_ack_code.
    rv_ack = xsdbool( iv_code = zif_cd_fmon_types=>gc_check_code-no_bank_ack
                      OR iv_code = zif_cd_fmon_types=>gc_check_code-bank_ack_late
                      OR iv_code = zif_cd_fmon_types=>gc_check_code-ack_count
                      OR iv_code = zif_cd_fmon_types=>gc_check_code-ack_amount ).
  ENDMETHOD.


  METHOD is_ack_deadline.
    rv_ack = xsdbool( is_finding-check_code = zif_cd_fmon_types=>gc_check_code-deadline_missed
                      AND is_finding-details CS missed_stage_line( zif_cd_fmon_types=>gc_stage-ack ) ).
  ENDMETHOD.


  METHOD missed_stage_line.
    rv_line = zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-missed_stage
                                         iv_value = iv_stage ).
  ENDMETHOD.


  METHOD run_key.
    IF iv_gen_group IS INITIAL OR iv_group_fields IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT to_upper( condense( CONV string( iv_group_fields ) ) ) AT gc_field_separator INTO TABLE DATA(lt_names).
    SPLIT condense( CONV string( iv_gen_group ) ) AT gc_part_separator INTO TABLE DATA(lt_values).
    " a key longer than the reference width is stored as a digest - its parts cannot be read back
    IF lines( lt_values ) > lines( lt_names ).
      RETURN.
    ENDIF.
    LOOP AT lt_values INTO DATA(lv_value).
      DATA(lv_name) = condense( lt_names[ sy-tabix ] ).
      CASE lv_name.
        WHEN zif_cd_fmon_types=>gc_run_field-laufd.
          IF strlen( lv_value ) = gc_date_length AND lv_value CO gc_digits.
            rs_key-laufd = lv_value.
          ENDIF.
        WHEN zif_cd_fmon_types=>gc_run_field-laufi.
          rs_key-laufi = lv_value.
        WHEN zif_cd_fmon_types=>gc_run_field-hbkid.
          rs_key-hbkid = lv_value.
        WHEN zif_cd_fmon_types=>gc_run_field-hktid.
          rs_key-hktid = lv_value.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD needs_fallback.
    rv_need = xsdbool( is_file-record_count <= 0 OR is_file-control_total = 0 ).
  ENDMETHOD.


  METHOD total_for.
    LOOP AT it_totals ASSIGNING FIELD-SYMBOL(<ls_total>)
         WHERE laufd = is_key-laufd AND laufi = is_key-laufi.
      IF is_key-hbkid IS NOT INITIAL AND <ls_total>-hbkid <> is_key-hbkid.
        CONTINUE.
      ENDIF.
      IF rs_total IS INITIAL.
        rs_total = <ls_total>.
        CONTINUE.
      ENDIF.
      " several currencies cannot be added: the amount is not known then
      IF <ls_total>-currency <> rs_total-currency.
        CLEAR rs_total.
        RETURN.
      ENDIF.
      rs_total-payments += <ls_total>-payments.
      rs_total-amount   += <ls_total>-amount.
    ENDLOOP.
  ENDMETHOD.


  METHOD block.
    DATA lt_lines TYPE string_table.
    DATA(ls_file) = is_input-file.

    DATA(lv_house_bank) = COND string(
      WHEN is_input-run_key-hbkid IS INITIAL THEN unknown( )
      WHEN is_input-run_key-hktid IS INITIAL THEN condense( CONV string( is_input-run_key-hbkid ) )
      ELSE |{ is_input-run_key-hbkid }{ gc_part_separator }{ is_input-run_key-hktid }| ).
    DATA(lv_method) = COND string( WHEN ls_file-pay_method IS NOT INITIAL THEN CONV string( ls_file-pay_method )
                                   WHEN is_input-iface-pay_method IS NOT INITIAL THEN CONV string( is_input-iface-pay_method )
                                   ELSE unknown( ) ).
    " payments and amount: the file's own counts, else the payment run, else unknown (never 0)
    DATA(lv_payments) = COND string( WHEN ls_file-record_count > 0 THEN |{ ls_file-record_count }|
                                     WHEN is_input-total-payments > 0 THEN |{ is_input-total-payments }|
                                     ELSE unknown( ) ).
    IF ls_file-control_total <> 0.
      rs_block-amount       = ls_file-control_total.
      rs_block-currency     = is_input-currency.
      rs_block-amount_known = abap_true.
    ELSEIF is_input-total-payments > 0.
      rs_block-amount       = is_input-total-amount.
      rs_block-currency     = is_input-total-currency.
      rs_block-amount_known = abap_true.
    ENDIF.
    DATA(lv_amount) = COND string( WHEN rs_block-amount_known = abap_true
                                   THEN |{ rs_block-currency } { zcl_ca_ops_util=>format_amount( rs_block-amount ) }|
                                   ELSE unknown( ) ).
    DATA(lv_run) = COND string( WHEN is_input-run_key-laufd IS INITIAL AND is_input-run_key-laufi IS INITIAL
                                THEN unknown( )
                                ELSE |{ is_input-run_key-laufd DATE = ISO }{ gc_part_separator }{ is_input-run_key-laufi }| ).

    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-house_bank iv_value = lv_house_bank )
      INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-bank
                                      iv_value = COND string( WHEN is_input-iface-bank_key IS NOT INITIAL
                                                              THEN CONV string( is_input-iface-bank_key )
                                                              ELSE unknown( ) ) ) INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-file_name
                                      iv_value = COND string( WHEN ls_file-file_name IS NOT INITIAL
                                                              THEN CONV string( ls_file-file_name )
                                                              ELSE CONV string( ls_file-file_ref ) ) ) INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-iface
                                      iv_value = |{ ls_file-iface_id } { is_input-iface-description }| ) INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-pay_method iv_value = lv_method )
      INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-payments iv_value = lv_payments )
      INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-amount iv_value = lv_amount )
      INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-pay_run iv_value = lv_run )
      INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-business_date
                                      iv_value = |{ ls_file-business_date DATE = ISO }| ) INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-generated
                                      iv_value = time_text( iv_timestamp = is_input-generated_at
                                                            iv_time_zone = is_input-time_zone ) ) INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-sent
                                      iv_value = time_text( iv_timestamp = is_input-sent_at
                                                            iv_time_zone = is_input-time_zone ) ) INTO TABLE lt_lines.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-delivered
                                      iv_value = time_text( iv_timestamp = is_input-delivered_at
                                                            iv_time_zone = is_input-time_zone ) ) INTO TABLE lt_lines.
    IF is_input-timing = abap_true.
      INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-ack_due
                                        iv_value = time_text( iv_timestamp = is_input-ack_due
                                                              iv_time_zone = is_input-time_zone ) ) INTO TABLE lt_lines.
      INSERT zcl_cd_ops_ack_mail=>line(
               iv_label = zif_cd_ops_types=>gc_ack_msg-overdue
               iv_value = COND string( WHEN is_input-ack_due IS INITIAL THEN unknown( )
                                       ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_ack_msg-hours_minutes
                                                                   iv_v1    = is_input-overdue_min DIV gc_minutes_per_hour
                                                                   iv_v2    = is_input-overdue_min MOD gc_minutes_per_hour ) ) )
        INTO TABLE lt_lines.
    ENDIF.
    INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-ack_level
                                      iv_value = COND string( WHEN is_input-iface-ack_level IS NOT INITIAL
                                                              THEN CONV string( is_input-iface-ack_level )
                                                              ELSE unknown( ) ) ) INTO TABLE lt_lines.
    IF is_input-earlier_file IS NOT INITIAL.
      INSERT zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-earlier_file
                                        iv_value = is_input-earlier_file ) INTO TABLE lt_lines.
    ENDIF.
    rs_block-text = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD time_text.
    IF iv_timestamp IS INITIAL.
      rv_text = unknown( ).
      RETURN.
    ENDIF.
    DATA(lv_timestamp) = CONV timestamp( iv_timestamp ).
    CONVERT TIME STAMP lv_timestamp TIME ZONE iv_time_zone INTO DATE DATA(lv_date) TIME DATA(lv_time).
    rv_text = |{ lv_date DATE = ISO } { lv_time TIME = ISO } { iv_time_zone }|.
  ENDMETHOD.


  METHOD unknown.
    rv_text = zcl_cd_ops_util=>text( zif_cd_ops_types=>gc_ack_msg-unknown ).
  ENDMETHOD.

ENDCLASS.
