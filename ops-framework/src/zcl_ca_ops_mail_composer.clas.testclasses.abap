*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_mail_composer.clas.testclasses.abap
*& Purpose:
*& Unit tests of the alert e-mail composer: plain tokens, template order,
*& tables put in after rendering (HTML and text), a customised template
*& without a table placeholder (table appended, named), fallback to the
*& built-in layout when the renderer is not available or fails (never
*& silent). Renderer double LTD_TEMPLATE; no database.
*& Modification log:
*& 2026-11-10 | Initial version (alert e-mail templates, user decisions 2026-11-10).
*&---------------------------------------------------------------------*
CLASS ltd_template DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_mail_template.
    DATA mv_available TYPE abap_bool VALUE abap_true.
    DATA mv_fail      TYPE abap_bool.
    DATA ms_rendered  TYPE zif_ca_ops_types=>ty_mail_rendered.
    DATA mv_asked     TYPE zif_ca_ops_types=>ty_template_id.
ENDCLASS.

CLASS ltd_template IMPLEMENTATION.
  METHOD zif_ca_ops_mail_template~is_available.
    rv_available = mv_available.
  ENDMETHOD.
  METHOD zif_ca_ops_mail_template~exists.
    rv_exists = abap_true.
  ENDMETHOD.
  METHOD zif_ca_ops_mail_template~render.
    mv_asked = iv_template_id.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e072(zca_ops) WITH iv_template_id 'TEST'.
    ENDIF.
    rs_rendered = ms_rendered.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_mail_composer DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        template   TYPE zif_ca_ops_types=>ty_template_id VALUE 'ZT_TEMPLATE',
        table_html TYPE string VALUE `<table><tr><td>row</td></tr></table>`,
        table_text TYPE string VALUE `row`,
        builtin    TYPE string VALUE `<p>built-in</p>`,
      END OF gc_test.

    DATA mo_template TYPE REF TO ltd_template.
    DATA mv_token    TYPE string.

    METHODS setup.
    "! A message with one main block and the built-in layout
    METHODS message
      RETURNING
        VALUE(rs_message) TYPE zif_ca_ops_types=>ty_alert_message.

    METHODS token_is_plain_and_unique    FOR TESTING.
    METHODS template_order_rule_first    FOR TESTING.
    METHODS template_order_falls_back    FOR TESTING.
    METHODS table_replaces_token         FOR TESTING.
    METHODS missing_token_appends_table  FOR TESTING.
    METHODS token_left_out_of_subject    FOR TESTING.
    METHODS apply_uses_template          FOR TESTING.
    METHODS apply_keeps_code_subject     FOR TESTING.
    METHODS unavailable_keeps_builtin    FOR TESTING.
    METHODS render_failure_is_recorded   FOR TESTING.
    METHODS customised_template_noted    FOR TESTING.
ENDCLASS.


