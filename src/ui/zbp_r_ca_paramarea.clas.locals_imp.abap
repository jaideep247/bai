*&---------------------------------------------------------------------*
*& Artifact: zbp_r_ca_paramarea.clas.locals_imp.abap
*& Purpose:
*& Handlers and saver of the parameter maintenance app:
*&  - authorization: ZCA_PARAM 01 (create area, any area), 02 per area
*&    (edit), 06 per area (delete definitions / values, via features);
*&  - features: create / change of areas and definitions, new values and
*&    deletions only in TRANSPORT mode; existing values also in LOCAL mode
*&    for PROD_EDITABLE areas and definitions not DEVELOPER_OWNED;
*&  - defaults on create, validations on save (ZCL_CA_PARAM_VALIDATOR, the
*&    runtime rules), one row per single-value parameter, request check;
*&  - early numbering of value rows (NUMB = highest + 1 per parameter);
*&  - saver: records the save on the customizing request (MBC_CP_API via
*&    ZCL_CA_PARAM_MAINT) in TRANSPORT mode; production changes are audited
*&    by table logging. Thin: no rule is decided here.
*& VERIFY-ADT: EML READ in save_modified (request of the area); validation
*& trigger delete; draft action Edit with instance features.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! State areas of the validations (messages are replaced per area on each check)
INTERFACE lif_c.
  CONSTANTS:
    BEGIN OF gc_state,
      fields    TYPE string VALUE `FIELDS`,
      transport TYPE string VALUE `TRANSPORT`,
    END OF gc_state.
ENDINTERFACE.


CLASS lhc_area DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Area RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Area RESULT result.

    METHODS get_global_features FOR GLOBAL FEATURES
      IMPORTING REQUEST requested_features FOR Area RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Area RESULT result.

    METHODS setareadefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Area~setAreaDefaults.

    METHODS validatearea FOR VALIDATE ON SAVE
      IMPORTING keys FOR Area~validateArea.

    METHODS validatetransport FOR VALIDATE ON SAVE
      IMPORTING keys FOR Area~validateTransport.

    METHODS fc
      IMPORTING
        iv_on        TYPE abap_bool
      RETURNING
        VALUE(rv_fc) TYPE if_abap_behv=>t_xflag.

    METHODS auth
      IMPORTING
        iv_on          TYPE abap_bool
      RETURNING
        VALUE(rv_auth) TYPE if_abap_behv=>t_xflag.

    METHODS msg
      IMPORTING
        is_message    TYPE zif_ca_param_types=>ty_message
      RETURNING
        VALUE(ro_msg) TYPE REF TO if_abap_behv_message.
ENDCLASS.


