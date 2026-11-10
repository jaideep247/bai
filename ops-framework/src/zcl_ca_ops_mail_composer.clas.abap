*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_mail_composer.clas.abap
*& Purpose:
*& Puts an alert e-mail together from a template (user decisions
*& 2026-11-10): which template applies (rule, consumer section, channel,
*& generic template), the plain token of each table block, rendering
*& through a renderer (ZIF_CA_OPS_MAIL_TEMPLATE) and, after rendering,
*& the code-rendered tables in place of their tokens (HTML table in the HTML
*& body, text table in the text body). Placeholders carry plain text only,
*& so this works whether or not the engine escapes placeholder values. A
*& template without the placeholder of a table gets the table at the end
*& and the message records it (073). A renderer that is not available, a
*& missing template or a failed rendering leaves the built-in layout in
*& the message and names the reason (070-072): never silent, never blocking.
*& Pure logic: no database, no delivery.
*& Modification log:
*& 2026-11-10 | Initial version (alert e-mail templates, user decisions 2026-11-10).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert e-mail composer</p>
CLASS zcl_ca_ops_mail_composer DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Rendered e-mail with the tables in place and the blocks whose token the template lacked
    TYPES:
      BEGIN OF ty_composed,
        rendered TYPE zif_ca_ops_types=>ty_mail_rendered,
        "! Blocks appended at the end (the template has no placeholder for them)
        missing  TYPE string_table,
      END OF ty_composed.

    "! Plain token of a table block: prefix, block name and seed, letters and digits only
    "! @parameter iv_seed | makes the token unique (e.g. the run ID in hex)
    CLASS-METHODS token
      IMPORTING
        iv_block        TYPE zif_ca_ops_types=>ty_mail_block_name
        iv_seed         TYPE clike
      RETURNING
        VALUE(rv_token) TYPE string.

    "! The template of a message: the rule's, else the consumer section's, else the channel's,
    "! else the generic template (first one not blank)
    CLASS-METHODS template_for
      IMPORTING
        iv_rule            TYPE zif_ca_ops_types=>ty_template_id OPTIONAL
        iv_section         TYPE zif_ca_ops_types=>ty_template_id OPTIONAL
        iv_channel         TYPE zif_ca_ops_types=>ty_template_id OPTIONAL
        iv_default         TYPE zif_ca_ops_types=>ty_template_id OPTIONAL
      RETURNING
        VALUE(rv_template) TYPE zif_ca_ops_types=>ty_template_id.

    "! Replace each block's token by its HTML table (HTML body) and text table (text body); a
    "! token the template lacks: the table is appended at the end and the block is named in
    "! MISSING. Tokens in the subject are removed (a subject carries no table).
    CLASS-METHODS insert_blocks
      IMPORTING
        is_rendered        TYPE zif_ca_ops_types=>ty_mail_rendered
        it_blocks          TYPE zif_ca_ops_types=>tt_mail_block
      RETURNING
        VALUE(rs_composed) TYPE ty_composed.

    "! Render the message's template with the renderer and put the tables in. Success: subject
    "! (blank = the code's subject), HTML and text of the template, RENDERER = iv_renderer,
    "! RENDER_INFO = a table appended at the end (073) or blank. Not available (070), template
    "! missing (071) or not rendered (072): subject, HTML and text stay as they are (the built-in
    "! layout) and RENDER_INFO names the reason.
    "! @parameter iv_alert_id | key of the alert log row for a data source by key
    CLASS-METHODS apply
      IMPORTING
        io_template TYPE REF TO zif_ca_ops_mail_template
        iv_renderer TYPE zif_ca_ops_types=>ty_renderer
        iv_alert_id TYPE zif_ca_ops_types=>ty_run_id OPTIONAL
      CHANGING
        cs_message  TYPE zif_ca_ops_types=>ty_alert_message.

  PRIVATE SECTION.
    "! Characters a token keeps (letters and digits)
    CONSTANTS gc_token_strip TYPE string VALUE `[^A-Za-z0-9]`.

