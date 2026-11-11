*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_registry.clas.abap
*& Purpose:
*& Pure logic of the link registry (the runtime twin of the offline
*& validator tools/abaptools/link_registry.py): validates the rows of the
*& registry tables - layers and ID prefixes, objects and their key fields,
*& every condition's TABLE-FIELD a declared field of its object, condition
*& kinds, transforms and values, an active link on confirmed fields only,
*& sensitive fields never a constant, cardinality against the object keys,
*& fallback chains (same objects, no cycle) and replacements (lower layer
*& only) - and derives the effective registry the walker follows: links
*& whose layer and own switch are on (activation overrides of a customer
*& layer win), not replaced, valid, as chains of fallbacks per head.
*& No database: ZCL_CA_OPS_LINK_DAO reads the rows.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link registry rules (pure)</p>
"! A fallback runs only after its predecessor ran: a chain stops at its first link that is not
"! effective (a fallback alone would change what the chain means, e.g. a partner found by number
"! without its source).
CLASS zcl_ca_ops_link_registry DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! The effective registry: chains of effective links and the problems that took links out
    CLASS-METHODS effective
      IMPORTING
        is_registry         TYPE zif_ca_ops_link_types=>ty_registry
      RETURNING
        VALUE(rs_effective) TYPE zif_ca_ops_link_types=>ty_effective.

    "! Every problem of the registry rows (empty = valid); the subject is the link or object ID
    CLASS-METHODS validate
      IMPORTING
        is_registry        TYPE zif_ca_ops_link_types=>ty_registry
      RETURNING
        VALUE(rt_problems) TYPE zif_ca_ops_link_types=>tt_problem.

    "! The layer is switched on: its own flag, overridden by an activation row (kind L)
    CLASS-METHODS layer_on
      IMPORTING
        is_registry  TYPE zif_ca_ops_link_types=>ty_registry
        iv_layer_id  TYPE zif_ca_ops_link_types=>ty_layer_id
      RETURNING
        VALUE(rv_on) TYPE abap_bool.

    "! The link is switched on: its layer on, its own flag (overridden by an activation row, kind K)
    "! and no link of a switched-on layer replaces it
    CLASS-METHODS link_on
      IMPORTING
        is_registry  TYPE zif_ca_ops_link_types=>ty_registry
        is_link      TYPE zif_ca_ops_link_types=>ty_link
      RETURNING
        VALUE(rv_on) TYPE abap_bool.

    "! Key fields of an object (upper case, in order)
    CLASS-METHODS key_fields
      IMPORTING
        is_object        TYPE zif_ca_ops_link_types=>ty_object
      RETURNING
        VALUE(rt_fields) TYPE zif_ca_ops_link_types=>tt_fieldname.

    "! Conditions of a link in order
    CLASS-METHODS conds_of
      IMPORTING
        is_registry     TYPE zif_ca_ops_link_types=>ty_registry
        iv_link_id      TYPE zif_ca_ops_link_types=>ty_link_id
      RETURNING
        VALUE(rt_conds) TYPE zif_ca_ops_link_types=>tt_cond.

    "! Sensitivity of a field of an object (blank when the field is not declared)
    CLASS-METHODS sensitivity_of
      IMPORTING
        is_registry           TYPE zif_ca_ops_link_types=>ty_registry
        iv_object_id          TYPE zif_ca_ops_link_types=>ty_object_id
        iv_field              TYPE clike
      RETURNING
        VALUE(rv_sensitivity) TYPE zif_ca_ops_link_types=>ty_flag1.

  PRIVATE SECTION.
    CLASS-METHODS rank_of
      IMPORTING
        is_registry    TYPE zif_ca_ops_link_types=>ty_registry
        iv_layer_id    TYPE zif_ca_ops_link_types=>ty_layer_id
      RETURNING
        VALUE(rv_rank) TYPE i.

    CLASS-METHODS has_prefix
      IMPORTING
        is_registry   TYPE zif_ca_ops_link_types=>ty_registry
        iv_layer_id   TYPE zif_ca_ops_link_types=>ty_layer_id
        iv_id         TYPE clike
      RETURNING
        VALUE(rv_has) TYPE abap_bool.

    CLASS-METHODS add
      IMPORTING
        iv_subject  TYPE clike
        iv_msgno    TYPE zif_ca_ops_types=>ty_msgno
        iv_v1       TYPE clike OPTIONAL
        iv_v2       TYPE clike OPTIONAL
        iv_v3       TYPE clike OPTIONAL
        iv_v4       TYPE clike OPTIONAL
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    CLASS-METHODS validate_objects
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    CLASS-METHODS validate_link
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
        is_link     TYPE zif_ca_ops_link_types=>ty_link
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    "! One condition: kind, value, transform, the references of both sides
    CLASS-METHODS validate_cond
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
        is_link     TYPE zif_ca_ops_link_types=>ty_link
        is_cond     TYPE zif_ca_ops_link_types=>ty_cond
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    "! The reference names the object's source and a declared field of a layer not above the link's
    CLASS-METHODS validate_ref
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
        is_link     TYPE zif_ca_ops_link_types=>ty_link
        iv_ref      TYPE zif_ca_ops_link_types=>ty_field_ref
        iv_object   TYPE zif_ca_ops_link_types=>ty_object_id
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    "! An active link uses confirmed fields only (conditions and the target's keys)
    CLASS-METHODS validate_evidence
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
        is_link     TYPE zif_ca_ops_link_types=>ty_link
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    "! Fallback / replaced link exists and links the same objects; a replaced link is of a lower layer
    CLASS-METHODS validate_relation
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
        is_link     TYPE zif_ca_ops_link_types=>ty_link
        iv_target   TYPE zif_ca_ops_link_types=>ty_link_id
        iv_replace  TYPE abap_bool
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    "! A "to one" link covers the target's keys with EQ / CONST conditions or prefers one row
    CLASS-METHODS validate_cardinality
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
        is_link     TYPE zif_ca_ops_link_types=>ty_link
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

    CLASS-METHODS validate_chains
      IMPORTING
        is_registry TYPE zif_ca_ops_link_types=>ty_registry
      CHANGING
        ct_problems TYPE zif_ca_ops_link_types=>tt_problem.

