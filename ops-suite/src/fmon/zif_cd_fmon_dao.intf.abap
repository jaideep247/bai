*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_dao.intf.abap
*& Purpose:
*& Repository seam for FMON: customizing (ZCD_FMON_*), file registry,
*& event audit trail and the DDIC-validated read of configured legacy
*& tables. The only FMON seam that issues SQL.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - repository (config, registry, events)</p>
INTERFACE zif_cd_fmon_dao
  PUBLIC.

  "! All active interface definitions (ZCD_FMON_IFACE)
  METHODS get_ifaces
    RETURNING
      VALUE(rt_ifaces) TYPE zif_cd_fmon_types=>tt_iface.

  METHODS get_slas
    RETURNING
      VALUE(rt_slas) TYPE zif_cd_fmon_types=>tt_sla.

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
  METHODS find_files_by_ref
    IMPORTING
      it_keys         TYPE zif_cd_fmon_types=>tt_file_key
    RETURNING
      VALUE(rt_files) TYPE zif_cd_fmon_types=>tt_file.

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
  METHODS save_files
    IMPORTING
      it_files TYPE zif_cd_fmon_types=>tt_file
    RAISING
      zcx_cd_ops_error.

  "! Idempotent: an event with the same SRC_ID + SRC_KEY + STAGE is not
  "! inserted again (returns abap_false). EVENT_NO is assigned here.
  METHODS insert_event
    IMPORTING
      is_event           TYPE zif_cd_fmon_types=>ty_event
    RETURNING
      VALUE(rv_inserted) TYPE abap_bool
    RAISING
      zcx_cd_ops_error.

  "! Dynamic read of a configured table. The caller has validated every
  "! name against the DDIC (ZCL_CD_FMON_QUERY=>VALIDATE); no free-text WHERE.
  METHODS read_legacy
    IMPORTING
      is_query       TYPE zif_cd_fmon_types=>ty_query
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_fmon_types=>tt_raw_row
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
