*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_link_dao.intf.abap
*& Purpose:
*& Data access of the link registry: the registry tables (layers, objects,
*& fields, links, conditions, activation overrides) and the read of one
*& link for a set of source rows - validated and run here, never trusting
*& a caller-built string: the target source must be approved for the area
*& (ZCA_OPS_TABWL) and displayable (S_TABU_NAM), every field name is
*& checked against its runtime DDIC, literals are quoted
*& (ZCL_CA_OPS_LINK_QUERY). Read only; no business table is changed.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link registry data access</p>
INTERFACE zif_ca_ops_link_dao
  PUBLIC.

  "! Every row of the six registry tables (small customizing tables)
  METHODS read_registry
    RETURNING
      VALUE(rs_registry) TYPE zif_ca_ops_link_types=>ty_registry.

  "! Rows of the target object linked to the source rows by the link's conditions (one database read
  "! per call: an IN list or OR groups of the source rows' transformed values)
  "! @parameter iv_area      | Area whose approved tables may be read
  "! @parameter is_target    | Object read (its source)
  "! @parameter it_conds     | Conditions of the link (TABLE-FIELD references)
  "! @parameter it_sources   | Source rows (the from fields of the EQ conditions)
  "! @parameter it_select    | Fields of the target to return (keys, the to fields of the link, the fields
  "!                           the next links read)
  "! @parameter iv_max_rows  | Rows at most
  "! @raising zcx_ca_ops_error | 212 not approved, 213 unknown field, 214 / 215 / 227 invalid condition,
  "!                             087 no display authorisation, 222 the read failed
  METHODS read_linked
    IMPORTING
      iv_area        TYPE zif_ca_ops_types=>ty_area
      is_target      TYPE zif_ca_ops_link_types=>ty_object
      it_conds       TYPE zif_ca_ops_link_types=>tt_cond
      it_sources     TYPE zif_ca_ops_link_types=>tt_row
      it_select      TYPE zif_ca_ops_link_types=>tt_fieldname
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_ca_ops_link_types=>tt_row
    RAISING
      zcx_ca_ops_error.

  "! Fields of the runtime DDIC of a source (table or CDS view entity); empty when it is unknown.
  "! Metadata only: no data is read, no authorisation needed
  METHODS source_fields
    IMPORTING
      iv_source        TYPE zif_ca_ops_link_types=>ty_source
    RETURNING
      VALUE(rt_fields) TYPE zif_ca_ops_chk_types=>tt_field.

ENDINTERFACE.
