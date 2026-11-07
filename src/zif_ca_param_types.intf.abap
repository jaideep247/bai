*&---------------------------------------------------------------------*
*& Artifact: zif_ca_param_types.intf.abap
*& Purpose:
*& Named types and constants of the parameter framework: keys, values,
*& definitions, value rows, area snapshot, messages, kinds, value types,
*& range signs / options, PCRE patterns of the validator, authorization
*& object and the client / request settings of the maintenance app.
*& No logic. The message numbers here and the rows in
*& config/zca_param_messages.md are compared by tools/checks.py.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - types and constants</p>
INTERFACE zif_ca_param_types
  PUBLIC.

  TYPES ty_area        TYPE zca_param_area_id.
  TYPES ty_name        TYPE zca_param_name.
  TYPES ty_value       TYPE zca_param_value.
  TYPES ty_kind        TYPE zca_param_kind.
  TYPES ty_value_type  TYPE zca_param_vtype.
  TYPES ty_numb        TYPE zca_param_numb.
  TYPES ty_sign        TYPE zca_param_sign.
  TYPES ty_option      TYPE zca_param_option.
  TYPES ty_description TYPE zca_param_descr.
  TYPES ty_owner       TYPE zca_param_owner.
  TYPES ty_interface   TYPE seoclsname.
  TYPES ty_request     TYPE trkorr.
  TYPES ty_decimal     TYPE decfloat34.
  TYPES ty_actvt       TYPE c LENGTH 2.
  TYPES ty_mode        TYPE c LENGTH 1.
  TYPES ty_role        TYPE c LENGTH 1.
  TYPES ty_change_opt  TYPE c LENGTH 1.
  TYPES ty_req_status  TYPE c LENGTH 1.
  TYPES ty_req_func    TYPE c LENGTH 1.
  TYPES ty_field       TYPE c LENGTH 30.

  "! Elements of a list parameter (get_list)
  TYPES tt_list TYPE string_table.
  "! Select-option of a parameter (get_range): SIGN, OPTION, LOW, HIGH (CHAR 255)
  TYPES tt_range TYPE RANGE OF ty_value.
  TYPES ty_range_line TYPE LINE OF tt_range.

  "! Area master data (ZCA_PARAM_AREA)
  TYPES:
    BEGIN OF ty_area_row,
      area          TYPE ty_area,
      description   TYPE ty_description,
      owner_team    TYPE ty_owner,
      prod_editable TYPE abap_bool,
      active        TYPE abap_bool,
    END OF ty_area_row.
  TYPES tt_area_row TYPE HASHED TABLE OF ty_area_row WITH UNIQUE KEY area.

  "! Definition of one parameter (ZCA_PARAM_DEF); AREA + NAME is its only identity
  TYPES:
    BEGIN OF ty_definition,
      area            TYPE ty_area,
      name            TYPE ty_name,
      kind            TYPE ty_kind,
      value_type      TYPE ty_value_type,
      min_value       TYPE ty_value,
      max_value       TYPE ty_value,
      default_value   TYPE ty_value,
      allowed_pcre    TYPE ty_value,
      interface_name  TYPE ty_interface,
      mandatory       TYPE abap_bool,
      developer_owned TYPE abap_bool,
      description     TYPE ty_description,
      owner           TYPE ty_owner,
    END OF ty_definition.
  TYPES tt_definition TYPE SORTED TABLE OF ty_definition WITH UNIQUE KEY area name.

  "! One value row (ZCA_PARAM_VAL); rows of a parameter are ordered by NUMB
  TYPES:
    BEGIN OF ty_value_row,
      area TYPE ty_area,
      name TYPE ty_name,
      numb TYPE ty_numb,
      sign TYPE ty_sign,
      opti TYPE ty_option,
      low  TYPE ty_value,
      high TYPE ty_value,
    END OF ty_value_row.
  TYPES tt_value_row TYPE SORTED TABLE OF ty_value_row WITH UNIQUE KEY area name numb.

  "! Everything of one area, read in one go by the DAO
  TYPES:
    BEGIN OF ty_area_data,
      found       TYPE abap_bool,
      area        TYPE ty_area_row,
      definitions TYPE tt_definition,
      values      TYPE tt_value_row,
    END OF ty_area_data.

  "! A message of class ZCA_PARAM (msgno initial = no message); field = UI element
  TYPES:
    BEGIN OF ty_message,
      msgid TYPE symsgid,
      msgno TYPE symsgno,
      v1    TYPE symsgv,
      v2    TYPE symsgv,
      v3    TYPE symsgv,
      v4    TYPE symsgv,
      field TYPE ty_field,
    END OF ty_message.
  TYPES tt_message TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

  "! Client settings (T000 / SCC4) and customizing changeability
  TYPES:
    BEGIN OF ty_client,
      role          TYPE ty_role,
      change_option TYPE ty_change_opt,
      cust_editable TYPE abap_bool,
    END OF ty_client.

  "! State of a transport request (E070)
  TYPES:
    BEGIN OF ty_request_info,
      exists   TYPE abap_bool,
      status   TYPE ty_req_status,
      function TYPE ty_req_func,
    END OF ty_request_info.

  "! RAP entity (alias) and its persistent table, for transport recording
  TYPES:
    BEGIN OF ty_relation,
      entity TYPE ty_field,
      table  TYPE ty_field,
    END OF ty_relation.
  TYPES tt_relation TYPE STANDARD TABLE OF ty_relation WITH EMPTY KEY.

  CONSTANTS gc_msgid TYPE symsgid VALUE 'ZCA_PARAM'.

  "! Message numbers of class ZCA_PARAM (config/zca_param_messages.md)
  CONSTANTS:
    BEGIN OF gc_msg,
      area_unknown       TYPE symsgno VALUE '001',
      area_inactive      TYPE symsgno VALUE '002',
      name_unknown       TYPE symsgno VALUE '003',
      mandatory_missing  TYPE symsgno VALUE '004',
      single_multiple    TYPE symsgno VALUE '005',
      type_invalid       TYPE symsgno VALUE '006',
      below_min          TYPE symsgno VALUE '007',
      above_max          TYPE symsgno VALUE '008',
      pattern_mismatch   TYPE symsgno VALUE '009',
      pattern_invalid    TYPE symsgno VALUE '010',
      ddic_unknown       TYPE symsgno VALUE '011',
      class_unknown      TYPE symsgno VALUE '012',
      class_no_intf      TYPE symsgno VALUE '013',
      type_mismatch      TYPE symsgno VALUE '014',
      kind_mismatch      TYPE symsgno VALUE '015',
      row_not_list       TYPE symsgno VALUE '016',
      row_invalid        TYPE symsgno VALUE '017',
      no_value           TYPE symsgno VALUE '018',
      name_invalid       TYPE symsgno VALUE '019',
      kind_invalid       TYPE symsgno VALUE '020',
      vtype_invalid      TYPE symsgno VALUE '021',
      field_not_allowed  TYPE symsgno VALUE '022',
      min_above_max      TYPE symsgno VALUE '023',
      intf_unknown       TYPE symsgno VALUE '024',
      list_needs_single  TYPE symsgno VALUE '025',
      request_missing    TYPE symsgno VALUE '040',
      request_unknown    TYPE symsgno VALUE '041',
      request_not_cust   TYPE symsgno VALUE '042',
      request_released   TYPE symsgno VALUE '043',
      config_not_allowed TYPE symsgno VALUE '044',
      value_not_editable TYPE symsgno VALUE '045',
      not_authorized     TYPE symsgno VALUE '046',
      record_failed      TYPE symsgno VALUE '047',
    END OF gc_msg.

  "! Parameter kinds (domain ZCA_PARAM_KIND)
  CONSTANTS:
    BEGIN OF gc_kind,
      single TYPE ty_kind VALUE 'P',
      select TYPE ty_kind VALUE 'S',
    END OF gc_kind.

  "! Value types (domain ZCA_PARAM_VTYPE)
  CONSTANTS:
    BEGIN OF gc_value_type,
      int   TYPE ty_value_type VALUE 'INT',
      dec   TYPE ty_value_type VALUE 'DEC',
      char  TYPE ty_value_type VALUE 'CHAR',
      bool  TYPE ty_value_type VALUE 'BOOL',
      date  TYPE ty_value_type VALUE 'DATE',
      time  TYPE ty_value_type VALUE 'TIME',
      list  TYPE ty_value_type VALUE 'LIST',
      pcre  TYPE ty_value_type VALUE 'PCRE',
      ddic  TYPE ty_value_type VALUE 'DDIC',
      class TYPE ty_value_type VALUE 'CLASS',
    END OF gc_value_type.

  "! How a value is read, for messages 014 / 015 (value types or these)
  CONSTANTS:
    BEGIN OF gc_read_as,
      value TYPE ty_value_type VALUE 'VALUE',
      range TYPE ty_value_type VALUE 'RANGE',
    END OF gc_read_as.

  "! Separator of list elements after normalisation (comma or semicolon in the value)
  CONSTANTS gc_list_separator TYPE c LENGTH 1 VALUE ','.

  "! BOOL values: X = on, blank = off
  CONSTANTS gc_true TYPE ty_value VALUE 'X'.

  "! Range signs and options (domains ZCA_PARAM_SIGN / ZCA_PARAM_OPTION); no pattern options
  CONSTANTS:
    BEGIN OF gc_sign,
      include TYPE ty_sign VALUE 'I',
      exclude TYPE ty_sign VALUE 'E',
    END OF gc_sign.
  CONSTANTS:
    BEGIN OF gc_option,
      eq TYPE ty_option VALUE 'EQ',
      ne TYPE ty_option VALUE 'NE',
      gt TYPE ty_option VALUE 'GT',
      ge TYPE ty_option VALUE 'GE',
      lt TYPE ty_option VALUE 'LT',
      le TYPE ty_option VALUE 'LE',
      bt TYPE ty_option VALUE 'BT',
      nb TYPE ty_option VALUE 'NB',
    END OF gc_option.

  "! PCRE patterns of the validator (whole value; names are upper case)
  CONSTANTS:
    BEGIN OF gc_pcre,
      identifier TYPE string VALUE `^[A-Z][A-Z0-9_]*$`,
      int        TYPE string VALUE `^[+-]?[0-9]+$`,
      dec        TYPE string VALUE `^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$`,
      date       TYPE string VALUE `^[0-9]{8}$`,
      time       TYPE string VALUE `^([01][0-9]|2[0-3])[0-5][0-9][0-5][0-9]$`,
      repository TYPE string VALUE `^(/[A-Z0-9_]+/)?[A-Z0-9_]+$`,
      separator  TYPE string VALUE `[,;]`,
    END OF gc_pcre.

  "! Bounds of value type INT (ABAP type i)
  CONSTANTS gc_int_min TYPE ty_decimal VALUE '-2147483648'.
  CONSTANTS gc_int_max TYPE ty_decimal VALUE '2147483647'.

  "! Element names of the maintenance app (CDS element names, upper case)
  CONSTANTS:
    BEGIN OF gc_field,
      area           TYPE ty_field VALUE 'AREA',
      name           TYPE ty_field VALUE 'NAME',
      kind           TYPE ty_field VALUE 'KIND',
      value_type     TYPE ty_field VALUE 'VALUETYPE',
      min_value      TYPE ty_field VALUE 'MINVALUE',
      max_value      TYPE ty_field VALUE 'MAXVALUE',
      default_value  TYPE ty_field VALUE 'DEFAULTVALUE',
      allowed_pcre   TYPE ty_field VALUE 'ALLOWEDPCRE',
      interface_name TYPE ty_field VALUE 'INTERFACENAME',
      sign           TYPE ty_field VALUE 'SIGN',
      opti           TYPE ty_field VALUE 'OPTI',
      low            TYPE ty_field VALUE 'LOW',
      high           TYPE ty_field VALUE 'HIGH',
      request        TYPE ty_field VALUE 'TRANSPORTREQUEST',
    END OF gc_field.

  "! Persistent tables and RAP entity aliases of the maintenance app (transport recording)
  CONSTANTS:
    BEGIN OF gc_table,
      area       TYPE ty_field VALUE 'ZCA_PARAM_AREA',
      definition TYPE ty_field VALUE 'ZCA_PARAM_DEF',
      value      TYPE ty_field VALUE 'ZCA_PARAM_VAL',
    END OF gc_table.
  CONSTANTS:
    BEGIN OF gc_entity,
      area       TYPE ty_field VALUE 'Area',
      definition TYPE ty_field VALUE 'Definition',
      value      TYPE ty_field VALUE 'Value',
    END OF gc_entity.

  "! Authorization object ZCA_PARAM (maintenance only; runtime reads are not checked)
  CONSTANTS:
    BEGIN OF gc_auth,
      object TYPE c LENGTH 10 VALUE 'ZCA_PARAM',
      area   TYPE c LENGTH 10 VALUE 'ZCA_PARAR',
      actvt  TYPE c LENGTH 10 VALUE 'ACTVT',
    END OF gc_auth.
  CONSTANTS:
    BEGIN OF gc_actvt,
      create  TYPE ty_actvt VALUE '01',
      change  TYPE ty_actvt VALUE '02',
      display TYPE ty_actvt VALUE '03',
      delete  TYPE ty_actvt VALUE '06',
    END OF gc_actvt.

  "! Maintenance mode of a client: T = transport (customizing client), L = local
  CONSTANTS:
    BEGIN OF gc_mode,
      transport TYPE ty_mode VALUE 'T',
      local     TYPE ty_mode VALUE 'L',
    END OF gc_mode.

  "! T000-CCCATEGORY production; T000-CCCORACTIV (VERIFY-SE11: fixed values of CCCORACTIV)
  CONSTANTS gc_role_production TYPE ty_role VALUE 'P'.
  CONSTANTS:
    BEGIN OF gc_change_option,
      no_recording  TYPE ty_change_opt VALUE ' ',
      auto_record   TYPE ty_change_opt VALUE '1',
      no_changes    TYPE ty_change_opt VALUE '2',
      no_transports TYPE ty_change_opt VALUE '3',
    END OF gc_change_option.

  "! E070: TRSTATUS modifiable (D) / modifiable, protected (L); TRFUNCTION customizing request (W) / task (Q)
  CONSTANTS:
    BEGIN OF gc_request,
      modifiable          TYPE ty_req_status VALUE 'D',
      protected           TYPE ty_req_status VALUE 'L',
      customizing_request TYPE ty_req_func VALUE 'W',
      customizing_task    TYPE ty_req_func VALUE 'Q',
    END OF gc_request.

ENDINTERFACE.
