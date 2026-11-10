*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_mail_tpl_smtg.clas.abap
*& Purpose:
*& Adapter to SAP e-mail templates (object type SMTG, maintained in ADT /
*& Fiori "Maintain Email Templates"; user decision 2026-11-10). The only
*& place that calls the template API CL_SMTG_EMAIL_API. The API is not
*& verified in this landscape: it is called dynamically (no static
*& reference), every class, method and parameter name is a constant marked
*& VERIFY-ADT, and each call sits in a test seam. Availability: the class
*& exists and has GET_INSTANCE and RENDER_W_DATA or RENDER (RTTI); when it
*& does not, IS_AVAILABLE is false and the composer keeps the built-in
*& layout. Data: RENDER_W_DATA with the standard context keys
*& (ZIF_CA_OPS_TYPES=>TY_MAIL_HEADER) is preferred; RENDER with the key of
*& the alert log row (data source ZI_CA_OPS_ALERTMAILCTX) is the second
*& option. A missing template raises 071, a failed rendering 072.
*& Modification log:
*& 2026-11-10 | Initial version (alert e-mail templates, user decisions 2026-11-10).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - SAP e-mail template adapter</p>
CLASS zcl_ca_ops_mail_tpl_smtg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_mail_template.

    "! The template API as best known - VERIFY-ADT every name in DV1 (SE24 / ADT on CL_SMTG_EMAIL_API)
    CONSTANTS:
      BEGIN OF gc_api,
        "! VERIFY-ADT: class of the e-mail template API
        class          TYPE seoclsname VALUE 'CL_SMTG_EMAIL_API',
        "! VERIFY-ADT: static factory, importing the template ID, returning the API instance
        get_instance   TYPE seocpdname VALUE 'GET_INSTANCE',
        "! VERIFY-ADT: render with data passed by the caller (preferred)
        render_w_data  TYPE seocpdname VALUE 'RENDER_W_DATA',
        "! VERIFY-ADT: render with the key of the template's CDS data source
        render         TYPE seocpdname VALUE 'RENDER',
      END OF gc_api.

    "! Parameter names of the API methods - VERIFY-ADT
    CONSTANTS:
      BEGIN OF gc_api_param,
        "! GET_INSTANCE importing: template ID
        template_id TYPE abap_parmname VALUE 'IV_TEMPLATE_ID',
        "! GET_INSTANCE returning: the API instance
        instance    TYPE abap_parmname VALUE 'RO_INSTANCE',
        "! RENDER / RENDER_W_DATA importing: language
        language    TYPE abap_parmname VALUE 'IV_LANGUAGE',
        "! RENDER_W_DATA importing: reference to the data (a structure with the placeholder names)
        data        TYPE abap_parmname VALUE 'IR_DATA',
        "! RENDER importing: key of the CDS data source (table of name / value)
        data_key    TYPE abap_parmname VALUE 'IT_DATA_KEY',
        "! RENDER / RENDER_W_DATA exporting: subject, HTML body, text body
        subject     TYPE abap_parmname VALUE 'EV_SUBJECT',
        body_html   TYPE abap_parmname VALUE 'EV_BODY_HTML',
        body_text   TYPE abap_parmname VALUE 'EV_BODY_TEXT',
      END OF gc_api_param.

    "! Row of IT_DATA_KEY - VERIFY-ADT: component names and the key element of ZI_CA_OPS_ALERTMAILCTX
    CONSTANTS:
      BEGIN OF gc_data_key,
        name_component  TYPE abap_compname VALUE 'NAME',
        value_component TYPE abap_compname VALUE 'VALUE',
        alert_id        TYPE string VALUE `ALERT_ID`,
      END OF gc_data_key.

  PRIVATE SECTION.
    "! The API in this system: blank = not checked yet, X = usable, - = not usable
    DATA mv_state TYPE c LENGTH 1.
    "! RENDER_W_DATA exists (else RENDER with the key)
    DATA mv_with_data TYPE abap_bool.

    CONSTANTS:
      BEGIN OF gc_state,
        usable     TYPE c LENGTH 1 VALUE 'X',
        not_usable TYPE c LENGTH 1 VALUE '-',
      END OF gc_state.

    "! Read the API's methods once (RTTI, no database)
    METHODS probe.

    "! API instance of the template; raises 071 when it cannot be had
    METHODS instance
      IMPORTING
        iv_template_id TYPE zif_ca_ops_types=>ty_template_id
      RETURNING
        VALUE(ro_api)  TYPE REF TO object
      RAISING
        zcx_ca_ops_error.

    "! IT_DATA_KEY of RENDER with the alert log key (type taken from the method's signature)
    METHODS data_key
      IMPORTING
        io_api         TYPE REF TO object
        iv_alert_id    TYPE zif_ca_ops_types=>ty_run_id
      RETURNING
        VALUE(rr_keys) TYPE REF TO data
      RAISING
        cx_sy_create_data_error.

