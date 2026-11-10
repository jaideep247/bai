*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_ack_mail.clas.testclasses.abap
*& Purpose:
*& Domain tests of the missing bank ACK table: two files in different
*& currencies give one row each (most overdue first) and totals per
*& currency, the subject leads with files, payments and amounts, an unknown
*& count is not added as 0, a finding without ACK evidence is no row; on
*& the template mechanism of the framework the subject is the key SUBJECT,
*& the table the block TABLE_SECTION of ZCD_OPS_ALERT_ACK (a rule's own
*& template wins).
*& No doubles. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (missing bank ACK alert, user request 2026-11-10).
*& 2026-11-10 | Template mechanism: ACK subject = key SUBJECT, table = block TABLE_SECTION of ZCD_OPS_ALERT_ACK,
*&            | rule template wins; subject test expects the area constant (was the former area name).
*&---------------------------------------------------------------------*
CLASS ltc_ack_mail DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        file_usd TYPE string VALUE `ACH_JPMC_20261110_01.txt`,
        file_cad TYPE string VALUE `WIRE_BOA_20261110_02.txt`,
        due_early TYPE string VALUE `2026-11-10 09:00:00 CST`,
        due_late  TYPE string VALUE `2026-11-10 11:00:00 CST`,
        usd      TYPE zif_ca_ops_types=>ty_currency VALUE 'USD',
        cad      TYPE zif_ca_ops_types=>ty_currency VALUE 'CAD',
        amount_usd TYPE string VALUE `USD 1,234,567.80`,
        amount_cad TYPE string VALUE `CAD 2,500.00`,
      END OF gc_test.

    METHODS two_currencies_two_totals FOR TESTING.
    METHODS most_overdue_first        FOR TESTING.
    METHODS subject_leads_with_impact FOR TESTING.
    METHODS unknown_count_not_added   FOR TESTING.
    METHODS other_finding_is_no_row   FOR TESTING.
    METHODS html_has_totals_row       FOR TESTING.
    METHODS template_section_and_subject FOR TESTING.
    METHODS rule_template_wins        FOR TESTING.

    "! The alert message of the framework's policy with this section for the ACK files
    METHODS message
      IMPORTING
        iv_rule_template  TYPE zif_ca_ops_types=>ty_template_id OPTIONAL
      RETURNING
        VALUE(rs_message) TYPE zif_ca_ops_types=>ty_alert_message.

    METHODS ack_finding
      IMPORTING
        iv_file           TYPE string
        iv_amount         TYPE string
        iv_payments       TYPE string
        iv_due            TYPE string
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    METHODS two_files
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.
ENDCLASS.


