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
*&---------------------------------------------------------------------*
CLASS ltc_util DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS block_outranks_error         FOR TESTING.
    METHODS worst_of_mixed_findings      FOR TESTING.
    METHODS red_at_red_threshold         FOR TESTING.
    METHODS lower_is_worse_inverts_rag   FOR TESTING.
    METHODS warning_findings_are_amber   FOR TESTING.
    METHODS red_beats_amber              FOR TESTING.
    METHODS key_padded_after_zero_strip  FOR TESTING.
    METHODS key_length_zero_keeps_value  FOR TESTING.
    METHODS list_split_on_comma_and_semi FOR TESTING.
    METHODS markup_is_escaped            FOR TESTING.
    METHODS elapsed_crosses_minute       FOR TESTING.
    METHODS bad_decimal_gives_default    FOR TESTING.
    METHODS text_fills_message_vars      FOR TESTING.
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


  " A value equal to the red threshold is red
  METHOD red_at_red_threshold.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_util=>rag_from_value( iv_value = 10 iv_amber = 5 iv_red = 10 )
      exp = zif_cd_ops_types=>gc_rag-red
      msg = 'Value at the red threshold must be red' ).
  ENDMETHOD.


  " Lower-is-worse metrics (e.g. pass rate) turn red below the threshold
  METHOD lower_is_worse_inverts_rag.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_util=>rag_from_value( iv_value = 80 iv_amber = 95 iv_red = 90 iv_higher_is_worse = abap_false )
      exp = zif_cd_ops_types=>gc_rag-red
      msg = 'Pass rate 80 with red at 90 must be red' ).
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

ENDCLASS.
