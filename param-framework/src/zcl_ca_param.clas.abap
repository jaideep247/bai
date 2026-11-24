*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param.clas.abap
*& Purpose:
*& The semantics of the parameter framework (ZIF_CA_PARAM), in one place:
*& resolution of a parameter (context / value rows / default / mandatory), the kind
*& and value type rules of every getter, validation of every row and of
*& the default on every read (ZCL_CA_PARAM_VALIDATOR) and the per-area
*& buffer (HASHED by area; one DAO read per area until refresh). Every
*& failure raises ZCX_CA_PARAM. The DAO is injected: production uses
*& ZCL_CA_PARAM_DAO (ZCL_CA_PARAM_FACTORY), tests ZCL_CA_PARAM_DAO_MEM - so
*& tests run exactly this logic. No SQL, no authorization check (runtime
*& reads are free for batch users), no maintenance.
*& Modification log:
*& 2026-11-07 | Initial version.
*& 2026-11-10 | RAISE keeps the caught conversion error as PREVIOUS (exception chain).
*& 2026-11-10 | CHECK_AREA (area registered and active, through the area buffer).
*& 2026-11-24 | Context: access sequence over the dimensions of the definition (most specific
*&            | context with rows wins, all rows from that one context); every row of every
*&            | context validated on every read; GET_EFFECTIVE_CONTEXT.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - read logic and buffer</p>
CLASS zcl_ca_param DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_param.

    "! @parameter io_dao | Data access (database or in memory)
    "! @parameter io_validator | Validation rules (default: a new ZCL_CA_PARAM_VALIDATOR)
    METHODS constructor
      IMPORTING
        io_dao       TYPE REF TO zif_ca_param_dao
        io_validator TYPE REF TO zcl_ca_param_validator OPTIONAL.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_buffer,
        area TYPE zif_ca_param_types=>ty_area,
        data TYPE zif_ca_param_types=>ty_area_data,
      END OF ty_buffer.
    TYPES tt_buffer TYPE HASHED TABLE OF ty_buffer WITH UNIQUE KEY area.
    TYPES ty_ctx_list TYPE STANDARD TABLE OF zif_ca_param_types=>ty_ctx WITH EMPTY KEY.

    "! A parameter resolved for one read: definition, the rows of the context used (NUMB order),
    "! the rows of every context (validation), the context used and the effective value
    TYPES:
      BEGIN OF ty_resolved,
        definition TYPE zif_ca_param_types=>ty_definition,
        rows       TYPE zif_ca_param_types=>tt_value_row,
        all_rows   TYPE zif_ca_param_types=>tt_value_row,
        context    TYPE zif_ca_param_types=>ty_ctx,
        value      TYPE zif_ca_param_types=>ty_value,
      END OF ty_resolved.

    DATA mo_dao       TYPE REF TO zif_ca_param_dao.
    DATA mo_validator TYPE REF TO zcl_ca_param_validator.
    DATA mt_buffer    TYPE tt_buffer.

    "! Buffered snapshot of an active area
    METHODS area_data
      IMPORTING
        iv_area        TYPE zif_ca_param_types=>ty_area
      RETURNING
        VALUE(rr_data) TYPE REF TO zif_ca_param_types=>ty_area_data
      RAISING
        zcx_ca_param.

    "! Definition, rows of every context and the rows of the context the read uses, without validation
    METHODS lookup
      IMPORTING
        iv_area            TYPE zif_ca_param_types=>ty_area
        iv_name            TYPE zif_ca_param_types=>ty_name
        it_context         TYPE zif_ca_param_types=>tt_context OPTIONAL
      RETURNING
        VALUE(rs_resolved) TYPE ty_resolved
      RAISING
        zcx_ca_param.

    "! Definition, validated rows and effective value (single value or default)
    METHODS resolve
      IMPORTING
        iv_area            TYPE zif_ca_param_types=>ty_area
        iv_name            TYPE zif_ca_param_types=>ty_name
        it_context         TYPE zif_ca_param_types=>tt_context OPTIONAL
      RETURNING
        VALUE(rs_resolved) TYPE ty_resolved
      RAISING
        zcx_ca_param.

    "! resolve for a single-value read: kind P and one of the value types (blank = any)
    METHODS resolve_single
      IMPORTING
        iv_area            TYPE zif_ca_param_types=>ty_area
        iv_name            TYPE zif_ca_param_types=>ty_name
        it_context         TYPE zif_ca_param_types=>tt_context OPTIONAL
        iv_read_as         TYPE zif_ca_param_types=>ty_value_type
        iv_type_1          TYPE zif_ca_param_types=>ty_value_type OPTIONAL
        iv_type_2          TYPE zif_ca_param_types=>ty_value_type OPTIONAL
        iv_value_required  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_resolved) TYPE ty_resolved
      RAISING
        zcx_ca_param.

    "! Context values of the read in the positions of the definition's dimensions (upper case);
    "! facts for dimensions the definition does not declare are ignored
    METHODS context_key
      IMPORTING
        is_definition TYPE zif_ca_param_types=>ty_definition
        it_context    TYPE zif_ca_param_types=>tt_context
      RETURNING
        VALUE(rs_key) TYPE zif_ca_param_types=>ty_ctx.

    "! Number of declared dimensions (DIM1 .. DIMn; the validator rejects gaps)
    METHODS dimension_count
      IMPORTING
        is_definition   TYPE zif_ca_param_types=>ty_definition
      RETURNING
        VALUE(rv_count) TYPE i.

    "! Access sequence: the candidate contexts of a read, most specific first. With n dimensions
    "! there are 2**n combinations of 'the read's value' / 'any' per dimension; DIM1 is the most
    "! significant. A combination that needs a value the read did not supply is left out.
    METHODS candidates
      IMPORTING
        is_key           TYPE zif_ca_param_types=>ty_ctx
        iv_dims          TYPE i
      RETURNING
        VALUE(rt_result) TYPE ty_ctx_list.

    "! Rows of one context
    METHODS rows_of_context
      IMPORTING
        it_rows        TYPE zif_ca_param_types=>tt_value_row
        is_context     TYPE zif_ca_param_types=>ty_ctx
      RETURNING
        VALUE(rt_rows) TYPE zif_ca_param_types=>tt_value_row.

    "! Number of a validated INT / DEC value; a conversion error raises 006, never a dump
    METHODS to_number
      IMPORTING
        is_resolved     TYPE ty_resolved
      RETURNING
        VALUE(rv_value) TYPE zif_ca_param_types=>ty_decimal
      RAISING
        zcx_ca_param.

    METHODS raise
      IMPORTING
        is_definition TYPE zif_ca_param_types=>ty_definition
        iv_msgno      TYPE symsgno
        iv_v3         TYPE csequence OPTIONAL
        iv_v4         TYPE csequence OPTIONAL
        ix_previous   TYPE REF TO cx_root OPTIONAL
      RAISING
        zcx_ca_param.

    METHODS raise_if
      IMPORTING
        is_message TYPE zif_ca_param_types=>ty_message
      RAISING
        zcx_ca_param.

