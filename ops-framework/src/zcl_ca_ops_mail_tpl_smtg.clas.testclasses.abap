*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_mail_tpl_smtg.clas.testclasses.abap
*& Purpose:
*& Unit tests of the SAP e-mail template adapter with test injections for
*& the API probe, the template instance and the render calls (the API is not
*& verified in this landscape and never called here): not available, render
*& with data, render by key, unknown template (071), empty rendering (072).
*& Does not prove the real API - VERIFY-ADT items in docs/ALERT_TEMPLATES.md.
*& Modification log:
*& 2026-11-10 | Initial version (alert e-mail templates, user decisions 2026-11-10).
*&---------------------------------------------------------------------*
CLASS ltc_mail_tpl_smtg DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_template TYPE zif_ca_ops_types=>ty_template_id VALUE 'ZT_TEMPLATE'.
    DATA mo_cut TYPE REF TO zif_ca_ops_mail_template.
    DATA ms_context TYPE zif_ca_ops_types=>ty_mail_context.

    METHODS setup.
    METHODS api_missing_not_available   FOR TESTING.
    METHODS render_with_data_returns    FOR TESTING.
    METHODS render_by_key_without_data  FOR TESTING.
    METHODS unknown_template_raises_071 FOR TESTING.
    METHODS empty_rendering_raises_072  FOR TESTING.
ENDCLASS.


CLASS ltc_mail_tpl_smtg IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_ca_ops_mail_tpl_smtg( ).
    ms_context-header-subject = 'SUBJECT'.
  ENDMETHOD.


  " No API in the system: not available, every template "exists" (nothing to check), render raises 070
  METHOD api_missing_not_available.
    TEST-INJECTION smtg_describe.
    END-TEST-INJECTION.
    cl_abap_unit_assert=>assert_false( act = mo_cut->is_available( ) msg = 'Without the API the adapter is not usable' ).
    cl_abap_unit_assert=>assert_true( act = mo_cut->exists( gc_template ) msg = 'Nothing to check against' ).
    TRY.
        mo_cut->render( iv_template_id = gc_template is_context = ms_context ).
        cl_abap_unit_assert=>fail( msg = 'Rendering without the API must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '070'
                                            msg = 'Renderer not available (070)' ).
    ENDTRY.
  ENDMETHOD.


  METHOD render_with_data_returns.
    TEST-INJECTION smtg_describe.
      lv_instance  = abap_true.
      mv_with_data = abap_true.
    END-TEST-INJECTION.
    TEST-INJECTION smtg_instance.
      ro_api = NEW zcl_ca_ops_mail_tpl_builtin( ).
    END-TEST-INJECTION.
    TEST-INJECTION smtg_render_data.
      lv_subject = `RENDERED SUBJECT`.
      lv_html    = `<p>rendered</p>`.
      lv_text    = `rendered`.
    END-TEST-INJECTION.
    TRY.
        DATA(ls_rendered) = mo_cut->render( iv_template_id = gc_template is_context = ms_context ).
        cl_abap_unit_assert=>assert_equals( act = ls_rendered-html exp = `<p>rendered</p>`
                                            msg = 'The HTML body of the template' ).
        cl_abap_unit_assert=>assert_equals( act = ls_rendered-subject exp = `RENDERED SUBJECT`
                                            msg = 'The subject of the template' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->exists( gc_template ) msg = 'The template exists' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An API without RENDER_W_DATA renders by the key of the alert log row (data source by key)
  METHOD render_by_key_without_data.
    TEST-INJECTION smtg_describe.
      lv_instance = abap_true.
      lv_render   = abap_true.
    END-TEST-INJECTION.
    TEST-INJECTION smtg_instance.
      ro_api = NEW zcl_ca_ops_mail_tpl_builtin( ).
    END-TEST-INJECTION.
    TEST-INJECTION smtg_render_data.
      lv_html = `<p>by data</p>`.
    END-TEST-INJECTION.
    TEST-INJECTION smtg_render_key.
      lv_html = `<p>by key</p>`.
    END-TEST-INJECTION.
    TRY.
        DATA(ls_rendered) = mo_cut->render( iv_template_id = gc_template is_context = ms_context ).
        cl_abap_unit_assert=>assert_equals( act = ls_rendered-html exp = `<p>by key</p>`
                                            msg = 'RENDER with the key is used' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_template_raises_071.
    TEST-INJECTION smtg_describe.
      lv_instance  = abap_true.
      mv_with_data = abap_true.
    END-TEST-INJECTION.
    TEST-INJECTION smtg_instance.
    END-TEST-INJECTION.
    cl_abap_unit_assert=>assert_false( act = mo_cut->exists( gc_template ) msg = 'An unknown template does not exist' ).
    TRY.
        mo_cut->render( iv_template_id = gc_template is_context = ms_context ).
        cl_abap_unit_assert=>fail( msg = 'An unknown template must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '071'
                                            msg = 'Template not found (071)' ).
    ENDTRY.
  ENDMETHOD.


  METHOD empty_rendering_raises_072.
    TEST-INJECTION smtg_describe.
      lv_instance  = abap_true.
      mv_with_data = abap_true.
    END-TEST-INJECTION.
    TEST-INJECTION smtg_instance.
      ro_api = NEW zcl_ca_ops_mail_tpl_builtin( ).
    END-TEST-INJECTION.
    TEST-INJECTION smtg_render_data.
    END-TEST-INJECTION.
    TRY.
        mo_cut->render( iv_template_id = gc_template is_context = ms_context ).
        cl_abap_unit_assert=>fail( msg = 'An empty rendering must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '072'
                                            msg = 'Template not rendered (072)' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
