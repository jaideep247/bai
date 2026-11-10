*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_ack_mail.clas.abap
*& Purpose:
*& Missing or late bank ACK in the alert e-mail (user request 2026-11-10).
*& File monitoring writes the evidence of each file into the finding's
*& DETAILS as labelled lines (label: value, one block per file, marker line
*& first; labels are ZCD_OPS messages GC_ACK_MSG). This class writes such a
*& line and reads the blocks back for the alert policy: one row per file,
*& sorted most overdue first (earliest ACK due), the totals (files,
*& payments, amount per currency), the impact-first subject and the HTML
*& table / text version. Pure logic: no database, no delivery. A value that
*& was not known is shown as such and never counted as 0.
*& Modification log:
*& 2026-11-10 | Initial version (missing bank ACK alert, user request 2026-11-10).
*& 2026-11-10 | Alert section plug-in of the framework ZCA_OPS (ZIF_CA_OPS_ALERT_SECTION, parameter
*&            | ALERT_SECTION_CLASS): the framework's alert policy no longer calls this class directly.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - missing bank ACK alert table</p>
CLASS zcl_cd_ops_ack_mail DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! The alert section of missing / late bank ACK findings (configured in ALERT_SECTION_CLASS)
    INTERFACES zif_ca_ops_alert_section.

    "! One file of a missing / late ACK finding as shown in the e-mail
    TYPES:
      BEGIN OF ty_row,
        house_bank     TYPE string,
        bank           TYPE string,
        file_name      TYPE string,
        pay_method     TYPE string,
        payments       TYPE string,
        payments_count TYPE i,
        payments_known TYPE abap_bool,
        amount         TYPE string,
        amount_value   TYPE decfloat34,
        currency       TYPE zif_ca_ops_types=>ty_currency,
        amount_known   TYPE abap_bool,
        pay_run        TYPE string,
        generated      TYPE string,
        delivered      TYPE string,
        ack_due        TYPE string,
        overdue        TYPE string,
      END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_currency_total,
        currency TYPE zif_ca_ops_types=>ty_currency,
        amount   TYPE decfloat34,
      END OF ty_currency_total.
    TYPES tt_currency_total TYPE SORTED TABLE OF ty_currency_total WITH UNIQUE KEY currency.

    TYPES:
      BEGIN OF ty_totals,
        files    TYPE i,
        payments TYPE i,
        "! Files whose payment count was not known (not in PAYMENTS)
        unknown  TYPE i,
        amounts  TYPE tt_currency_total,
      END OF ty_totals.

    "! First line of the DETAILS of a missing / late ACK finding
    CLASS-METHODS marker
      RETURNING
        VALUE(rv_line) TYPE string.

    "! One detail line: label (ZCD_OPS message without variables), separator, value
    CLASS-METHODS line
      IMPORTING
        iv_label       TYPE zif_ca_ops_types=>ty_msgno
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_line) TYPE string.

    "! The finding carries missing / late ACK evidence (DETAILS starts with the marker)
    CLASS-METHODS is_ack
      IMPORTING
        is_finding    TYPE zif_ca_ops_types=>ty_finding
      RETURNING
        VALUE(rv_ack) TYPE abap_bool.

    "! Rows of every ACK finding, most overdue first (earliest ACK due; unknown due last)
    CLASS-METHODS rows
      IMPORTING
        it_findings    TYPE zif_ca_ops_types=>tt_finding
      RETURNING
        VALUE(rt_rows) TYPE tt_row.

    CLASS-METHODS totals
      IMPORTING
        it_rows          TYPE tt_row
      RETURNING
        VALUE(rs_totals) TYPE ty_totals.

    "! [<area>][<severity>] Missing bank ACK: <n> file(s), <payments> payments, <CUR> <total>
    CLASS-METHODS subject
      IMPORTING
        it_rows           TYPE tt_row
        iv_pe_area        TYPE zif_ca_ops_types=>ty_area
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
      RETURNING
        VALUE(rv_subject) TYPE string.

    "! Table House bank | Bank | File name | Payment method | Payments | Amount | Payment run |
    "! Generated | Delivered to bank | ACK due | Overdue by, with a totals row (HTML-escaped)
    CLASS-METHODS html
      IMPORTING
        it_rows        TYPE tt_row
      RETURNING
        VALUE(rv_html) TYPE string.

    "! The same table as text lines (columns separated by ' | ')
    CLASS-METHODS text
      IMPORTING
        it_rows        TYPE tt_row
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_html,
        table_open TYPE string VALUE `<table border="1" cellpadding="4" style="border-collapse:collapse">`,
        table_close TYPE string VALUE `</table>`,
        tr_open    TYPE string VALUE `<tr>`,
        tr_close   TYPE string VALUE `</tr>`,
        th_open    TYPE string VALUE `<th>`,
        th_close   TYPE string VALUE `</th>`,
        td_open    TYPE string VALUE `<td>`,
        td_right   TYPE string VALUE `<td style="text-align:right">`,
        td_close   TYPE string VALUE `</td>`,
        line_break TYPE string VALUE `<br>`,
      END OF gc_html.
    CONSTANTS gc_column_separator TYPE string VALUE ` | `.
    CONSTANTS gc_amount_separator TYPE string VALUE `; `.
    CONSTANTS gc_blank TYPE string VALUE ` `.
    CONSTANTS gc_digits TYPE string VALUE `0123456789`.

    "! Column labels in table order
    CLASS-METHODS columns
      RETURNING
        VALUE(rt_labels) TYPE string_table.

    "! Cell values of a row in table order
    CLASS-METHODS cells
      IMPORTING
        is_row          TYPE ty_row
      RETURNING
        VALUE(rt_cells) TYPE string_table.

    "! Cell values of the totals row in table order
    CLASS-METHODS total_cells
      IMPORTING
        is_totals       TYPE ty_totals
      RETURNING
        VALUE(rt_cells) TYPE string_table.

    CLASS-METHODS amounts_text
      IMPORTING
        it_amounts     TYPE tt_currency_total
        iv_separator   TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS label
      IMPORTING
        iv_msgno       TYPE zif_ca_ops_types=>ty_msgno
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_ops_ack_mail IMPLEMENTATION.

  METHOD zif_ca_ops_alert_section~owns.
    rv_owns = is_ack( is_finding ).
  ENDMETHOD.


  METHOD zif_ca_ops_alert_section~subject.
    rv_subject = subject( it_rows     = rows( it_findings )
                          iv_pe_area  = iv_area
                          iv_severity = iv_severity ).
  ENDMETHOD.


  METHOD zif_ca_ops_alert_section~html.
    rv_html = html( rows( it_findings ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_alert_section~text.
    rv_text = text( rows( it_findings ) ).
  ENDMETHOD.


  METHOD marker.
    rv_line = label( zif_cd_ops_types=>gc_ack_msg-marker ).
  ENDMETHOD.


  METHOD line.
    rv_line = |{ label( iv_label ) }{ zif_cd_ops_types=>gc_ack_label_separator }{ condense( CONV string( iv_value ) ) }|.
  ENDMETHOD.


  METHOD is_ack.
    SPLIT is_finding-details AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).
    rv_ack = xsdbool( lt_lines IS NOT INITIAL AND lt_lines[ 1 ] = marker( ) ).
  ENDMETHOD.


  METHOD rows.
    DATA ls_row TYPE ty_row.

    DATA(lv_unknown) = label( zif_cd_ops_types=>gc_ack_msg-unknown ).
    LOOP AT it_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      IF is_ack( <ls_finding> ) = abap_false.
        CONTINUE.
      ENDIF.
      SPLIT <ls_finding>-details AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).
      " an empty line (and the end) closes the block of one file
      INSERT `` INTO TABLE lt_lines.
      CLEAR ls_row.
      LOOP AT lt_lines INTO DATA(lv_line) FROM 2.
        IF lv_line IS INITIAL.
          IF ls_row-file_name IS NOT INITIAL.
            INSERT ls_row INTO TABLE rt_rows.
          ENDIF.
          CLEAR ls_row.
          CONTINUE.
        ENDIF.
        SPLIT lv_line AT zif_cd_ops_types=>gc_ack_label_separator INTO DATA(lv_label) DATA(lv_value).
        DATA(lv_known) = xsdbool( lv_value <> lv_unknown ).
        CASE lv_label.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-house_bank ).
            ls_row-house_bank = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-bank ).
            ls_row-bank = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-file_name ).
            ls_row-file_name = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-pay_method ).
            ls_row-pay_method = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-payments ).
            ls_row-payments       = lv_value.
            ls_row-payments_known = xsdbool( lv_known = abap_true AND lv_value CO gc_digits ).
            IF ls_row-payments_known = abap_true.
              ls_row-payments_count = lv_value.
            ENDIF.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-amount ).
            ls_row-amount = lv_value.
            IF lv_known = abap_true.
              " written as '<currency> <amount with thousands separators>'
              SPLIT lv_value AT gc_blank INTO DATA(lv_currency) DATA(lv_number).
              ls_row-currency     = lv_currency.
              ls_row-amount_value = zcl_ca_ops_util=>to_decimal(
                                      replace( val = lv_number sub = zcl_ca_ops_util=>gc_thousands_separator
                                               with = `` occ = 0 ) ).
              ls_row-amount_known = abap_true.
            ENDIF.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-pay_run ).
            ls_row-pay_run = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-generated ).
            ls_row-generated = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-delivered ).
            ls_row-delivered = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-ack_due ).
            ls_row-ack_due = lv_value.
          WHEN label( zif_cd_ops_types=>gc_ack_msg-overdue ).
            ls_row-overdue = lv_value.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.
    " most overdue first: the earliest ACK due (ISO date and time sort as text); unknown due last
    SORT rt_rows BY ack_due file_name.
    DATA(lt_no_due) = VALUE tt_row( FOR ls IN rt_rows WHERE ( ack_due IS INITIAL OR ack_due = lv_unknown ) ( ls ) ).
    DELETE rt_rows WHERE ack_due IS INITIAL OR ack_due = lv_unknown.
    INSERT LINES OF lt_no_due INTO TABLE rt_rows.
  ENDMETHOD.


  METHOD totals.
    rs_totals-files = lines( it_rows ).
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF <ls_row>-payments_known = abap_true.
        rs_totals-payments += <ls_row>-payments_count.
      ELSE.
        rs_totals-unknown += 1.
      ENDIF.
      IF <ls_row>-amount_known = abap_true.
        READ TABLE rs_totals-amounts ASSIGNING FIELD-SYMBOL(<ls_amount>) WITH TABLE KEY currency = <ls_row>-currency.
        IF sy-subrc <> 0.
          INSERT VALUE #( currency = <ls_row>-currency ) INTO TABLE rs_totals-amounts ASSIGNING <ls_amount>.
        ENDIF.
        <ls_amount>-amount += <ls_row>-amount_value.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD subject.
    DATA(ls_totals) = totals( it_rows ).
    rv_subject = |[{ iv_pe_area }][{ iv_severity }] |
              && zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_ack_msg-subject
                                        iv_v1    = ls_totals-files
                                        iv_v2    = ls_totals-payments
                                        iv_v3    = amounts_text( it_amounts   = ls_totals-amounts
                                                                 iv_separator = gc_amount_separator ) ).
  ENDMETHOD.


  METHOD html.
    IF it_rows IS INITIAL.
      RETURN.
    ENDIF.
    rv_html = gc_html-table_open && gc_html-tr_open.
    LOOP AT columns( ) INTO DATA(lv_title).
      rv_html = rv_html && gc_html-th_open && zcl_ca_ops_util=>html_escape( lv_title ) && gc_html-th_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-tr_close.
    DATA(lv_payments_col) = 5.
    DATA(lv_amount_col) = 6.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      rv_html = rv_html && gc_html-tr_open.
      LOOP AT cells( <ls_row> ) INTO DATA(lv_cell).
        rv_html = rv_html && COND string( WHEN sy-tabix = lv_payments_col OR sy-tabix = lv_amount_col
                                          THEN gc_html-td_right ELSE gc_html-td_open )
               && zcl_ca_ops_util=>html_escape( lv_cell ) && gc_html-td_close.
      ENDLOOP.
      rv_html = rv_html && gc_html-tr_close.
    ENDLOOP.
    DATA(lt_total) = total_cells( totals( it_rows ) ).
    rv_html = rv_html && gc_html-tr_open.
    LOOP AT lt_total INTO lv_cell.
      DATA(lv_index) = sy-tabix.
      rv_html = rv_html && COND string( WHEN lv_index = lv_payments_col OR lv_index = lv_amount_col
                                        THEN gc_html-td_right ELSE gc_html-td_open )
             && replace( val  = zcl_ca_ops_util=>html_escape( lv_cell )
                         sub  = cl_abap_char_utilities=>newline
                         with = gc_html-line_break
                         occ  = 0 )
             && gc_html-td_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-tr_close && gc_html-table_close.
  ENDMETHOD.


  METHOD text.
    IF it_rows IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = concat_lines_of( table = columns( ) sep = gc_column_separator ).
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      rv_text = |{ rv_text }{ cl_abap_char_utilities=>newline }|
             && concat_lines_of( table = cells( <ls_row> ) sep = gc_column_separator ).
    ENDLOOP.
    DATA(lt_total) = total_cells( totals( it_rows ) ).
    rv_text = |{ rv_text }{ cl_abap_char_utilities=>newline }|
           && replace( val  = concat_lines_of( table = lt_total sep = gc_column_separator )
                       sub  = cl_abap_char_utilities=>newline
                       with = gc_amount_separator
                       occ  = 0 ).
  ENDMETHOD.


  METHOD columns.
    rt_labels = VALUE #( ( label( zif_cd_ops_types=>gc_ack_msg-house_bank ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-bank ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-file_name ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-pay_method ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-payments ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-amount ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-pay_run ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-generated ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-delivered ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-ack_due ) )
                         ( label( zif_cd_ops_types=>gc_ack_msg-overdue ) ) ).
  ENDMETHOD.


  METHOD cells.
    rt_cells = VALUE #( ( is_row-house_bank ) ( is_row-bank ) ( is_row-file_name ) ( is_row-pay_method )
                        ( is_row-payments ) ( is_row-amount ) ( is_row-pay_run ) ( is_row-generated )
                        ( is_row-delivered ) ( is_row-ack_due ) ( is_row-overdue ) ).
  ENDMETHOD.


  METHOD total_cells.
    " Total | files | | | payments | amount per currency (one per line) | ...
    rt_cells = VALUE #( ( label( zif_cd_ops_types=>gc_ack_msg-total ) )
                        ( `` )
                        ( |{ is_totals-files }| )
                        ( `` )
                        ( COND string( WHEN is_totals-unknown > 0
                                       THEN |{ is_totals-payments } + { label( zif_cd_ops_types=>gc_ack_msg-unknown ) }|
                                       ELSE |{ is_totals-payments }| ) )
                        ( amounts_text( it_amounts   = is_totals-amounts
                                        iv_separator = CONV #( cl_abap_char_utilities=>newline ) ) )
                        ( `` ) ( `` ) ( `` ) ( `` ) ( `` ) ).
  ENDMETHOD.


  METHOD amounts_text.
    DATA lt_parts TYPE string_table.
    LOOP AT it_amounts ASSIGNING FIELD-SYMBOL(<ls_amount>).
      INSERT |{ <ls_amount>-currency } { zcl_ca_ops_util=>format_amount( <ls_amount>-amount ) }| INTO TABLE lt_parts.
    ENDLOOP.
    rv_text = COND #( WHEN lt_parts IS INITIAL THEN label( zif_cd_ops_types=>gc_ack_msg-unknown )
                      ELSE concat_lines_of( table = lt_parts sep = iv_separator ) ).
  ENDMETHOD.


  METHOD label.
    rv_text = zcl_cd_ops_util=>text( iv_msgno ).
  ENDMETHOD.

ENDCLASS.