CLASS lhc_area IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = auth( zcl_ca_param_maint=>get( )->is_authorized(
                               iv_area  = VALUE #( )
                               iv_actvt = zif_ca_param_types=>gc_actvt-create ) ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_authorizations.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      DATA(lv_change) = auth( lo_maint->is_authorized( iv_area  = <ls_key>-Area
                                                       iv_actvt = zif_ca_param_types=>gc_actvt-change ) ).
      INSERT VALUE #( %tky         = <ls_key>-%tky
                      %update      = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on
                                             THEN lv_change )
                      %action-Edit = COND #( WHEN requested_authorizations-%action-Edit = if_abap_behv=>mk-on
                                             THEN lv_change ) ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_global_features.
    IF requested_features-%create = if_abap_behv=>mk-on.
      result-%create = fc( zcl_ca_param_maint=>get( )->can_maintain_config( ) ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    DATA(lv_config) = lo_maint->can_maintain_config( ).
    DATA(lv_field) = COND if_abap_behv=>t_xflag( WHEN lv_config = abap_true
                                                 THEN if_abap_behv=>fc-f-unrestricted
                                                 ELSE if_abap_behv=>fc-f-read_only ).
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Area
        FIELDS ( ProdEditable ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_areas).
    LOOP AT lt_areas ASSIGNING FIELD-SYMBOL(<ls_area>).
      DATA(lv_edit) = fc( lo_maint->can_edit_area( <ls_area>-ProdEditable ) ).
      " answer only what the framework asked for
      INSERT VALUE #( %tky                    = <ls_area>-%tky
                      %update                 = COND #( WHEN requested_features-%update = if_abap_behv=>mk-on
                                                        THEN lv_edit )
                      %action-Edit            = COND #( WHEN requested_features-%action-Edit = if_abap_behv=>mk-on
                                                        THEN lv_edit )
                      %assoc-_Definition      = COND #( WHEN requested_features-%assoc-_Definition = if_abap_behv=>mk-on
                                                        THEN fc( lv_config ) )
                      %field-Description      = lv_field
                      %field-OwnerTeam        = lv_field
                      %field-ProdEditable     = lv_field
                      %field-Active           = lv_field
                      %field-TransportRequest = lv_field ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD setareadefaults.
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Area
        FIELDS ( Active ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_areas).
    DELETE lt_areas WHERE Active IS NOT INITIAL.
    IF lt_areas IS INITIAL.
      RETURN.
    ENDIF.
    MODIFY ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Area
        UPDATE FIELDS ( Active )
        WITH VALUE #( FOR ls_area IN lt_areas ( %tky   = ls_area-%tky
                                                Active = abap_true ) ).
  ENDMETHOD.


  METHOD validatearea.
    DATA(lo_validator) = zcl_ca_param_maint=>get( )->validator( ).
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Area
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_areas).
    LOOP AT lt_areas ASSIGNING FIELD-SYMBOL(<ls_area>).
      INSERT VALUE #( %tky = <ls_area>-%tky %state_area = lif_c=>gc_state-fields ) INTO TABLE reported-area.
      DATA(lt_messages) = lo_validator->check_area(
                            CORRESPONDING #( <ls_area> MAPPING owner_team    = OwnerTeam
                                                               prod_editable = ProdEditable ) ).
      LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<ls_message>).
        INSERT VALUE #( %tky = <ls_area>-%tky ) INTO TABLE failed-area.
        INSERT VALUE #( %tky        = <ls_area>-%tky
                        %state_area = lif_c=>gc_state-fields
                        %msg        = msg( <ls_message> ) ) INTO TABLE reported-area ASSIGNING FIELD-SYMBOL(<ls_reported>).
        IF <ls_message>-field IS NOT INITIAL.
          ASSIGN COMPONENT <ls_message>-field OF STRUCTURE <ls_reported>-%element TO FIELD-SYMBOL(<lv_flag>).
          IF sy-subrc = 0.
            <lv_flag> = if_abap_behv=>mk-on.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD validatetransport.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Area
        FIELDS ( TransportRequest ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_areas).
    LOOP AT lt_areas ASSIGNING FIELD-SYMBOL(<ls_area>).
      INSERT VALUE #( %tky = <ls_area>-%tky %state_area = lif_c=>gc_state-transport ) INTO TABLE reported-area.
      DATA(ls_message) = lo_maint->check_request( iv_area    = <ls_area>-Area
                                                  iv_request = <ls_area>-TransportRequest ).
      IF ls_message IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( %tky = <ls_area>-%tky ) INTO TABLE failed-area.
      INSERT VALUE #( %tky                     = <ls_area>-%tky
                      %state_area              = lif_c=>gc_state-transport
                      %msg                     = msg( ls_message )
                      %element-TransportRequest = if_abap_behv=>mk-on ) INTO TABLE reported-area.
    ENDLOOP.
  ENDMETHOD.


  METHOD fc.
    rv_fc = COND #( WHEN iv_on = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.


  METHOD auth.
    rv_auth = COND #( WHEN iv_on = abap_true THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).
  ENDMETHOD.


  METHOD msg.
    ro_msg = new_message( id       = is_message-msgid
                          number   = is_message-msgno
                          severity = if_abap_behv_message=>severity-error
                          v1       = is_message-v1
                          v2       = is_message-v2
                          v3       = is_message-v3
                          v4       = is_message-v4 ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_definition DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Definition RESULT result.

    METHODS setdefinitiondefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Definition~setDefinitionDefaults.

    METHODS validatedefinition FOR VALIDATE ON SAVE
      IMPORTING keys FOR Definition~validateDefinition.

    METHODS validatetransport FOR VALIDATE ON SAVE
      IMPORTING keys FOR Definition~validateTransport.

    METHODS earlynumbering_cba_value FOR NUMBERING
      IMPORTING entities FOR CREATE Definition\_Value.

    METHODS fc
      IMPORTING
        iv_on        TYPE abap_bool
      RETURNING
        VALUE(rv_fc) TYPE if_abap_behv=>t_xflag.

    METHODS msg
      IMPORTING
        is_message    TYPE zif_ca_param_types=>ty_message
      RETURNING
        VALUE(ro_msg) TYPE REF TO if_abap_behv_message.
ENDCLASS.


CLASS lhc_definition IMPLEMENTATION.

  METHOD get_instance_features.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    DATA(lv_config) = lo_maint->can_maintain_config( ).
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      INSERT VALUE #( %tky          = <ls_key>-%tky
                      %update       = COND #( WHEN requested_features-%update = if_abap_behv=>mk-on
                                              THEN fc( lv_config ) )
                      %delete       = COND #( WHEN requested_features-%delete = if_abap_behv=>mk-on
                                              THEN fc( xsdbool( lv_config = abap_true
                                                                AND lo_maint->is_authorized(
                                                                      iv_area  = <ls_key>-Area
                                                                      iv_actvt = zif_ca_param_types=>gc_actvt-delete )
                                                                    = abap_true ) ) )
                      %assoc-_Value = COND #( WHEN requested_features-%assoc-_Value = if_abap_behv=>mk-on
                                              THEN fc( lv_config ) ) ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD setdefinitiondefaults.
    " new definitions start as single CHAR values owned by development (transport only)
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Definition
        FIELDS ( Kind ValueType ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_definitions).
    IF lt_definitions IS INITIAL.
      RETURN.
    ENDIF.
    MODIFY ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Definition
        UPDATE FIELDS ( Kind ValueType DeveloperOwned )
        WITH VALUE #( FOR ls_definition IN lt_definitions
                      ( %tky           = ls_definition-%tky
                        Kind           = COND #( WHEN ls_definition-Kind IS INITIAL
                                                 THEN zif_ca_param_types=>gc_kind-single
                                                 ELSE ls_definition-Kind )
                        ValueType      = COND #( WHEN ls_definition-ValueType IS INITIAL
                                                 THEN zif_ca_param_types=>gc_value_type-char
                                                 ELSE ls_definition-ValueType )
                        DeveloperOwned = abap_true ) ).
  ENDMETHOD.


  METHOD validatedefinition.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Definition
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_definitions).
    LOOP AT lt_definitions ASSIGNING FIELD-SYMBOL(<ls_definition>).
      INSERT VALUE #( %tky = <ls_definition>-%tky %state_area = lif_c=>gc_state-fields ) INTO TABLE reported-definition.
      DATA(lt_messages) = lo_maint->validator( )->check_definition(
                            CORRESPONDING #( <ls_definition> MAPPING value_type      = ValueType
                                                                     min_value       = MinValue
                                                                     max_value       = MaxValue
                                                                     default_value   = DefaultValue
                                                                     allowed_pcre    = AllowedPcre
                                                                     interface_name  = InterfaceName
                                                                     developer_owned = DeveloperOwned ) ).
      DATA(ls_config) = lo_maint->check_config_change( <ls_definition>-Area ).
      IF ls_config IS NOT INITIAL.
        INSERT ls_config INTO TABLE lt_messages.
      ENDIF.
      LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<ls_message>).
        INSERT VALUE #( %tky = <ls_definition>-%tky ) INTO TABLE failed-definition.
        INSERT VALUE #( %tky        = <ls_definition>-%tky
                        %state_area = lif_c=>gc_state-fields
                        %msg        = msg( <ls_message> ) ) INTO TABLE reported-definition ASSIGNING FIELD-SYMBOL(<ls_reported>).
        <ls_reported>-%path-area-%is_draft = <ls_definition>-%is_draft.
        <ls_reported>-%path-area-Area      = <ls_definition>-Area.
        IF <ls_message>-field IS NOT INITIAL.
          ASSIGN COMPONENT <ls_message>-field OF STRUCTURE <ls_reported>-%element TO FIELD-SYMBOL(<lv_flag>).
          IF sy-subrc = 0.
            <lv_flag> = if_abap_behv=>mk-on.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD validatetransport.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      INSERT VALUE #( %tky = <ls_key>-%tky %state_area = lif_c=>gc_state-transport ) INTO TABLE reported-definition.
      READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
        ENTITY Area
          FIELDS ( TransportRequest ) WITH VALUE #( ( %is_draft = <ls_key>-%is_draft Area = <ls_key>-Area ) )
        RESULT DATA(lt_areas).
      DATA(ls_message) = lo_maint->check_request( iv_area    = <ls_key>-Area
                                                  iv_request = VALUE #( lt_areas[ 1 ]-TransportRequest OPTIONAL ) ).
      IF ls_message IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( %tky = <ls_key>-%tky ) INTO TABLE failed-definition.
      INSERT VALUE #( %tky        = <ls_key>-%tky
                      %state_area = lif_c=>gc_state-transport
                      %msg        = msg( ls_message ) ) INTO TABLE reported-definition ASSIGNING FIELD-SYMBOL(<ls_reported>).
      <ls_reported>-%path-area-%is_draft = <ls_key>-%is_draft.
      <ls_reported>-%path-area-Area      = <ls_key>-Area.
    ENDLOOP.
  ENDMETHOD.


  METHOD earlynumbering_cba_value.
    DATA lv_numb TYPE zif_ca_param_types=>ty_numb.

    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Definition BY \_Value
        FIELDS ( Numb ) WITH CORRESPONDING #( entities )
      RESULT DATA(lt_existing).
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>).
      CLEAR lv_numb.
      LOOP AT lt_existing ASSIGNING FIELD-SYMBOL(<ls_existing>)
           WHERE %is_draft = <ls_entity>-%is_draft AND Area = <ls_entity>-Area AND Name = <ls_entity>-Name.
        IF <ls_existing>-Numb > lv_numb.
          lv_numb = <ls_existing>-Numb.
        ENDIF.
      ENDLOOP.
      LOOP AT <ls_entity>-%target ASSIGNING FIELD-SYMBOL(<ls_target>).
        lv_numb = lv_numb + 1.
        INSERT VALUE #( %cid      = <ls_target>-%cid
                        %is_draft = <ls_target>-%is_draft
                        Area      = <ls_entity>-Area
                        Name      = <ls_entity>-Name
                        Numb      = lv_numb ) INTO TABLE mapped-value.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD fc.
    rv_fc = COND #( WHEN iv_on = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.


  METHOD msg.
    ro_msg = new_message( id       = is_message-msgid
                          number   = is_message-msgno
                          severity = if_abap_behv_message=>severity-error
                          v1       = is_message-v1
                          v2       = is_message-v2
                          v3       = is_message-v3
                          v4       = is_message-v4 ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_value DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Value RESULT result.

    METHODS setvaluedefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Value~setValueDefaults.

    METHODS validatevalue FOR VALIDATE ON SAVE
      IMPORTING keys FOR Value~validateValue.

    METHODS validatetransport FOR VALIDATE ON SAVE
      IMPORTING keys FOR Value~validateTransport.

    METHODS fc
      IMPORTING
        iv_on        TYPE abap_bool
      RETURNING
        VALUE(rv_fc) TYPE if_abap_behv=>t_xflag.

    METHODS msg
      IMPORTING
        is_message    TYPE zif_ca_param_types=>ty_message
      RETURNING
        VALUE(ro_msg) TYPE REF TO if_abap_behv_message.
ENDCLASS.


CLASS lhc_value IMPLEMENTATION.

  METHOD get_instance_features.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    DATA(lv_config) = lo_maint->can_maintain_config( ).
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
        ENTITY Definition
          FIELDS ( DeveloperOwned )
          WITH VALUE #( ( %is_draft = <ls_key>-%is_draft Area = <ls_key>-Area Name = <ls_key>-Name ) )
        RESULT DATA(lt_definitions)
        ENTITY Area
          FIELDS ( ProdEditable ) WITH VALUE #( ( %is_draft = <ls_key>-%is_draft Area = <ls_key>-Area ) )
        RESULT DATA(lt_areas).
      DATA(lv_change) = lo_maint->can_change_value(
                          iv_prod_editable   = VALUE #( lt_areas[ 1 ]-ProdEditable OPTIONAL )
                          iv_developer_owned = VALUE #( lt_definitions[ 1 ]-DeveloperOwned DEFAULT abap_true ) ).
      INSERT VALUE #( %tky    = <ls_key>-%tky
                      %update = COND #( WHEN requested_features-%update = if_abap_behv=>mk-on
                                        THEN fc( lv_change ) )
                      %delete = COND #( WHEN requested_features-%delete = if_abap_behv=>mk-on
                                        THEN fc( xsdbool( lv_config = abap_true
                                                          AND lo_maint->is_authorized(
                                                                iv_area  = <ls_key>-Area
                                                                iv_actvt = zif_ca_param_types=>gc_actvt-delete )
                                                              = abap_true ) ) ) )
        INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD setvaluedefaults.
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Value
        FIELDS ( Sign Opti ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_values).
    DELETE lt_values WHERE Sign IS NOT INITIAL AND Opti IS NOT INITIAL.
    IF lt_values IS INITIAL.
      RETURN.
    ENDIF.
    MODIFY ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Value
        UPDATE FIELDS ( Sign Opti )
        WITH VALUE #( FOR ls_value IN lt_values
                      ( %tky = ls_value-%tky
                        Sign = COND #( WHEN ls_value-Sign IS INITIAL
                                       THEN zif_ca_param_types=>gc_sign-include
                                       ELSE ls_value-Sign )
                        Opti = COND #( WHEN ls_value-Opti IS INITIAL
                                       THEN zif_ca_param_types=>gc_option-eq
                                       ELSE ls_value-Opti ) ) ).
  ENDMETHOD.


  METHOD validatevalue.
    DATA lt_messages TYPE zif_ca_param_types=>tt_message.

    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Value
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_values).
    LOOP AT lt_values ASSIGNING FIELD-SYMBOL(<ls_value>).
      INSERT VALUE #( %tky = <ls_value>-%tky %state_area = lif_c=>gc_state-fields ) INTO TABLE reported-value.
      READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
        ENTITY Definition
          ALL FIELDS
          WITH VALUE #( ( %is_draft = <ls_value>-%is_draft Area = <ls_value>-Area Name = <ls_value>-Name ) )
        RESULT DATA(lt_definitions)
        ENTITY Definition BY \_Value
          FIELDS ( Numb )
          WITH VALUE #( ( %is_draft = <ls_value>-%is_draft Area = <ls_value>-Area Name = <ls_value>-Name ) )
        RESULT DATA(lt_rows)
        ENTITY Area
          FIELDS ( ProdEditable ) WITH VALUE #( ( %is_draft = <ls_value>-%is_draft Area = <ls_value>-Area ) )
        RESULT DATA(lt_areas).
      IF lt_definitions IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_definition) = CORRESPONDING zif_ca_param_types=>ty_definition(
                              lt_definitions[ 1 ] MAPPING value_type      = ValueType
                                                          min_value       = MinValue
                                                          max_value       = MaxValue
                                                          default_value   = DefaultValue
                                                          allowed_pcre    = AllowedPcre
                                                          interface_name  = InterfaceName
                                                          developer_owned = DeveloperOwned ).
      CLEAR lt_messages.
      DATA(ls_message) = lo_maint->validator( )->check_row( is_definition = ls_definition
                                                            is_row        = CORRESPONDING #( <ls_value> ) ).
      IF ls_message IS NOT INITIAL.
        INSERT ls_message INTO TABLE lt_messages.
      ENDIF.
      IF ls_definition-kind = zif_ca_param_types=>gc_kind-single AND lines( lt_rows ) > 1.
        INSERT VALUE #( msgid = zif_ca_param_types=>gc_msgid
                        msgno = zif_ca_param_types=>gc_msg-single_multiple
                        v1    = ls_definition-area
                        v2    = ls_definition-name
                        v3    = |{ lines( lt_rows ) }| ) INTO TABLE lt_messages.
      ENDIF.
      ls_message = lo_maint->check_value_change( iv_area            = ls_definition-area
                                                 iv_name            = ls_definition-name
                                                 iv_prod_editable   = VALUE #( lt_areas[ 1 ]-ProdEditable OPTIONAL )
                                                 iv_developer_owned = ls_definition-developer_owned ).
      IF ls_message IS NOT INITIAL.
        INSERT ls_message INTO TABLE lt_messages.
      ENDIF.

      LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<ls_message>).
        INSERT VALUE #( %tky = <ls_value>-%tky ) INTO TABLE failed-value.
        INSERT VALUE #( %tky        = <ls_value>-%tky
                        %state_area = lif_c=>gc_state-fields
                        %msg        = msg( <ls_message> ) ) INTO TABLE reported-value ASSIGNING FIELD-SYMBOL(<ls_reported>).
        <ls_reported>-%path-area-%is_draft       = <ls_value>-%is_draft.
        <ls_reported>-%path-area-Area            = <ls_value>-Area.
        <ls_reported>-%path-definition-%is_draft = <ls_value>-%is_draft.
        <ls_reported>-%path-definition-Area      = <ls_value>-Area.
        <ls_reported>-%path-definition-Name      = <ls_value>-Name.
        IF <ls_message>-field IS NOT INITIAL.
          ASSIGN COMPONENT <ls_message>-field OF STRUCTURE <ls_reported>-%element TO FIELD-SYMBOL(<lv_flag>).
          IF sy-subrc = 0.
            <lv_flag> = if_abap_behv=>mk-on.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD validatetransport.
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      INSERT VALUE #( %tky = <ls_key>-%tky %state_area = lif_c=>gc_state-transport ) INTO TABLE reported-value.
      READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
        ENTITY Area
          FIELDS ( TransportRequest ) WITH VALUE #( ( %is_draft = <ls_key>-%is_draft Area = <ls_key>-Area ) )
        RESULT DATA(lt_areas).
      DATA(ls_message) = lo_maint->check_request( iv_area    = <ls_key>-Area
                                                  iv_request = VALUE #( lt_areas[ 1 ]-TransportRequest OPTIONAL ) ).
      IF ls_message IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( %tky = <ls_key>-%tky ) INTO TABLE failed-value.
      INSERT VALUE #( %tky        = <ls_key>-%tky
                      %state_area = lif_c=>gc_state-transport
                      %msg        = msg( ls_message ) ) INTO TABLE reported-value ASSIGNING FIELD-SYMBOL(<ls_reported>).
      <ls_reported>-%path-area-%is_draft       = <ls_key>-%is_draft.
      <ls_reported>-%path-area-Area            = <ls_key>-Area.
      <ls_reported>-%path-definition-%is_draft = <ls_key>-%is_draft.
      <ls_reported>-%path-definition-Area      = <ls_key>-Area.
      <ls_reported>-%path-definition-Name      = <ls_key>-Name.
    ENDLOOP.
  ENDMETHOD.


  METHOD fc.
    rv_fc = COND #( WHEN iv_on = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.


  METHOD msg.
    ro_msg = new_message( id       = is_message-msgid
                          number   = is_message-msgno
                          severity = if_abap_behv_message=>severity-error
                          v1       = is_message-v1
                          v2       = is_message-v2
                          v3       = is_message-v3
                          v4       = is_message-v4 ).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_zr_ca_paramarea DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.