ENDCLASS.



CLASS zcl_ca_ops_mail_composer IMPLEMENTATION.

  METHOD token.
    rv_token = replace( val   = |{ zif_ca_ops_types=>gc_mail_token_prefix }{ iv_block }{ iv_seed }|
                        pcre  = gc_token_strip
                        with  = ``
                        occ   = 0 ).
    rv_token = to_upper( rv_token ).
  ENDMETHOD.


  METHOD template_for.
    rv_template = COND #( WHEN iv_rule IS NOT INITIAL THEN iv_rule
                          WHEN iv_section IS NOT INITIAL THEN iv_section
                          WHEN iv_channel IS NOT INITIAL THEN iv_channel
                          ELSE iv_default ).
  ENDMETHOD.


  METHOD insert_blocks.
    rs_composed-rendered = is_rendered.
    LOOP AT it_blocks ASSIGNING FIELD-SYMBOL(<ls_block>) WHERE token IS NOT INITIAL.
      DATA(lv_missing) = abap_false.
      IF rs_composed-rendered-html CS <ls_block>-token.
        rs_composed-rendered-html = replace( val  = rs_composed-rendered-html
                                             sub  = <ls_block>-token
                                             with = <ls_block>-html
                                             occ  = 0 ).
      ELSEIF <ls_block>-html IS NOT INITIAL.
        rs_composed-rendered-html = rs_composed-rendered-html && <ls_block>-html.
        lv_missing = abap_true.
      ENDIF.
      IF rs_composed-rendered-text CS <ls_block>-token.
        rs_composed-rendered-text = replace( val  = rs_composed-rendered-text
                                             sub  = <ls_block>-token
                                             with = <ls_block>-text
                                             occ  = 0 ).
      ELSEIF <ls_block>-text IS NOT INITIAL.
        rs_composed-rendered-text = |{ rs_composed-rendered-text }{ cl_abap_char_utilities=>newline }|
                                 && <ls_block>-text.
        lv_missing = abap_true.
      ENDIF.
      rs_composed-rendered-subject = condense( replace( val  = rs_composed-rendered-subject
                                                        sub  = <ls_block>-token
                                                        with = ``
                                                        occ  = 0 ) ).
      IF lv_missing = abap_true.
        INSERT CONV string( <ls_block>-name ) INTO TABLE rs_composed-missing.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD apply.
    DATA ls_rendered TYPE zif_ca_ops_types=>ty_mail_rendered.
    IF io_template IS NOT BOUND OR io_template->is_available( ) = abap_false.
      cs_message-render_info = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-tpl_unavailable
                                                      iv_v1    = iv_renderer ).
      RETURN.
    ENDIF.
    TRY.
        ls_rendered = io_template->render( iv_template_id = cs_message-template_id
                                           is_context     = cs_message-context
                                           iv_alert_id    = iv_alert_id ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " the built-in layout stays in the message; the reason goes to the alert log
        cs_message-render_info = lx_error->get_text( ).
        RETURN.
    ENDTRY.
    DATA(ls_composed) = insert_blocks( is_rendered = ls_rendered
                                       it_blocks   = cs_message-context-blocks ).
    IF ls_composed-rendered-subject IS NOT INITIAL.
      cs_message-subject = ls_composed-rendered-subject.
    ENDIF.
    cs_message-html     = ls_composed-rendered-html.
    cs_message-text     = ls_composed-rendered-text.
    cs_message-renderer = iv_renderer.
    CLEAR cs_message-render_info.
    IF ls_composed-missing IS NOT INITIAL.
      cs_message-render_info = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_types=>gc_msg-tpl_token_missing
                                                      iv_v1    = cs_message-template_id
                                                      iv_v2    = concat_lines_of( table = ls_composed-missing
                                                                                  sep   = `,` ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
