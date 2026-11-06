*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_pattern_dao.intf.abap
*& Purpose:
*& Repository of the pattern check and the pattern migration: configured
*& patterns of a pattern area, the distinct real values of the area's source
*& in a date window (row cap), the configuration rows that hold patterns, and
*& the write of converted patterns to the suite's own configuration tables.
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: pattern check and migration).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - pattern check and migration DAO</p>
INTERFACE zif_cd_ops_pattern_dao
  PUBLIC.

  "! Configured, active, non-blank patterns of the area with where they are maintained
  METHODS get_patterns
    IMPORTING
      iv_area            TYPE zif_cd_ops_pattern_types=>ty_area
    RETURNING
      VALUE(rt_patterns) TYPE zif_cd_ops_pattern_types=>tt_pattern.

  "! Distinct real values of the area's source in the date window, ascending, at most
  "! iv_max_rows (a result of iv_max_rows rows may be incomplete)
  METHODS get_values
    IMPORTING
      iv_area          TYPE zif_cd_ops_pattern_types=>ty_area
      iv_from          TYPE d
      iv_to            TYPE d
      iv_max_rows      TYPE i
    RETURNING
      VALUE(rt_values) TYPE zif_cd_ops_pattern_types=>tt_value.

  "! Every non-blank pattern of the configuration tables (ZCD_EBS_FLOW_PAT, ZCD_FMON_IFACE,
  "! ZCD_JOB_STEP, ZCD_OPS_ALRULE, the pattern-list parameters of ZCD_HCK_DEF,
  "! ZCD_HCK_SUPPRESS) with its row key and field length; NEW and STATUS empty
  METHODS get_migration_rows
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_ops_pattern_types=>tt_migration.

  "! Writes NEW of every row with status CONVERT (key field PATTERN of ZCD_EBS_FLOW_PAT:
  "! delete + insert) and the change stamps; no commit. Returns the rows written per table.
  METHODS write_migration
    IMPORTING
      it_rows           TYPE zif_cd_ops_pattern_types=>tt_migration
    RETURNING
      VALUE(rt_written) TYPE zif_cd_ops_pattern_types=>tt_written
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