CLASS lsc_zr_ca_paramarea IMPLEMENTATION.

  METHOD save_modified.
    DATA lt_areas   TYPE STANDARD TABLE OF zif_ca_param_types=>ty_area WITH EMPTY KEY.
    DATA lv_request TYPE zif_ca_param_types=>ty_request.

    " The framework persists the rows (managed); here they are recorded on the customizing
    " request where the client records changes. Local clients: no-op (table logging audits).
    DATA(lo_maint) = zcl_ca_param_maint=>get( ).
    IF lo_maint->mode( ) <> zif_ca_param_types=>gc_mode-transport.
      RETURN.
    ENDIF.
    lt_areas = VALUE #( BASE lt_areas FOR ls_c_area IN create-area ( ls_c_area-Area ) ).
    lt_areas = VALUE #( BASE lt_areas FOR ls_u_area IN update-area ( ls_u_area-Area ) ).
    lt_areas = VALUE #( BASE lt_areas FOR ls_c_def IN create-definition ( ls_c_def-Area ) ).
    lt_areas = VALUE #( BASE lt_areas FOR ls_u_def IN update-definition ( ls_u_def-Area ) ).
    lt_areas = VALUE #( BASE lt_areas FOR ls_d_def IN delete-definition ( ls_d_def-Area ) ).
    lt_areas = VALUE #( BASE lt_areas FOR ls_c_val IN create-value ( ls_c_val-Area ) ).
    lt_areas = VALUE #( BASE lt_areas FOR ls_u_val IN update-value ( ls_u_val-Area ) ).
    lt_areas = VALUE #( BASE lt_areas FOR ls_d_val IN delete-value ( ls_d_val-Area ) ).
    SORT lt_areas BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_areas COMPARING table_line.
    IF lt_areas IS INITIAL.
      RETURN.
    ENDIF.

    " one draft activation saves one area; its request (validated on save) takes all rows
    READ ENTITIES OF zr_ca_paramarea IN LOCAL MODE
      ENTITY Area
        FIELDS ( TransportRequest )
        WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off Area = lt_areas[ 1 ] ) )
      RESULT DATA(lt_roots).
    lv_request = VALUE #( lt_roots[ 1 ]-TransportRequest OPTIONAL ).
    IF lv_request IS INITIAL.
      lv_request = VALUE #( update-area[ 1 ]-TransportRequest OPTIONAL ).
    ENDIF.
    IF lv_request IS INITIAL.
      lv_request = VALUE #( create-area[ 1 ]-TransportRequest OPTIONAL ).
    ENDIF.
    TRY.
        lo_maint->record( iv_request = lv_request
                          ir_create  = REF #( create )
                          ir_update  = REF #( update )
                          ir_delete  = REF #( delete ) ).
      CATCH zcx_ca_param INTO DATA(lx_error).
        " a recording client must never keep changes that are not on the request (rollback)
        RAISE SHORTDUMP lx_error.
    ENDTRY.
  ENDMETHOD.


  METHOD cleanup_finalize ##NEEDED.
  ENDMETHOD.

ENDCLASS.
