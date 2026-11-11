*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_brk_dao.intf.abap
*& Purpose:
*& Data access of the clearing-account break analysis: its configuration
*& (accounts, buckets, bucket rules, conditions), the journal reads of a
*& clearing account - grouped on the database by assignment and currency,
*& only groups that do not net to zero (HAVING), oldest first, capped; the
*& lines of a package of groups (assignment IN list, windowed) - and the
*& snapshot it writes (header, groups, lines) and reads back for the check.
*& The journal reads are read-only (ACDOCA, D-C8: kept on the table until
*& PlanViz BRK-PV1 / BRK-PV2 prove the released view keeps the plan).
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - break analysis data access</p>
INTERFACE zif_ca_ops_brk_dao
  PUBLIC.

  TYPES tt_assignment_range TYPE RANGE OF zif_ca_ops_brk_types=>ty_assignment.

  "! Active accounts of an area (one account when IV_ACCT_ID is given)
  METHODS get_accounts
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      iv_acct_id         TYPE zif_ca_ops_brk_types=>ty_acct_id OPTIONAL
    RETURNING
      VALUE(rt_accounts) TYPE zif_ca_ops_brk_types=>tt_account.

  "! Every bucket (active or not)
  METHODS get_buckets
    RETURNING
      VALUE(rt_buckets) TYPE zif_ca_ops_brk_types=>tt_bucket.

  "! Active bucket rules of the area and of every area (*)
  METHODS get_rules
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_rules) TYPE zif_ca_ops_brk_types=>tt_rule.

  "! Conditions of the bucket rules of the area and of every area (*)
  METHODS get_conds
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_conds) TYPE zif_ca_ops_brk_types=>tt_cond.

  "! Groups of the account's lines posted from IV_FROM to IV_KEY_DATE by assignment and currency that do not
  "! net to zero, oldest first, at most IV_MAX (grouped and filtered on the database)
  METHODS open_groups
    IMPORTING
      is_account      TYPE zif_ca_ops_brk_types=>ty_account
      iv_ledger       TYPE zif_ca_ops_brk_types=>ty_ledger
      iv_from         TYPE d
      iv_key_date     TYPE d
      iv_max          TYPE i
    RETURNING
      VALUE(rt_sums)  TYPE zif_ca_ops_brk_types=>tt_group_sum.

  "! Lines of the account with the given assignments posted from IV_FROM to IV_TO (LATER = after the key date),
  "! at most IV_MAX
  METHODS group_lines
    IMPORTING
      is_account      TYPE zif_ca_ops_brk_types=>ty_account
      iv_ledger       TYPE zif_ca_ops_brk_types=>ty_ledger
      iv_from         TYPE d
      iv_to           TYPE d
      iv_key_date     TYPE d
      it_assignments  TYPE tt_assignment_range
      iv_max          TYPE i
    RETURNING
      VALUE(rt_items) TYPE zif_ca_ops_brk_types=>tt_item.

  "! Write a snapshot: header, groups and lines (no commit)
  "! @raising zcx_ca_ops_error | 010 a row could not be inserted
  METHODS save_snapshot
    IMPORTING
      is_snapshot TYPE zif_ca_ops_brk_types=>ty_snapshot
      it_groups   TYPE zif_ca_ops_brk_types=>tt_group
      it_items    TYPE zif_ca_ops_brk_types=>tt_item_result
    RAISING
      zcx_ca_ops_error.

  "! Latest snapshot of an account (latest key date, then latest start); initial when none
  METHODS latest_snapshot
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      iv_acct_id         TYPE zif_ca_ops_brk_types=>ty_acct_id
    RETURNING
      VALUE(rs_snapshot) TYPE zif_ca_ops_brk_types=>ty_snapshot.

  "! Unexplained groups (bucket OTHER) of a snapshot at least IV_MIN_AGE days old, oldest first, at most IV_MAX
  METHODS open_breaks
    IMPORTING
      iv_snap_id       TYPE zif_ca_ops_types=>ty_run_id
      iv_min_age       TYPE i
      iv_max           TYPE i
    RETURNING
      VALUE(rt_breaks) TYPE zif_ca_ops_brk_types=>tt_open_break.

  "! Number of unexplained groups of a snapshot at least IV_MIN_AGE days old
  METHODS count_open_breaks
    IMPORTING
      iv_snap_id      TYPE zif_ca_ops_types=>ty_run_id
      iv_min_age      TYPE i
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Commit the snapshot of one account (the report commits after every account)
  METHODS commit.

ENDINTERFACE.
