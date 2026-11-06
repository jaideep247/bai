*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_types.intf.abap
*& Purpose:
*& File monitoring (FMON) types, status model, constants and the
*& configuration / registry / check-context structures shared by all
*& FMON classes. No logic.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | gc_manual_src_id (design 6.4).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A04-A52: file instance identity, version check, payment-level ACK
*&              dedupe, lot truncation, SLA evidence, age basis, approved tables, malformed rows.
*& 2026-11-06 | gc_engine_key-registry.
*& 2026-11-06 | Plug-in interface names for the core factory check (audit A62).
*& 2026-11-06 | File reference digest for names longer than the key (audit A100).
*& 2026-11-06 | Performance fix 8: TY_RAW_COUNT (grouped legacy read: values by role + number of rows).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | PRISM status API: stages PRISM_RECEIVED / PRISM_DELIVERED / PRISM_FAILED
*&              (both directions), check codes and messages of the PRISM checks.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - types, status model and constants</p>
"! Status model (ordered stages; a later stage never regresses):
"!   outbound  GENERATED_IN_SAP -> SENT_TO_PRISM -> PRISM_RECEIVED -> PRISM_DELIVERED = FORWARDED_TO_BANK
"!             -> ACK_RECEIVED | NACK_REJECTED
"!   inbound   PRISM_RECEIVED -> PRISM_DELIVERED -> FILE_RECEIVED -> FILE_LOADED
"!             -> FULLY_PROCESSED | PARTIALLY_PROCESSED | FAILED
"! PRISM_* stages belong to both directions (PRISM status API); PRISM_FAILED is an outcome
"! that later evidence of progress supersedes (PRISM retried successfully).
"! Terminal outcomes are never overwritten, with one exception: on a re-run an inbound
"! outcome may only improve (FAILED -> PARTIALLY_PROCESSED -> FULLY_PROCESSED).
"! ACK_RECEIVED and NACK_REJECTED are final. See ZCL_CD_FMON_STATUS.
INTERFACE zif_cd_fmon_types
  PUBLIC.

  TYPES ty_iface_id     TYPE c LENGTH 20.
  TYPES ty_direction    TYPE c LENGTH 1.
  TYPES ty_file_type    TYPE c LENGTH 10.
  TYPES ty_system       TYPE c LENGTH 10.
  TYPES ty_pay_method   TYPE c LENGTH 10.
  TYPES ty_lob          TYPE c LENGTH 10.
  TYPES ty_bank_key     TYPE c LENGTH 15.
  TYPES ty_pattern      TYPE c LENGTH 128.
  TYPES ty_stage        TYPE c LENGTH 20.
  TYPES ty_ack_level    TYPE c LENGTH 8.
  TYPES ty_src_id       TYPE c LENGTH 10.
  TYPES ty_tabname      TYPE c LENGTH 30.
  TYPES ty_fieldname    TYPE c LENGTH 30.
  TYPES ty_status_value TYPE c LENGTH 40.
  TYPES ty_day_type     TYPE c LENGTH 12.
  TYPES ty_fcal_id      TYPE c LENGTH 2.
  TYPES ty_lot_type     TYPE c LENGTH 10.
  TYPES ty_check_id     TYPE zif_cd_ops_types=>ty_rule_id.
  TYPES ty_params       TYPE c LENGTH 255.
  TYPES ty_file_ref     TYPE c LENGTH 70.
  TYPES ty_file_name    TYPE c LENGTH 255.
  TYPES ty_checksum     TYPE c LENGTH 64.
  TYPES ty_sla_basis    TYPE c LENGTH 1.
  TYPES ty_link_by      TYPE c LENGTH 1.
  TYPES ty_role         TYPE c LENGTH 12.
  TYPES ty_value_list   TYPE c LENGTH 255.
  TYPES ty_text60       TYPE c LENGTH 60.
  TYPES ty_info         TYPE c LENGTH 255.
  TYPES ty_transition   TYPE c LENGTH 1.
  TYPES ty_file_id      TYPE x LENGTH 16.
  TYPES ty_size         TYPE int8.
  TYPES ty_inttype      TYPE c LENGTH 1.
  TYPES ty_date_kind    TYPE c LENGTH 1.
  TYPES ty_key_value    TYPE c LENGTH 255.
  TYPES ty_time_zone    TYPE c LENGTH 6.
  TYPES ty_light        TYPE c LENGTH 1.
  "! Banking-day age basis (FMON_AGE_BASIS): A = days strictly after receipt, N = from next working day
  TYPES ty_age_basis    TYPE c LENGTH 1.
  "! Factory-calendar correction option of DATE_CONVERT_TO_FACTORYDATE ('+' next, '-' previous)
  TYPES ty_fcal_correct TYPE c LENGTH 1.

  "! File reference longer than the correlation key (audit A100): first PREFIX characters of the
  "! canonical name + MARKER + SHA-1 hex of the whole canonical name = exactly WIDTH characters
  CONSTANTS:
    BEGIN OF gc_ref_digest,
      width     TYPE i VALUE 70,
      prefix    TYPE i VALUE 29,
      marker    TYPE c LENGTH 1 VALUE '#',
      algorithm TYPE string VALUE `SHA1`,
    END OF gc_ref_digest.

  "! Plug-in interfaces checked by the core factory before instantiation (audit A62)
  CONSTANTS:
    BEGIN OF gc_plugin_interface,
      adapter TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZIF_CD_FMON_ADAPTER',
      check   TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZIF_CD_FMON_CHECK',
    END OF gc_plugin_interface.

  CONSTANTS:
    BEGIN OF gc_direction,
      outbound TYPE ty_direction VALUE 'O',
      inbound  TYPE ty_direction VALUE 'I',
    END OF gc_direction.

  CONSTANTS:
    BEGIN OF gc_file_type,
      payment   TYPE ty_file_type VALUE 'PAYMENT',
      ack       TYPE ty_file_type VALUE 'ACK',
      statement TYPE ty_file_type VALUE 'STATEMENT',
      returns   TYPE ty_file_type VALUE 'RETURNS',
      noc       TYPE ty_file_type VALUE 'NOC',
      pospay    TYPE ty_file_type VALUE 'POSPAY',
      other     TYPE ty_file_type VALUE 'OTHER',
    END OF gc_file_type.

  "! File status values (stage and outcome share one value set)
  CONSTANTS:
    BEGIN OF gc_stage,
      generated TYPE ty_stage VALUE 'GENERATED_IN_SAP',
      sent      TYPE ty_stage VALUE 'SENT_TO_PRISM',
      forwarded TYPE ty_stage VALUE 'FORWARDED_TO_BANK',
      ack       TYPE ty_stage VALUE 'ACK_RECEIVED',
      nack      TYPE ty_stage VALUE 'NACK_REJECTED',
      received  TYPE ty_stage VALUE 'FILE_RECEIVED',
      loaded    TYPE ty_stage VALUE 'FILE_LOADED',
      fully     TYPE ty_stage VALUE 'FULLY_PROCESSED',
      partially TYPE ty_stage VALUE 'PARTIALLY_PROCESSED',
      failed    TYPE ty_stage VALUE 'FAILED',
      "! PRISM status API (both directions): PRISM received the file from SAP / the bank,
      "! IRIS or source; delivered it onward; could not process or deliver it
      prism_received  TYPE ty_stage VALUE 'PRISM_RECEIVED',
      prism_delivered TYPE ty_stage VALUE 'PRISM_DELIVERED',
      prism_failed    TYPE ty_stage VALUE 'PRISM_FAILED',
    END OF gc_stage.

  "! Result of applying a status to a file
  CONSTANTS:
    BEGIN OF gc_transition,
      advanced TYPE ty_transition VALUE 'A',
      updated  TYPE ty_transition VALUE 'U',
      ignored  TYPE ty_transition VALUE 'I',
      rejected TYPE ty_transition VALUE 'R',
    END OF gc_transition.

  CONSTANTS:
    BEGIN OF gc_day_type,
      normal      TYPE ty_day_type VALUE 'NORMAL',
      month_end   TYPE ty_day_type VALUE 'MONTH_END',
      holiday     TYPE ty_day_type VALUE 'HOLIDAY',
      returns_day TYPE ty_day_type VALUE 'RETURNS_DAY',
    END OF gc_day_type.

  "! Disbursements are acknowledged per payment, collections per file
  CONSTANTS:
    BEGIN OF gc_ack_level,
      file    TYPE ty_ack_level VALUE 'FILE',
      payment TYPE ty_ack_level VALUE 'PAYMENT',
    END OF gc_ack_level.

  "! SLA measured from the previous stage (P) or from the first event / generation (G)
  CONSTANTS:
    BEGIN OF gc_sla_basis,
      previous   TYPE ty_sla_basis VALUE 'P',
      generation TYPE ty_sla_basis VALUE 'G',
    END OF gc_sla_basis.

  CONSTANTS:
    BEGIN OF gc_lot_type,
      returns TYPE ty_lot_type VALUE 'RETURNS',
      noc     TYPE ty_lot_type VALUE 'NOC',
    END OF gc_lot_type.

  "! Lot link value: file name (N) or file reference (R)
  CONSTANTS:
    BEGIN OF gc_link_by,
      name TYPE ty_link_by VALUE 'N',
      ref  TYPE ty_link_by VALUE 'R',
    END OF gc_link_by.

  CONSTANTS:
    BEGIN OF gc_date_kind,
      date      TYPE ty_date_kind VALUE 'D',
      timestamp TYPE ty_date_kind VALUE 'T',
    END OF gc_date_kind.

  "! Dynamic WHERE of the legacy reader: exclusive upper bound of the timestamp window
  "! [TS_FROM, TS_TO) - TS_TO is the next midnight (audit A52)
  CONSTANTS gc_ts_window_upper TYPE string VALUE ` < @LV_TS_TO`.

  "! Field roles = component names of TY_RAW_ROW
  CONSTANTS:
    BEGIN OF gc_role,
      file_key    TYPE ty_role VALUE 'FILE_KEY',
      file_name   TYPE ty_role VALUE 'FILE_NAME',
      ev_date     TYPE ty_role VALUE 'EV_DATE',
      ev_time     TYPE ty_role VALUE 'EV_TIME',
      ev_ts       TYPE ty_role VALUE 'EV_TS',
      status      TYPE ty_role VALUE 'STATUS',
      rec_count   TYPE ty_role VALUE 'REC_COUNT',
      amount      TYPE ty_role VALUE 'AMOUNT',
      size        TYPE ty_role VALUE 'SIZE',
      checksum    TYPE ty_role VALUE 'CHECKSUM',
      source      TYPE ty_role VALUE 'SOURCE',
      lob         TYPE ty_role VALUE 'LOB',
      lot_key     TYPE ty_role VALUE 'LOT_KEY',
      item_key    TYPE ty_role VALUE 'ITEM_KEY',
      item_status TYPE ty_role VALUE 'ITEM_STATUS',
      file_link   TYPE ty_role VALUE 'FILE_LINK',
    END OF gc_role.

  CONSTANTS:
    BEGIN OF gc_check_code,
      file_missing     TYPE zif_cd_ops_types=>ty_check_code VALUE 'FILE_MISSING',
      unexpected_file  TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNEXPECTED_FILE',
      file_late        TYPE zif_cd_ops_types=>ty_check_code VALUE 'FILE_LATE',
      no_prism_handoff TYPE zif_cd_ops_types=>ty_check_code VALUE 'NO_PRISM_HANDOFF',
      prism_late       TYPE zif_cd_ops_types=>ty_check_code VALUE 'PRISM_HANDOFF_LATE',
      no_bank_ack      TYPE zif_cd_ops_types=>ty_check_code VALUE 'NO_BANK_ACK',
      bank_ack_late    TYPE zif_cd_ops_types=>ty_check_code VALUE 'BANK_ACK_LATE',
      nack             TYPE zif_cd_ops_types=>ty_check_code VALUE 'NACK',
      file_failed      TYPE zif_cd_ops_types=>ty_check_code VALUE 'FILE_FAILED',
      ack_count        TYPE zif_cd_ops_types=>ty_check_code VALUE 'ACK_COUNT_MISMATCH',
      ack_amount       TYPE zif_cd_ops_types=>ty_check_code VALUE 'ACK_AMOUNT_MISMATCH',
      duplicate        TYPE zif_cd_ops_types=>ty_check_code VALUE 'DUPLICATE_FILE',
      zero_byte        TYPE zif_cd_ops_types=>ty_check_code VALUE 'ZERO_BYTE',
      size_bounds      TYPE zif_cd_ops_types=>ty_check_code VALUE 'SIZE_OUT_OF_BOUNDS',
      lot_unprocessed  TYPE zif_cd_ops_types=>ty_check_code VALUE 'LOT_UNPROCESSED',
      lot_not_found    TYPE zif_cd_ops_types=>ty_check_code VALUE 'LOT_NOT_FOUND',
      noc_aging        TYPE zif_cd_ops_types=>ty_check_code VALUE 'NOC_AGING',
      noc_due_today    TYPE zif_cd_ops_types=>ty_check_code VALUE 'NOC_DUE_TODAY',
      unmapped_file    TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNMAPPED_FILE',
      unmapped_status  TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNMAPPED_STATUS',
      " retired by audit A49 (no longer raised); kept for findings of earlier runs
      ref_reused       TYPE zif_cd_ops_types=>ty_check_code VALUE 'FILE_REF_REUSED',
      ref_ambiguous    TYPE zif_cd_ops_types=>ty_check_code VALUE 'FILE_REF_AMBIGUOUS',
      persist_conflict TYPE zif_cd_ops_types=>ty_check_code VALUE 'PERSIST_CONFLICT',
      lot_truncated    TYPE zif_cd_ops_types=>ty_check_code VALUE 'LOT_SCAN_TRUNCATED',
      malformed_row    TYPE zif_cd_ops_types=>ty_check_code VALUE 'MALFORMED_SOURCE_ROW',
      plugin_error     TYPE zif_cd_ops_types=>ty_check_code VALUE 'PLUGIN_ERROR',
      persist_error    TYPE zif_cd_ops_types=>ty_check_code VALUE 'PERSIST_ERROR',
      alert_failed     TYPE zif_cd_ops_types=>ty_check_code VALUE 'ALERT_FAILED',
      "! PRISM reported that it could not process or deliver the file
      prism_failed     TYPE zif_cd_ops_types=>ty_check_code VALUE 'PRISM_FAILED',
      "! Outbound: PRISM evidence for a file SAP has no generation / send record of
      prism_unknown    TYPE zif_cd_ops_types=>ty_check_code VALUE 'PRISM_UNKNOWN_FILE',
      "! Inbound: PRISM delivered the file, SAP has not received it after the grace period
      prism_not_loaded TYPE zif_cd_ops_types=>ty_check_code VALUE 'PRISM_NOT_LOADED',
    END OF gc_check_code.

  "! Runtime parameters in ZCD_OPS_PARAM (defaults in brackets)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Days read back from legacy tables and files evaluated [1]
      lookback_days TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_LOOKBACK_DAYS',
      "! Open (not terminal / partially processed) files kept under watch [30]
      open_days     TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_OPEN_DAYS',
      "! Duplicate-file history window [7]
      dup_days      TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_DUP_DAYS',
      "! Time zone of legacy date/time fields and calendar windows [UTC]
      time_zone     TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_TIME_ZONE',
      "! Factory calendar when ZCD_FMON_CAL has none [US]
      factory_cal   TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_FACTORY_CAL',
      "! Weekdays (1 = Monday) that are ACH returns cycle days [blank]
      returns_days  TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_RETURNS_WEEKDAYS',
      "! NACHA NOC banking-day SLA when ZCD_FMON_LOTCFG has none [6]
      noc_sla_days  TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_NOC_SLA_DAYS',
      "! Row cap per legacy table read [50000]
      max_rows      TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_MAX_ROWS',
      "! Banking-day age basis: A strictly after receipt, N from next working day [A]
      age_basis     TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_AGE_BASIS',
    END OF gc_param.

  CONSTANTS gc_wildcard TYPE c LENGTH 1 VALUE '*'.
  CONSTANTS gc_object_type TYPE zif_cd_ops_types=>ty_object_type VALUE 'FILE'.
  CONSTANTS gc_engine_rule TYPE ty_check_id VALUE 'ENGINE'.
  CONSTANTS gc_lot_src_id TYPE ty_src_id VALUE 'LOT'.
  "! Source of events set by hand in the manual-status app (design 6.4)
  CONSTANTS gc_manual_src_id TYPE ty_src_id VALUE 'MANUAL'.
  "! Banking-day age that could not be determined (calendar failure): no aging verdict
  CONSTANTS gc_age_unknown TYPE i VALUE -1.
  CONSTANTS:
    BEGIN OF gc_age_basis,
      after_receipt TYPE ty_age_basis VALUE 'A',
      next_working  TYPE ty_age_basis VALUE 'N',
    END OF gc_age_basis.
  CONSTANTS:
    BEGIN OF gc_fcal_correct,
      next     TYPE ty_fcal_correct VALUE '+',
      previous TYPE ty_fcal_correct VALUE '-',
    END OF gc_fcal_correct.
  "! Display authorisation checked at the dynamic read boundary (ZCL_CD_FMON_DDIC=>MAY_READ)
  CONSTANTS:
    BEGIN OF gc_table_auth,
      object   TYPE xuobject VALUE 'S_TABU_NAM',
      id_actvt TYPE xufield VALUE 'ACTVT',
      id_table TYPE xufield VALUE 'TABLE',
      display  TYPE activ_auth VALUE '03',
    END OF gc_table_auth.
  "! Token in a done-value list that stands for an initial status
  CONSTANTS gc_blank_token TYPE string VALUE `<BLANK>`.

  " ---------------------------------------------------------------- customizing
  TYPES:
    BEGIN OF ty_iface,
      iface_id     TYPE ty_iface_id,
      direction    TYPE ty_direction,
      file_type    TYPE ty_file_type,
      source_sys   TYPE ty_system,
      target_sys   TYPE ty_system,
      pay_method   TYPE ty_pay_method,
      lob          TYPE ty_lob,
      bank_key     TYPE ty_bank_key,
      name_pattern TYPE ty_pattern,
      min_bytes    TYPE ty_size,
      max_bytes    TYPE ty_size,
      ack_expected TYPE abap_bool,
      ack_level    TYPE ty_ack_level,
      owner        TYPE syuname,
      active       TYPE abap_bool,
      description  TYPE ty_text60,
    END OF ty_iface.
  TYPES tt_iface TYPE SORTED TABLE OF ty_iface WITH UNIQUE KEY iface_id.

  TYPES:
    BEGIN OF ty_sla,
      iface_id    TYPE ty_iface_id,
      stage       TYPE ty_stage,
      max_minutes TYPE i,
      basis       TYPE ty_sla_basis,
      severity    TYPE zif_cd_ops_types=>ty_severity,
    END OF ty_sla.
  TYPES tt_sla TYPE SORTED TABLE OF ty_sla WITH UNIQUE KEY iface_id stage.

  TYPES:
    BEGIN OF ty_cal,
      iface_id       TYPE ty_iface_id,
      day_type       TYPE ty_day_type,
      expected_count TYPE i,
      window_from    TYPE t,
      window_to      TYPE t,
      fcal_id        TYPE ty_fcal_id,
    END OF ty_cal.
  TYPES tt_cal TYPE SORTED TABLE OF ty_cal WITH UNIQUE KEY iface_id day_type.

  TYPES:
    BEGIN OF ty_src,
      src_id          TYPE ty_src_id,
      iface_id        TYPE ty_iface_id,
      table_name      TYPE ty_tabname,
      file_key_field  TYPE ty_fieldname,
      file_name_field TYPE ty_fieldname,
      date_field      TYPE ty_fieldname,
      time_field      TYPE ty_fieldname,
      ts_field        TYPE ty_fieldname,
      status_field    TYPE ty_fieldname,
      count_field     TYPE ty_fieldname,
      amount_field    TYPE ty_fieldname,
      size_field      TYPE ty_fieldname,
      checksum_field  TYPE ty_fieldname,
      source_field    TYPE ty_fieldname,
      lob_field       TYPE ty_fieldname,
      "! Payment identity of per-payment ACK/NACK rows (dedupe, audit A39); blank = row count
      item_key_field  TYPE ty_fieldname,
      default_stage   TYPE ty_stage,
      adapter_class   TYPE zif_cd_ops_types=>ty_class_name,
      active          TYPE abap_bool,
      description     TYPE ty_text60,
    END OF ty_src.
  TYPES tt_src TYPE SORTED TABLE OF ty_src WITH UNIQUE KEY src_id.

  TYPES:
    BEGIN OF ty_srcmap,
      src_id       TYPE ty_src_id,
      status_value TYPE ty_status_value,
      stage        TYPE ty_stage,
      info         TYPE ty_text60,
    END OF ty_srcmap.
  TYPES tt_srcmap TYPE SORTED TABLE OF ty_srcmap WITH UNIQUE KEY src_id status_value.

  TYPES:
    BEGIN OF ty_lotcfg,
      iface_id          TYPE ty_iface_id,
      lot_type          TYPE ty_lot_type,
      hdr_table         TYPE ty_tabname,
      hdr_lot_field     TYPE ty_fieldname,
      hdr_link_field    TYPE ty_fieldname,
      item_table        TYPE ty_tabname,
      item_lot_field    TYPE ty_fieldname,
      item_key_field    TYPE ty_fieldname,
      item_status_field TYPE ty_fieldname,
      item_link_field   TYPE ty_fieldname,
      link_by           TYPE ty_link_by,
      done_values       TYPE ty_value_list,
      noc_sla_days      TYPE i,
      active            TYPE abap_bool,
    END OF ty_lotcfg.
  TYPES tt_lotcfg TYPE SORTED TABLE OF ty_lotcfg WITH UNIQUE KEY iface_id lot_type.

  TYPES:
    BEGIN OF ty_chk,
      check_id    TYPE ty_check_id,
      class_name  TYPE zif_cd_ops_types=>ty_class_name,
      severity    TYPE zif_cd_ops_types=>ty_severity,
      active      TYPE abap_bool,
      params      TYPE ty_params,
      description TYPE ty_text60,
    END OF ty_chk.
  TYPES tt_chk TYPE SORTED TABLE OF ty_chk WITH UNIQUE KEY check_id.

  "! Tables (and fields; '*' = all) the dynamic reader may read (ZCD_FMON_TABWL, audit A51)
  TYPES:
    BEGIN OF ty_tab_allow,
      table_name TYPE ty_tabname,
      field_name TYPE ty_fieldname,
    END OF ty_tab_allow.
  TYPES tt_tab_allow TYPE STANDARD TABLE OF ty_tab_allow WITH EMPTY KEY.

  " ---------------------------------------------------------------- registry
  TYPES:
    BEGIN OF ty_file,
      file_id           TYPE ty_file_id,
      iface_id          TYPE ty_iface_id,
      file_ref          TYPE ty_file_ref,
      direction         TYPE ty_direction,
      file_type         TYPE ty_file_type,
      source_sys        TYPE ty_system,
      lob               TYPE ty_lob,
      pay_method        TYPE ty_pay_method,
      file_name         TYPE ty_file_name,
      business_date     TYPE d,
      size_bytes        TYPE ty_size,
      size_known        TYPE abap_bool,
      record_count      TYPE i,
      control_total     TYPE zif_cd_ops_types=>ty_amount,
      checksum          TYPE ty_checksum,
      stage             TYPE ty_stage,
      outcome           TYPE ty_stage,
      unprocessed_count TYPE i,
      ack_count         TYPE i,
      ack_amount        TYPE zif_cd_ops_types=>ty_amount,
      "! ACK/NACK count reported by the source (X) - blank = not reported, not zero (audit A39)
      ack_known         TYPE abap_bool,
      nack_count        TYPE i,
      origin_rows       TYPE i,
      first_event_at    TYPE timestampl,
      last_event_at     TYPE timestampl,
      src_id            TYPE ty_src_id,
      src_key           TYPE ty_file_ref,
      created_at        TYPE timestampl,
      changed_at        TYPE timestampl,
      changed_by        TYPE syuname,
      "! Not stored: the row exists in ZCD_FMON_FILE and CHANGED_AT as read (version check, audit A04)
      db_exists         TYPE abap_bool,
      db_version        TYPE timestampl,
    END OF ty_file.
  "! Sweep: secondary keys for the checks - a file by ID (lot checks), the files of an
  "! interface and business date (late check); primary order unchanged
  TYPES tt_file TYPE STANDARD TABLE OF ty_file WITH EMPTY KEY
                WITH NON-UNIQUE SORTED KEY by_id COMPONENTS file_id
                WITH NON-UNIQUE SORTED KEY by_iface COMPONENTS iface_id business_date.

  TYPES:
    BEGIN OF ty_file_key,
      iface_id TYPE ty_iface_id,
      file_ref TYPE ty_file_ref,
    END OF ty_file_key.
  TYPES tt_file_key TYPE STANDARD TABLE OF ty_file_key WITH EMPTY KEY.
  TYPES tt_file_id TYPE STANDARD TABLE OF ty_file_id WITH EMPTY KEY.
  TYPES tt_file_name TYPE STANDARD TABLE OF ty_file_name WITH EMPTY KEY.
  TYPES tt_checksum TYPE STANDARD TABLE OF ty_checksum WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_event,
      file_id      TYPE ty_file_id,
      event_no     TYPE i,
      stage        TYPE ty_stage,
      event_at     TYPE timestampl,
      src_id       TYPE ty_src_id,
      src_key      TYPE ty_file_ref,
      record_count TYPE i,
      amount       TYPE zif_cd_ops_types=>ty_amount,
      info         TYPE ty_info,
      created_by   TYPE syuname,
      created_at   TYPE timestampl,
    END OF ty_event.
  "! Sweep: secondary key BY_FILE - the events of a file (SLA verdict) and the business
  "! event identity (engine de-duplication)
  TYPES tt_event TYPE STANDARD TABLE OF ty_event WITH EMPTY KEY
                 WITH NON-UNIQUE SORTED KEY by_file COMPONENTS file_id src_id src_key stage.

  " ---------------------------------------------------------------- legacy access
  TYPES:
    BEGIN OF ty_qfield,
      role  TYPE ty_role,
      field TYPE ty_fieldname,
    END OF ty_qfield.
  TYPES tt_qfield TYPE STANDARD TABLE OF ty_qfield WITH EMPTY KEY.
  TYPES tt_key_value TYPE STANDARD TABLE OF ty_key_value WITH EMPTY KEY.

  "! A read of a configured table. Every name is validated against the DDIC
  "! (ZCL_CD_FMON_QUERY=>VALIDATE) before the DAO executes it.
  TYPES:
    BEGIN OF ty_query,
      table_name TYPE ty_tabname,
      fields     TYPE tt_qfield,
      date_field TYPE ty_fieldname,
      date_kind  TYPE ty_date_kind,
      date_from  TYPE d,
      date_to    TYPE d,
      ts_from    TYPE timestampl,
      ts_to      TYPE timestampl,
      in_field   TYPE ty_fieldname,
      in_values  TYPE tt_key_value,
      max_rows   TYPE i,
    END OF ty_query.

  "! One row of a configured table, values as unformatted text, by role
  TYPES:
    BEGIN OF ty_raw_row,
      file_key    TYPE string,
      file_name   TYPE string,
      ev_date     TYPE string,
      ev_time     TYPE string,
      ev_ts       TYPE string,
      status      TYPE string,
      rec_count   TYPE string,
      amount      TYPE string,
      size        TYPE string,
      checksum    TYPE string,
      source      TYPE string,
      lob         TYPE string,
      lot_key     TYPE string,
      item_key    TYPE string,
      item_status TYPE string,
      file_link   TYPE string,
    END OF ty_raw_row.
  TYPES tt_raw_row TYPE STANDARD TABLE OF ty_raw_row WITH EMPTY KEY.

  "! Fix 8: one group of a grouped legacy read - the field values by role and the rows counted
  TYPES:
    BEGIN OF ty_raw_count,
      row       TYPE ty_raw_row,
      row_count TYPE int8,
    END OF ty_raw_count.
  TYPES tt_raw_count TYPE STANDARD TABLE OF ty_raw_count WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_ddic_field,
      fieldname TYPE ty_fieldname,
      inttype   TYPE ty_inttype,
      leng      TYPE i,
      keyflag   TYPE abap_bool,
    END OF ty_ddic_field.
  TYPES tt_ddic_field TYPE SORTED TABLE OF ty_ddic_field WITH UNIQUE KEY fieldname.

  TYPES:
    BEGIN OF ty_read_request,
      src       TYPE ty_src,
      maps      TYPE tt_srcmap,
      date_from TYPE d,
      date_to   TYPE d,
      time_zone TYPE ty_time_zone,
      max_rows  TYPE i,
    END OF ty_read_request.

  "! One legacy row translated to the file status model
  TYPES:
    BEGIN OF ty_src_record,
      src_id        TYPE ty_src_id,
      iface_id      TYPE ty_iface_id,
      file_ref      TYPE ty_file_ref,
      file_name     TYPE ty_file_name,
      raw_status    TYPE ty_status_value,
      "! Blank = status value not mapped in ZCD_FMON_SRCMAP
      stage         TYPE ty_stage,
      event_at      TYPE timestampl,
      business_date TYPE d,
      rec_count     TYPE i,
      count_known   TYPE abap_bool,
      amount        TYPE zif_cd_ops_types=>ty_amount,
      size_bytes    TYPE ty_size,
      size_known    TYPE abap_bool,
      checksum      TYPE ty_checksum,
      source_sys    TYPE ty_system,
      lob           TYPE ty_lob,
      "! Payment identity (ITEM_KEY_FIELD) of per-payment rows
      item_key      TYPE ty_key_value,
      "! Row failed conversion of a required or numeric field: quarantined, never counted (audit A52)
      malformed     TYPE abap_bool,
      malformed_role TYPE ty_role,
    END OF ty_src_record.
  TYPES tt_src_record TYPE STANDARD TABLE OF ty_src_record WITH EMPTY KEY.

  " ---------------------------------------------------------------- lots
  TYPES:
    BEGIN OF ty_lot_status,
      file_id     TYPE ty_file_id,
      lot_type    TYPE ty_lot_type,
      found       TYPE abap_bool,
      total_items TYPE i,
      done_items  TYPE i,
      open_items  TYPE i,
      "! Sample of open lot/item keys for the finding text
      open_keys   TYPE string,
      age_days    TYPE i,
      sla_days    TYPE i,
      "! The item scan hit the row cap: completion cannot be proven (audit A38)
      truncated   TYPE abap_bool,
    END OF ty_lot_status.
  TYPES tt_lot_status TYPE SORTED TABLE OF ty_lot_status WITH UNIQUE KEY file_id.

  " ---------------------------------------------------------------- checks
  TYPES:
    BEGIN OF ty_expect,
      iface_id       TYPE ty_iface_id,
      day_type       TYPE ty_day_type,
      expected_count TYPE i,
      ts_from        TYPE timestampl,
      ts_to          TYPE timestampl,
      fcal_id        TYPE ty_fcal_id,
    END OF ty_expect.
  TYPES tt_expect TYPE SORTED TABLE OF ty_expect WITH UNIQUE KEY iface_id.

  "! Everything a check may look at. Checks are pure: no SQL, no clock.
  TYPES:
    BEGIN OF ty_check_ctx,
      business_date TYPE d,
      now           TYPE timestampl,
      files         TYPE tt_file,
      events        TYPE tt_event,
      ifaces        TYPE tt_iface,
      slas          TYPE tt_sla,
      expects       TYPE tt_expect,
      lots          TYPE tt_lot_status,
      "! Older registry entries with the same name or checksum (duplicate check)
      history       TYPE tt_file,
    END OF ty_check_ctx.

  "! SLA verdict: ' ' = met or not yet due, M = stage not reached and overdue,
  "! L = stage reached but later than allowed
  TYPES ty_sla_state TYPE c LENGTH 1.
  CONSTANTS:
    BEGIN OF gc_sla_state,
      ok      TYPE ty_sla_state VALUE ' ',
      missing TYPE ty_sla_state VALUE 'M',
      late    TYPE ty_sla_state VALUE 'L',
      "! Only a later or different stage was observed: the stage itself is not evidenced
      inferred TYPE ty_sla_state VALUE 'I',
    END OF gc_sla_state.

  TYPES:
    BEGIN OF ty_sla_verdict,
      state       TYPE ty_sla_state,
      elapsed_min TYPE i,
      basis_at    TYPE timestampl,
      reached_at  TYPE timestampl,
    END OF ty_sla_verdict.

  " ---------------------------------------------------------------- result
  TYPES:
    BEGIN OF ty_board,
      sla_light         TYPE ty_light,
      sla_status        TYPE zif_cd_ops_types=>ty_rag,
      iface_id          TYPE ty_iface_id,
      direction         TYPE ty_direction,
      file_type         TYPE ty_file_type,
      source_sys        TYPE ty_system,
      lob               TYPE ty_lob,
      pay_method        TYPE ty_pay_method,
      owner             TYPE syuname,
      business_date     TYPE d,
      file_name         TYPE ty_file_name,
      stage             TYPE ty_stage,
      outcome           TYPE ty_stage,
      unprocessed_count TYPE i,
      record_count      TYPE i,
      control_total     TYPE zif_cd_ops_types=>ty_amount,
      ack_count         TYPE i,
      nack_count        TYPE i,
      first_event_at    TYPE timestampl,
      last_event_at     TYPE timestampl,
      finding_count     TYPE i,
      top_message       TYPE zif_cd_ops_types=>ty_message,
    END OF ty_board.
  TYPES tt_board TYPE STANDARD TABLE OF ty_board WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_result,
      run      TYPE zif_cd_ops_types=>ty_run,
      board    TYPE tt_board,
      findings TYPE zif_cd_ops_types=>tt_finding,
    END OF ty_result.

  "! Delivered default of a parameter: factory calendar (SCAL) when none is configured
  CONSTANTS:
    BEGIN OF gc_param_default,
      factory_cal TYPE string VALUE `US`,
    END OF gc_param_default.

  "! Object-key prefixes of engine findings (what failed: source, lot, calendar, check)
  CONSTANTS:
    BEGIN OF gc_engine_key,
      source   TYPE c LENGTH 4 VALUE 'SRC:',
      lot      TYPE c LENGTH 4 VALUE 'LOT:',
      calendar TYPE c LENGTH 4 VALUE 'CAL:',
      check    TYPE c LENGTH 4 VALUE 'CHK:',
      "! Object key of registry persistence findings
      registry TYPE c LENGTH 13 VALUE 'ZCD_FMON_FILE',
    END OF gc_engine_key.

  "! SLA check codes are built from the stage label: NO_<stage> (missing), <stage>_LATE
  CONSTANTS:
    BEGIN OF gc_sla_code,
      missing_prefix TYPE c LENGTH 3 VALUE 'NO_',
      late_suffix    TYPE c LENGTH 5 VALUE '_LATE',
      inferred_suffix TYPE c LENGTH 9 VALUE '_INFERRED',
    END OF gc_sla_code.

  "! Message numbers (class ZCD_OPS) of this area's user-facing texts
  CONSTANTS:
    BEGIN OF gc_msg,
      record_s_sent_ack_nack      TYPE zif_cd_ops_types=>ty_msgno VALUE '207',
      control_total_acknowledged  TYPE zif_cd_ops_types=>ty_msgno VALUE '210',
      reported_times_by_the_sourc TYPE zif_cd_ops_types=>ty_msgno VALUE '212',
      same_name_checksum_as_of    TYPE zif_cd_ops_types=>ty_msgno VALUE '213',
      first_event_after_the_windo TYPE zif_cd_ops_types=>ty_msgno VALUE '214',
      window_closed_of_file_s     TYPE zif_cd_ops_types=>ty_msgno VALUE '215',
      loaded_but_no_lot_found     TYPE zif_cd_ops_types=>ty_msgno VALUE '216',
      of_expected_file_s_received TYPE zif_cd_ops_types=>ty_msgno VALUE '217',
      file_s_on_a_day             TYPE zif_cd_ops_types=>ty_msgno VALUE '218',
      noc_entr_ies_open_after     TYPE zif_cd_ops_types=>ty_msgno VALUE '219',
      rejected_by_the_bank_record TYPE zif_cd_ops_types=>ty_msgno VALUE '221',
      processing_failed           TYPE zif_cd_ops_types=>ty_msgno VALUE '222',
      bytes_min_max               TYPE zif_cd_ops_types=>ty_msgno VALUE '223',
      after_min_sla_min           TYPE zif_cd_ops_types=>ty_msgno VALUE '224',
      source                      TYPE zif_cd_ops_types=>ty_msgno VALUE '225',
      reference_of_reused_on_conf TYPE zif_cd_ops_types=>ty_msgno VALUE '226',
      source_no_interface_matches TYPE zif_cd_ops_types=>ty_msgno VALUE '227',
      source_status_has_no_stage  TYPE zif_cd_ops_types=>ty_msgno VALUE '228',
      lot_reader                  TYPE zif_cd_ops_types=>ty_msgno VALUE '229',
      factory_calendar_calendar_d TYPE zif_cd_ops_types=>ty_msgno VALUE '231',
      factory_calendar_normal_day TYPE zif_cd_ops_types=>ty_msgno VALUE '233',
      check                       TYPE zif_cd_ops_types=>ty_msgno VALUE '234',
      registry_not_saved          TYPE zif_cd_ops_types=>ty_msgno VALUE '235',
      file_s_finding_s            TYPE zif_cd_ops_types=>ty_msgno VALUE '236',
      alert_dispatch_failed       TYPE zif_cd_ops_types=>ty_msgno VALUE '237',
      lot_unprocessed             TYPE zif_cd_ops_types=>ty_msgno VALUE '238',
      event_info                  TYPE zif_cd_ops_types=>ty_msgno VALUE '239',
      newer_registry_state        TYPE zif_cd_ops_types=>ty_msgno VALUE '240',
      lot_scan_truncated          TYPE zif_cd_ops_types=>ty_msgno VALUE '241',
      reference_ambiguous         TYPE zif_cd_ops_types=>ty_msgno VALUE '242',
      malformed_rows              TYPE zif_cd_ops_types=>ty_msgno VALUE '243',
      database_error              TYPE zif_cd_ops_types=>ty_msgno VALUE '246',
      lot_items_open              TYPE zif_cd_ops_types=>ty_msgno VALUE '247',
      factory_calendar_age_unknwn TYPE zif_cd_ops_types=>ty_msgno VALUE '248',
      prism_failed                TYPE zif_cd_ops_types=>ty_msgno VALUE '265',
      prism_unknown_file          TYPE zif_cd_ops_types=>ty_msgno VALUE '266',
      prism_not_loaded            TYPE zif_cd_ops_types=>ty_msgno VALUE '267',
    END OF gc_msg.

ENDINTERFACE.