ENDCLASS.



CLASS zcl_ca_ops_mail_tpl_smtg IMPLEMENTATION.

  METHOD zif_ca_ops_mail_template~is_available.
    IF mv_state IS INITIAL.
      probe( ).
    ENDIF.
    rv_available = xsdbool( mv_state = gc_state-usable ).
  ENDMETHOD.


  METHOD zif_ca_ops_mail_template~exists.
    IF zif_ca_ops_mail_template~is_available( ) = abap_false OR iv_template_id IS INITIAL.
      " nothing to check against: the syntax check of the configuration app applies
      rv_exists = abap_true.
      RETURN.
    ENDIF.
    TRY.
        instance( iv_template_id ).
        rv_exists = abap_true.
      CATCH zcx_ca_ops_error.
        rv_exists = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_mail_template~render.
    DATA lv_subject TYPE string.
    DATA lv_html    TYPE string.
    DATA lv_text    TYPE string.
    DATA lr_data    TYPE REF TO data.
    DATA lr_keys    TYPE REF TO data.
    DATA lv_failure TYPE string.

    IF zif_ca_ops_mail_template~is_available( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e070(zca_ops) WITH zif_ca_ops_types=>gc_renderer-smtg.
    ENDIF.
    DATA(lo_api) = instance( iv_template_id ).
    DATA(ls_header) = is_context-header.
    DATA(lt_bind) = VALUE abap_parmbind_tab(
      ( name = gc_api_param-language  kind = cl_abap_objectdescr=>exporting value = REF #( iv_language ) )
      ( name = gc_api_param-subject   kind = cl_abap_objectdescr=>importing value = REF #( lv_subject ) )
      ( name = gc_api_param-body_html kind = cl_abap_objectdescr=>importing value = REF #( lv_html ) )
      ( name = gc_api_param-body_text kind = cl_abap_objectdescr=>importing value = REF #( lv_text ) ) ).
    TRY.
        IF mv_with_data = abap_true.
          " VERIFY-ADT: the API maps the components of the structure to the placeholders by name
          lr_data = REF #( ls_header ).
          INSERT VALUE #( name = gc_api_param-data kind = cl_abap_objectdescr=>exporting value = REF #( lr_data ) )
            INTO TABLE lt_bind.
          TEST-SEAM smtg_render_data.
            CALL METHOD lo_api->(gc_api-render_w_data) PARAMETER-TABLE lt_bind.
          END-TEST-SEAM.
        ELSE.
          " VERIFY-ADT: the key of the data source is the alert log row (written before rendering)
          lr_keys = data_key( io_api = lo_api iv_alert_id = iv_alert_id ).
          INSERT VALUE #( name = gc_api_param-data_key kind = cl_abap_objectdescr=>exporting value = lr_keys )
            INTO TABLE lt_bind.
          TEST-SEAM smtg_render_key.
            CALL METHOD lo_api->(gc_api-render) PARAMETER-TABLE lt_bind.
          END-TEST-SEAM.
        ENDIF.
      CATCH cx_root INTO DATA(lx_render).
        " Deliberately broad: the API's exception classes are not verified (VERIFY-ADT); a failed
        " rendering never stops the alert - the composer keeps the built-in layout
        lv_failure = lx_render->get_text( ).
    ENDTRY.
    IF lv_failure IS NOT INITIAL OR ( lv_html IS INITIAL AND lv_text IS INITIAL ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e072(zca_ops) WITH iv_template_id lv_failure.
    ENDIF.
    rs_rendered-subject = lv_subject.
    rs_rendered-html    = lv_html.
    rs_rendered-text    = lv_text.
  ENDMETHOD.


  METHOD probe.
    DATA lo_type     TYPE REF TO cl_abap_typedescr.
    DATA lo_class    TYPE REF TO cl_abap_classdescr.
    DATA lv_instance TYPE abap_bool.
    DATA lv_render   TYPE abap_bool.

    mv_state = gc_state-not_usable.
    TEST-SEAM smtg_describe.
      cl_abap_typedescr=>describe_by_name(
        EXPORTING
          p_name         = gc_api-class
        RECEIVING
          p_descr_ref    = lo_type
        EXCEPTIONS
          type_not_found = 1
          OTHERS         = 2 ).
      IF sy-subrc = 0 AND lo_type IS BOUND.
        TRY.
            lo_class = CAST cl_abap_classdescr( lo_type ).
            lv_instance  = xsdbool( line_exists( lo_class->methods[ name = gc_api-get_instance ] ) ).
            mv_with_data = xsdbool( line_exists( lo_class->methods[ name = gc_api-render_w_data ] ) ).
            lv_render    = xsdbool( line_exists( lo_class->methods[ name = gc_api-render ] ) ).
          CATCH cx_sy_move_cast_error.
            " a type of that name that is no class: not usable
            CLEAR lo_class.
        ENDTRY.
      ENDIF.
    END-TEST-SEAM.
    IF lv_instance = abap_true AND ( mv_with_data = abap_true OR lv_render = abap_true ).
      mv_state = gc_state-usable.
    ENDIF.
  ENDMETHOD.


  METHOD instance.
    DATA lv_failure TYPE string.
    DATA(lt_bind) = VALUE abap_parmbind_tab(
      ( name = gc_api_param-template_id kind = cl_abap_objectdescr=>exporting value = REF #( iv_template_id ) )
      ( name = gc_api_param-instance    kind = cl_abap_objectdescr=>returning value = REF #( ro_api ) ) ).
    TRY.
        TEST-SEAM smtg_instance.
          CALL METHOD (gc_api-class)=>(gc_api-get_instance) PARAMETER-TABLE lt_bind.
        END-TEST-SEAM.
      CATCH cx_root INTO DATA(lx_instance).
        " Deliberately broad: unknown template, inactive template or an API that differs (VERIFY-ADT)
        lv_failure = lx_instance->get_text( ).
    ENDTRY.
    IF ro_api IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e071(zca_ops) WITH iv_template_id lv_failure.
    ENDIF.
  ENDMETHOD.


  METHOD data_key.
    FIELD-SYMBOLS <lt_keys> TYPE STANDARD TABLE.
    DATA lr_row TYPE REF TO data.
    DATA lo_type TYPE REF TO cl_abap_datadescr.

    DATA(lo_object) = CAST cl_abap_objectdescr( cl_abap_typedescr=>describe_by_object_ref( io_api ) ).
    lo_object->get_method_parameter_type(
      EXPORTING
        p_method_name       = gc_api-render
        p_parameter_name    = gc_api_param-data_key
      RECEIVING
        p_descr_ref         = lo_type
      EXCEPTIONS
        parameter_not_found = 1
        method_not_found    = 2
        OTHERS              = 3 ).
    IF sy-subrc <> 0 OR lo_type IS NOT BOUND OR lo_type->kind <> cl_abap_typedescr=>kind_table.
      RETURN.
    ENDIF.
    CREATE DATA rr_keys TYPE HANDLE lo_type.
    ASSIGN rr_keys->* TO <lt_keys>.
    CREATE DATA lr_row LIKE LINE OF <lt_keys>.
    ASSIGN lr_row->* TO FIELD-SYMBOL(<ls_row>).
    ASSIGN COMPONENT gc_data_key-name_component OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_name>).
    ASSIGN COMPONENT gc_data_key-value_component OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_value>).
    IF <lv_name> IS ASSIGNED AND <lv_value> IS ASSIGNED.
      <lv_name>  = gc_data_key-alert_id.
      <lv_value> = |{ iv_alert_id }|.
      INSERT <ls_row> INTO TABLE <lt_keys>.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
