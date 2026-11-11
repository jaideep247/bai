*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_link_types.intf.abap
*& Purpose:
*& Types and constants of the link registry of the operations framework
*& (docs/LINK_REGISTRY.md): layers (product baseline, industry package,
*& customer overlay), business objects and their fields, links with their
*& conditions, activation overrides (tables ZCA_OPS_LNKLYR, _LNKOBJ,
*& _LNKFLD, _LINK, _LNKCND, _LNKACT), the problems of a validation, the
*& request and result of a walk (nodes with key, path and evidence
*& quality), parameters (prefix LINK_, area CA_OPS) and messages 210-239
*& of ZCA_OPS. No logic.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link registry types</p>
INTERFACE zif_ca_ops_link_types
  PUBLIC.

  TYPES ty_layer_id    TYPE c LENGTH 10.
  TYPES ty_object_id   TYPE c LENGTH 30.
  TYPES ty_link_id     TYPE c LENGTH 30.
  TYPES ty_fieldname   TYPE c LENGTH 30.
  TYPES ty_source      TYPE c LENGTH 30.
  TYPES ty_field_ref   TYPE c LENGTH 61.
  TYPES ty_value       TYPE c LENGTH 70.
  TYPES ty_cond_kind   TYPE c LENGTH 8.
  TYPES ty_transform   TYPE c LENGTH 6.
  TYPES ty_arg         TYPE c LENGTH 20.
  TYPES ty_cardinality TYPE c LENGTH 2.
  TYPES ty_flag1       TYPE c LENGTH 1.
  TYPES ty_text        TYPE c LENGTH 60.
  TYPES ty_owner       TYPE c LENGTH 30.
  TYPES ty_verify      TYPE c LENGTH 20.
  TYPES ty_key_list    TYPE c LENGTH 255.
  TYPES ty_cond_no     TYPE n LENGTH 3.
  "! A key or field value as the walker carries it (character form of the database value)
  TYPES ty_key_value   TYPE c LENGTH 70.

  CONSTANTS:
    BEGIN OF gc_layer_kind,
      standard TYPE ty_flag1 VALUE 'S',
      industry TYPE ty_flag1 VALUE 'I',
      customer TYPE ty_flag1 VALUE 'C',
    END OF gc_layer_kind.

  CONSTANTS:
    BEGIN OF gc_source_kind,
      table TYPE ty_flag1 VALUE 'T',
      view  TYPE ty_flag1 VALUE 'V',
    END OF gc_source_kind.

  "! EQ to = from (transformed); CONST to = value (comma list = IN); NOTINIT to filled; PREFER keep the rows
  "! with to = value when a source row found several (never "the highest counter")
  CONSTANTS:
    BEGIN OF gc_cond_kind,
      eq          TYPE ty_cond_kind VALUE 'EQ',
      const       TYPE ty_cond_kind VALUE 'CONST',
      not_initial TYPE ty_cond_kind VALUE 'NOTINIT',
      prefer      TYPE ty_cond_kind VALUE 'PREFER',
    END OF gc_cond_kind.

  "! Applied to the from value of an EQ condition
  CONSTANTS:
    BEGIN OF gc_transform,
      none     TYPE ty_transform VALUE '',
      alpha    TYPE ty_transform VALUE 'ALPHA',
      no_zeros TYPE ty_transform VALUE 'NOZERO',
      upper    TYPE ty_transform VALUE 'UPPER',
      left     TYPE ty_transform VALUE 'LEFT',
      right    TYPE ty_transform VALUE 'RIGHT',
      prefix   TYPE ty_transform VALUE 'PREFIX',
      suffix   TYPE ty_transform VALUE 'SUFFIX',
    END OF gc_transform.

  CONSTANTS:
    BEGIN OF gc_cardinality,
      one_one   TYPE ty_cardinality VALUE '11',
      one_many  TYPE ty_cardinality VALUE '1N',
      many_one  TYPE ty_cardinality VALUE 'N1',
      many_many TYPE ty_cardinality VALUE 'NM',
    END OF gc_cardinality.

  "! Evidence quality of a link and of a node of a walk (P as soon as one link of the path is P)
  CONSTANTS:
    BEGIN OF gc_quality,
      confirmed TYPE ty_flag1 VALUE 'C',
      probable  TYPE ty_flag1 VALUE 'P',
    END OF gc_quality.

  "! Evidence of a field name: C confirmed, V VERIFY (an active link uses confirmed fields only)
  CONSTANTS:
    BEGIN OF gc_evidence,
      confirmed TYPE ty_flag1 VALUE 'C',
      verify    TYPE ty_flag1 VALUE 'V',
    END OF gc_evidence.

  "! Blank none, M masked (last four characters shown), H hidden (never shown, never a key)
  CONSTANTS:
    BEGIN OF gc_sensitivity,
      none   TYPE ty_flag1 VALUE ' ',
      masked TYPE ty_flag1 VALUE 'M',
      hidden TYPE ty_flag1 VALUE 'H',
    END OF gc_sensitivity.

  "! Target of an activation override: a layer or a link of a lower layer
  CONSTANTS:
    BEGIN OF gc_target_kind,
      layer TYPE ty_flag1 VALUE 'L',
      link  TYPE ty_flag1 VALUE 'K',
    END OF gc_target_kind.

  "! Visible characters of a masked value (the end of it), the mask character and the separators
  CONSTANTS gc_mask_visible TYPE i VALUE 4.
  CONSTANTS gc_mask_char TYPE c LENGTH 1 VALUE '*'.
  CONSTANTS gc_ref_separator TYPE c LENGTH 1 VALUE '-'.
  CONSTANTS gc_list_separator TYPE c LENGTH 1 VALUE ','.

  "! Parameters (area CA_OPS, prefix LINK_)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Levels a walk follows from its start object
      max_depth  TYPE zif_ca_ops_types=>ty_param_name VALUE 'LINK_MAX_DEPTH',
      "! Rows one read of a link returns at most (breadth per link and level)
      max_rows   TYPE zif_ca_ops_types=>ty_param_name VALUE 'LINK_MAX_ROWS',
      "! Objects (nodes) of one walk at most
      max_nodes  TYPE zif_ca_ops_types=>ty_param_name VALUE 'LINK_MAX_NODES',
      "! Source rows (key tuples) per database read (IN list / OR groups)
      read_chunk TYPE zif_ca_ops_types=>ty_param_name VALUE 'LINK_READ_CHUNK',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_default,
      max_depth  TYPE i VALUE 4,
      max_rows   TYPE i VALUE 100,
      max_nodes  TYPE i VALUE 500,
      read_chunk TYPE i VALUE 100,
    END OF gc_default.

  "! Messages of ZCA_OPS (210-239)
  CONSTANTS:
    BEGIN OF gc_msg,
      object_unknown   TYPE zif_ca_ops_types=>ty_msgno VALUE '210',
      key_missing      TYPE zif_ca_ops_types=>ty_msgno VALUE '211',
      not_approved     TYPE zif_ca_ops_types=>ty_msgno VALUE '212',
      field_unknown    TYPE zif_ca_ops_types=>ty_msgno VALUE '213',
      cond_invalid     TYPE zif_ca_ops_types=>ty_msgno VALUE '214',
      transform        TYPE zif_ca_ops_types=>ty_msgno VALUE '215',
      cycle            TYPE zif_ca_ops_types=>ty_msgno VALUE '216',
      cardinality      TYPE zif_ca_ops_types=>ty_msgno VALUE '217',
      verify_field     TYPE zif_ca_ops_types=>ty_msgno VALUE '218',
      walk_depth       TYPE zif_ca_ops_types=>ty_msgno VALUE '219',
      walk_nodes       TYPE zif_ca_ops_types=>ty_msgno VALUE '220',
      walk_rows        TYPE zif_ca_ops_types=>ty_msgno VALUE '221',
      read_failed      TYPE zif_ca_ops_types=>ty_msgno VALUE '222',
      sensitive        TYPE zif_ca_ops_types=>ty_msgno VALUE '223',
      replace          TYPE zif_ca_ops_types=>ty_msgno VALUE '224',
      higher_layer     TYPE zif_ca_ops_types=>ty_msgno VALUE '226',
      value_invalid    TYPE zif_ca_ops_types=>ty_msgno VALUE '227',
      summary          TYPE zif_ca_ops_types=>ty_msgno VALUE '228',
      link_unknown     TYPE zif_ca_ops_types=>ty_msgno VALUE '229',
      objects_differ   TYPE zif_ca_ops_types=>ty_msgno VALUE '230',
      prefix           TYPE zif_ca_ops_types=>ty_msgno VALUE '231',
      key_invalid      TYPE zif_ca_ops_types=>ty_msgno VALUE '232',
      layer_unknown    TYPE zif_ca_ops_types=>ty_msgno VALUE '233',
      ref_mismatch     TYPE zif_ca_ops_types=>ty_msgno VALUE '234',
    END OF gc_msg.

  "! Findings of the registry check ZCL_CA_OPS_CHK_LINKS: object type, rule ID and check codes
  CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'LINK'.
  CONSTANTS gc_rule_id TYPE zif_ca_ops_types=>ty_rule_id VALUE 'LINKS'.
  CONSTANTS:
    BEGIN OF gc_code,
      "! A row of the registry breaks a rule (the link or object is left out of every walk)
      problem TYPE zif_ca_ops_types=>ty_check_code VALUE 'LINK_REGISTRY',
      "! A declared field is not in the runtime DDIC of its source (or the source is unknown)
      ddic    TYPE zif_ca_ops_types=>ty_check_code VALUE 'LINK_DDIC',
      "! Summary of the registry (effective links, problems)
      summary TYPE zif_ca_ops_types=>ty_check_code VALUE 'LINK_SUMMARY',
    END OF gc_code.

  "! Rows of the registry tables (fields as in the DDIC, without client and administrative fields)
  TYPES:
    BEGIN OF ty_layer,
      layer_id    TYPE ty_layer_id,
      layer_kind  TYPE ty_flag1,
      layer_rank  TYPE i,
      id_prefix   TYPE ty_layer_id,
      description TYPE ty_text,
      owner       TYPE ty_owner,
      active      TYPE abap_bool,
    END OF ty_layer.
  TYPES tt_layer TYPE SORTED TABLE OF ty_layer WITH UNIQUE KEY layer_id.

  TYPES:
    BEGIN OF ty_object,
      object_id   TYPE ty_object_id,
      layer_id    TYPE ty_layer_id,
      source_name TYPE ty_source,
      source_kind TYPE ty_flag1,
      key_fields  TYPE ty_key_list,
      description TYPE ty_text,
      active      TYPE abap_bool,
    END OF ty_object.
  TYPES tt_object TYPE SORTED TABLE OF ty_object WITH UNIQUE KEY object_id.

  TYPES:
    BEGIN OF ty_field,
      object_id    TYPE ty_object_id,
      field_name   TYPE ty_fieldname,
      layer_id     TYPE ty_layer_id,
      source_name  TYPE ty_source,
      data_element TYPE ty_fieldname,
      sensitivity  TYPE ty_flag1,
      evidence     TYPE ty_flag1,
      verify_ref   TYPE ty_verify,
      description  TYPE ty_text,
    END OF ty_field.
  TYPES tt_field TYPE SORTED TABLE OF ty_field WITH UNIQUE KEY object_id field_name.

  TYPES:
    BEGIN OF ty_link,
      link_id     TYPE ty_link_id,
      layer_id    TYPE ty_layer_id,
      from_object TYPE ty_object_id,
      to_object   TYPE ty_object_id,
      cardinality TYPE ty_cardinality,
      quality     TYPE ty_flag1,
      fallback_of TYPE ty_link_id,
      replaces    TYPE ty_link_id,
      active      TYPE abap_bool,
      owner       TYPE ty_owner,
      verify_ref  TYPE ty_verify,
      description TYPE ty_text,
    END OF ty_link.
  TYPES tt_link TYPE SORTED TABLE OF ty_link WITH UNIQUE KEY link_id.

  TYPES:
    BEGIN OF ty_cond,
      link_id       TYPE ty_link_id,
      cond_no       TYPE ty_cond_no,
      cond_kind     TYPE ty_cond_kind,
      from_ref      TYPE ty_field_ref,
      to_ref        TYPE ty_field_ref,
      cond_value    TYPE ty_value,
      transform     TYPE ty_transform,
      transform_arg TYPE ty_arg,
    END OF ty_cond.
  TYPES tt_cond TYPE SORTED TABLE OF ty_cond WITH UNIQUE KEY link_id cond_no.

  TYPES:
    BEGIN OF ty_activation,
      target_kind TYPE ty_flag1,
      target_id   TYPE ty_object_id,
      layer_id    TYPE ty_layer_id,
      active      TYPE abap_bool,
      reason      TYPE ty_text,
      owner       TYPE ty_owner,
    END OF ty_activation.
  TYPES tt_activation TYPE SORTED TABLE OF ty_activation WITH UNIQUE KEY target_kind target_id.

  "! The whole registry as read from the tables
  TYPES:
    BEGIN OF ty_registry,
      layers      TYPE tt_layer,
      objects     TYPE tt_object,
      fields      TYPE tt_field,
      links       TYPE tt_link,
      conds       TYPE tt_cond,
      activations TYPE tt_activation,
    END OF ty_registry.

  "! One problem of a validation (message of ZCA_OPS with its variables; the subject is a link or object ID)
  TYPES:
    BEGIN OF ty_problem,
      subject TYPE ty_link_id,
      msgno   TYPE zif_ca_ops_types=>ty_msgno,
      v1      TYPE ty_key_value,
      v2      TYPE ty_key_value,
      v3      TYPE ty_key_value,
      v4      TYPE ty_key_value,
    END OF ty_problem.
  TYPES tt_problem TYPE STANDARD TABLE OF ty_problem WITH EMPTY KEY.

  TYPES tt_fieldname TYPE STANDARD TABLE OF ty_fieldname WITH EMPTY KEY.
  TYPES tt_link_id TYPE STANDARD TABLE OF ty_link_id WITH EMPTY KEY.

  "! A chain of links tried in order (the head and its fallbacks; only effective links)
  TYPES:
    BEGIN OF ty_chain,
      head  TYPE ty_link_id,
      links TYPE tt_link_id,
    END OF ty_chain.
  TYPES tt_chain TYPE STANDARD TABLE OF ty_chain WITH EMPTY KEY.

  "! The registry as the walker uses it: effective links (layer and link switched on, not replaced,
  "! valid) as chains per from object, and the problems that took links out
  TYPES:
    BEGIN OF ty_effective,
      registry TYPE ty_registry,
      chains   TYPE tt_chain,
      problems TYPE tt_problem,
    END OF ty_effective.

  "! A field and its value (a key of a node, or a field a link reads)
  TYPES:
    BEGIN OF ty_pair,
      fieldname TYPE ty_fieldname,
      value     TYPE ty_key_value,
    END OF ty_pair.
  TYPES tt_pair TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY.

  "! A row read from a source: its fields and values
  TYPES:
    BEGIN OF ty_row,
      pairs TYPE tt_pair,
    END OF ty_row.
  TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

  "! The validated read of one link: built only from registry names checked against the runtime DDIC
  "! and literals quoted by CL_ABAP_DYN_PRG
  TYPES:
    BEGIN OF ty_query,
      source       TYPE ty_source,
      select_list  TYPE string,
      where_clause TYPE string,
      fields       TYPE tt_fieldname,
    END OF ty_query.

  "! Start of a walk
  TYPES:
    BEGIN OF ty_request,
      "! Area whose approved tables (ZCA_OPS_TABWL) the walk may read; display authorisation ZCA_OPS 03
      area      TYPE zif_ca_ops_types=>ty_area,
      object_id TYPE ty_object_id,
      "! Values of the key fields of the start object
      keys      TYPE tt_pair,
      "! 0 = parameter LINK_MAX_DEPTH
      max_depth TYPE i,
      "! Only these links (blank = every effective link)
      links     TYPE tt_link_id,
    END OF ty_request.

  "! An object reached by a walk
  TYPES:
    BEGIN OF ty_node,
      node_id   TYPE i,
      parent_id TYPE i,
      depth     TYPE i,
      object_id TYPE ty_object_id,
      "! Key of the row, sensitive fields masked
      keys      TYPE tt_pair,
      "! Link that reached it (blank for the start) and its position in its fallback chain (1 = head)
      link_id   TYPE ty_link_id,
      step      TYPE i,
      "! C when every link of the path is confirmed, else P
      quality   TYPE ty_flag1,
      "! Start object -LINK-> object ... (IDs only)
      path      TYPE string,
    END OF ty_node.
  TYPES tt_node TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_result,
      nodes     TYPE tt_node,
      "! A limit stopped the walk (depth, nodes or rows of a read)
      truncated TYPE abap_bool,
      "! Messages of the walk: limits, links skipped (invalid, not approved, read failed)
      problems  TYPE tt_problem,
    END OF ty_result.

ENDINTERFACE.
