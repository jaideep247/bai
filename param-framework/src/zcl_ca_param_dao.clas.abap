*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_dao.clas.abap
*& Purpose:
*& Database access of the parameter framework: reads one area (master row,
*& definitions, values) from ZCA_PARAM_AREA / _DEF / _VAL with explicit
*& field lists and ORDER BY the full key, into SORTED tables - the result
*& is deterministic. Three statements per area and session (the caller
*& buffers); the tables are also fully buffered by the kernel. No logic,
*& no defaults, no validation (ZCL_CA_PARAM).
*& Modification log:
*& 2026-11-07 | Initial version.
*& 2026-11-24 | PROD_EDITABLE, DEVELOPER_OWNED and OWNER removed from the field lists.
*& 2026-11-24 | Context: DIM1-4 and CTX1-4 read; values ordered by context, then NUMB.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - database access</p>
CLASS zcl_ca_param_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_param_dao.

ENDCLASS.



CLASS zcl_ca_param_dao IMPLEMENTATION.

  METHOD zif_ca_param_dao~read_area.
    SELECT SINGLE area, description, owner_team, active
      FROM zca_param_area
      WHERE area = @iv_area
      INTO CORRESPONDING FIELDS OF @rs_data-area.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rs_data-found = abap_true.

    SELECT area, name, kind, value_type, min_value, max_value, default_value, allowed_pcre,
           interface_name, mandatory, dim1, dim2, dim3, dim4, description
      FROM zca_param_def
      WHERE area = @iv_area
      ORDER BY area, name
      INTO CORRESPONDING FIELDS OF TABLE @rs_data-definitions.

    SELECT area, name, ctx1, ctx2, ctx3, ctx4, numb, sign, opti, low, high
      FROM zca_param_val
      WHERE area = @iv_area
      ORDER BY area, name, ctx1, ctx2, ctx3, ctx4, numb
      INTO CORRESPONDING FIELDS OF TABLE @rs_data-values.
  ENDMETHOD.

ENDCLASS.