ENDCLASS.



CLASS zcl_ca_ops_link_registry IMPLEMENTATION.

  METHOD effective.
    DATA lt_bad TYPE SORTED TABLE OF zif_ca_ops_link_types=>ty_link_id WITH UNIQUE KEY table_line.
    DATA lt_on TYPE SORTED TABLE OF zif_ca_ops_link_types=>ty_link_id WITH UNIQUE KEY table_line.

    rs_effective-registry = is_registry.
    rs_effective-problems = validate( is_registry ).
    LOOP AT rs_effective-problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
      INSERT <ls_problem>-subject INTO TABLE lt_bad.
    ENDLOOP.

    LOOP AT is_registry-links ASSIGNING FIELD-SYMBOL(<ls_link>).
      READ TABLE is_registry-objects ASSIGNING FIELD-SYMBOL(<ls_from>) WITH TABLE KEY object_id = <ls_link>-from_object.
      DATA(lv_from_ok) = xsdbool( sy-subrc = 0 ).
      READ TABLE is_registry-objects ASSIGNING FIELD-SYMBOL(<ls_to>) WITH TABLE KEY object_id = <ls_link>-to_object.
      IF lv_from_ok = abap_false OR sy-subrc <> 0
          OR line_exists( lt_bad[ table_line = <ls_link>-link_id ] )
          OR line_exists( lt_bad[ table_line = <ls_link>-from_object ] )
          OR line_exists( lt_bad[ table_line = <ls_link>-to_object ] )
          OR link_on( is_registry = is_registry is_link = <ls_link> ) = abap_false
          OR <ls_from>-active = abap_false OR <ls_to>-active = abap_false
          OR layer_on( is_registry = is_registry iv_layer_id = <ls_from>-layer_id ) = abap_false
          OR layer_on( is_registry = is_registry iv_layer_id = <ls_to>-layer_id ) = abap_false.
        CONTINUE.
      ENDIF.
      INSERT <ls_link>-link_id INTO TABLE lt_on.
    ENDLOOP.

    " Chains: an effective head and its effective fallbacks in order (stop at the first that is not)
    LOOP AT is_registry-links ASSIGNING <ls_link> WHERE fallback_of IS INITIAL.
      IF NOT line_exists( lt_on[ table_line = <ls_link>-link_id ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_chain) = VALUE zif_ca_ops_link_types=>ty_chain( head = <ls_link>-link_id ).
      DATA(lv_current) = <ls_link>-link_id.
      DO lines( is_registry-links ) TIMES.
        INSERT lv_current INTO TABLE ls_chain-links.
        READ TABLE is_registry-links ASSIGNING FIELD-SYMBOL(<ls_next>) WITH KEY fallback_of = lv_current.
        IF sy-subrc <> 0 OR NOT line_exists( lt_on[ table_line = <ls_next>-link_id ] ).
          EXIT.
        ENDIF.
        lv_current = <ls_next>-link_id.
      ENDDO.
      INSERT ls_chain INTO TABLE rs_effective-chains.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate.
    LOOP AT is_registry-layers ASSIGNING FIELD-SYMBOL(<ls_layer>).
      IF <ls_layer>-id_prefix IS INITIAL.
        add( EXPORTING iv_subject = <ls_layer>-layer_id iv_msgno = zif_ca_ops_link_types=>gc_msg-prefix
                       iv_v1 = <ls_layer>-layer_id iv_v2 = <ls_layer>-id_prefix iv_v3 = <ls_layer>-layer_id
             CHANGING ct_problems = rt_problems ).
      ENDIF.
    ENDLOOP.
    validate_objects( EXPORTING is_registry = is_registry CHANGING ct_problems = rt_problems ).
    LOOP AT is_registry-links ASSIGNING FIELD-SYMBOL(<ls_link>).
      validate_link( EXPORTING is_registry = is_registry is_link = <ls_link> CHANGING ct_problems = rt_problems ).
    ENDLOOP.
    validate_chains( EXPORTING is_registry = is_registry CHANGING ct_problems = rt_problems ).
  ENDMETHOD.


  METHOD validate_objects.
    LOOP AT is_registry-objects ASSIGNING FIELD-SYMBOL(<ls_object>).
      IF NOT line_exists( is_registry-layers[ layer_id = <ls_object>-layer_id ] ).
        add( EXPORTING iv_subject = <ls_object>-object_id iv_msgno = zif_ca_ops_link_types=>gc_msg-layer_unknown
                       iv_v1 = <ls_object>-object_id iv_v2 = <ls_object>-layer_id
             CHANGING ct_problems = ct_problems ).
        CONTINUE.
      ENDIF.
      IF has_prefix( is_registry = is_registry iv_layer_id = <ls_object>-layer_id iv_id = <ls_object>-object_id )
          = abap_false.
        add( EXPORTING iv_subject = <ls_object>-object_id iv_msgno = zif_ca_ops_link_types=>gc_msg-prefix
                       iv_v1 = <ls_object>-object_id
                       iv_v2 = is_registry-layers[ layer_id = <ls_object>-layer_id ]-id_prefix
                       iv_v3 = <ls_object>-layer_id
             CHANGING ct_problems = ct_problems ).
      ENDIF.
      DATA(lt_keys) = key_fields( <ls_object> ).
      IF lt_keys IS INITIAL.
        add( EXPORTING iv_subject = <ls_object>-object_id iv_msgno = zif_ca_ops_link_types=>gc_msg-key_invalid
                       iv_v1 = <ls_object>-object_id
             CHANGING ct_problems = ct_problems ).
      ENDIF.
      LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<lv_key>).
        READ TABLE is_registry-fields ASSIGNING FIELD-SYMBOL(<ls_field>)
             WITH TABLE KEY object_id = <ls_object>-object_id field_name = <lv_key>.
        IF sy-subrc <> 0 OR <ls_field>-layer_id <> <ls_object>-layer_id
            OR <ls_field>-sensitivity = zif_ca_ops_link_types=>gc_sensitivity-hidden.
          add( EXPORTING iv_subject = <ls_object>-object_id iv_msgno = zif_ca_ops_link_types=>gc_msg-key_invalid
                         iv_v1 = <ls_object>-object_id iv_v2 = <lv_key>
               CHANGING ct_problems = ct_problems ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_link.
    IF NOT line_exists( is_registry-layers[ layer_id = is_link-layer_id ] ).
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-layer_unknown
                     iv_v1 = is_link-link_id iv_v2 = is_link-layer_id
           CHANGING ct_problems = ct_problems ).
      RETURN.
    ENDIF.
    IF has_prefix( is_registry = is_registry iv_layer_id = is_link-layer_id iv_id = is_link-link_id ) = abap_false.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-prefix
                     iv_v1 = is_link-link_id iv_v2 = is_registry-layers[ layer_id = is_link-layer_id ]-id_prefix
                     iv_v3 = is_link-layer_id
           CHANGING ct_problems = ct_problems ).
    ENDIF.
    DATA(lv_rank) = rank_of( is_registry = is_registry iv_layer_id = is_link-layer_id ).
    DATA(lt_objects) = VALUE zif_ca_ops_link_types=>tt_fieldname( ( is_link-from_object ) ( is_link-to_object ) ).
    LOOP AT lt_objects ASSIGNING FIELD-SYMBOL(<lv_object>).
      READ TABLE is_registry-objects ASSIGNING FIELD-SYMBOL(<ls_object>) WITH TABLE KEY object_id = <lv_object>.
      IF sy-subrc <> 0.
        add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-object_unknown
                       iv_v1 = <lv_object> iv_v2 = is_link-link_id
             CHANGING ct_problems = ct_problems ).
        RETURN.
      ENDIF.
      IF rank_of( is_registry = is_registry iv_layer_id = <ls_object>-layer_id ) > lv_rank.
        add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-higher_layer
                       iv_v1 = is_link-link_id iv_v2 = <lv_object> iv_v3 = <ls_object>-layer_id
             CHANGING ct_problems = ct_problems ).
      ENDIF.
    ENDLOOP.

    DATA(lt_conds) = conds_of( is_registry = is_registry iv_link_id = is_link-link_id ).
    IF NOT line_exists( lt_conds[ cond_kind = zif_ca_ops_link_types=>gc_cond_kind-eq ] ).
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-cond_invalid
                     iv_v1 = is_link-link_id iv_v3 = zif_ca_ops_link_types=>gc_cond_kind-eq
           CHANGING ct_problems = ct_problems ).
    ENDIF.
    LOOP AT lt_conds ASSIGNING FIELD-SYMBOL(<ls_cond>).
      validate_cond( EXPORTING is_registry = is_registry is_link = is_link is_cond = <ls_cond>
                     CHANGING ct_problems = ct_problems ).
    ENDLOOP.
    IF is_link-active = abap_true.
      validate_evidence( EXPORTING is_registry = is_registry is_link = is_link CHANGING ct_problems = ct_problems ).
    ENDIF.
    IF is_link-fallback_of IS NOT INITIAL.
      validate_relation( EXPORTING is_registry = is_registry is_link = is_link iv_target = is_link-fallback_of
                                   iv_replace = abap_false
                         CHANGING ct_problems = ct_problems ).
    ENDIF.
    IF is_link-replaces IS NOT INITIAL.
      validate_relation( EXPORTING is_registry = is_registry is_link = is_link iv_target = is_link-replaces
                                   iv_replace = abap_true
                         CHANGING ct_problems = ct_problems ).
    ENDIF.
    validate_cardinality( EXPORTING is_registry = is_registry is_link = is_link CHANGING ct_problems = ct_problems ).
  ENDMETHOD.


  METHOD validate_cond.
    DATA(lv_complete) = SWITCH abap_bool( is_cond-cond_kind
      WHEN zif_ca_ops_link_types=>gc_cond_kind-eq THEN xsdbool( is_cond-from_ref IS NOT INITIAL )
      WHEN zif_ca_ops_link_types=>gc_cond_kind-const OR zif_ca_ops_link_types=>gc_cond_kind-prefer
        THEN xsdbool( is_cond-cond_value IS NOT INITIAL AND is_cond-from_ref IS INITIAL )
      WHEN zif_ca_ops_link_types=>gc_cond_kind-not_initial
        THEN xsdbool( is_cond-cond_value IS INITIAL AND is_cond-from_ref IS INITIAL )
      ELSE abap_false ).
    IF lv_complete = abap_false OR is_cond-to_ref IS INITIAL.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-cond_invalid
                     iv_v1 = is_link-link_id iv_v2 = is_cond-cond_no iv_v3 = is_cond-cond_kind
           CHANGING ct_problems = ct_problems ).
      RETURN.
    ENDIF.

    IF is_cond-cond_kind = zif_ca_ops_link_types=>gc_cond_kind-eq.
      TRY.
          zcl_ca_ops_link_query=>transform( iv_value     = zif_ca_ops_link_types=>gc_mask_char
                                            iv_transform = is_cond-transform
                                            iv_arg       = is_cond-transform_arg
                                            iv_link_id   = is_link-link_id ).
          IF ( is_cond-transform = zif_ca_ops_link_types=>gc_transform-prefix
               OR is_cond-transform = zif_ca_ops_link_types=>gc_transform-suffix ) AND is_cond-transform_arg IS INITIAL.
            add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-transform
                           iv_v1 = is_link-link_id iv_v2 = is_cond-transform
                 CHANGING ct_problems = ct_problems ).
          ENDIF.
        CATCH zcx_ca_ops_error.
          add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-transform
                         iv_v1 = is_link-link_id iv_v2 = is_cond-transform iv_v3 = is_cond-transform_arg
               CHANGING ct_problems = ct_problems ).
      ENDTRY.
      validate_ref( EXPORTING is_registry = is_registry is_link = is_link iv_ref = is_cond-from_ref
                              iv_object = is_link-from_object
                    CHANGING ct_problems = ct_problems ).
    ELSEIF is_cond-transform IS NOT INITIAL OR is_cond-transform_arg IS NOT INITIAL.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-transform
                     iv_v1 = is_link-link_id iv_v2 = is_cond-transform iv_v3 = is_cond-transform_arg
           CHANGING ct_problems = ct_problems ).
    ENDIF.
    validate_ref( EXPORTING is_registry = is_registry is_link = is_link iv_ref = is_cond-to_ref
                            iv_object = is_link-to_object
                  CHANGING ct_problems = ct_problems ).

    " A member or partner number is never a literal of the configuration
    IF ( is_cond-cond_kind = zif_ca_ops_link_types=>gc_cond_kind-const
         OR is_cond-cond_kind = zif_ca_ops_link_types=>gc_cond_kind-prefer )
        AND sensitivity_of( is_registry = is_registry iv_object_id = is_link-to_object
                            iv_field = zcl_ca_ops_link_query=>split_ref( is_cond-to_ref )-field ) IS NOT INITIAL.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-sensitive
                     iv_v1 = is_link-link_id iv_v2 = is_cond-to_ref
           CHANGING ct_problems = ct_problems ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_ref.
    DATA(ls_ref) = zcl_ca_ops_link_query=>split_ref( iv_ref ).
    DATA(ls_object) = VALUE #( is_registry-objects[ object_id = iv_object ] OPTIONAL ).
    IF ls_ref-source <> to_upper( condense( ls_object-source_name ) ).
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-ref_mismatch
                     iv_v1 = is_link-link_id iv_v2 = iv_ref iv_v3 = iv_object iv_v4 = ls_object-source_name
           CHANGING ct_problems = ct_problems ).
      RETURN.
    ENDIF.
    READ TABLE is_registry-fields ASSIGNING FIELD-SYMBOL(<ls_field>)
         WITH TABLE KEY object_id = iv_object field_name = ls_ref-field.
    IF sy-subrc <> 0.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-field_unknown
                     iv_v1 = is_link-link_id iv_v2 = ls_ref-field iv_v3 = iv_object
           CHANGING ct_problems = ct_problems ).
    ELSEIF rank_of( is_registry = is_registry iv_layer_id = <ls_field>-layer_id )
         > rank_of( is_registry = is_registry iv_layer_id = is_link-layer_id ).
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-higher_layer
                     iv_v1 = is_link-link_id iv_v2 = iv_ref iv_v3 = <ls_field>-layer_id
           CHANGING ct_problems = ct_problems ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_evidence.
    DATA lt_used TYPE SORTED TABLE OF zif_ca_ops_link_types=>ty_field_ref WITH UNIQUE KEY table_line.

    LOOP AT conds_of( is_registry = is_registry iv_link_id = is_link-link_id ) ASSIGNING FIELD-SYMBOL(<ls_cond>).
      INSERT |{ is_link-to_object }/{ zcl_ca_ops_link_query=>split_ref( <ls_cond>-to_ref )-field }| INTO TABLE lt_used.
      IF <ls_cond>-from_ref IS NOT INITIAL.
        INSERT |{ is_link-from_object }/{ zcl_ca_ops_link_query=>split_ref( <ls_cond>-from_ref )-field }|
               INTO TABLE lt_used.
      ENDIF.
    ENDLOOP.
    DATA(ls_target) = VALUE #( is_registry-objects[ object_id = is_link-to_object ] OPTIONAL ).
    LOOP AT key_fields( ls_target ) ASSIGNING FIELD-SYMBOL(<lv_key>).
      INSERT |{ is_link-to_object }/{ <lv_key> }| INTO TABLE lt_used.
    ENDLOOP.
    LOOP AT lt_used ASSIGNING FIELD-SYMBOL(<lv_used>).
      SPLIT <lv_used> AT `/` INTO DATA(lv_object) DATA(lv_field).
      READ TABLE is_registry-fields ASSIGNING FIELD-SYMBOL(<ls_field>)
           WITH TABLE KEY object_id = CONV zif_ca_ops_link_types=>ty_object_id( lv_object )
                          field_name = CONV zif_ca_ops_link_types=>ty_fieldname( lv_field ).
      IF sy-subrc = 0 AND <ls_field>-evidence <> zif_ca_ops_link_types=>gc_evidence-confirmed.
        add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-verify_field
                       iv_v1 = is_link-link_id iv_v2 = |{ <ls_field>-source_name }-{ <ls_field>-field_name }|
                       iv_v3 = <ls_field>-verify_ref
             CHANGING ct_problems = ct_problems ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_relation.
    READ TABLE is_registry-links ASSIGNING FIELD-SYMBOL(<ls_other>) WITH TABLE KEY link_id = iv_target.
    IF sy-subrc <> 0.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-link_unknown
                     iv_v1 = is_link-link_id iv_v2 = iv_target
           CHANGING ct_problems = ct_problems ).
      RETURN.
    ENDIF.
    IF <ls_other>-from_object <> is_link-from_object OR <ls_other>-to_object <> is_link-to_object.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-objects_differ
                     iv_v1 = is_link-link_id iv_v2 = iv_target
           CHANGING ct_problems = ct_problems ).
    ENDIF.
    IF iv_replace = abap_true
        AND rank_of( is_registry = is_registry iv_layer_id = <ls_other>-layer_id )
            >= rank_of( is_registry = is_registry iv_layer_id = is_link-layer_id ).
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-replace
                     iv_v1 = is_link-link_id iv_v2 = iv_target
           CHANGING ct_problems = ct_problems ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_cardinality.
    DATA lt_covered TYPE SORTED TABLE OF zif_ca_ops_link_types=>ty_fieldname WITH UNIQUE KEY table_line.

    IF is_link-cardinality <> zif_ca_ops_link_types=>gc_cardinality-one_one
        AND is_link-cardinality <> zif_ca_ops_link_types=>gc_cardinality-one_many
        AND is_link-cardinality <> zif_ca_ops_link_types=>gc_cardinality-many_one
        AND is_link-cardinality <> zif_ca_ops_link_types=>gc_cardinality-many_many.
      add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-cardinality
                     iv_v1 = is_link-link_id iv_v2 = is_link-cardinality iv_v3 = is_link-to_object
           CHANGING ct_problems = ct_problems ).
      RETURN.
    ENDIF.
    IF is_link-cardinality <> zif_ca_ops_link_types=>gc_cardinality-one_one
        AND is_link-cardinality <> zif_ca_ops_link_types=>gc_cardinality-many_one.
      RETURN.
    ENDIF.
    DATA(lt_conds) = conds_of( is_registry = is_registry iv_link_id = is_link-link_id ).
    IF line_exists( lt_conds[ cond_kind = zif_ca_ops_link_types=>gc_cond_kind-prefer ] ).
      RETURN.
    ENDIF.
    LOOP AT lt_conds ASSIGNING FIELD-SYMBOL(<ls_cond>)
         WHERE cond_kind = zif_ca_ops_link_types=>gc_cond_kind-eq OR cond_kind = zif_ca_ops_link_types=>gc_cond_kind-const.
      INSERT zcl_ca_ops_link_query=>split_ref( <ls_cond>-to_ref )-field INTO TABLE lt_covered.
    ENDLOOP.
    DATA(ls_target) = VALUE #( is_registry-objects[ object_id = is_link-to_object ] OPTIONAL ).
    LOOP AT key_fields( ls_target ) ASSIGNING FIELD-SYMBOL(<lv_key>).
      IF NOT line_exists( lt_covered[ table_line = <lv_key> ] ).
        add( EXPORTING iv_subject = is_link-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-cardinality
                       iv_v1 = is_link-link_id iv_v2 = is_link-cardinality iv_v3 = is_link-to_object
             CHANGING ct_problems = ct_problems ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_chains.
    LOOP AT is_registry-links ASSIGNING FIELD-SYMBOL(<ls_link>) WHERE fallback_of IS NOT INITIAL.
      DATA(lv_current) = <ls_link>-fallback_of.
      DO lines( is_registry-links ) + 1 TIMES.
        IF lv_current = <ls_link>-link_id.
          add( EXPORTING iv_subject = <ls_link>-link_id iv_msgno = zif_ca_ops_link_types=>gc_msg-cycle
                         iv_v1 = <ls_link>-link_id iv_v2 = <ls_link>-fallback_of
               CHANGING ct_problems = ct_problems ).
          EXIT.
        ENDIF.
        READ TABLE is_registry-links ASSIGNING FIELD-SYMBOL(<ls_previous>) WITH TABLE KEY link_id = lv_current.
        IF sy-subrc <> 0 OR <ls_previous>-fallback_of IS INITIAL.
          EXIT.
        ENDIF.
        lv_current = <ls_previous>-fallback_of.
      ENDDO.
    ENDLOOP.
  ENDMETHOD.


  METHOD layer_on.
    READ TABLE is_registry-layers ASSIGNING FIELD-SYMBOL(<ls_layer>) WITH TABLE KEY layer_id = iv_layer_id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv_on = <ls_layer>-active.
    READ TABLE is_registry-activations ASSIGNING FIELD-SYMBOL(<ls_override>)
         WITH TABLE KEY target_kind = zif_ca_ops_link_types=>gc_target_kind-layer target_id = iv_layer_id.
    IF sy-subrc = 0.
      rv_on = <ls_override>-active.
    ENDIF.
  ENDMETHOD.


  METHOD link_on.
    IF layer_on( is_registry = is_registry iv_layer_id = is_link-layer_id ) = abap_false.
      RETURN.
    ENDIF.
    rv_on = is_link-active.
    READ TABLE is_registry-activations ASSIGNING FIELD-SYMBOL(<ls_override>)
         WITH TABLE KEY target_kind = zif_ca_ops_link_types=>gc_target_kind-link target_id = is_link-link_id.
    IF sy-subrc = 0.
      rv_on = <ls_override>-active.
    ENDIF.
    LOOP AT is_registry-links ASSIGNING FIELD-SYMBOL(<ls_other>) WHERE replaces = is_link-link_id.
      IF layer_on( is_registry = is_registry iv_layer_id = <ls_other>-layer_id ) = abap_true.
        rv_on = abap_false.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD key_fields.
    LOOP AT zcl_ca_ops_util=>split_list( is_object-key_fields ) ASSIGNING FIELD-SYMBOL(<lv_key>).
      INSERT CONV zif_ca_ops_link_types=>ty_fieldname( to_upper( <lv_key> ) ) INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD conds_of.
    LOOP AT is_registry-conds ASSIGNING FIELD-SYMBOL(<ls_cond>) WHERE link_id = iv_link_id.
      INSERT <ls_cond> INTO TABLE rt_conds.
    ENDLOOP.
  ENDMETHOD.


  METHOD sensitivity_of.
    READ TABLE is_registry-fields ASSIGNING FIELD-SYMBOL(<ls_field>)
         WITH TABLE KEY object_id = iv_object_id field_name = to_upper( condense( CONV string( iv_field ) ) ).
    IF sy-subrc = 0.
      rv_sensitivity = <ls_field>-sensitivity.
    ENDIF.
  ENDMETHOD.


  METHOD rank_of.
    READ TABLE is_registry-layers ASSIGNING FIELD-SYMBOL(<ls_layer>) WITH TABLE KEY layer_id = iv_layer_id.
    IF sy-subrc = 0.
      rv_rank = <ls_layer>-layer_rank.
    ENDIF.
  ENDMETHOD.


  METHOD has_prefix.
    READ TABLE is_registry-layers ASSIGNING FIELD-SYMBOL(<ls_layer>) WITH TABLE KEY layer_id = iv_layer_id.
    IF sy-subrc <> 0 OR <ls_layer>-id_prefix IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_prefix) = condense( CONV string( <ls_layer>-id_prefix ) ).
    DATA(lv_id) = condense( CONV string( iv_id ) ).
    rv_has = xsdbool( strlen( lv_id ) > strlen( lv_prefix )
                      AND substring( val = lv_id len = strlen( lv_prefix ) ) = lv_prefix ).
  ENDMETHOD.


  METHOD add.
    INSERT VALUE #( subject = iv_subject msgno = iv_msgno v1 = iv_v1 v2 = iv_v2 v3 = iv_v3 v4 = iv_v4 )
           INTO TABLE ct_problems.
  ENDMETHOD.

ENDCLASS.