ENDCLASS.



CLASS zcl_ca_param IMPLEMENTATION.

  METHOD constructor.
    mo_dao       = io_dao.
    mo_validator = COND #( WHEN io_validator IS BOUND THEN io_validator ELSE NEW #( ) ).
  ENDMETHOD.


  METHOD zif_ca_param~get_value.
    rv_value = resolve_single( iv_area    = iv_area
                               iv_name    = iv_name
                               it_context = it_context
                               iv_read_as = zif_ca_param_types=>gc_read_as-value )-value.
  ENDMETHOD.


  METHOD zif_ca_param~get_int.
    " validated as INT within type i, so the conversion of the decimal cannot overflow
    rv_value = to_number( resolve_single( iv_area           = iv_area
                                          iv_name           = iv_name
                                          it_context        = it_context
                                          iv_read_as        = zif_ca_param_types=>gc_value_type-int
                                          iv_type_1         = zif_ca_param_types=>gc_value_type-int
                                          iv_value_required = abap_true ) ).
  ENDMETHOD.


  METHOD zif_ca_param~get_dec.
    rv_value = to_number( resolve_single( iv_area           = iv_area
                                          iv_name           = iv_name
                                          it_context        = it_context
                                          iv_read_as        = zif_ca_param_types=>gc_value_type-dec
                                          iv_type_1         = zif_ca_param_types=>gc_value_type-dec
                                          iv_type_2         = zif_ca_param_types=>gc_value_type-int
                                          iv_value_required = abap_true ) ).
  ENDMETHOD.


  METHOD zif_ca_param~get_bool.
    " blank is a value for BOOL: explicit off (row with blank LOW) or default blank
    rv_value = xsdbool( resolve_single( iv_area    = iv_area
                                        iv_name    = iv_name
                                        it_context = it_context
                                        iv_read_as = zif_ca_param_types=>gc_value_type-bool
                                        iv_type_1  = zif_ca_param_types=>gc_value_type-bool )-value
                        = zif_ca_param_types=>gc_true ).
  ENDMETHOD.


  METHOD zif_ca_param~get_date.
    rv_value = condense( CONV string( resolve_single( iv_area           = iv_area
                                                      iv_name           = iv_name
                                                      it_context        = it_context
                                                      iv_read_as        = zif_ca_param_types=>gc_value_type-date
                                                      iv_type_1         = zif_ca_param_types=>gc_value_type-date
                                                      iv_value_required = abap_true )-value ) ).
  ENDMETHOD.


  METHOD zif_ca_param~get_time.
    rv_value = condense( CONV string( resolve_single( iv_area           = iv_area
                                                      iv_name           = iv_name
                                                      it_context        = it_context
                                                      iv_read_as        = zif_ca_param_types=>gc_value_type-time
                                                      iv_type_1         = zif_ca_param_types=>gc_value_type-time
                                                      iv_value_required = abap_true )-value ) ).
  ENDMETHOD.


  METHOD zif_ca_param~get_list.
    DATA(ls_resolved) = resolve( iv_area    = iv_area
                                 iv_name    = iv_name
                                 it_context = it_context ).
    CASE ls_resolved-definition-kind.
      WHEN zif_ca_param_types=>gc_kind-single.
        IF ls_resolved-definition-value_type <> zif_ca_param_types=>gc_value_type-list.
          raise( is_definition = ls_resolved-definition
                 iv_msgno      = zif_ca_param_types=>gc_msg-type_mismatch
                 iv_v3         = ls_resolved-definition-value_type
                 iv_v4         = zif_ca_param_types=>gc_value_type-list ).
        ENDIF.
        rt_list = mo_validator->split_list( ls_resolved-value ).
      WHEN OTHERS.
        IF ls_resolved-rows IS INITIAL AND ls_resolved-value IS NOT INITIAL.
          " nothing maintained: the default is the only element
          INSERT CONV string( ls_resolved-value ) INTO TABLE rt_list.
          RETURN.
        ENDIF.
        LOOP AT ls_resolved-rows ASSIGNING FIELD-SYMBOL(<ls_row>).
          IF <ls_row>-sign <> zif_ca_param_types=>gc_sign-include OR <ls_row>-opti <> zif_ca_param_types=>gc_option-eq.
            raise( is_definition = ls_resolved-definition
                   iv_msgno      = zif_ca_param_types=>gc_msg-row_not_list
                   iv_v3         = <ls_row>-numb
                   iv_v4         = |{ <ls_row>-sign } { <ls_row>-opti }| ).
          ENDIF.
          INSERT CONV string( <ls_row>-low ) INTO TABLE rt_list.
        ENDLOOP.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_ca_param~get_range.
    DATA(ls_resolved) = resolve( iv_area    = iv_area
                                 iv_name    = iv_name
                                 it_context = it_context ).
    IF ls_resolved-definition-kind <> zif_ca_param_types=>gc_kind-select.
      raise( is_definition = ls_resolved-definition
             iv_msgno      = zif_ca_param_types=>gc_msg-kind_mismatch
             iv_v3         = ls_resolved-definition-kind
             iv_v4         = zif_ca_param_types=>gc_read_as-range ).
    ENDIF.
    IF ls_resolved-rows IS INITIAL AND ls_resolved-value IS NOT INITIAL.
      INSERT VALUE #( sign   = zif_ca_param_types=>gc_sign-include
                      option = zif_ca_param_types=>gc_option-eq
                      low    = ls_resolved-value ) INTO TABLE rt_range.
      RETURN.
    ENDIF.
    LOOP AT ls_resolved-rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( sign   = <ls_row>-sign
                      option = <ls_row>-opti
                      low    = <ls_row>-low
                      high   = <ls_row>-high ) INTO TABLE rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_param~is_set.
    rv_set = xsdbool( lookup( iv_area    = iv_area
                              iv_name    = iv_name
                              it_context = it_context )-rows IS NOT INITIAL ).
  ENDMETHOD.


  METHOD zif_ca_param~get_effective_context.
    DATA(ls_resolved) = lookup( iv_area    = iv_area
                                iv_name    = iv_name
                                it_context = it_context ).
    rs_effective = VALUE #( context = ls_resolved-context
                            rows    = lines( ls_resolved-rows ) ).
  ENDMETHOD.


  METHOD zif_ca_param~get_definition.
    rs_definition = lookup( iv_area = iv_area
                            iv_name = iv_name )-definition.
  ENDMETHOD.


  METHOD zif_ca_param~check_area.
    area_data( iv_area ).
  ENDMETHOD.


  METHOD zif_ca_param~refresh.
    IF iv_area IS INITIAL.
      CLEAR mt_buffer.
    ELSE.
      DATA(lv_area) = CONV zif_ca_param_types=>ty_area( to_upper( iv_area ) ).
      DELETE TABLE mt_buffer WITH TABLE KEY area = lv_area.
    ENDIF.
  ENDMETHOD.


  METHOD area_data.
    DATA ls_definition TYPE zif_ca_param_types=>ty_definition.

    DATA(lv_area) = CONV zif_ca_param_types=>ty_area( to_upper( iv_area ) ).
    ls_definition-area = lv_area.
    READ TABLE mt_buffer REFERENCE INTO DATA(lr_entry) WITH TABLE KEY area = lv_area.
    IF sy-subrc <> 0.
      DATA(ls_data) = mo_dao->read_area( lv_area ).
      IF ls_data-found = abap_false.
        " not buffered: an area created later is seen without refresh
        raise( is_definition = ls_definition
               iv_msgno      = zif_ca_param_types=>gc_msg-area_unknown ).
      ENDIF.
      INSERT VALUE #( area = lv_area
                      data = ls_data ) INTO TABLE mt_buffer REFERENCE INTO lr_entry.
    ENDIF.
    IF lr_entry->data-area-active = abap_false.
      raise( is_definition = ls_definition
             iv_msgno      = zif_ca_param_types=>gc_msg-area_inactive ).
    ENDIF.
    rr_data = REF #( lr_entry->data ).
  ENDMETHOD.


  METHOD lookup.
    DATA(lr_data) = area_data( iv_area ).
    DATA(lv_name) = CONV zif_ca_param_types=>ty_name( to_upper( iv_name ) ).
    READ TABLE lr_data->definitions INTO rs_resolved-definition
      WITH TABLE KEY area = lr_data->area-area
                     name = lv_name.
    IF sy-subrc <> 0.
      rs_resolved-definition-area = lr_data->area-area.
      rs_resolved-definition-name = lv_name.
      raise( is_definition = rs_resolved-definition
             iv_msgno      = zif_ca_param_types=>gc_msg-name_unknown ).
    ENDIF.
    " sorted key prefix: reads only the rows of this parameter, by context and NUMB
    LOOP AT lr_data->values ASSIGNING FIELD-SYMBOL(<ls_row>)
         WHERE area = lr_data->area-area
           AND name = lv_name.
      INSERT <ls_row> INTO TABLE rs_resolved-all_rows.
    ENDLOOP.

    " the first candidate context with rows wins, and all rows come from that one context
    DATA(lt_candidates) = candidates( is_key  = context_key( is_definition = rs_resolved-definition
                                                             it_context    = it_context )
                                      iv_dims = dimension_count( rs_resolved-definition ) ).
    LOOP AT lt_candidates INTO DATA(ls_candidate).
      rs_resolved-rows = rows_of_context( it_rows    = rs_resolved-all_rows
                                          is_context = ls_candidate ).
      IF rs_resolved-rows IS NOT INITIAL.
        rs_resolved-context = ls_candidate.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD context_key.
    DO zif_ca_param_types=>gc_max_dims TIMES.
      DATA(lv_position) = sy-index.
      ASSIGN COMPONENT |DIM{ lv_position }| OF STRUCTURE is_definition TO FIELD-SYMBOL(<lv_dimension>).
      IF sy-subrc <> 0 OR <lv_dimension> IS INITIAL.
        RETURN.
      ENDIF.
      LOOP AT it_context ASSIGNING FIELD-SYMBOL(<ls_fact>).
        IF to_upper( <ls_fact>-dim ) = <lv_dimension>.
          ASSIGN COMPONENT |CTX{ lv_position }| OF STRUCTURE rs_key TO FIELD-SYMBOL(<lv_value>).
          IF sy-subrc = 0.
            <lv_value> = to_upper( <ls_fact>-value ).
          ENDIF.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDDO.
  ENDMETHOD.


  METHOD dimension_count.
    DO zif_ca_param_types=>gc_max_dims TIMES.
      ASSIGN COMPONENT |DIM{ sy-index }| OF STRUCTURE is_definition TO FIELD-SYMBOL(<lv_dimension>).
      IF sy-subrc <> 0 OR <lv_dimension> IS INITIAL.
        RETURN.
      ENDIF.
      rv_count = rv_count + 1.
    ENDDO.
  ENDMETHOD.


  METHOD candidates.
    DATA ls_candidate TYPE zif_ca_param_types=>ty_ctx.
    DATA lv_complete  TYPE abap_bool.

    DATA(lv_combinations) = ipow( base = 2
                                  exp  = iv_dims ).
    DO lv_combinations TIMES.
      " mask 2**n - 1 (every dimension specific) down to 0 (general rows)
      DATA(lv_mask) = lv_combinations - sy-index.
      CLEAR ls_candidate.
      lv_complete = abap_true.
      DO iv_dims TIMES.
        DATA(lv_position) = sy-index.
        DATA(lv_specific) = ( lv_mask DIV ipow( base = 2
                                                exp  = iv_dims - lv_position ) ) MOD 2.
        IF lv_specific = 0.
          CONTINUE.
        ENDIF.
        ASSIGN COMPONENT |CTX{ lv_position }| OF STRUCTURE is_key TO FIELD-SYMBOL(<lv_read>).
        ASSIGN COMPONENT |CTX{ lv_position }| OF STRUCTURE ls_candidate TO FIELD-SYMBOL(<lv_target>).
        IF <lv_read> IS INITIAL.
          lv_complete = abap_false.        " the read gave no value for this dimension
          EXIT.
        ENDIF.
        <lv_target> = <lv_read>.
      ENDDO.
      IF lv_complete = abap_true.
        INSERT ls_candidate INTO TABLE rt_result.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD rows_of_context.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>)
         WHERE ctx1 = is_context-ctx1
           AND ctx2 = is_context-ctx2
           AND ctx3 = is_context-ctx3
           AND ctx4 = is_context-ctx4.
      INSERT <ls_row> INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD resolve.
    rs_resolved = lookup( iv_area    = iv_area
                          iv_name    = iv_name
                          it_context = it_context ).
    DATA(ls_definition) = rs_resolved-definition.

    " every row of every context is validated on every read - an invalid row is never skipped,
    " and a single value has at most one row in each context
    LOOP AT rs_resolved-all_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      raise_if( mo_validator->check_row( is_definition = ls_definition
                                         is_row        = <ls_row> ) ).
      IF ls_definition-kind = zif_ca_param_types=>gc_kind-single.
        DATA(lv_in_context) = lines( rows_of_context( it_rows    = rs_resolved-all_rows
                                                      is_context = CORRESPONDING #( <ls_row> ) ) ).
        IF lv_in_context > 1.
          raise( is_definition = ls_definition
                 iv_msgno      = zif_ca_param_types=>gc_msg-single_multiple
                 iv_v3         = |{ lv_in_context }| ).
        ENDIF.
      ENDIF.
    ENDLOOP.

    DATA(lv_rows) = lines( rs_resolved-rows ).

    IF lv_rows = 0.
      rs_resolved-value = ls_definition-default_value.
      raise_if( mo_validator->check_value( is_definition = ls_definition
                                           iv_value      = rs_resolved-value ) ).
    ELSEIF ls_definition-kind = zif_ca_param_types=>gc_kind-single.
      rs_resolved-value = rs_resolved-rows[ 1 ]-low.
    ENDIF.

    IF ls_definition-mandatory = abap_true.
      " no row and no default; or a blank single value that is not a BOOL off
      IF ( lv_rows = 0 AND rs_resolved-value IS INITIAL )
         OR ( lv_rows > 0 AND ls_definition-kind = zif_ca_param_types=>gc_kind-single
              AND rs_resolved-value IS INITIAL
              AND ls_definition-value_type <> zif_ca_param_types=>gc_value_type-bool ).
        raise( is_definition = ls_definition
               iv_msgno      = zif_ca_param_types=>gc_msg-mandatory_missing ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD resolve_single.
    rs_resolved = resolve( iv_area    = iv_area
                           iv_name    = iv_name
                           it_context = it_context ).
    DATA(ls_definition) = rs_resolved-definition.
    IF ls_definition-kind <> zif_ca_param_types=>gc_kind-single.
      raise( is_definition = ls_definition
             iv_msgno      = zif_ca_param_types=>gc_msg-kind_mismatch
             iv_v3         = ls_definition-kind
             iv_v4         = iv_read_as ).
    ENDIF.
    IF iv_type_1 IS NOT INITIAL
       AND ls_definition-value_type <> iv_type_1
       AND ( iv_type_2 IS INITIAL OR ls_definition-value_type <> iv_type_2 ).
      raise( is_definition = ls_definition
             iv_msgno      = zif_ca_param_types=>gc_msg-type_mismatch
             iv_v3         = ls_definition-value_type
             iv_v4         = iv_read_as ).
    ENDIF.
    IF iv_value_required = abap_true AND rs_resolved-value IS INITIAL.
      raise( is_definition = ls_definition
             iv_msgno      = zif_ca_param_types=>gc_msg-no_value ).
    ENDIF.
  ENDMETHOD.


  METHOD to_number.
    TRY.
        rv_value = condense( CONV string( is_resolved-value ) ).
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error INTO DATA(lx_error).
        raise( is_definition = is_resolved-definition
               iv_msgno      = zif_ca_param_types=>gc_msg-type_invalid
               iv_v3         = is_resolved-value
               iv_v4         = is_resolved-definition-value_type
               ix_previous   = lx_error ).
    ENDTRY.
  ENDMETHOD.


  METHOD raise.
    RAISE EXCEPTION zcx_ca_param=>create( is_message  = VALUE #( msgid = zif_ca_param_types=>gc_msgid
                                                                 msgno = iv_msgno
                                                                 v1    = is_definition-area
                                                                 v2    = is_definition-name
                                                                 v3    = iv_v3
                                                                 v4    = iv_v4 )
                                          ix_previous = ix_previous ).
  ENDMETHOD.


  METHOD raise_if.
    IF is_message-msgno IS NOT INITIAL.
      RAISE EXCEPTION zcx_ca_param=>create( is_message ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
