*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_brk_links.intf.abap
*& Purpose:
*& Linked objects of the journal lines of the break analysis, through the
*& link registry: the links effective from the line's object
*& (S4_JOURNAL_ITEM) and, for a set of lines, the rows of the linked
*& objects (bank statement line, returns lot item, cheque, ...) - set-based
*& (one read per link and chunk of lines), bounded, read only, approved
*& tables of the area, sensitive key values masked.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - break analysis linked objects</p>
INTERFACE zif_ca_ops_brk_links
  PUBLIC.

  "! A field of a linked object a condition compares (read with the link)
  TYPES:
    BEGIN OF ty_link_field,
      link_id TYPE zif_ca_ops_link_types=>ty_link_id,
      field   TYPE zif_ca_ops_link_types=>ty_fieldname,
    END OF ty_link_field.
  TYPES tt_link_field TYPE STANDARD TABLE OF ty_link_field WITH EMPTY KEY.

  "! Links of the registry effective from the line's object (layer and link switched on, valid)
  METHODS effective_links
    RETURNING
      VALUE(rt_links) TYPE zif_ca_ops_link_types=>tt_link_id.

  "! Rows of the linked objects of the lines (lines after the key date are not read)
  "! @parameter iv_area     | Area whose approved tables may be read
  "! @parameter it_fields   | Links to read and the fields the conditions compare
  "! @parameter it_items    | Journal lines
  "! @parameter et_hits     | One row per line, link and linked row
  "! @parameter et_problems | Links not read or read incompletely (293): their conditions see fewer rows
  METHODS read
    IMPORTING
      iv_area     TYPE zif_ca_ops_types=>ty_area
      it_fields   TYPE tt_link_field
      it_items    TYPE zif_ca_ops_brk_types=>tt_item
    EXPORTING
      et_hits     TYPE zif_ca_ops_brk_types=>tt_hit
      et_problems TYPE zif_ca_ops_brk_types=>tt_problem.

ENDINTERFACE.
