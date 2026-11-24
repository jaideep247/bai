*&---------------------------------------------------------------------*
*& Artifact: zif_ca_param_types.intf.abap
*& Purpose:
*& Named types and constants of the parameter framework: keys, values,
*& definitions, value rows, area snapshot, messages, kinds, value types,
*& range signs / options, context of a read, PCRE patterns of the validator
*& and the authorization object.
*& No logic. The message numbers here and the rows in
*& config/zca_param_messages.md are compared by tools/checks.py.
*& Modification log:
*& 2026-11-07 | Initial version.
*& 2026-11-10 | GC_VERSION: release of the framework, read by consumers that need a minimum release.
*& 2026-11-24 | 2.0.0: RAP app removed (maintenance in SM30 / SPRO). PROD_EDITABLE, DEVELOPER_OWNED,
*&            | OWNER, the client / request types and constants and messages 040-048 removed.
*& 2026-11-24 | Context: dimensions DIM1-4 on the definition, CTX1-4 on value rows, TT_CONTEXT of a read,
*&            | messages 026-029.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - types and constants</p>
INTERFACE zif_ca_param_types
  PUBLIC.

  "! Release of the parameter framework (CHANGELOG.md); consumers compare it with the release
  "! they need (e.g. the operations framework ZCA_OPS at startup)
  CONSTANTS gc_version TYPE string VALUE `2.0.0`.

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
  TYPES ty_dimension   TYPE zca_param_dim.
  TYPES ty_ctx_value   TYPE zca_param_ctx.
  TYPES ty_decimal     TYPE decfloat34.
  TYPES ty_actvt       TYPE c LENGTH 2.
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
      "! Context dimensions; DIM1 is the most significant in the access sequence
      dim1            TYPE ty_dimension,
      dim2            TYPE ty_dimension,
      dim3            TYPE ty_dimension,
      dim4            TYPE ty_dimension,
      description     TYPE ty_description,
    END OF ty_definition.
  TYPES tt_definition TYPE SORTED TABLE OF ty_definition WITH UNIQUE KEY area name.

  "! Context of a value row: values of DIM1-4 of the definition (blank = any)
  TYPES:
    BEGIN OF ty_ctx,
      ctx1 TYPE ty_ctx_value,
      ctx2 TYPE ty_ctx_value,
      ctx3 TYPE ty_ctx_value,
      ctx4 TYPE ty_ctx_value,
    END OF ty_ctx.

  "! One value row (ZCA_PARAM_VAL); rows of a parameter and context are ordered by NUMB
  TYPES:
    BEGIN OF ty_value_row,
      area TYPE ty_area,
      name TYPE ty_name,
      ctx1 TYPE ty_ctx_value,
      ctx2 TYPE ty_ctx_value,
      ctx3 TYPE ty_ctx_value,
      ctx4 TYPE ty_ctx_value,
      numb TYPE ty_numb,
      sign TYPE ty_sign,
      opti TYPE ty_option,
      low  TYPE ty_value,
      high TYPE ty_value,
    END OF ty_value_row.
  TYPES tt_value_row TYPE SORTED TABLE OF ty_value_row WITH UNIQUE KEY area name ctx1 ctx2 ctx3 ctx4 numb.

  "! Context of a read: the caller's facts by dimension name (e.g. SOURCE = SRC_A). A caller
  "! passes every fact it knows; each definition uses only the dimensions it declares.
  TYPES:
    BEGIN OF ty_context_line,
      dim   TYPE ty_dimension,
      value TYPE ty_ctx_value,
    END OF ty_context_line.
  TYPES tt_context TYPE STANDARD TABLE OF ty_context_line WITH EMPTY KEY.

  "! Context a read uses (initial = general rows or default) and its number of value rows
  TYPES:
    BEGIN OF ty_effective,
      context TYPE ty_ctx,
      rows    TYPE i,
    END OF ty_effective.

  "! Everything of one area, read in one go by the DAO
  TYPES:
    BEGIN OF ty_area_data,
      found       TYPE abap_bool,
      area        TYPE ty_area_row,
      definitions TYPE tt_definition,
      values      TYPE tt_value_row,
    END OF ty_area_data.

  "! A message of class ZCA_PARAM (msgno initial = no message); field = the field it refers to
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
      ctx_not_declared   TYPE symsgno VALUE '026',
      ctx_lower_case     TYPE symsgno VALUE '027',
      dim_invalid        TYPE symsgno VALUE '028',
      dim_sequence       TYPE symsgno VALUE '029',
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
      dec        TYPE string VALUE `^[+-]?[0-9]+([.][0-9]+)?$`,
      date       TYPE string VALUE `^[0-9]{8}$`,
      time       TYPE string VALUE `^([01][0-9]|2[0-3])[0-5][0-9][0-5][0-9]$`,
      repository TYPE string VALUE `^(/[A-Z0-9_]+/)?[A-Z0-9_]+$`,
      separator  TYPE string VALUE `[,;]`,
    END OF gc_pcre.

  "! Number of context dimensions of a definition (DIM1-4 / CTX1-4)
  CONSTANTS gc_max_dims TYPE i VALUE 4.

  "! Bounds of value type INT (ABAP type i)
  CONSTANTS gc_int_min TYPE ty_decimal VALUE '-2147483648'.
  CONSTANTS gc_int_max TYPE ty_decimal VALUE '2147483647'.

  "! Field a validation message refers to (upper case, no underscore)
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
      dim            TYPE ty_field VALUE 'DIM',
      ctx            TYPE ty_field VALUE 'CTX',
    END OF gc_field.

  "! Authorization object ZCA_PARAM (optional, for a maintenance check per area; runtime reads are not checked)
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

ENDINTERFACE.
