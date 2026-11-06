*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_parser_bai2.clas.abap
*& Purpose:
*& Parses a BAI2 bank file into the format-neutral EBS model and reports
*& structural/control-total findings (S00, S06, S11, S12). It never posts,
*& never reads the database and derives no engine fields (flow, category).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A86: an empty total/count of a present 49/98/99 trailer is TRAILER_FIELD_MISSING, never the computed value.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS - BAI2 bank statement file parser</p>
"! One statement per 03 account record; 16 detail records become lines.
"! Empty content returns finding S11 EMPTY_FILE (severity B); content that is
"! not BAI2 at all (first record not 01) raises ZCX_CD_OPS_ERROR (150).
CLASS zcl_cd_ebs_parser_bai2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_parser.

  PRIVATE SECTION.
    TYPES ty_rec_type   TYPE c LENGTH 2.
    TYPES ty_type_code  TYPE c LENGTH 3.
    TYPES ty_funds_type TYPE c LENGTH 1.
    TYPES ty_amount     TYPE zif_cd_ops_types=>ty_amount.

    TYPES:
      BEGIN OF ty_record,
        rec_type   TYPE ty_rec_type,
        "! Logical record: terminator removed, 88 continuations merged
        raw        TYPE string,
        "! Physical records forming the logical record (1 + number of 88)
        phys_count TYPE i,
        line_no    TYPE i,
      END OF ty_record.
    TYPES tt_record TYPE STANDARD TABLE OF ty_record WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_funds,
        funds_type     TYPE ty_funds_type,
        value_date_raw TYPE string,
        "! Fields occupied by the funds-type block, the funds type included
        field_count    TYPE i,
      END OF ty_funds.

    TYPES:
      BEGIN OF ty_account,
        is_open        TYPE abap_bool,
        stmt           TYPE zif_cd_ebs_types=>ty_statement,
        lines          TYPE zif_cd_ebs_types=>tt_line,
        computed_total TYPE ty_amount,
        record_count   TYPE i,
        credit_sum     TYPE ty_amount,
        debit_sum      TYPE ty_amount,
        credit_lines   TYPE i,
        debit_lines    TYPE i,
        has_credit_tot TYPE abap_bool,
        has_debit_tot  TYPE abap_bool,
        has_credit_cnt TYPE abap_bool,
        has_debit_cnt  TYPE abap_bool,
      END OF ty_account.

    TYPES:
      BEGIN OF ty_group,
        is_open       TYPE abap_bool,
        group_no      TYPE i,
        originator    TYPE zif_cd_ebs_types=>ty_text35,
        as_of_date    TYPE d,
        currency      TYPE zif_cd_ops_types=>ty_currency,
        "! Sum of the account totals (49 declared, computed when 49 is missing)
        child_total   TYPE ty_amount,
        account_count TYPE i,
        record_count  TYPE i,
      END OF ty_group.

    "! Target object and wording of a finding
    TYPES:
      BEGIN OF ty_check,
        object_type TYPE zif_cd_ops_types=>ty_object_type,
        object_key  TYPE zif_cd_ops_types=>ty_object_key,
        check_code  TYPE zif_cd_ops_types=>ty_check_code,
        label       TYPE string,
      END OF ty_check.

    CONSTANTS:
      BEGIN OF gc_rec,
        file_header     TYPE ty_rec_type VALUE '01',
        group_header    TYPE ty_rec_type VALUE '02',
        account         TYPE ty_rec_type VALUE '03',
        detail          TYPE ty_rec_type VALUE '16',
        continuation    TYPE ty_rec_type VALUE '88',
        account_trailer TYPE ty_rec_type VALUE '49',
        group_trailer   TYPE ty_rec_type VALUE '98',
        file_trailer    TYPE ty_rec_type VALUE '99',
      END OF gc_rec.

    CONSTANTS:
      BEGIN OF gc_code,
        opening_ledger TYPE ty_type_code VALUE '010',
        closing_ledger TYPE ty_type_code VALUE '015',
        opening_avail  TYPE ty_type_code VALUE '040',
        closing_avail  TYPE ty_type_code VALUE '045',
        total_credits  TYPE ty_type_code VALUE '100',
        total_debits   TYPE ty_type_code VALUE '400',
        check_returned TYPE ty_type_code VALUE '255',
        check_paid     TYPE ty_type_code VALUE '475',
        item_returned  TYPE ty_type_code VALUE '555',
      END OF gc_code.

    "! Type-code ranges (BAI2 2005): 0xx status, 1xx-3xx credit, 4xx-6xx debit, 7xx-9xx other
    CONSTANTS:
      BEGIN OF gc_range,
        balance_max TYPE i VALUE 99,
        credit_min  TYPE i VALUE 100,
        credit_max  TYPE i VALUE 399,
        debit_min   TYPE i VALUE 400,
        debit_max   TYPE i VALUE 699,
      END OF gc_range.

    CONSTANTS:
      BEGIN OF gc_funds,
        value_dated TYPE ty_funds_type VALUE 'V',
        distributed TYPE ty_funds_type VALUE 'S',
        detailed    TYPE ty_funds_type VALUE 'D',
      END OF gc_funds.

    "! Fields used by a funds-type block (funds type field included)
    CONSTANTS:
      BEGIN OF gc_funds_fields,
        plain         TYPE i VALUE 1,
        value_dated   TYPE i VALUE 3,
        distributed   TYPE i VALUE 4,
        detailed_base TYPE i VALUE 2,
        per_pair      TYPE i VALUE 2,
      END OF gc_funds_fields.

    "! Field positions (1 = record type)
    CONSTANTS:
      BEGIN OF gc_pos,
        rec_type         TYPE i VALUE 1,
        hdr_sender       TYPE i VALUE 2,
        hdr_receiver     TYPE i VALUE 3,
        hdr_date         TYPE i VALUE 4,
        hdr_time         TYPE i VALUE 5,
        hdr_file_id      TYPE i VALUE 6,
        grp_originator   TYPE i VALUE 3,
        grp_as_of_date   TYPE i VALUE 5,
        grp_currency     TYPE i VALUE 7,
        acct_number      TYPE i VALUE 2,
        acct_currency    TYPE i VALUE 3,
        acct_first_group TYPE i VALUE 4,
        sum_amount       TYPE i VALUE 1,
        sum_count        TYPE i VALUE 2,
        sum_funds_type   TYPE i VALUE 3,
        dtl_type_code    TYPE i VALUE 2,
        dtl_amount       TYPE i VALUE 3,
        dtl_funds_type   TYPE i VALUE 4,
        dtl_ref_fields   TYPE i VALUE 2,
        trl_total        TYPE i VALUE 2,
        trl_count_1      TYPE i VALUE 3,
        trl_count_2      TYPE i VALUE 4,
      END OF gc_pos.

    CONSTANTS:
      BEGIN OF gc_rule,
        structure     TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S00',
        control_total TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S06',
        empty         TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S11',
        count         TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S12',
      END OF gc_rule.

    CONSTANTS:
      BEGIN OF gc_check,
        acct_ctrl_total  TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_ACCT_CTRL_TOTAL',
        group_ctrl_total TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_GROUP_CTRL_TOTAL',
        file_ctrl_total  TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_FILE_CTRL_TOTAL',
        credit_sum       TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_CDT_SUM_MISMATCH',
        debit_sum        TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_DBT_SUM_MISMATCH',
        record_count     TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_RECORD_COUNT',
        item_count       TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_ITEM_COUNT',
        account_count    TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_ACCOUNT_COUNT',
        group_count      TYPE zif_cd_ops_types=>ty_check_code VALUE 'BAI2_GROUP_COUNT',
        empty_file       TYPE zif_cd_ops_types=>ty_check_code VALUE 'EMPTY_FILE',
        no_entries       TYPE zif_cd_ops_types=>ty_check_code VALUE 'NO_ENTRIES',
        unknown_record   TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNKNOWN_RECORD',
        missing_trailer  TYPE zif_cd_ops_types=>ty_check_code VALUE 'MISSING_TRAILER',
        record_order     TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNEXPECTED_RECORD_ORDER',
        invalid_amount   TYPE zif_cd_ops_types=>ty_check_code VALUE 'INVALID_AMOUNT',
        invalid_date     TYPE zif_cd_ops_types=>ty_check_code VALUE 'INVALID_DATE',
        invalid_code     TYPE zif_cd_ops_types=>ty_check_code VALUE 'INVALID_TYPE_CODE',
        info_skipped     TYPE zif_cd_ops_types=>ty_check_code VALUE 'INFO_CODE_SKIPPED',
        "! A86: a required total/count of a present 49/98/99 trailer is empty
        trailer_missing  TYPE zif_cd_ops_types=>ty_check_code VALUE 'TRAILER_FIELD_MISSING',
      END OF gc_check.

    CONSTANTS:
      BEGIN OF gc_object,
        file      TYPE zif_cd_ops_types=>ty_object_type VALUE 'FILE',
        statement TYPE zif_cd_ops_types=>ty_object_type VALUE 'STMT',
      END OF gc_object.

    CONSTANTS gc_delimiter TYPE c LENGTH 1 VALUE ','.
    CONSTANTS gc_terminator TYPE c LENGTH 1 VALUE '/'.
    CONSTANTS gc_minus TYPE c LENGTH 1 VALUE '-'.
    CONSTANTS gc_plus TYPE c LENGTH 1 VALUE '+'.
    CONSTANTS gc_digits TYPE string VALUE `0123456789`.
    CONSTANTS gc_century TYPE string VALUE `20`.
    CONSTANTS gc_date_length TYPE i VALUE 6.
    CONSTANTS gc_time_length TYPE i VALUE 4.
    CONSTANTS gc_code_length TYPE i VALUE 3.
    CONSTANTS gc_max_amount_digits TYPE i VALUE 20.
    CONSTANTS gc_max_count_digits TYPE i VALUE 9.
    CONSTANTS gc_implied_divisor TYPE i VALUE 100.
    CONSTANTS gc_hours_per_day TYPE i VALUE 24.
    CONSTANTS gc_minutes_per_hour TYPE i VALUE 60.
    CONSTANTS gc_seconds_suffix TYPE string VALUE `00`.
    CONSTANTS gc_end_of_day_2400 TYPE string VALUE `2400`.
    CONSTANTS gc_end_of_day_9999 TYPE string VALUE `9999`.
    CONSTANTS gc_end_of_day_time TYPE t VALUE '235959'.
    CONSTANTS gc_not_declared TYPE i VALUE -1.
    CONSTANTS gc_excerpt_length TYPE i VALUE 20.

    DATA ms_file TYPE zif_cd_ebs_types=>ty_file.
    DATA ms_group TYPE ty_group.
    DATA ms_account TYPE ty_account.
    DATA mv_stmt_index TYPE i.
    DATA mv_group_count TYPE i.
    "! Physical records read so far (01 ... 99)
    DATA mv_file_records TYPE i.
    "! Sum of the group totals (98 declared, computed when 98 is missing)
    DATA mv_file_total TYPE ty_amount.
    DATA mv_header_seen TYPE abap_bool.
    DATA mv_file_closed TYPE abap_bool.
    DATA mv_line_no TYPE i.

    METHODS reset_state
      IMPORTING
        iv_file_name TYPE string.

    METHODS split_physical_lines
      IMPORTING
        iv_content      TYPE string
      RETURNING
        VALUE(rt_lines) TYPE string_table.

    METHODS assert_bai2
      IMPORTING
        iv_first_line TYPE string
      RAISING
        zcx_cd_ops_error.

    METHODS build_records
      IMPORTING
        it_lines          TYPE string_table
      RETURNING
        VALUE(rt_records) TYPE tt_record.

    METHODS append_continuation
      IMPORTING
        iv_line   TYPE string
      CHANGING
        cs_record TYPE ty_record.

    METHODS record_type
      IMPORTING
        iv_raw         TYPE string
      RETURNING
        VALUE(rv_type) TYPE ty_rec_type.

    METHODS strip_terminator
      IMPORTING
        iv_rec_type   TYPE ty_rec_type
        iv_raw        TYPE string
      RETURNING
        VALUE(rv_raw) TYPE string.

    METHODS cut_at_terminator
      IMPORTING
        iv_raw        TYPE string
      RETURNING
        VALUE(rv_raw) TYPE string.

    METHODS detail_text_started
      IMPORTING
        iv_raw            TYPE string
      RETURNING
        VALUE(rv_started) TYPE abap_bool.

    METHODS detail_text_index
      IMPORTING
        it_fields       TYPE string_table
      RETURNING
        VALUE(rv_index) TYPE i.

    METHODS dispatch_record
      IMPORTING
        is_record TYPE ty_record.

    METHODS on_file_header
      IMPORTING
        is_record TYPE ty_record
        it_fields TYPE string_table.

    METHODS on_group_header
      IMPORTING
        is_record TYPE ty_record
        it_fields TYPE string_table.

    METHODS on_account
      IMPORTING
        is_record TYPE ty_record
        it_fields TYPE string_table.

    METHODS open_account
      IMPORTING
        it_fields TYPE string_table.

    METHODS read_summary_groups
      IMPORTING
        it_fields TYPE string_table.

    METHODS apply_summary
      IMPORTING
        iv_code       TYPE string
        iv_amount_raw TYPE string
        iv_count_raw  TYPE string.

    METHODS add_balance
      IMPORTING
        iv_bal_type TYPE zif_cd_ebs_types=>ty_bal_type
        iv_amount   TYPE ty_amount.

    METHODS balance_type
      IMPORTING
        iv_code            TYPE string
      RETURNING
        VALUE(rv_bal_type) TYPE zif_cd_ebs_types=>ty_bal_type.

    METHODS on_detail
      IMPORTING
        is_record TYPE ty_record
        it_fields TYPE string_table.

    METHODS append_line
      IMPORTING
        it_fields TYPE string_table
        iv_code   TYPE string
        iv_cdi    TYPE zif_cd_ebs_types=>ty_cdi
        iv_amount TYPE ty_amount.

    METHODS skip_detail
      IMPORTING
        iv_code    TYPE string
        iv_line_no TYPE i.

    METHODS detail_cdi
      IMPORTING
        iv_code       TYPE string
      RETURNING
        VALUE(rv_cdi) TYPE zif_cd_ebs_types=>ty_cdi.

    METHODS code_number
      IMPORTING
        iv_code          TYPE string
      RETURNING
        VALUE(rv_number) TYPE i.

    METHODS check_number
      IMPORTING
        iv_code            TYPE string
        iv_cust_ref        TYPE zif_cd_ebs_types=>ty_text35
      RETURNING
        VALUE(rv_check_no) TYPE zif_cd_ebs_types=>ty_text35.

    METHODS line_value_date
      IMPORTING
        is_funds       TYPE ty_funds
      RETURNING
        VALUE(rv_date) TYPE d.

    METHODS detail_text
      IMPORTING
        it_fields      TYPE string_table
        iv_index       TYPE i
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS on_account_trailer
      IMPORTING
        is_record TYPE ty_record
        it_fields TYPE string_table.

    METHODS on_group_trailer
      IMPORTING
        is_record TYPE ty_record
        it_fields TYPE string_table.

    METHODS on_file_trailer
      IMPORTING
        it_fields TYPE string_table.

    METHODS on_unknown_record
      IMPORTING
        is_record TYPE ty_record.

    METHODS count_record
      IMPORTING
        iv_phys_count TYPE i.

    METHODS close_account
      IMPORTING
        iv_has_trailer   TYPE abap_bool
        iv_trailer_total TYPE ty_amount OPTIONAL.

    METHODS check_statement_totals.

    METHODS close_group
      IMPORTING
        iv_has_trailer   TYPE abap_bool
        iv_trailer_total TYPE ty_amount OPTIONAL.

    METHODS finish_file.

    METHODS check_total
      IMPORTING
        is_check    TYPE ty_check
        iv_expected TYPE ty_amount
        iv_found    TYPE ty_amount.

    METHODS check_count
      IMPORTING
        is_check    TYPE ty_check
        iv_expected TYPE i
        iv_found    TYPE i.

    "! A86: compares the declared control total of a trailer with the computed one. An
    "! empty field is TRAILER_FIELD_MISSING (S06, B) - never replaced by the computed value.
    "! Returns the declared total, or the computed one when nothing was declared.
    METHODS compare_total
      IMPORTING
        is_check         TYPE ty_check
        iv_raw           TYPE string
        iv_found         TYPE ty_amount
      RETURNING
        VALUE(rv_amount) TYPE ty_amount.

    "! A86: compares a declared trailer count with the computed one. An empty field is
    "! TRAILER_FIELD_MISSING (S12) - omission is not zero and is never self-satisfied.
    METHODS compare_count
      IMPORTING
        is_check TYPE ty_check
        iv_raw   TYPE string
        iv_found TYPE i.

    METHODS field_missing
      IMPORTING
        is_check    TYPE ty_check
        iv_rule_id  TYPE zif_cd_ops_types=>ty_rule_id
        iv_severity TYPE zif_cd_ops_types=>ty_severity.

    METHODS add_finding
      IMPORTING
        is_check    TYPE ty_check
        iv_rule_id  TYPE zif_cd_ops_types=>ty_rule_id
        iv_severity TYPE zif_cd_ops_types=>ty_severity
        iv_message  TYPE string
        iv_amount   TYPE ty_amount OPTIONAL.

    METHODS add_order_finding
      IMPORTING
        iv_message TYPE string.

    METHODS file_check
      IMPORTING
        iv_check_code   TYPE zif_cd_ops_types=>ty_check_code
        iv_label        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_check) TYPE ty_check.

    METHODS stmt_check
      IMPORTING
        iv_check_code   TYPE zif_cd_ops_types=>ty_check_code
        iv_label        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_check) TYPE ty_check.

    "! Statement check while an account is open, else file check
    METHODS current_check
      IMPORTING
        iv_check_code   TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_check) TYPE ty_check.

    METHODS file_key
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ops_types=>ty_object_key.

    METHODS split_fields
      IMPORTING
        iv_raw           TYPE string
      RETURNING
        VALUE(rt_fields) TYPE string_table.

    METHODS field
      IMPORTING
        it_fields       TYPE string_table
        iv_index        TYPE i
      RETURNING
        VALUE(rv_value) TYPE string.

    METHODS funds_info
      IMPORTING
        it_fields       TYPE string_table
        iv_index        TYPE i
      RETURNING
        VALUE(rs_funds) TYPE ty_funds.

    METHODS to_amount
      IMPORTING
        iv_value         TYPE string
      RETURNING
        VALUE(rv_amount) TYPE ty_amount.

    METHODS to_count
      IMPORTING
        iv_value        TYPE string
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS to_date
      IMPORTING
        iv_value       TYPE string
      RETURNING
        VALUE(rv_date) TYPE d.

    METHODS to_time
      IMPORTING
        iv_value       TYPE string
      RETURNING
        VALUE(rv_time) TYPE t.

    METHODS trim
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS excerpt
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_ebs_parser_bai2 IMPLEMENTATION.

  METHOD zif_cd_ebs_parser~parse.
    reset_state( iv_file_name ).
    DATA(lt_lines) = split_physical_lines( iv_content ).
    ms_file-record_count = lines( lt_lines ).
    IF lt_lines IS INITIAL.
      add_finding( is_check    = file_check( gc_check-empty_file )
                   iv_rule_id  = gc_rule-empty
                   iv_severity = zif_cd_ops_types=>gc_severity-block
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-file_is_empty_expected_bai2
                                                        iv_v1    = file_key( ) ) ).
      rs_file = ms_file.
      RETURN.
    ENDIF.
    assert_bai2( lt_lines[ 1 ] ).
    DATA(lt_records) = build_records( lt_lines ).
    LOOP AT lt_records INTO DATA(ls_record).
      dispatch_record( ls_record ).
    ENDLOOP.
    finish_file( ).
    rs_file = ms_file.
  ENDMETHOD.


  METHOD reset_state.
    CLEAR: ms_group, ms_account, mv_stmt_index, mv_group_count, mv_file_records,
           mv_file_total, mv_header_seen, mv_file_closed, mv_line_no.
    ms_file = VALUE #( format    = zif_cd_ebs_types=>gc_format-bai2
                       file_name = iv_file_name ).
  ENDMETHOD.


  METHOD split_physical_lines.
    DATA(lv_content) = replace( val = iv_content sub = |\r\n| with = |\n| occ = 0 ).
    lv_content = replace( val = lv_content sub = |\r| with = |\n| occ = 0 ).
    SPLIT lv_content AT |\n| INTO TABLE DATA(lt_raw).
    LOOP AT lt_raw INTO DATA(lv_raw).
      DATA(lv_line) = trim( lv_raw ).
      IF lv_line IS NOT INITIAL.
        APPEND lv_line TO rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD assert_bai2.
    IF record_type( iv_first_line ) <> gc_rec-file_header.
      DATA(lv_start) = excerpt( iv_first_line ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e150(zcd_ops) WITH lv_start.
    ENDIF.
  ENDMETHOD.


  METHOD build_records.
    LOOP AT it_lines INTO DATA(lv_line).
      DATA(lv_line_no) = sy-tabix.
      DATA(lv_type) = record_type( lv_line ).
      IF lv_type = gc_rec-continuation AND rt_records IS NOT INITIAL.
        ASSIGN rt_records[ lines( rt_records ) ] TO FIELD-SYMBOL(<ls_last>).
        append_continuation( EXPORTING iv_line   = lv_line
                             CHANGING  cs_record = <ls_last> ).
      ELSE.
        APPEND VALUE #( rec_type   = lv_type
                        raw        = strip_terminator( iv_rec_type = lv_type iv_raw = lv_line )
                        phys_count = 1
                        line_no    = lv_line_no ) TO rt_records.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD append_continuation.
    " The 16 text field is free text: an 88 after it continues the text with a blank;
    " otherwise the 88 continues the field list of the preceding record.
    DATA(lv_data) = strip_terminator( iv_rec_type = cs_record-rec_type
                                      iv_raw      = substring_after( val = iv_line sub = gc_delimiter ) ).
    DATA(lv_separator) = COND string(
      WHEN cs_record-rec_type = gc_rec-detail AND detail_text_started( cs_record-raw ) = abap_true THEN ` `
      ELSE gc_delimiter ).
    cs_record-raw = cs_record-raw && lv_separator && lv_data.
    cs_record-phys_count += 1.
  ENDMETHOD.


  METHOD record_type.
    DATA(lv_first) = field( it_fields = split_fields( cut_at_terminator( iv_raw ) )
                            iv_index  = gc_pos-rec_type ).
    IF strlen( lv_first ) = strlen( gc_rec-file_header ).
      rv_type = lv_first.
    ENDIF.
  ENDMETHOD.


  METHOD strip_terminator.
    " Records end at the first '/'; the 16 text may contain '/', so only a final '/' is removed there.
    IF iv_rec_type <> gc_rec-detail.
      rv_raw = cut_at_terminator( iv_raw ).
      RETURN.
    ENDIF.
    rv_raw = trim( iv_raw ).
    DATA(lv_length) = strlen( rv_raw ).
    IF lv_length = 0.
      RETURN.
    ENDIF.
    IF substring( val = rv_raw off = lv_length - 1 ) = gc_terminator.
      rv_raw = trim( substring( val = rv_raw len = lv_length - 1 ) ).
    ENDIF.
  ENDMETHOD.


  METHOD cut_at_terminator.
    DATA(lv_offset) = find( val = iv_raw sub = gc_terminator ).
    rv_raw = COND #( WHEN lv_offset >= 0 THEN substring( val = iv_raw len = lv_offset ) ELSE iv_raw ).
  ENDMETHOD.


  METHOD detail_text_started.
    DATA(lt_fields) = split_fields( iv_raw ).
    rv_started = xsdbool( lines( lt_fields ) >= detail_text_index( lt_fields ) ).
  ENDMETHOD.


  METHOD detail_text_index.
    DATA(ls_funds) = funds_info( it_fields = it_fields iv_index = gc_pos-dtl_funds_type ).
    rv_index = gc_pos-dtl_funds_type + ls_funds-field_count + gc_pos-dtl_ref_fields.
  ENDMETHOD.


  METHOD dispatch_record.
    mv_line_no = is_record-line_no.
    mv_file_records += is_record-phys_count.
    IF mv_file_closed = abap_true.
      add_order_finding( zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-record_after_trailer
                                                iv_v1    = excerpt( is_record-raw )
                                                iv_v2    = is_record-line_no ) ).
      RETURN.
    ENDIF.
    DATA(lt_fields) = split_fields( is_record-raw ).
    CASE is_record-rec_type.
      WHEN gc_rec-file_header.
        on_file_header( is_record = is_record it_fields = lt_fields ).
      WHEN gc_rec-group_header.
        on_group_header( is_record = is_record it_fields = lt_fields ).
      WHEN gc_rec-account.
        on_account( is_record = is_record it_fields = lt_fields ).
      WHEN gc_rec-detail.
        on_detail( is_record = is_record it_fields = lt_fields ).
      WHEN gc_rec-account_trailer.
        on_account_trailer( is_record = is_record it_fields = lt_fields ).
      WHEN gc_rec-group_trailer.
        on_group_trailer( is_record = is_record it_fields = lt_fields ).
      WHEN gc_rec-file_trailer.
        on_file_trailer( lt_fields ).
      WHEN OTHERS.
        on_unknown_record( is_record ).
    ENDCASE.
  ENDMETHOD.


  METHOD on_file_header.
    IF mv_header_seen = abap_true.
      add_order_finding( zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-second_file_header iv_v1 = is_record-line_no ) ).
      RETURN.
    ENDIF.
    mv_header_seen = abap_true.
    ms_file-sender_id    = field( it_fields = it_fields iv_index = gc_pos-hdr_sender ).
    ms_file-receiver_id  = field( it_fields = it_fields iv_index = gc_pos-hdr_receiver ).
    ms_file-created_date = to_date( field( it_fields = it_fields iv_index = gc_pos-hdr_date ) ).
    ms_file-created_time = to_time( field( it_fields = it_fields iv_index = gc_pos-hdr_time ) ).
    ms_file-file_id      = field( it_fields = it_fields iv_index = gc_pos-hdr_file_id ).
  ENDMETHOD.


  METHOD on_group_header.
    close_account( abap_false ).
    close_group( abap_false ).
    mv_group_count += 1.
    ms_group = VALUE #(
      is_open    = abap_true
      group_no   = mv_group_count
      originator = field( it_fields = it_fields iv_index = gc_pos-grp_originator )
      as_of_date = to_date( field( it_fields = it_fields iv_index = gc_pos-grp_as_of_date ) )
      currency   = field( it_fields = it_fields iv_index = gc_pos-grp_currency ) ).
    count_record( is_record-phys_count ).
  ENDMETHOD.


  METHOD on_account.
    close_account( abap_false ).
    IF ms_group-is_open = abap_false.
      add_order_finding( zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account_outside_group iv_v1 = is_record-line_no ) ).
    ENDIF.
    open_account( it_fields ).
    ms_group-account_count += 1.
    count_record( is_record-phys_count ).
    read_summary_groups( it_fields ).
  ENDMETHOD.


  METHOD open_account.
    mv_stmt_index += 1.
    DATA(lv_account) = field( it_fields = it_fields iv_index = gc_pos-acct_number ).
    DATA(lv_currency) = field( it_fields = it_fields iv_index = gc_pos-acct_currency ).
    ms_account = VALUE #( is_open = abap_true ).
    ms_account-stmt = VALUE #(
      stmt_key       = zif_cd_ebs_types=>gc_file_stmt_prefix && |{ mv_stmt_index WIDTH = 4 ALIGN = RIGHT PAD = '0' }|
      format         = zif_cd_ebs_types=>gc_format-bai2
      source         = zif_cd_ebs_types=>gc_source-file
      bank_id        = ms_group-originator
      account_no     = lv_account
      currency       = COND #( WHEN lv_currency IS NOT INITIAL THEN lv_currency ELSE ms_group-currency )
      stmt_id        = |{ ms_file-file_id }-{ ms_group-group_no }-{ lv_account }|
      stmt_no        = ms_file-file_id
      stmt_date      = ms_group-as_of_date
      created_date   = ms_file-created_date
      created_time   = ms_file-created_time
      declared_count = gc_not_declared ).
  ENDMETHOD.


  METHOD read_summary_groups.
    " Repeating groups: type code, amount, item count, funds type [+ funds-type fields]
    DATA(lv_index) = gc_pos-acct_first_group.
    WHILE lv_index <= lines( it_fields ).
      DATA(lv_code) = field( it_fields = it_fields iv_index = lv_index ).
      IF lv_code IS INITIAL.
        " empty field left by a ',/' before an 88 continuation
        lv_index += 1.
        CONTINUE.
      ENDIF.
      apply_summary( iv_code       = lv_code
                     iv_amount_raw = field( it_fields = it_fields iv_index = lv_index + gc_pos-sum_amount )
                     iv_count_raw  = field( it_fields = it_fields iv_index = lv_index + gc_pos-sum_count ) ).
      DATA(ls_funds) = funds_info( it_fields = it_fields iv_index = lv_index + gc_pos-sum_funds_type ).
      lv_index += gc_pos-sum_funds_type + ls_funds-field_count.
    ENDWHILE.
  ENDMETHOD.


  METHOD apply_summary.
    DATA(lv_amount) = to_amount( iv_amount_raw ).
    ms_account-computed_total += lv_amount.
    CASE iv_code.
      WHEN gc_code-total_credits.
        ms_account-stmt-has_totals    = abap_true.
        ms_account-stmt-total_credits = lv_amount.
        ms_account-stmt-credit_count  = to_count( iv_count_raw ).
        ms_account-has_credit_tot     = xsdbool( iv_amount_raw IS NOT INITIAL ).
        ms_account-has_credit_cnt     = xsdbool( iv_count_raw IS NOT INITIAL ).
      WHEN gc_code-total_debits.
        ms_account-stmt-has_totals    = abap_true.
        ms_account-stmt-total_debits  = lv_amount.
        ms_account-stmt-debit_count   = to_count( iv_count_raw ).
        ms_account-has_debit_tot      = xsdbool( iv_amount_raw IS NOT INITIAL ).
        ms_account-has_debit_cnt      = xsdbool( iv_count_raw IS NOT INITIAL ).
      WHEN OTHERS.
        DATA(lv_bal_type) = balance_type( iv_code ).
        IF lv_bal_type IS NOT INITIAL AND iv_amount_raw IS NOT INITIAL.
          add_balance( iv_bal_type = lv_bal_type iv_amount = lv_amount ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD balance_type.
    CASE iv_code.
      WHEN gc_code-opening_ledger.
        rv_bal_type = zif_cd_ebs_types=>gc_balance-opening_booked.
      WHEN gc_code-closing_ledger.
        rv_bal_type = zif_cd_ebs_types=>gc_balance-closing_booked.
      WHEN gc_code-opening_avail.
        rv_bal_type = zif_cd_ebs_types=>gc_balance-opening_avail.
      WHEN gc_code-closing_avail.
        rv_bal_type = zif_cd_ebs_types=>gc_balance-closing_avail.
      WHEN OTHERS.
        " other status (balance) codes 0xx are kept under their BAI2 code
        DATA(lv_number) = code_number( iv_code ).
        IF lv_number BETWEEN 0 AND gc_range-balance_max.
          rv_bal_type = iv_code.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD add_balance.
    APPEND VALUE #( bal_type = iv_bal_type
                    amount   = iv_amount
                    currency = ms_account-stmt-currency
                    bal_date = ms_group-as_of_date ) TO ms_account-stmt-balances.
    CASE iv_bal_type.
      WHEN zif_cd_ebs_types=>gc_balance-opening_booked.
        ms_account-stmt-has_opening = abap_true.
        ms_account-stmt-opening_bal = iv_amount.
      WHEN zif_cd_ebs_types=>gc_balance-closing_booked.
        ms_account-stmt-has_closing = abap_true.
        ms_account-stmt-closing_bal = iv_amount.
    ENDCASE.
  ENDMETHOD.


  METHOD on_detail.
    count_record( is_record-phys_count ).
    IF ms_account-is_open = abap_false.
      add_order_finding( zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-detail_outside_account iv_v1 = is_record-line_no ) ).
      RETURN.
    ENDIF.
    DATA(lv_code) = field( it_fields = it_fields iv_index = gc_pos-dtl_type_code ).
    DATA(lv_amount) = to_amount( field( it_fields = it_fields iv_index = gc_pos-dtl_amount ) ).
    ms_account-computed_total += lv_amount.
    DATA(lv_cdi) = detail_cdi( lv_code ).
    IF lv_cdi IS INITIAL.
      skip_detail( iv_code = lv_code iv_line_no = is_record-line_no ).
      RETURN.
    ENDIF.
    append_line( it_fields = it_fields
                 iv_code   = lv_code
                 iv_cdi    = lv_cdi
                 iv_amount = lv_amount ).
  ENDMETHOD.


  METHOD append_line.
    DATA(ls_funds) = funds_info( it_fields = it_fields iv_index = gc_pos-dtl_funds_type ).
    DATA(lv_text_index) = detail_text_index( it_fields ).
    DATA(ls_line) = VALUE zif_cd_ebs_types=>ty_line(
      stmt_key     = ms_account-stmt-stmt_key
      line_no      = lines( ms_account-lines ) + 1
      scheme       = zif_cd_ebs_types=>gc_scheme-bai2
      btc_code     = iv_code
      cdi          = iv_cdi
      amount       = abs( iv_amount )
      currency     = ms_account-stmt-currency
      booking_date = ms_group-as_of_date
      value_date   = line_value_date( ls_funds )
      bank_ref     = field( it_fields = it_fields iv_index = lv_text_index - gc_pos-dtl_ref_fields )
      cust_ref     = field( it_fields = it_fields iv_index = lv_text_index - 1 )
      addtl_info   = detail_text( it_fields = it_fields iv_index = lv_text_index ) ).
    ls_line-reference = COND #( WHEN ls_line-cust_ref IS NOT INITIAL THEN ls_line-cust_ref ELSE ls_line-bank_ref ).
    ls_line-check_no  = check_number( iv_code = iv_code iv_cust_ref = ls_line-cust_ref ).
    APPEND ls_line TO ms_account-lines.
    IF iv_cdi = zif_cd_ebs_types=>gc_cdi-credit.
      ms_account-credit_lines += 1.
      ms_account-credit_sum   += ls_line-amount.
    ELSE.
      ms_account-debit_lines += 1.
      ms_account-debit_sum   += ls_line-amount.
    ENDIF.
  ENDMETHOD.


  METHOD skip_detail.
    IF code_number( iv_code ) > gc_range-debit_max.
      add_finding( is_check    = stmt_check( gc_check-info_skipped )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-info
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-type_code_in_line_is
                                                        iv_v1    = iv_code
                                                        iv_v2    = iv_line_no ) ).
    ELSE.
      add_finding( is_check    = stmt_check( gc_check-invalid_code )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-error
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-type_code_in_line_is_2
                                                        iv_v1    = iv_code
                                                        iv_v2    = iv_line_no ) ).
    ENDIF.
  ENDMETHOD.


  METHOD detail_cdi.
    DATA(lv_number) = code_number( iv_code ).
    IF lv_number BETWEEN gc_range-credit_min AND gc_range-credit_max.
      rv_cdi = zif_cd_ebs_types=>gc_cdi-credit.
    ELSEIF lv_number BETWEEN gc_range-debit_min AND gc_range-debit_max.
      rv_cdi = zif_cd_ebs_types=>gc_cdi-debit.
    ENDIF.
  ENDMETHOD.


  METHOD code_number.
    rv_number = gc_not_declared.
    IF strlen( iv_code ) = gc_code_length AND iv_code CO gc_digits.
      rv_number = iv_code.
    ENDIF.
  ENDMETHOD.


  METHOD check_number.
    " 475 check paid, 255 check returned, 555 deposited item returned: numeric customer reference
    DATA(lv_reference) = CONV string( iv_cust_ref ).
    IF lv_reference IS INITIAL OR lv_reference CN gc_digits.
      RETURN.
    ENDIF.
    CASE iv_code.
      WHEN gc_code-check_paid OR gc_code-check_returned OR gc_code-item_returned.
        rv_check_no = iv_cust_ref.
    ENDCASE.
  ENDMETHOD.


  METHOD line_value_date.
    IF is_funds-funds_type = gc_funds-value_dated AND is_funds-value_date_raw IS NOT INITIAL.
      rv_date = to_date( is_funds-value_date_raw ).
    ENDIF.
    IF rv_date IS INITIAL.
      rv_date = ms_group-as_of_date.
    ENDIF.
  ENDMETHOD.


  METHOD detail_text.
    " The text is the remainder of the record and may itself contain commas
    DATA lt_parts TYPE string_table.
    LOOP AT it_fields INTO DATA(lv_part) FROM iv_index.
      APPEND lv_part TO lt_parts.
    ENDLOOP.
    rv_text = trim( concat_lines_of( table = lt_parts sep = gc_delimiter ) ).
  ENDMETHOD.


  METHOD on_account_trailer.
    count_record( is_record-phys_count ).
    IF ms_account-is_open = abap_false.
      add_order_finding( zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-acct_trailer_no_account iv_v1 = is_record-line_no ) ).
      RETURN.
    ENDIF.
    DATA(lv_label) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account_trailer_49
                                            iv_v1    = ms_account-stmt-account_no ).
    DATA(lv_total) = compare_total( is_check = stmt_check( iv_check_code = gc_check-acct_ctrl_total
                                                           iv_label      = zcl_cd_ops_util=>text(
                                                                             iv_msgno = zif_cd_ebs_types=>gc_msg-control_total
                                                                             iv_v1    = lv_label ) )
                                    iv_raw   = field( it_fields = it_fields iv_index = gc_pos-trl_total )
                                    iv_found = ms_account-computed_total ).
    compare_count( is_check = stmt_check( iv_check_code = gc_check-record_count
                                          iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-number_of_records
                                                                                 iv_v1    = lv_label ) )
                   iv_raw   = field( it_fields = it_fields iv_index = gc_pos-trl_count_1 )
                   iv_found = ms_account-record_count ).
    close_account( iv_has_trailer = abap_true iv_trailer_total = lv_total ).
  ENDMETHOD.


  METHOD on_group_trailer.
    close_account( abap_false ).
    IF ms_group-is_open = abap_false.
      add_order_finding( zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-group_trailer_no_group iv_v1 = is_record-line_no ) ).
      RETURN.
    ENDIF.
    count_record( is_record-phys_count ).
    DATA(lv_label) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-group_trailer_98 iv_v1 = ms_group-group_no ).
    DATA(lv_total) = compare_total( is_check = file_check( iv_check_code = gc_check-group_ctrl_total
                                                           iv_label      = zcl_cd_ops_util=>text(
                                                                             iv_msgno = zif_cd_ebs_types=>gc_msg-control_total
                                                                             iv_v1    = lv_label ) )
                                    iv_raw   = field( it_fields = it_fields iv_index = gc_pos-trl_total )
                                    iv_found = ms_group-child_total ).
    compare_count( is_check = file_check( iv_check_code = gc_check-account_count
                                          iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-number_of_accounts
                                                                                 iv_v1    = lv_label ) )
                   iv_raw   = field( it_fields = it_fields iv_index = gc_pos-trl_count_1 )
                   iv_found = ms_group-account_count ).
    compare_count( is_check = file_check( iv_check_code = gc_check-record_count
                                          iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-number_of_records
                                                                                 iv_v1    = lv_label ) )
                   iv_raw   = field( it_fields = it_fields iv_index = gc_pos-trl_count_2 )
                   iv_found = ms_group-record_count ).
    close_group( iv_has_trailer = abap_true iv_trailer_total = lv_total ).
  ENDMETHOD.


  METHOD on_file_trailer.
    close_account( abap_false ).
    close_group( abap_false ).
    DATA(lv_total_raw) = field( it_fields = it_fields iv_index = gc_pos-trl_total ).
    DATA(lv_total_label) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-file_trailer_99_control_tot ).
    DATA(lv_total) = compare_total( is_check = file_check( iv_check_code = gc_check-file_ctrl_total
                                                           iv_label      = lv_total_label )
                                    iv_raw   = lv_total_raw
                                    iv_found = mv_file_total ).
    IF strlen( condense( lv_total_raw ) ) > 0.
      ms_file-control_total = lv_total.
    ENDIF.
    compare_count( is_check = file_check( iv_check_code = gc_check-group_count
                                          iv_label      = zcl_cd_ops_util=>text(
                                                            iv_msgno = zif_cd_ebs_types=>gc_msg-file_trailer_99_number_of ) )
                   iv_raw   = field( it_fields = it_fields iv_index = gc_pos-trl_count_1 )
                   iv_found = mv_group_count ).
    compare_count( is_check = file_check( iv_check_code = gc_check-record_count
                                          iv_label      = zcl_cd_ops_util=>text(
                                                            iv_msgno = zif_cd_ebs_types=>gc_msg-file_trailer_99_number_of_2 ) )
                   iv_raw   = field( it_fields = it_fields iv_index = gc_pos-trl_count_2 )
                   iv_found = mv_file_records ).
    mv_file_closed = abap_true.
  ENDMETHOD.


  METHOD on_unknown_record.
    count_record( is_record-phys_count ).
    add_finding( is_check    = current_check( gc_check-unknown_record )
                 iv_rule_id  = gc_rule-structure
                 iv_severity = zif_cd_ops_types=>gc_severity-error
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-unknown_record
                                                      iv_v1    = excerpt( is_record-raw )
                                                      iv_v2    = is_record-line_no ) ).
  ENDMETHOD.


  METHOD count_record.
    IF ms_group-is_open = abap_true.
      ms_group-record_count += iv_phys_count.
    ENDIF.
    IF ms_account-is_open = abap_true.
      ms_account-record_count += iv_phys_count.
    ENDIF.
  ENDMETHOD.


  METHOD close_account.
    IF ms_account-is_open = abap_false.
      RETURN.
    ENDIF.
    IF iv_has_trailer = abap_false.
      add_finding( is_check    = stmt_check( gc_check-missing_trailer )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-error
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account_expected_account_tr
                                                        iv_v1    = ms_account-stmt-account_no
                                                        iv_v2    = mv_line_no ) ).
    ENDIF.
    check_statement_totals( ).
    IF ms_account-lines IS INITIAL.
      add_finding( is_check    = stmt_check( gc_check-no_entries )
                   iv_rule_id  = gc_rule-empty
                   iv_severity = zif_cd_ops_types=>gc_severity-warning
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account_statement_without_d
                                                        iv_v1    = ms_account-stmt-account_no ) ).
    ENDIF.
    ms_group-child_total += COND ty_amount( WHEN iv_has_trailer = abap_true THEN iv_trailer_total
                                            ELSE ms_account-computed_total ).
    APPEND ms_account-stmt TO ms_file-statements.
    APPEND LINES OF ms_account-lines TO ms_file-lines.
    CLEAR ms_account.
  ENDMETHOD.


  METHOD check_statement_totals.
    DATA(lv_label) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account iv_v1 = ms_account-stmt-account_no ).
    IF ms_account-has_credit_tot = abap_true.
      check_total( is_check    = stmt_check( iv_check_code = gc_check-credit_sum
                                             iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-total_credits_100
                                                                                    iv_v1    = lv_label ) )
                   iv_expected = ms_account-stmt-total_credits
                   iv_found    = ms_account-credit_sum ).
    ENDIF.
    IF ms_account-has_debit_tot = abap_true.
      check_total( is_check    = stmt_check( iv_check_code = gc_check-debit_sum
                                             iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-total_debits_400
                                                                                    iv_v1    = lv_label ) )
                   iv_expected = ms_account-stmt-total_debits
                   iv_found    = ms_account-debit_sum ).
    ENDIF.
    IF ms_account-has_credit_cnt = abap_true.
      check_count( is_check    = stmt_check( iv_check_code = gc_check-item_count
                                             iv_label      =
                                               zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-credit_item_count_100
                                                                                    iv_v1    = lv_label ) )
                   iv_expected = ms_account-stmt-credit_count
                   iv_found    = ms_account-credit_lines ).
    ENDIF.
    IF ms_account-has_debit_cnt = abap_true.
      check_count( is_check    = stmt_check( iv_check_code = gc_check-item_count
                                             iv_label      = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-debit_item_count_400
                                                                                    iv_v1    = lv_label ) )
                   iv_expected = ms_account-stmt-debit_count
                   iv_found    = ms_account-debit_lines ).
    ENDIF.
    IF ms_account-has_credit_cnt = abap_true AND ms_account-has_debit_cnt = abap_true.
      ms_account-stmt-declared_count = ms_account-stmt-credit_count + ms_account-stmt-debit_count.
    ENDIF.
  ENDMETHOD.


  METHOD close_group.
    IF ms_group-is_open = abap_false.
      RETURN.
    ENDIF.
    IF iv_has_trailer = abap_false.
      add_finding( is_check    = file_check( gc_check-missing_trailer )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-error
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-group_trailer_missing
                                                        iv_v1    = ms_group-group_no
                                                        iv_v2    = ms_group-originator
                                                        iv_v3    = mv_line_no ) ).
    ENDIF.
    mv_file_total += COND ty_amount( WHEN iv_has_trailer = abap_true THEN iv_trailer_total
                                     ELSE ms_group-child_total ).
    CLEAR ms_group.
  ENDMETHOD.


  METHOD finish_file.
    close_account( abap_false ).
    close_group( abap_false ).
    IF mv_file_closed = abap_false.
      add_finding( is_check    = file_check( gc_check-missing_trailer )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-error
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-file_expected_file_trailer
                                                        iv_v1    = file_key( ) ) ).
    ENDIF.
    IF ms_file-statements IS INITIAL.
      add_finding( is_check    = file_check( gc_check-empty_file )
                   iv_rule_id  = gc_rule-empty
                   iv_severity = zif_cd_ops_types=>gc_severity-block
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-file_expected_at_least_one
                                                        iv_v1    = file_key( ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD check_total.
    IF iv_expected = iv_found.
      RETURN.
    ENDIF.
    DATA lv_difference TYPE ty_amount.
    lv_difference = iv_found - iv_expected.
    add_finding( is_check    = is_check
                 iv_rule_id  = gc_rule-control_total
                 iv_severity = zif_cd_ops_types=>gc_severity-block
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-expected_found_records
                                                      iv_v1    = is_check-label
                                                      iv_v2    = iv_expected
                                                      iv_v3    = iv_found )
                 iv_amount   = lv_difference ).
  ENDMETHOD.


  METHOD check_count.
    IF iv_expected = iv_found.
      RETURN.
    ENDIF.
    add_finding( is_check    = is_check
                 iv_rule_id  = gc_rule-count
                 iv_severity = zif_cd_ops_types=>gc_severity-error
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-expected_found
                                                      iv_v1    = is_check-label
                                                      iv_v2    = iv_expected
                                                      iv_v3    = iv_found ) ).
  ENDMETHOD.


  METHOD compare_total.
    IF strlen( condense( iv_raw ) ) = 0.
      field_missing( is_check    = is_check
                     iv_rule_id  = gc_rule-control_total
                     iv_severity = zif_cd_ops_types=>gc_severity-block ).
      rv_amount = iv_found.
      RETURN.
    ENDIF.
    rv_amount = to_amount( iv_raw ).
    check_total( is_check = is_check iv_expected = rv_amount iv_found = iv_found ).
  ENDMETHOD.


  METHOD compare_count.
    IF strlen( condense( iv_raw ) ) = 0.
      field_missing( is_check    = is_check
                     iv_rule_id  = gc_rule-count
                     iv_severity = zif_cd_ops_types=>gc_severity-error ).
      RETURN.
    ENDIF.
    check_count( is_check = is_check iv_expected = to_count( iv_raw ) iv_found = iv_found ).
  ENDMETHOD.


  METHOD field_missing.
    DATA(ls_check) = is_check.
    ls_check-check_code = gc_check-trailer_missing.
    add_finding( is_check    = ls_check
                 iv_rule_id  = iv_rule_id
                 iv_severity = iv_severity
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-trailer_field_missing
                                                      iv_v1    = is_check-label ) ).
  ENDMETHOD.


  METHOD add_finding.
    DATA(lv_currency) = COND zif_cd_ops_types=>ty_currency(
      WHEN iv_amount IS INITIAL THEN space
      WHEN ms_account-is_open = abap_true THEN ms_account-stmt-currency
      ELSE ms_group-currency ).
    APPEND VALUE #( object_type = is_check-object_type
                    object_key  = is_check-object_key
                    rule_id     = iv_rule_id
                    check_code  = is_check-check_code
                    severity    = iv_severity
                    amount      = iv_amount
                    currency    = lv_currency
                    message     = iv_message ) TO ms_file-findings.
  ENDMETHOD.


  METHOD add_order_finding.
    add_finding( is_check    = current_check( gc_check-record_order )
                 iv_rule_id  = gc_rule-structure
                 iv_severity = zif_cd_ops_types=>gc_severity-error
                 iv_message  = iv_message ).
  ENDMETHOD.


  METHOD file_check.
    rs_check = VALUE #( object_type = gc_object-file
                        object_key  = file_key( )
                        check_code  = iv_check_code
                        label       = iv_label ).
  ENDMETHOD.


  METHOD stmt_check.
    rs_check = VALUE #( object_type = gc_object-statement
                        object_key  = ms_account-stmt-stmt_key
                        check_code  = iv_check_code
                        label       = iv_label ).
  ENDMETHOD.


  METHOD current_check.
    rs_check = COND #( WHEN ms_account-is_open = abap_true THEN stmt_check( iv_check_code )
                       ELSE file_check( iv_check_code ) ).
  ENDMETHOD.


  METHOD file_key.
    rv_key = COND #( WHEN ms_file-file_name IS NOT INITIAL THEN ms_file-file_name ELSE ms_file-file_id ).
  ENDMETHOD.


  METHOD split_fields.
    " Unlike SPLIT, keeps every empty field, trailing ones included (positions matter)
    DATA(lv_offset) = 0.
    DO.
      DATA(lv_comma) = find( val = iv_raw sub = gc_delimiter off = lv_offset ).
      IF lv_comma < 0.
        APPEND substring( val = iv_raw off = lv_offset ) TO rt_fields.
        RETURN.
      ENDIF.
      APPEND substring( val = iv_raw off = lv_offset len = lv_comma - lv_offset ) TO rt_fields.
      lv_offset = lv_comma + 1.
    ENDDO.
  ENDMETHOD.


  METHOD field.
    rv_value = condense( VALUE string( it_fields[ iv_index ] OPTIONAL ) ).
  ENDMETHOD.


  METHOD funds_info.
    rs_funds-funds_type = to_upper( field( it_fields = it_fields iv_index = iv_index ) ).
    CASE rs_funds-funds_type.
      WHEN gc_funds-value_dated.
        " V: value date (YYMMDD) and value time
        rs_funds-value_date_raw = field( it_fields = it_fields iv_index = iv_index + 1 ).
        rs_funds-field_count    = gc_funds_fields-value_dated.
      WHEN gc_funds-distributed.
        " S: immediate, one-day and two-or-more-day amounts
        rs_funds-field_count = gc_funds_fields-distributed.
      WHEN gc_funds-detailed.
        " D: number of distributions n, then n pairs (days, amount)
        rs_funds-field_count = gc_funds_fields-detailed_base + gc_funds_fields-per_pair
                               * to_count( field( it_fields = it_fields iv_index = iv_index + 1 ) ).
      WHEN OTHERS.
        " blank, Z, 0, 1, 2: no further fields
        rs_funds-field_count = gc_funds_fields-plain.
    ENDCASE.
  ENDMETHOD.


  METHOD to_amount.
    " No decimal point in BAI2: two implied decimals; optional sign
    DATA(lv_value) = condense( iv_value ).
    IF lv_value IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_sign) = 1.
    DATA(lv_digits) = lv_value.
    DATA(lv_first) = substring( val = lv_value len = 1 ).
    IF lv_first = gc_minus OR lv_first = gc_plus.
      lv_sign = COND #( WHEN lv_first = gc_minus THEN -1 ELSE 1 ).
      lv_digits = substring( val = lv_value off = 1 ).
    ENDIF.
    IF lv_digits IS INITIAL OR lv_digits CN gc_digits OR strlen( lv_digits ) > gc_max_amount_digits.
      add_finding( is_check    = current_check( gc_check-invalid_amount )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-error
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-line_expected_amount_of_dig
                                                        iv_v1    = mv_line_no
                                                        iv_v2    = lv_value ) ).
      RETURN.
    ENDIF.
    rv_amount = lv_sign * CONV decfloat34( lv_digits ) / gc_implied_divisor.
  ENDMETHOD.


  METHOD to_count.
    DATA(lv_value) = condense( iv_value ).
    IF lv_value IS NOT INITIAL AND lv_value CO gc_digits AND strlen( lv_value ) <= gc_max_count_digits.
      rv_count = lv_value.
    ENDIF.
  ENDMETHOD.


  METHOD to_date.
    " YYMMDD, century 20
    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.
    DATA lv_days TYPE i.
    IF strlen( iv_value ) = gc_date_length AND iv_value CO gc_digits.
      rv_date = |{ gc_century }{ iv_value }|.
      lv_days = rv_date.
    ENDIF.
    IF lv_days = 0.
      CLEAR rv_date.
      add_finding( is_check    = current_check( gc_check-invalid_date )
                   iv_rule_id  = gc_rule-structure
                   iv_severity = zif_cd_ops_types=>gc_severity-error
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-line_expected_date_yymmdd_f
                                                        iv_v1    = mv_line_no
                                                        iv_v2    = iv_value ) ).
    ENDIF.
  ENDMETHOD.


  METHOD to_time.
    " HHMM; 2400 and 9999 mean end of day
    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.
    IF iv_value = gc_end_of_day_2400 OR iv_value = gc_end_of_day_9999.
      rv_time = gc_end_of_day_time.
      RETURN.
    ENDIF.
    IF strlen( iv_value ) = gc_time_length AND iv_value CO gc_digits.
      DATA(lv_hours) = CONV i( substring( val = iv_value len = 2 ) ).
      DATA(lv_minutes) = CONV i( substring( val = iv_value off = 2 len = 2 ) ).
      IF lv_hours < gc_hours_per_day AND lv_minutes < gc_minutes_per_hour.
        rv_time = |{ iv_value }{ gc_seconds_suffix }|.
        RETURN.
      ENDIF.
    ENDIF.
    add_finding( is_check    = current_check( gc_check-invalid_date )
                 iv_rule_id  = gc_rule-structure
                 iv_severity = zif_cd_ops_types=>gc_severity-error
                 iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-line_expected_time_hhmm_fou
                                                      iv_v1    = mv_line_no
                                                      iv_v2    = iv_value ) ).
  ENDMETHOD.


  METHOD trim.
    rv_text = shift_left( val = shift_right( val = iv_text sub = ` ` ) sub = ` ` ).
  ENDMETHOD.


  METHOD excerpt.
    rv_text = substring( val = iv_text len = nmin( val1 = strlen( iv_text ) val2 = gc_excerpt_length ) ).
  ENDMETHOD.

ENDCLASS.
