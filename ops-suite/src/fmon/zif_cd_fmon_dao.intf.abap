*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_dao.intf.abap
*& Purpose:
*& Repository seam for FMON: customizing (ZCD_FMON_*), file registry,
*& event audit trail and the DDIC-validated read of configured legacy
*& tables. The only FMON seam that issues SQL.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A04/A49: version-checked save returns conflicts; reference lookup bounded by date.
*& 2026-11-06 | Performance fix 8: count_legacy - grouped COUNT(*) on the same validated read path (DEFAULT IGNORE).
*& 2026-11-07 | get_deadlines (ZCD_FMON_DEADL, DEFAULT IGNORE); SLA and calendar rows: active only.
*& 2026-11-07 | get_group_files (regenerated files: generations of a payment run, DEFAULT IGNORE).
*& 2026-11-08 | get_group_acks (files of generation groups with their ACK events, one read; consumer
*&            | HCK A_INFLIGHT status lag of payments acknowledged per file, DEFAULT IGNORE).
*& 2026-11-08 | Table consolidation: approved tables read from ZCD_OPS_TABWL (area FMON, purpose SOURCE; was
*&            | ZCD_FMON_TABWL).
*& 2026-11-08 | Table consolidation: get_slas reads both kinds of ZCD_FMON_SLA (DURATION, DEADLINE);
*&            | get_deadlines (ZCD_FMON_DEADL) removed.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - repository (config, registry, events)</p>
INTERFACE zif_cd_fmon_dao
  PUBLIC.

  "! All active interface definitions (ZCD_FMON_IFACE)
  METHODS get_ifaces
    RETURNING
      VALUE(rt_ifaces) TYPE zif_cd_fmon_types=>tt_iface.

  "! Active stage SLAs of both kinds (ZCD_FMON_SLA: DURATION and DEADLINE rows, one read;
  "! production deactivates a row, never deletes it)
  METHODS get_slas
    RETURNING
      VALUE(rt_slas) TYPE zif_cd_fmon_types=>tt_sla.

  "! Active expected-file rows (ZCD_FMON_CAL)
  METHODS get_calendars
    RETURNING
      VALUE(rt_cals) TYPE zif_cd_fmon_types=>tt_cal.

  "! Active legacy source adapters (ZCD_FMON_SRC)
  METHODS get_sources
    RETURNING
      VALUE(rt_sources) TYPE zif_cd_fmon_types=>tt_src.

  METHODS get_source_maps
    RETURNING
      VALUE(rt_maps) TYPE zif_cd_fmon_types=>tt_srcmap.

  "! Active lot completeness configurations (ZCD_FMON_LOTCFG)
  METHODS get_lot_configs
    RETURNING
      VALUE(rt_cfgs) TYPE zif_cd_fmon_types=>tt_lotcfg.

  "! Active plug-in checks (ZCD_FMON_CHK)
  METHODS get_checks
    RETURNING
      VALUE(rt_checks) TYPE zif_cd_fmon_types=>tt_chk.

  "! Registry entries by interface + file reference
  "! Instances of the references (all business dates since iv_since - audit A49);
  "! every row comes back with DB_EXISTS and DB_VERSION (= CHANGED_AT as read)
  METHODS find_files_by_ref
    IMPORTING
      it_keys         TYPE zif_cd_fmon_types=>tt_file_key
      iv_since        TYPE d OPTIONAL
    RETURNING
      VALUE(rt_files) TYPE zif_cd_fmon_types=>tt_file.

  "! Every registered generation of the interface + generation group keys (ZCD_FMON_FILE-GEN_GROUP,
  "! index GRP) since iv_since; rows come back with DB_EXISTS and DB_VERSION
  METHODS get_group_files DEFAULT IGNORE
    IMPORTING
      it_keys         TYPE zif_cd_fmon_types=>tt_group_key
      iv_since        TYPE d
    RETURNING
      VALUE(rt_files) TYPE zif_cd_fmon_types=>tt_file.

  "! Every registered file of the interface + generation group keys (index GRP) since iv_since with
  "! its ACK_RECEIVED events - one read (files LEFT OUTER JOIN events): one row per file and ACK
  "! event, ACK_AT initial for a file without ACK. Read-only; consumer HCK A_INFLIGHT (status lag)
  METHODS get_group_acks DEFAULT IGNORE
    IMPORTING
      it_keys        TYPE zif_cd_fmon_types=>tt_group_key
      iv_since       TYPE d
    RETURNING
      VALUE(rt_acks) TYPE zif_cd_fmon_types=>tt_group_ack.

  "! Files of business dates iv_date_from..iv_date_to plus files since
  "! iv_open_since that are still open (no outcome or PARTIALLY_PROCESSED)
  METHODS get_eval_files
    IMPORTING
      iv_date_from    TYPE d
      iv_date_to      TYPE d
      iv_open_since   TYPE d
      iv_iface_id     TYPE zif_cd_fmon_types=>ty_iface_id OPTIONAL
    RETURNING
      VALUE(rt_files) TYPE zif_cd_fmon_types=>tt_file.

  "! Earlier files with one of the names or checksums (duplicate detection)
  METHODS get_history
    IMPORTING
      it_names        TYPE zif_cd_fmon_types=>tt_file_name
      it_checksums    TYPE zif_cd_fmon_types=>tt_checksum
      iv_since        TYPE d
    RETURNING
      VALUE(rt_files) TYPE zif_cd_fmon_types=>tt_file.

  METHODS get_events
    IMPORTING
      it_file_ids      TYPE zif_cd_fmon_types=>tt_file_id
    RETURNING
      VALUE(rt_events) TYPE zif_cd_fmon_types=>tt_event.

  "! Insert or update registry entries (no commit)
  "! New rows are inserted; a row read before (DB_EXISTS) is updated only while its
  "! CHANGED_AT still equals DB_VERSION - otherwise another process changed it and the
  "! file is returned as a conflict, never overwritten (audit A04)
  METHODS save_files
    IMPORTING
      it_files            TYPE zif_cd_fmon_types=>tt_file
    RETURNING
      VALUE(rt_conflicts) TYPE zif_cd_fmon_types=>tt_file_id
    RAISING
      zcx_cd_ops_error
      "! Technical database error: the caller (LUW owner) rolls back (audit A05)
      cx_sy_open_sql_db.

  "! Idempotent per file instance: an event with the same FILE_ID + SRC_ID + SRC_KEY +
  "! STAGE is not inserted again (returns abap_false). EVENT_NO is assigned here.
  METHODS insert_event
    IMPORTING
      is_event           TYPE zif_cd_fmon_types=>ty_event
    RETURNING
      VALUE(rv_inserted) TYPE abap_bool
    RAISING
      zcx_cd_ops_error
      "! Technical database error: the caller (LUW owner) rolls back (audit A05)
      cx_sy_open_sql_db.

  "! Dynamic read of a configured table. The caller has validated every
  "! name against the DDIC (ZCL_CD_FMON_QUERY=>VALIDATE); no free-text WHERE.
  METHODS read_legacy
    IMPORTING
      is_query       TYPE zif_cd_fmon_types=>ty_query
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_fmon_types=>tt_raw_row
    RAISING
      zcx_cd_ops_error.

  "! Fix 8: the rows of the same read counted per distinct combination of the query's fields
  "! (GROUP BY every field, COUNT(*)); same name validation, ZCD_OPS_TABWL approval (FMON / SOURCE) and
  "! S_TABU_NAM check as read_legacy. No row cap: one row per group
  METHODS count_legacy DEFAULT IGNORE
    IMPORTING
      is_query         TYPE zif_cd_fmon_types=>ty_query
    RETURNING
      VALUE(rt_counts) TYPE zif_cd_fmon_types=>tt_raw_count
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
