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
    SELECT SINGLE area, description, owner_team, prod_editable, active
      FROM zca_param_area
      WHERE area = @iv_area
      INTO CORRESPONDING FIELDS OF @rs_data-area.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rs_data-found = abap_true.

    SELECT area, name, kind, value_type, min_value, max_value, default_value, allowed_pcre,
           interface_name, mandatory, developer_owned, description, owner
      FROM zca_param_def
      WHERE area = @iv_area
      ORDER BY area, name
      INTO CORRESPONDING FIELDS OF TABLE @rs_data-definitions.

    SELECT area, name, numb, sign, opti, low, high
      FROM zca_param_val
      WHERE area = @iv_area
      ORDER BY area, name, numb
      INTO CORRESPONDING FIELDS OF TABLE @rs_data-values.
  ENDMETHOD.

ENDCLASS.
