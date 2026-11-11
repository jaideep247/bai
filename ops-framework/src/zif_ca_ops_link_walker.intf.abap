*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_link_walker.intf.abap
*& Purpose:
*& Drill-down over the link registry: from an object and the key of one of
*& its rows, the linked objects and their keys, level by level along the
*& effective links (fallback chains in order), with the path and the
*& evidence quality of every node. Bounded (depth, rows per read, nodes),
*& read only, set-based (one read per link and level), through the
*& approved tables of the caller's area; sensitive key values are masked.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link registry walker</p>
INTERFACE zif_ca_ops_link_walker
  PUBLIC.

  "! Walk from the start object along the effective links
  "! @parameter is_request | Area, start object, its key values, depth (0 = LINK_MAX_DEPTH), link filter
  "! @parameter rs_result  | Nodes (start = node 1) with masked keys, path and quality; truncated flag and
  "!                         the problems of the walk (limits, links skipped)
  "! @raising zcx_ca_ops_error | 041 no display authorisation for the area, 210 start object unknown or not
  "!                             active, 211 a key field of the start has no value
  METHODS walk
    IMPORTING
      is_request       TYPE zif_ca_ops_link_types=>ty_request
    RETURNING
      VALUE(rs_result) TYPE zif_ca_ops_link_types=>ty_result
    RAISING
      zcx_ca_ops_error.

  "! The effective registry the walker follows (chains of effective links and the problems of the
  "! registry rows) - read once per instance
  METHODS registry
    RETURNING
      VALUE(rs_effective) TYPE zif_ca_ops_link_types=>ty_effective.

ENDINTERFACE.
