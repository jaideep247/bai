*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_util.clas.testclasses.abap
*& Purpose:
*& Domain tests of the shared helpers: severity ranking, RAG derivation, key
*& normalisation, list splitting, HTML escaping, elapsed time, safe decimal
*& conversion. No doubles. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Test text_fills_message_vars (texts as ZCD_OPS messages).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | PCRE patterns: whole-value match, case ignored, invalid pattern, literal count.
*& 2026-11-07 | param_int (shared integer parameter helper) over the shared fake ZCL_CD_OPS_PARAMS_MEM.
*& 2026-11-07 | Tests of the removed rag_from_value dropped.
*& 2026-11-07 | param_int over ZCA_PARAM (ZCL_CD_OPS_PARAM_SEED, INT parameter without definition
*&            | default): a value that is not a number is a logged parameter error and gives the default.
*& 2026-11-10 | exception_trace, error_class, account_label, job_link (test seam JOB_INFO); format_amount.
*&---------------------------------------------------------------------*
CLASS ltc_util DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS block_outranks_error         FOR TESTING.
    METHODS worst_of_mixed_findings      FOR TESTING.
    METHODS warning_findings_are_amber   FOR TESTING.
    METHODS red_beats_amber              FOR TESTING.
    METHODS key_padded_after_zero_strip  FOR TESTING.
    METHODS key_length_zero_keeps_value  FOR TESTING.
    METHODS list_split_on_comma_and_semi FOR TESTING.
    METHODS markup_is_escaped            FOR TESTING.
    METHODS elapsed_crosses_minute       FOR TESTING.
    METHODS bad_decimal_gives_default    FOR TESTING.
    METHODS int_param_reads_value        FOR TESTING.
    METHODS int_param_blank_is_default   FOR TESTING.
    METHODS int_param_text_is_default    FOR TESTING.
    METHODS text_fills_message_vars      FOR TESTING.
    METHODS text_tail_is_not_truncated   FOR TESTING.
    METHODS pcre_matches_whole_value     FOR TESTING.
    METHODS pcre_part_of_value_no_match  FOR TESTING.
    METHODS pcre_ignores_case            FOR TESTING.
    METHODS pcre_ignores_trailing_blanks FOR TESTING.
    METHODS pcre_invalid_never_matches   FOR TESTING.
    METHODS pcre_blank_is_valid          FOR TESTING.
    METHODS pcre_literals_skip_meta      FOR TESTING.
    METHODS trace_lists_every_link       FOR TESTING.
    METHODS lock_message_is_transient    FOR TESTING.
    METHODS database_error_is_transient  FOR TESTING.
    METHODS config_message_wins_over_cx  FOR TESTING.
    METHODS runtime_error_is_code        FOR TESTING.
    METHODS other_message_is_data        FOR TESTING.
    METHODS account_shows_house_bank     FOR TESTING.
    METHODS account_number_is_masked     FOR TESTING.
    METHODS short_account_fully_masked   FOR TESTING.
    METHODS job_link_in_batch            FOR TESTING.
    METHODS job_link_blank_in_dialog     FOR TESTING.
    METHODS amount_has_thousands_groups  FOR TESTING.

    CONSTANTS:
      BEGIN OF gc_test,
        msg_lock    TYPE symsgno VALUE '040',
        msg_class   TYPE symsgno VALUE '032',
        msg_insert  TYPE symsgno VALUE '010',
        account     TYPE string VALUE `0012345678`,
        masked      TYPE string VALUE `****5678`,
        short       TYPE string VALUE `678`,
        hbkid       TYPE string VALUE `JPMC1`,
        hktid       TYPE string VALUE `OPS01`,
        house_label TYPE string VALUE `JPMC1/OPS01`,
        jobname     TYPE btcjob VALUE 'ZCD_FMON_MONITOR_ALL',
        jobcount    TYPE btcjobcnt VALUE '10203040',
      END OF gc_test.

    "! A ZCD_OPS exception with the given message, optionally chained to ix_previous
    METHODS ops_error
      IMPORTING
        iv_msgno        TYPE symsgno
        ix_previous     TYPE REF TO cx_root OPTIONAL
      RETURNING
        VALUE(rx_error) TYPE REF TO zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_util IMPLEMENTATION.

  " B (never post) is the most severe level
  METHOD block_outranks_error.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_cd_ops_util=>severity_rank( zif_cd_ops_types=>gc_severity-block )
                   > zcl_cd_ops_util=>severity_rank( zif_cd_ops_types=>gc_severity-error ) )
      msg = 'B must rank above E' ).
  ENDMETHOD.


  " The worst severity of W, B, I is B
  METHOD worst_of_mixed_findings.
    DATA lt_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    ls_finding-severity = zif_cd_ops_types=>gc_severity-warning.
    INSERT ls_finding INTO TABLE lt_findings.
    ls_finding-severity = zif_cd_ops_types=>gc_severity-block.
    INSERT ls_finding INTO TABLE lt_findings.
    ls_finding-severity = zif_cd_ops_types=>gc_severity-info.
    INSERT ls_finding INTO TABLE lt_findings.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>worst_severity( lt_findings )
                                        exp = zif_cd_ops_types=>gc_severity-block
                                        msg = 'Worst of W, B, I must be B' ).
  ENDMETHOD.


  " Findings with only warnings give amber
  METHOD warning_findings_are_amber.
    DATA lt_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    ls_finding-severity = zif_cd_ops_types=>gc_severity-warning.
    INSERT ls_finding INTO TABLE lt_findings.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>rag_from_findings( lt_findings )
                                        exp = zif_cd_ops_types=>gc_rag-amber
                                        msg = 'Warnings only must be amber' ).
  ENDMETHOD.


  " Combining RAG values keeps the worse one
  METHOD red_beats_amber.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_util=>worse_rag( iv_rag1 = zif_cd_ops_types=>gc_rag-amber iv_rag2 = zif_cd_ops_types=>gc_rag-red )
      exp = zif_cd_ops_types=>gc_rag-red
      msg = 'Red must beat amber' ).
  ENDMETHOD.


  " 0000012345 becomes the 12-digit document number 000000012345
  METHOD key_padded_after_zero_strip.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>normalize_key( iv_reference = ' 0000012345 '
                                                                             iv_length    = 12 )
                                        exp = `000000012345`
                                        msg = 'Reference must be normalised to 12 digits' ).
  ENDMETHOD.


  " Length 0 keeps the reference as delivered (check numbers)
  METHOD key_length_zero_keeps_value.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>normalize_key( iv_reference = '00777' iv_length = 0 )
                                        exp = `00777`
                                        msg = 'Length 0 must keep leading zeros' ).
  ENDMETHOD.


  " Recipient lists accept comma and semicolon and drop blanks
  METHOD list_split_on_comma_and_semi.
    DATA(lt_tokens) = zcl_cd_ops_util=>split_list( 'a@x.com; b@x.com,,c@x.com ' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_tokens ) exp = 3 msg = 'Three recipients expected' ).
    cl_abap_unit_assert=>assert_equals( act = lt_tokens[ 2 ] exp = `b@x.com` msg = 'Tokens must be trimmed' ).
  ENDMETHOD.


  " HTML markup in data is escaped
  METHOD markup_is_escaped.
    cl_abap_unit_assert=>assert_char_np( act = zcl_cd_ops_util=>html_escape( '<b>' ) exp = '*<b>*'
                                         msg = 'Markup must be escaped' ).
  ENDMETHOD.


  " Elapsed time across a minute boundary (the legacy subtraction got this wrong)
  METHOD elapsed_crosses_minute.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_util=>elapsed_ms( iv_from = '20261105075959.5000000' iv_to = '20261105080000.5000000' )
      exp = 1000
      msg = '07:59:59.5 to 08:00:00.5 is 1000 ms' ).
  ENDMETHOD.


  " Unconvertible parameter values fall back to the default
  METHOD bad_decimal_gives_default.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>to_decimal( iv_value = 'abc' iv_default = 7 )
                                        exp = CONV decfloat34( 7 )
                                        msg = 'Bad number must give the default' ).
  ENDMETHOD.


  " Rule: an integer parameter reads the maintained value (ZCA_PARAM over ZCL_CD_OPS_PARAM_SEED)
  METHOD int_param_reads_value.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAX_AGE_H_EBS'.
    DATA(lo_params) = NEW zcl_cd_ops_param_seed( )->set( iv_name = lc_name iv_value = `25` )->params( ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                                          iv_name    = lc_name
                                                                          iv_default = 20 )
                                        exp = 25
                                        msg = 'The maintained value must be read' ).
  ENDMETHOD.


  " Rule: a blank value (no definition default) gives the caller's default
  METHOD int_param_blank_is_default.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAX_AGE_H_EBS'.
    DATA(lo_params) = NEW zcl_cd_ops_param_seed( )->set( iv_name = lc_name iv_value = ` ` )->params( ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                                          iv_name    = lc_name
                                                                          iv_default = 20 )
                                        exp = 20
                                        msg = 'A blank parameter must give the default' ).
  ENDMETHOD.


  " Rule: a value that is not a number is a parameter error (never silent) and gives the default
  METHOD int_param_text_is_default.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAX_AGE_H_EBS'.
    DATA(lo_params) = NEW zcl_cd_ops_param_seed( )->set( iv_name = lc_name iv_value = `many` )->params( ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                                          iv_name    = lc_name
                                                                          iv_default = 20 )
                                        exp = 20
                                        msg = 'A value that is not a number must give the default' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_params->get_errors( ) ) exp = 1
                                        msg = 'The invalid value is reported' ).
  ENDMETHOD.


  " Texts are T100 text elements: message 000 (&1 &2 &3 &4) with the variables filled
  " in order; numbers keep their template formatting
  METHOD text_fills_message_vars.
    TRY.
        DATA(lv_text) = zcl_cd_ops_util=>text( iv_msgno = '000'
                                               iv_v1    = `A`
                                               iv_v2    = 42
                                               iv_v3    = `C` ).
        cl_abap_unit_assert=>assert_equals( act = condense( lv_text ) exp = `A 42 C`
                                            msg = 'Variables must replace &1 to &3 in order' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A long value (exception text, finding message) is appended untruncated as the tail -
  " message variables are only 50 characters long
  METHOD text_tail_is_not_truncated.
    TRY.
        DATA(lv_long) = repeat( val = `x` occ = 80 ).
        DATA(lv_text) = zcl_cd_ops_util=>text( iv_msgno = '000' iv_v1 = `A` iv_tail = lv_long ).
        cl_abap_unit_assert=>assert_equals( act = condense( lv_text ) exp = |A { lv_long }|
                                            msg = 'The tail must follow the message text in full' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A pattern describes the complete value: ZCD_PAYM_.* covers every ZCD_PAYM_ job
  METHOD pcre_matches_whole_value.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_match( iv_value   = 'ZCD_PAYM_WIRE_01'
                                                                          iv_pattern = 'ZCD_PAYM_.*' )
                                        exp = abap_true
                                        msg = 'The pattern covers the complete job name' ).
  ENDMETHOD.


  " Never a partial find: a pattern that matches only part of the value does not match
  METHOD pcre_part_of_value_no_match.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_match( iv_value   = 'XZCD_PAYM_WIRE'
                                                                          iv_pattern = 'ZCD_PAYM' )
                                        exp = abap_false
                                        msg = 'A pattern found inside the value is not a match' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_match( iv_value   = 'ZCD_PAYM_WIRE'
                                                                          iv_pattern = 'ZCD_PAYM' )
                                        exp = abap_false
                                        msg = 'A pattern matching only the start is not a match' ).
  ENDMETHOD.


  " Case is ignored, as the CP wildcards did before
  METHOD pcre_ignores_case.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_match( iv_value   = 'ach_pnc_20261106.txt'
                                                                          iv_pattern = 'ACH_PNC_[0-9]{8}\.TXT' )
                                        exp = abap_true
                                        msg = 'Upper and lower case must match each other' ).
  ENDMETHOD.


  " Trailing blanks of character fields are not part of value or pattern
  METHOD pcre_ignores_trailing_blanks.
    DATA lv_value TYPE c LENGTH 32.
    DATA lv_pattern TYPE c LENGTH 40.
    lv_value   = 'ZCD_POST_GL'.
    lv_pattern = 'ZCD_POST_GL'.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_match( iv_value   = lv_value
                                                                          iv_pattern = lv_pattern )
                                        exp = abap_true
                                        msg = 'Field padding must not prevent the match' ).
  ENDMETHOD.


  " An invalid pattern is reported by pcre_valid and never matches
  METHOD pcre_invalid_never_matches.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_valid( 'ZCD_(PAYM' )
                                        exp = abap_false
                                        msg = 'An unbalanced bracket is not valid PCRE' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_match( iv_value   = 'ZCD_(PAYM'
                                                                          iv_pattern = 'ZCD_(PAYM' )
                                        exp = abap_false
                                        msg = 'An invalid pattern never matches' ).
  ENDMETHOD.


  " Blank keeps its meaning at each call site: valid, and matches only a blank value
  METHOD pcre_blank_is_valid.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_valid( space )
                                        exp = abap_true
                                        msg = 'A blank pattern is valid' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_match( iv_value = 'X' iv_pattern = space )
                                        exp = abap_false
                                        msg = 'A blank pattern matches only a blank value' ).
  ENDMETHOD.


  " Specificity: literal characters count, escaped ones too; classes and quantifiers do not
  METHOD pcre_literals_skip_meta.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_literals( 'ACH_PNC_.*\.TXT' )
                                        exp = 12
                                        msg = 'ACH_PNC_ (8) + . (escaped) + TXT (3)' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>pcre_literals( 'A[0-9]{8}\d' )
                                        exp = 1
                                        msg = 'Only A is literal' ).
  ENDMETHOD.


  METHOD ops_error.
    TRY.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE ID zif_cd_ops_types=>gc_message_class TYPE zif_cd_ops_types=>gc_msgty_error NUMBER iv_msgno
          EXPORTING
            previous = ix_previous.
      CATCH zcx_cd_ops_error INTO rx_error.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  " B10: the trace keeps every link of the chain, outermost first, with class and message
  METHOD trace_lists_every_link.
    TRY.
        DATA(lx_error) = ops_error( iv_msgno    = gc_test-msg_class
                                    ix_previous = NEW cx_sy_move_cast_error( ) ).
        SPLIT zcl_cd_ops_util=>exception_trace( lx_error ) AT cl_abap_char_utilities=>newline
          INTO TABLE DATA(lt_lines).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines )
                                            exp = 2
                                            msg = 'One trace line per link of the chain' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( lt_lines[ 1 ] CS |ZCX_CD_OPS_ERROR { zif_cd_ops_types=>gc_message_class }/{ gc_test-msg_class }| )
          msg = 'The outermost link names its class and message' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lt_lines[ 2 ] CS `CX_SY_MOVE_CAST_ERROR` )
                                          msg = 'The previous exception is not lost' ).
      CATCH cx_root INTO DATA(lx_unexpected).
        cl_abap_unit_assert=>fail( msg = lx_unexpected->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B12: a run lock held by another run may be retried
  METHOD lock_message_is_transient.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>error_class( ops_error( gc_test-msg_lock ) )
                                        exp = zif_cd_ops_types=>gc_error_class-transient
                                        msg = 'Message 040 (lock held) is TRANSIENT' ).
  ENDMETHOD.


  " B12: a database error anywhere in the chain may be retried
  METHOD database_error_is_transient.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_util=>error_class( ops_error( iv_msgno    = gc_test-msg_insert
                                                     ix_previous = NEW cx_sy_open_sql_db( ) ) )
      exp = zif_cd_ops_types=>gc_error_class-transient
      msg = 'CX_SY_OPEN_SQL_DB is TRANSIENT' ).
  ENDMETHOD.


  " B12: a configuration message classifies the chain even when a runtime error is below it
  METHOD config_message_wins_over_cx.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_util=>error_class( ops_error( iv_msgno    = gc_test-msg_class
                                                     ix_previous = NEW cx_sy_move_cast_error( ) ) )
      exp = zif_cd_ops_types=>gc_error_class-config
      msg = 'Message 032 (class does not implement the interface) is CONFIG' ).
  ENDMETHOD.


  " B12: a runtime error of the ABAP kernel is a code defect
  METHOD runtime_error_is_code.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>error_class( NEW cx_sy_zerodivide( ) )
                                        exp = zif_cd_ops_types=>gc_error_class-code
                                        msg = 'CX_SY_ZERODIVIDE is CODE' ).
  ENDMETHOD.


  " B12: everything else is data
  METHOD other_message_is_data.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>error_class( ops_error( gc_test-msg_insert ) )
                                        exp = zif_cd_ops_types=>gc_error_class-data
                                        msg = 'Message 010 without a classified cause is DATA' ).
  ENDMETHOD.


  " B15: house bank and account ID replace the account number when both are known
  METHOD account_shows_house_bank.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>account_label( iv_account = gc_test-account
                                                                             iv_hbkid   = gc_test-hbkid
                                                                             iv_hktid   = gc_test-hktid )
                                        exp = gc_test-house_label
                                        msg = 'House bank / account ID, never the number' ).
  ENDMETHOD.


  " B15: without house bank only the last four characters are shown
  METHOD account_number_is_masked.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>account_label( gc_test-account )
                                        exp = gc_test-masked
                                        msg = 'Masked to the last four characters' ).
  ENDMETHOD.


  " B15: a number of four characters or fewer is masked completely
  METHOD short_account_fully_masked.
    cl_abap_unit_assert=>assert_false( act = xsdbool( zcl_cd_ops_util=>account_label( gc_test-short ) CS gc_test-short )
                                       msg = 'A short number never appears in full' ).
  ENDMETHOD.


  " B12: a batch run knows its job (SM37 link)
  METHOD job_link_in_batch.
    TEST-INJECTION job_info.
      lv_batch    = abap_true.
      lv_jobname  = gc_test-jobname.
      lv_jobcount = gc_test-jobcount.
      lv_subrc    = 0.
    END-TEST-INJECTION.
    DATA(ls_link) = zcl_cd_ops_util=>job_link( ).
    cl_abap_unit_assert=>assert_equals( act = ls_link
                                        exp = VALUE zif_cd_ops_types=>ty_job_link( jobname  = gc_test-jobname
                                                                                   jobcount = gc_test-jobcount
                                                                                   sysid    = sy-sysid )
                                        msg = 'Job name, count and system of the batch run' ).
  ENDMETHOD.


  " B12: a dialog run has no job
  METHOD job_link_blank_in_dialog.
    TEST-INJECTION job_info.
      lv_batch = abap_false.
    END-TEST-INJECTION.
    DATA(ls_link) = zcl_cd_ops_util=>job_link( ).
    cl_abap_unit_assert=>assert_initial( act = ls_link-jobname
                                         msg = 'No job name outside batch' ).
    cl_abap_unit_assert=>assert_equals( act = ls_link-sysid
                                        exp = sy-sysid
                                        msg = 'The system is always known' ).
  ENDMETHOD.


  " Missing bank ACK alert: thousands separators and two decimals, sign kept
  METHOD amount_has_thousands_groups.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>format_amount( CONV decfloat34( '-1234567.8' ) )
                                        exp = `-1,234,567.80`
                                        msg = 'Groups of three, two decimals, minus first' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>format_amount( CONV decfloat34( '999' ) )
                                        exp = `999.00`
                                        msg = 'No separator below one thousand' ).
  ENDMETHOD.

ENDCLASS.