CLASS ltc_mail_composer IMPLEMENTATION.

  METHOD setup.
    mo_template = NEW #( ).
    mv_token = zcl_ca_ops_mail_composer=>token( iv_block = zif_ca_ops_types=>gc_mail_block-main
                                                iv_seed  = '0A1B2C' ).
  ENDMETHOD.


  METHOD message.
    rs_message-template_id = gc_test-template.
    rs_message-subject     = 'CODE SUBJECT'.
    rs_message-html        = gc_test-builtin.
    rs_message-text        = 'built-in'.
    rs_message-renderer    = zif_ca_ops_types=>gc_renderer-builtin.
    rs_message-context-header-table_main = mv_token.
    INSERT VALUE #( name  = zif_ca_ops_types=>gc_mail_block-main
                    token = mv_token
                    html  = gc_test-table_html
                    text  = gc_test-table_text ) INTO TABLE rs_message-context-blocks.
  ENDMETHOD.


  " A token is letters and digits only (an engine that escapes values leaves it as it is) and differs per block
  METHOD token_is_plain_and_unique.
    TRY.
        DATA(lv_section) = zcl_ca_ops_mail_composer=>token( iv_block = zif_ca_ops_types=>gc_mail_block-section
                                                            iv_seed  = '0A1B2C' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( matches( val = mv_token pcre = `[A-Z0-9]+` ) )
                                          msg = 'A token holds letters and digits only' ).
        cl_abap_unit_assert=>assert_differs( act = lv_section exp = mv_token
                                             msg = 'Each block has its own token' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Resolution order: rule -> section -> channel -> generic template
  METHOD template_order_rule_first.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_mail_composer=>template_for( iv_rule    = 'ZT_RULE'
                                                        iv_section = 'ZT_SECTION'
                                                        iv_channel = 'ZT_CHANNEL'
                                                        iv_default = 'ZT_DEFAULT' )
          exp = 'ZT_RULE'
          msg = 'The rule template wins' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD template_order_falls_back.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_mail_composer=>template_for( iv_channel = 'ZT_CHANNEL' iv_default = 'ZT_DEFAULT' )
          exp = 'ZT_CHANNEL'
          msg = 'Without rule and section template the channel template applies' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_ca_ops_mail_composer=>template_for( iv_default = 'ZT_DEFAULT' )
          exp = 'ZT_DEFAULT'
          msg = 'Last the generic template' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " After rendering the code puts its HTML table in the HTML body and its text table in the text body
  METHOD table_replaces_token.
    DATA ls_rendered TYPE zif_ca_ops_types=>ty_mail_rendered.
    TRY.
        ls_rendered-html = |<p>before</p>{ mv_token }<p>after</p>|.
        ls_rendered-text = |before\n{ mv_token }\nafter|.
        DATA(ls_composed) = zcl_ca_ops_mail_composer=>insert_blocks( is_rendered = ls_rendered
                                                                     it_blocks   = message( )-context-blocks ).
        cl_abap_unit_assert=>assert_equals( act = ls_composed-rendered-html
                                            exp = |<p>before</p>{ gc_test-table_html }<p>after</p>|
                                            msg = 'The HTML table stands where the token was' ).
        cl_abap_unit_assert=>assert_equals( act = ls_composed-rendered-text
                                            exp = |before\n{ gc_test-table_text }\nafter|
                                            msg = 'The text table stands where the token was' ).
        cl_abap_unit_assert=>assert_initial( act = ls_composed-missing msg = 'No table appended' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A customised template without the table placeholder: the table is appended and the block named
  METHOD missing_token_appends_table.
    DATA ls_rendered TYPE zif_ca_ops_types=>ty_mail_rendered.
    TRY.
        ls_rendered-html = `<p>no table here</p>`.
        ls_rendered-text = `no table here`.
        DATA(ls_composed) = zcl_ca_ops_mail_composer=>insert_blocks( is_rendered = ls_rendered
                                                                     it_blocks   = message( )-context-blocks ).
        cl_abap_unit_assert=>assert_equals( act = ls_composed-rendered-html
                                            exp = |<p>no table here</p>{ gc_test-table_html }|
                                            msg = 'The table is appended at the end of the HTML' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_composed-rendered-text exp = |*{ gc_test-table_text }|
                                             msg = 'The text table is appended at the end' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_composed-missing ) exp = 1
                                            msg = 'The block is named as appended' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD token_left_out_of_subject.
    DATA ls_rendered TYPE zif_ca_ops_types=>ty_mail_rendered.
    TRY.
        ls_rendered-subject = |Subject { mv_token }|.
        ls_rendered-html    = mv_token.
        DATA(ls_composed) = zcl_ca_ops_mail_composer=>insert_blocks( is_rendered = ls_rendered
                                                                     it_blocks   = message( )-context-blocks ).
        cl_abap_unit_assert=>assert_equals( act = ls_composed-rendered-subject exp = `Subject`
                                            msg = 'A subject carries no table' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD apply_uses_template.
    TRY.
        DATA(ls_message) = message( ).
        mo_template->ms_rendered-subject = `TEMPLATE SUBJECT`.
        mo_template->ms_rendered-html    = |<h1>Template</h1>{ mv_token }|.
        mo_template->ms_rendered-text    = |Template\n{ mv_token }|.
        zcl_ca_ops_mail_composer=>apply( EXPORTING io_template = mo_template
                                                   iv_renderer = zif_ca_ops_types=>gc_renderer-smtg
                                         CHANGING  cs_message  = ls_message ).
        cl_abap_unit_assert=>assert_equals( act = mo_template->mv_asked exp = gc_test-template
                                            msg = 'The message template is rendered' ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-html exp = |<h1>Template</h1>{ gc_test-table_html }|
                                            msg = 'Template HTML with the table in place' ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-subject exp = 'TEMPLATE SUBJECT'
                                            msg = 'The template subject is used' ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-renderer exp = zif_ca_ops_types=>gc_renderer-smtg
                                            msg = 'The renderer is recorded' ).
        cl_abap_unit_assert=>assert_initial( act = ls_message-render_info msg = 'Nothing to note' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A template with an empty subject keeps the impact-first subject of the code
  METHOD apply_keeps_code_subject.
    TRY.
        DATA(ls_message) = message( ).
        mo_template->ms_rendered-html = mv_token.
        zcl_ca_ops_mail_composer=>apply( EXPORTING io_template = mo_template
                                                   iv_renderer = zif_ca_ops_types=>gc_renderer-smtg
                                         CHANGING  cs_message  = ls_message ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-subject exp = 'CODE SUBJECT'
                                            msg = 'The code subject stays when the template has none' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Renderer not available: the built-in layout is sent and the reason recorded (never silent)
  METHOD unavailable_keeps_builtin.
    TRY.
        DATA(ls_message) = message( ).
        mo_template->mv_available = abap_false.
        zcl_ca_ops_mail_composer=>apply( EXPORTING io_template = mo_template
                                                   iv_renderer = zif_ca_ops_types=>gc_renderer-smtg
                                         CHANGING  cs_message  = ls_message ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-html exp = gc_test-builtin
                                            msg = 'The built-in layout stays' ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-renderer exp = zif_ca_ops_types=>gc_renderer-builtin
                                            msg = 'The built-in renderer is recorded' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_message-render_info
          exp = CONV zif_ca_ops_types=>ty_message( zcl_ca_ops_util=>text(
                  iv_msgno = zif_ca_ops_types=>gc_msg-tpl_unavailable
                  iv_v1    = zif_ca_ops_types=>gc_renderer-smtg ) )
          msg = 'The fallback names the renderer (070)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD render_failure_is_recorded.
    TRY.
        DATA(ls_message) = message( ).
        mo_template->mv_fail = abap_true.
        zcl_ca_ops_mail_composer=>apply( EXPORTING io_template = mo_template
                                                   iv_renderer = zif_ca_ops_types=>gc_renderer-smtg
                                         CHANGING  cs_message  = ls_message ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-html exp = gc_test-builtin
                                            msg = 'A failed rendering leaves the built-in layout' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_message-render_info exp = |*{ gc_test-template }*|
                                             msg = 'The reason names the template' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD customised_template_noted.
    TRY.
        DATA(ls_message) = message( ).
        mo_template->ms_rendered-html = `<p>customised</p>`.
        zcl_ca_ops_mail_composer=>apply( EXPORTING io_template = mo_template
                                                   iv_renderer = zif_ca_ops_types=>gc_renderer-smtg
                                         CHANGING  cs_message  = ls_message ).
        cl_abap_unit_assert=>assert_equals( act = ls_message-html exp = |<p>customised</p>{ gc_test-table_html }|
                                            msg = 'The table is added at the end' ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_message-render_info
                                             exp = |*{ zif_ca_ops_types=>gc_mail_block-main }*|
                                             msg = 'The appended table is recorded (073)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
