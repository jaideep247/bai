*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_mail_tpl_builtin.clas.testclasses.abap
*& Purpose:
*& Unit tests of the built-in alert e-mail layout: subject, the known
*& context keys labelled (blank keys left out), values HTML-escaped, the
*& table blocks as their tokens (section before findings). Pure logic.
*& Modification log:
*& 2026-11-10 | Initial version (alert e-mail templates, user decisions 2026-11-10).
*&---------------------------------------------------------------------*
CLASS ltc_mail_tpl_builtin DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zif_ca_ops_mail_template.
    DATA ms_context TYPE zif_ca_ops_types=>ty_mail_context.

    METHODS setup.
    METHODS subject_and_known_keys      FOR TESTING.
    METHODS blank_keys_are_left_out     FOR TESTING.
    METHODS values_are_escaped          FOR TESTING.
    METHODS tokens_section_before_main  FOR TESTING.
    METHODS always_available            FOR TESTING.
ENDCLASS.


CLASS ltc_mail_tpl_builtin IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_ca_ops_mail_tpl_builtin( ).
    CLEAR ms_context.
    ms_context-header-subject        = '[ZT1][ZT_OPS_A][E] UNMAPPED_BTC: 2 finding(s)'.
    ms_context-header-area           = 'ZT_OPS_A'.
    ms_context-header-rule_id        = 'ZT_RULE'.
    ms_context-header-findings_total = '2'.
    ms_context-header-reference_line = 'Run 01, job ZT_JOB / 11223344'.
    ms_context-header-table_main     = 'ZCAOPSTABLETABLEMAIN01'.
    ms_context-header-table_section  = 'ZCAOPSTABLETABLESECTION01'.
  ENDMETHOD.


  METHOD subject_and_known_keys.
    TRY.
        DATA(ls_rendered) = mo_cut->render( iv_template_id = space is_context = ms_context ).
        cl_abap_unit_assert=>assert_equals( act = ls_rendered-subject exp = CONV string( ms_context-header-subject )
                                            msg = 'The subject is the code subject' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_rendered-html CS 'ZT_RULE' AND ls_rendered-text CS 'ZT_RULE' )
                                          msg = 'The rule is a labelled key in HTML and text' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_rendered-text CS '11223344' )
                                          msg = 'The reference line names the job' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A key that is not known for the message is not shown (no empty label)
  METHOD blank_keys_are_left_out.
    TRY.
        DATA(ls_rendered) = mo_cut->render( iv_template_id = space is_context = ms_context ).
        SPLIT ls_rendered-text AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).
        LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<lv_line>).
          cl_abap_unit_assert=>assert_false( act = xsdbool( matches( val = <lv_line> pcre = `.*:\s*` ) )
                                             msg = |No label without a value: { <lv_line> }| ).
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD values_are_escaped.
    TRY.
        ms_context-header-rule_id = '<b>X</b>'.
        DATA(ls_rendered) = mo_cut->render( iv_template_id = space is_context = ms_context ).
        cl_abap_unit_assert=>assert_char_np( act = ls_rendered-html exp = '*<b>X</b>*'
                                             msg = 'A value never becomes markup' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD tokens_section_before_main.
    TRY.
        DATA(ls_rendered) = mo_cut->render( iv_template_id = space is_context = ms_context ).
        DATA(lv_section) = find( val = ls_rendered-html sub = CONV string( ms_context-header-table_section ) ).
        DATA(lv_main) = find( val = ls_rendered-html sub = CONV string( ms_context-header-table_main ) ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lv_section >= 0 AND lv_main > lv_section )
                                          msg = 'The section table comes before the findings table' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD always_available.
    TRY.
        cl_abap_unit_assert=>assert_true( act = mo_cut->is_available( ) msg = 'The built-in layout is always there' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->exists( 'ANY' ) msg = 'It needs no template' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