CLASS ltc_ack_mail IMPLEMENTATION.

  METHOD ack_finding.
    DATA(lv_nl) = cl_abap_char_utilities=>newline.
    rs_finding-check_code = 'NO_BANK_ACK'.
    rs_finding-details = zcl_cd_ops_ack_mail=>marker( )
      && lv_nl && zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-house_bank iv_value = `JPMC1` )
      && lv_nl && zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-file_name iv_value = iv_file )
      && lv_nl && zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-payments iv_value = iv_payments )
      && lv_nl && zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-amount iv_value = iv_amount )
      && lv_nl && zcl_cd_ops_ack_mail=>line( iv_label = zif_cd_ops_types=>gc_ack_msg-ack_due iv_value = iv_due ).
  ENDMETHOD.


  METHOD two_files.
    rt_findings = VALUE #( ( ack_finding( iv_file = gc_test-file_cad iv_amount = gc_test-amount_cad
                                          iv_payments = `1` iv_due = gc_test-due_late ) )
                           ( ack_finding( iv_file = gc_test-file_usd iv_amount = gc_test-amount_usd
                                          iv_payments = `120` iv_due = gc_test-due_early ) ) ).
  ENDMETHOD.


  " Two files in two currencies: one total per currency, never added together
  METHOD two_currencies_two_totals.
    DATA(ls_totals) = zcl_cd_ops_ack_mail=>totals( zcl_cd_ops_ack_mail=>rows( two_files( ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_totals-files exp = 2 msg = 'Two files' ).
    cl_abap_unit_assert=>assert_equals( act = ls_totals-payments exp = 121 msg = 'Payments added' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_totals-amounts
      exp = VALUE zcl_cd_ops_ack_mail=>tt_currency_total( ( currency = gc_test-cad amount = '2500.00' )
                                                         ( currency = gc_test-usd amount = '1234567.80' ) )
      msg = 'One amount per currency' ).
  ENDMETHOD.


  " The earliest ACK due is the most overdue file and comes first
  METHOD most_overdue_first.
    DATA(lt_rows) = zcl_cd_ops_ack_mail=>rows( two_files( ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-file_name exp = gc_test-file_usd
                                        msg = 'Due 09:00 before due 11:00' ).
  ENDMETHOD.


  " Subject: [area][severity] Missing bank ACK: files, payments, amounts
  METHOD subject_leads_with_impact.
    DATA(lv_subject) = zcl_cd_ops_ack_mail=>subject( it_rows     = zcl_cd_ops_ack_mail=>rows( two_files( ) )
                                                     iv_pe_area  = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                     iv_severity = zif_ca_ops_types=>gc_severity-error ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_subject
      exp = |[{ zif_cd_ops_types=>gc_pe_area-file_monitor }][E] { zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_types=>gc_ack_msg-subject
                                                 iv_v1    = 2
                                                 iv_v2    = 121
                                                 iv_v3    = |{ gc_test-amount_cad }; { gc_test-amount_usd }| ) }|
      msg = 'Area, severity, files, payments, amounts per currency' ).
  ENDMETHOD.


  " A count that was not known is not added as 0 - the total says so
  METHOD unknown_count_not_added.
    DATA(lt_findings) = two_files( ).
    INSERT ack_finding( iv_file = `POSPAY_PNC.txt` iv_amount = zcl_cd_ops_util=>text( zif_cd_ops_types=>gc_ack_msg-unknown )
                        iv_payments = zcl_cd_ops_util=>text( zif_cd_ops_types=>gc_ack_msg-unknown )
                        iv_due = gc_test-due_late ) INTO TABLE lt_findings.
    DATA(ls_totals) = zcl_cd_ops_ack_mail=>totals( zcl_cd_ops_ack_mail=>rows( lt_findings ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_totals-payments exp = 121 msg = 'Known payments only' ).
    cl_abap_unit_assert=>assert_equals( act = ls_totals-unknown exp = 1 msg = 'One file with unknown count' ).
  ENDMETHOD.


  " A finding without ACK evidence is not a row of the ACK table
  METHOD other_finding_is_no_row.
    DATA(lt_findings) = two_files( ).
    INSERT VALUE #( check_code = 'FILE_MISSING' details = `Trace` ) INTO TABLE lt_findings.
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_cd_ops_ack_mail=>rows( lt_findings ) ) exp = 2
                                        msg = 'Only the two ACK files' ).
  ENDMETHOD.


  " The HTML table ends with the totals row: both currencies, right-aligned amounts
  METHOD html_has_totals_row.
    DATA(lv_html) = zcl_cd_ops_ack_mail=>html( zcl_cd_ops_ack_mail=>rows( two_files( ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_html CS gc_test-amount_usd AND lv_html CS gc_test-amount_cad )
                                      msg = 'Both amounts formatted' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_html CS zcl_cd_ops_util=>text( zif_cd_ops_types=>gc_ack_msg-total ) )
                                      msg = 'Totals row' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lv_html CS `text-align:right` )
                                      msg = 'Amounts right-aligned' ).
  ENDMETHOD.


  METHOD message.
    DATA ls_selection TYPE zcl_ca_ops_alert_policy=>ty_selection.
    DATA ls_run       TYPE zif_ca_ops_types=>ty_run.
    ls_run-area   = zif_cd_ops_types=>gc_pe_area-file_monitor.
    ls_run-status = zif_ca_ops_types=>gc_run_status-error.
    ls_selection-rule-rule_id      = 'ZT_ACK'.
    ls_selection-rule-channel      = zif_ca_ops_types=>gc_channel-email.
    ls_selection-rule-digest       = abap_true.
    ls_selection-rule-max_items    = 50.
    ls_selection-rule-template_id  = iv_rule_template.
    ls_selection-rule-show_amounts = abap_true.
    ls_selection-findings          = two_files( ).
    DATA(lt_messages) = NEW zcl_ca_ops_alert_policy( io_section = NEW zcl_cd_ops_ack_mail( ) )->build_messages(
                          is_selection   = ls_selection
                          is_run         = ls_run
                          iv_destination = 'ZT_LIST' ).
    rs_message = lt_messages[ 1 ].
  ENDMETHOD.


  " Template mechanism (2026-11-10): the ACK subject is the key SUBJECT, the file table the block
  " TABLE_SECTION of ZCD_OPS_ALERT_ACK - same subject, sorting and totals as before
  METHOD template_section_and_subject.
    TRY.
        DATA(ls_message) = message( ).
        DATA(lt_rows) = zcl_cd_ops_ack_mail=>rows( two_files( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-template_id exp = zif_cd_ops_types=>gc_ack_template
                                            msg = 'The ACK template when the rule names none' ).
        cl_abap_unit_assert=>assert_equals(
          act = CONV string( ls_message-context-header-subject )
          exp = |[{ sy-sysid }]| && zcl_cd_ops_ack_mail=>subject( it_rows     = lt_rows
                                                                 iv_pe_area  = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                                 iv_severity = zif_ca_ops_types=>gc_severity-error )
          msg = 'The impact-first ACK subject is the key SUBJECT' ).
        DATA(ls_block) = ls_message-context-blocks[ name = zif_ca_ops_types=>gc_mail_block-section ].
        cl_abap_unit_assert=>assert_equals( act = ls_block-html exp = zcl_cd_ops_ack_mail=>html( lt_rows )
                                            msg = 'The file table is the block TABLE_SECTION' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_message-html CS gc_test-amount_usd
                                                         AND ls_message-html CS gc_test-file_cad )
                                          msg = 'The built-in layout carries the table' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD rule_template_wins.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = message( iv_rule_template = 'ZT_RULE_TPL' )-template_id
                                            exp = 'ZT_RULE_TPL'
                                            msg = 'A rule with its own template keeps it' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
