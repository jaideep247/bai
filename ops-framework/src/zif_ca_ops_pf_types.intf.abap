*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_types.intf.abap
*& Purpose:
*& Types and constants of the payment file lifecycle (module CASH_OPS,
*& docs/PAYMENT_FILE_LIFECYCLE.md): milestones of a payment file (payment
*& run, SAP generation, middleware pickup, onward delivery, bank receipt,
*& bank acceptance, posting / settlement - receipt and acceptance are two
*& milestones), outcomes, milestone statuses, file states, evaluation
*& states, results of a business day, adapter roles and their interfaces,
*& configuration rows (ZCA_OPS_PFTYP / PFSTG / PFMAP / PFADP), what an
*& adapter delivers, the register rows (ZCA_OPS_PFFILE / PFPAY / PFEVT /
*& PFMST / PFSRC / PFDAY), check codes, parameters and messages. No logic.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*& 2026-11-16 | TY_TICKET-COMPANY_CODE: a ticket carries its file's company code only (build Q).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file lifecycle types</p>
INTERFACE zif_ca_ops_pf_types
  PUBLIC.

  TYPES ty_file_type   TYPE c LENGTH 10.
  TYPES ty_milestone   TYPE c LENGTH 10.
  TYPES ty_outcome     TYPE c LENGTH 10.
  TYPES ty_ms_status   TYPE c LENGTH 10.
  TYPES ty_state       TYPE c LENGTH 10.
  TYPES ty_day_result  TYPE c LENGTH 10.
  TYPES ty_role        TYPE c LENGTH 10.
  TYPES ty_source_id   TYPE c LENGTH 10.
  TYPES ty_source_type TYPE c LENGTH 4.
  TYPES ty_native_key  TYPE c LENGTH 70.
  TYPES ty_status      TYPE c LENGTH 30.
  TYPES ty_pay_key     TYPE c LENGTH 40.
  TYPES ty_event_key   TYPE c LENGTH 40.
  TYPES ty_batch_id    TYPE c LENGTH 35.
  TYPES ty_flag        TYPE c LENGTH 1.
  TYPES ty_setting     TYPE c LENGTH 255.
  TYPES ty_reason      TYPE c LENGTH 255.
  TYPES ty_time_zone   TYPE c LENGTH 6.
  TYPES ty_amount      TYPE p LENGTH 12 DECIMALS 2.
  TYPES ty_currency    TYPE c LENGTH 5.
  TYPES ty_file_id     TYPE sysuuid_x16.
  TYPES ty_ticket_ref  TYPE c LENGTH 40.
  TYPES tt_file_id     TYPE SORTED TABLE OF ty_file_id WITH UNIQUE KEY table_line.
  TYPES tt_native_key  TYPE STANDARD TABLE OF ty_native_key WITH EMPTY KEY.

  "! Milestones of a payment file, in their order (GC_MILESTONE_ORDER). Receipt (the bank has the file) and
  "! acceptance (the bank accepted the payments) are distinct and never collapsed
  CONSTANTS:
    BEGIN OF gc_milestone,
      payrun    TYPE ty_milestone VALUE 'PAYRUN',
      generated TYPE ty_milestone VALUE 'GENERATED',
      pickup    TYPE ty_milestone VALUE 'PICKUP',
      delivered TYPE ty_milestone VALUE 'DELIVERED',
      receipt   TYPE ty_milestone VALUE 'RECEIPT',
      accepted  TYPE ty_milestone VALUE 'ACCEPTED',
      settled   TYPE ty_milestone VALUE 'SETTLED',
    END OF gc_milestone.
  "! The order of the milestones (rank = position, 1 = payment run)
  CONSTANTS gc_milestone_order TYPE string VALUE `PAYRUN,GENERATED,PICKUP,DELIVERED,RECEIPT,ACCEPTED,SETTLED`.

  "! Outcome of an event (status mapping ZCA_OPS_PFMAP): INFO is evidence that moves nothing
  CONSTANTS:
    BEGIN OF gc_outcome,
      ok       TYPE ty_outcome VALUE 'OK',
      rejected TYPE ty_outcome VALUE 'REJECTED',
      partial  TYPE ty_outcome VALUE 'PARTIAL',
      failed   TYPE ty_outcome VALUE 'FAILED',
      info     TYPE ty_outcome VALUE 'INFO',
    END OF gc_outcome.

  "! Status of a milestone of a file (stage timeline)
  CONSTANTS:
    BEGIN OF gc_ms_status,
      reached  TYPE ty_ms_status VALUE 'REACHED',
      late     TYPE ty_ms_status VALUE 'LATE',
      implied  TYPE ty_ms_status VALUE 'IMPLIED',
      pending  TYPE ty_ms_status VALUE 'PENDING',
      missing  TYPE ty_ms_status VALUE 'MISSING',
      rejected TYPE ty_ms_status VALUE 'REJECTED',
      partial  TYPE ty_ms_status VALUE 'PARTIAL',
      failed   TYPE ty_ms_status VALUE 'FAILED',
      unknown  TYPE ty_ms_status VALUE 'UNKNOWN',
    END OF gc_ms_status.

  "! State of a file
  CONSTANTS:
    BEGIN OF gc_state,
      open     TYPE ty_state VALUE 'OPEN',
      done     TYPE ty_state VALUE 'DONE',
      rejected TYPE ty_state VALUE 'REJECTED',
      partial  TYPE ty_state VALUE 'PARTIAL',
      failed   TYPE ty_state VALUE 'FAILED',
      replaced TYPE ty_state VALUE 'REPLACED',
    END OF gc_state.

  "! Evaluation of a file or a day: C complete, P partial, N not evaluated (a source failed), S a source is stale
  CONSTANTS:
    BEGIN OF gc_eval,
      complete      TYPE ty_flag VALUE 'C',
      partial       TYPE ty_flag VALUE 'P',
      not_evaluated TYPE ty_flag VALUE 'N',
      stale         TYPE ty_flag VALUE 'S',
    END OF gc_eval.

  "! Result of a business day of a file type (expected versus observed)
  CONSTANTS:
    BEGIN OF gc_day,
      ok       TYPE ty_day_result VALUE 'OK',
      zero_ok  TYPE ty_day_result VALUE 'ZERO_OK',
      holiday  TYPE ty_day_result VALUE 'HOLIDAY',
      stale    TYPE ty_day_result VALUE 'STALE',
      not_eval TYPE ty_day_result VALUE 'NOT_EVAL',
      missing  TYPE ty_day_result VALUE 'MISSING',
      partial  TYPE ty_day_result VALUE 'PARTIAL',
      pending  TYPE ty_day_result VALUE 'PENDING',
    END OF gc_day.

  "! Kind of a calendar day: B business day, H holiday or weekend
  CONSTANTS:
    BEGIN OF gc_day_kind,
      business TYPE ty_flag VALUE 'B',
      holiday  TYPE ty_flag VALUE 'H',
    END OF gc_day_kind.

  "! Adapter roles (ZCA_OPS_PFADP-ROLE)
  CONSTANTS:
    BEGIN OF gc_role,
      file     TYPE ty_role VALUE 'FILE',
      transfer TYPE ty_role VALUE 'TRANSFER',
      ack      TYPE ty_role VALUE 'ACK',
      sched    TYPE ty_role VALUE 'SCHED',
      stmt     TYPE ty_role VALUE 'STMT',
      ticket   TYPE ty_role VALUE 'TICKET',
      calendar TYPE ty_role VALUE 'CALENDAR',
    END OF gc_role.

  "! Interfaces of the roles (checked by RTTI when the adapter is created; ZIF_CA_OPS_PF_ADAPTER by all)
  CONSTANTS:
    BEGIN OF gc_intf,
      adapter  TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_ADAPTER',
      file     TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_FILE_SRC',
      transfer TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_TRANSFER_SRC',
      ack      TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_ACK_SRC',
      sched    TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_SCHED_SRC',
      stmt     TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_STMT_SRC',
      ticket   TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_TICKET_SINK',
      calendar TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_PF_CALENDAR',
    END OF gc_intf.

  "! Delivered default classes: business calendar (factory calendar) and ticket sink (log only)
  CONSTANTS:
    BEGIN OF gc_default_class,
      calendar TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_OPS_PF_CALENDAR',
      ticket   TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_OPS_PF_TICKET_LOG',
    END OF gc_default_class.

  "! Granularity of the bank acknowledgement
  CONSTANTS:
    BEGIN OF gc_ack_level,
      file    TYPE ty_flag VALUE 'F',
      batch   TYPE ty_flag VALUE 'B',
      payment TYPE ty_flag VALUE 'P',
      none    TYPE ty_flag VALUE 'N',
    END OF gc_ack_level.

  "! Deadline of a milestone: T clock time on a business day, O offset after another milestone
  CONSTANTS:
    BEGIN OF gc_due_kind,
      clock  TYPE ty_flag VALUE 'T',
      offset TYPE ty_flag VALUE 'O',
    END OF gc_due_kind.

  "! Read status of a source: S read, P read in part, F failed
  CONSTANTS:
    BEGIN OF gc_src_status,
      read    TYPE ty_flag VALUE 'S',
      partial TYPE ty_flag VALUE 'P',
      failed  TYPE ty_flag VALUE 'F',
    END OF gc_src_status.

  "! Source type of evidence (= ZIF_CA_OPS_EXC_CONTRACT=>GC_KIND)
  CONSTANTS:
    BEGIN OF gc_source_type,
      sap  TYPE ty_source_type VALUE 'SAP',
      mw   TYPE ty_source_type VALUE 'MW',
      bank TYPE ty_source_type VALUE 'BANK',
    END OF gc_source_type.

  "! Ticket sink result: L logged only, C created, F failed
  CONSTANTS:
    BEGIN OF gc_ticket,
      logged  TYPE ty_flag VALUE 'L',
      created TYPE ty_flag VALUE 'C',
      failed  TYPE ty_flag VALUE 'F',
    END OF gc_ticket.
  CONSTANTS gc_ticket_logged TYPE ty_ticket_ref VALUE 'LOGGED'.

  "! Object types and rule of the findings
  CONSTANTS:
    BEGIN OF gc_object_type,
      file   TYPE zif_ca_ops_types=>ty_object_type VALUE 'PAYFILE',
      day    TYPE zif_ca_ops_types=>ty_object_type VALUE 'PFDAY',
      source TYPE zif_ca_ops_types=>ty_object_type VALUE 'PFSOURCE',
    END OF gc_object_type.
  CONSTANTS gc_rule_id TYPE zif_ca_ops_types=>ty_rule_id VALUE 'PAYFILE'.
  CONSTANTS gc_key_separator TYPE c LENGTH 1 VALUE '/'.

  "! Check codes of ZCL_CA_OPS_CHK_PAYFILE (one finding per file and currency: where the file stopped)
  CONSTANTS:
    BEGIN OF gc_code,
      "! The flagship: generated (the job finished) but no acceptance of the bank past its deadline
      ack_missing     TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_ACK_MISSING',
      receipt_missing TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_RECEIPT_MISSING',
      not_transferred TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_NOT_TRANSFERRED',
      not_generated   TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_NOT_GENERATED',
      not_settled     TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_NOT_SETTLED',
      job_failed      TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_JOB_FAILED',
      transfer_failed TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_TRANSFER_FAILED',
      rejected        TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_ACK_REJECTED',
      partial         TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_ACK_PARTIAL',
      conflict        TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_ACK_CONFLICT',
      late            TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_STAGE_LATE',
      dup_exposure    TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_DUP_EXPOSURE',
      orig_ack        TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_ORIG_ACK_AFTER_REISSUE',
      file_missing    TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_FILE_MISSING',
      not_evaluated   TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_NOT_EVALUATED',
      stale           TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_SOURCE_STALE',
      more            TYPE zif_ca_ops_types=>ty_check_code VALUE 'PF_MORE_FILES',
    END OF gc_code.

  "! Parameters of area CA_OPS (prefix PF_) [default]
  CONSTANTS:
    BEGIN OF gc_param,
      "! A first read of a source (no watermark) starts this many days back [3]
      lookback   TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_LOOKBACK_DAYS',
      "! A read starts this many minutes before the watermark (late and out-of-order records) [60]
      overlap    TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_OVERLAP_MIN',
      "! Days a file stays under watch after its business date when its type names none [10]
      open_days  TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_OPEN_DAYS',
      "! Minutes after which a source's data is stale when its file type names none [120]
      stale_min  TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_STALE_MIN',
      "! Minutes overdue before a finding is an error when its milestone names none [30]
      grace_min  TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_GRACE_MIN',
      "! Minutes overdue from which a finding blocks (B) [240]
      red_min    TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_BREACH_RED_MIN',
      "! Amounts from which a finding blocks: list of [company code:]currency amount, e.g. USD 1000000 or
      "! 1000:EUR 500000 - compared only with a finding of that currency (and company code) [none]
      amount_red TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_AMOUNT_RED',
      "! Payments kept per file; more are counted only (the file is then partial) [5000]
      max_pay    TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_MAX_PAYMENTS',
      "! Findings per file type and run; more are summarised (the check is then partial) [200]
      max_finds  TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_MAX_FINDINGS',
      "! Evidence rows per finding [20]
      max_evid   TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_EVIDENCE_MAX',
      "! Days the register keeps a file after its business date (0 = never removed) [400]
      retention  TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_RETENTION_DAYS',
    END OF gc_param.
  "! Area-specific amount limits: PF_AMOUNT_RED_<area> (same syntax; read before PF_AMOUNT_RED)
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      amount_red TYPE zif_ca_ops_types=>ty_param_name VALUE 'PF_AMOUNT_RED_',
    END OF gc_param_prefix.

  CONSTANTS:
    BEGIN OF gc_default,
      lookback  TYPE i VALUE 3,
      overlap   TYPE i VALUE 60,
      open_days TYPE i VALUE 10,
      stale_min TYPE i VALUE 120,
      grace_min TYPE i VALUE 30,
      red_min   TYPE i VALUE 240,
      max_pay   TYPE i VALUE 5000,
      max_finds TYPE i VALUE 200,
      max_evid  TYPE i VALUE 20,
      retention TYPE i VALUE 400,
    END OF gc_default.

  "! Messages of ZCA_OPS (370-399)
  CONSTANTS:
    BEGIN OF gc_msg,
      summary         TYPE zif_ca_ops_types=>ty_msgno VALUE '370',
      ack_missing     TYPE zif_ca_ops_types=>ty_msgno VALUE '371',
      receipt_missing TYPE zif_ca_ops_types=>ty_msgno VALUE '372',
      not_transferred TYPE zif_ca_ops_types=>ty_msgno VALUE '373',
      job_failed      TYPE zif_ca_ops_types=>ty_msgno VALUE '374',
      rejected        TYPE zif_ca_ops_types=>ty_msgno VALUE '375',
      partial         TYPE zif_ca_ops_types=>ty_msgno VALUE '376',
      file_missing    TYPE zif_ca_ops_types=>ty_msgno VALUE '378',
      late            TYPE zif_ca_ops_types=>ty_msgno VALUE '379',
      dup_exposure    TYPE zif_ca_ops_types=>ty_msgno VALUE '380',
      orig_ack        TYPE zif_ca_ops_types=>ty_msgno VALUE '381',
      conflict        TYPE zif_ca_ops_types=>ty_msgno VALUE '382',
      not_evaluated   TYPE zif_ca_ops_types=>ty_msgno VALUE '383',
      stale           TYPE zif_ca_ops_types=>ty_msgno VALUE '384',
      ms_missing      TYPE zif_ca_ops_types=>ty_msgno VALUE '385',
      not_adapter     TYPE zif_ca_ops_types=>ty_msgno VALUE '386',
      no_file_source  TYPE zif_ca_ops_types=>ty_msgno VALUE '387',
      unmapped        TYPE zif_ca_ops_types=>ty_msgno VALUE '388',
      ticket_logged   TYPE zif_ca_ops_types=>ty_msgno VALUE '389',
      day_not_eval    TYPE zif_ca_ops_types=>ty_msgno VALUE '390',
      zero_ok         TYPE zif_ca_ops_types=>ty_msgno VALUE '391',
      holiday         TYPE zif_ca_ops_types=>ty_msgno VALUE '392',
      calendar        TYPE zif_ca_ops_types=>ty_msgno VALUE '393',
      basis_missing   TYPE zif_ca_ops_types=>ty_msgno VALUE '394',
      pay_cut         TYPE zif_ca_ops_types=>ty_msgno VALUE '395',
      more            TYPE zif_ca_ops_types=>ty_msgno VALUE '396',
      time_zone       TYPE zif_ca_ops_types=>ty_msgno VALUE '397',
      transfer_failed TYPE zif_ca_ops_types=>ty_msgno VALUE '398',
      day_stale       TYPE zif_ca_ops_types=>ty_msgno VALUE '399',
    END OF gc_msg.

  "! A file type (ZCA_OPS_PFTYP)
  TYPES:
    BEGIN OF ty_type_cfg,
      area           TYPE zif_ca_ops_types=>ty_area,
      file_type      TYPE ty_file_type,
      description    TYPE c LENGTH 60,
      process_id     TYPE zif_ca_ops_chk_types=>ty_process_id,
      direction      TYPE ty_flag,
      ack_level      TYPE ty_flag,
      ack_multi      TYPE abap_bool,
      calendar_id    TYPE zif_ca_ops_exc_contract=>ty_calendar_id,
      time_zone      TYPE ty_time_zone,
      day_cutoff     TYPE t,
      expected_files TYPE i,
      zero_ok        TYPE abap_bool,
      stale_min      TYPE i,
      open_days      TYPE i,
      active         TYPE abap_bool,
    END OF ty_type_cfg.
  TYPES tt_type_cfg TYPE STANDARD TABLE OF ty_type_cfg WITH EMPTY KEY.

  "! A milestone of a file type (ZCA_OPS_PFSTG)
  TYPES:
    BEGIN OF ty_stage,
      area       TYPE zif_ca_ops_types=>ty_area,
      file_type  TYPE ty_file_type,
      milestone  TYPE ty_milestone,
      required   TYPE abap_bool,
      due_kind   TYPE ty_flag,
      due_time   TYPE t,
      day_offset TYPE i,
      basis      TYPE ty_milestone,
      offset_min TYPE i,
      grace_min  TYPE i,
      active     TYPE abap_bool,
    END OF ty_stage.
  TYPES tt_stage TYPE STANDARD TABLE OF ty_stage WITH EMPTY KEY.

  "! A status mapping row (ZCA_OPS_PFMAP)
  TYPES:
    BEGIN OF ty_map,
      area      TYPE zif_ca_ops_types=>ty_area,
      source_id TYPE ty_source_id,
      status    TYPE ty_status,
      milestone TYPE ty_milestone,
      outcome   TYPE ty_outcome,
      active    TYPE abap_bool,
    END OF ty_map.
  TYPES tt_map TYPE SORTED TABLE OF ty_map WITH UNIQUE KEY source_id status.

  "! An adapter (ZCA_OPS_PFADP)
  TYPES:
    BEGIN OF ty_adapter,
      area        TYPE zif_ca_ops_types=>ty_area,
      file_type   TYPE ty_file_type,
      role        TYPE ty_role,
      source_id   TYPE ty_source_id,
      class_name  TYPE zif_ca_ops_types=>ty_class_name,
      setting     TYPE ty_setting,
      source_type TYPE ty_source_type,
      active      TYPE abap_bool,
    END OF ty_adapter.
  TYPES tt_adapter TYPE STANDARD TABLE OF ty_adapter WITH EMPTY KEY.

  "! A file the engine already knows (an adapter that reads by file looks them up)
  TYPES:
    BEGIN OF ty_known_file,
      native_key TYPE ty_native_key,
      bukrs      TYPE bukrs,
      run_date   TYPE d,
      run_id     TYPE c LENGTH 5,
      bus_date   TYPE d,
      gen_at     TYPE timestampl,
    END OF ty_known_file.
  TYPES tt_known_file TYPE STANDARD TABLE OF ty_known_file WITH EMPTY KEY.

  "! What the engine asks an adapter: the window (UTC, overlap applied), the adapter row and the open files
  TYPES:
    BEGIN OF ty_request,
      area      TYPE zif_ca_ops_types=>ty_area,
      file_type TYPE ty_file_type,
      adapter   TYPE ty_adapter,
      from_ts   TYPE timestampl,
      to_ts     TYPE timestampl,
      "! X = no watermark yet (the look-back applied)
      first     TYPE abap_bool,
      "! Most records to return (a source with more answers partial)
      max       TYPE i,
      files     TYPE tt_known_file,
    END OF ty_request.

  "! A payment of a file as the file source delivers it (the partner in full; the engine masks it)
  TYPES:
    BEGIN OF ty_src_payment,
      pay_key      TYPE ty_pay_key,
      bukrs        TYPE bukrs,
      currency     TYPE ty_currency,
      amount       TYPE ty_amount,
      amount_known TYPE abap_bool,
      partner      TYPE c LENGTH 20,
      pay_doc      TYPE c LENGTH 24,
      pay_method   TYPE c LENGTH 10,
      batch_id     TYPE ty_batch_id,
    END OF ty_src_payment.
  TYPES tt_src_payment TYPE STANDARD TABLE OF ty_src_payment WITH EMPTY KEY.

  "! A file as the file source delivers it
  TYPES:
    BEGIN OF ty_src_file,
      native_key      TYPE ty_native_key,
      bukrs           TYPE bukrs,
      run_date        TYPE d,
      run_id          TYPE c LENGTH 5,
      pay_method      TYPE c LENGTH 10,
      house_bank      TYPE c LENGTH 5,
      account_id      TYPE c LENGTH 5,
      "! Business date (initial = derived from GEN_AT with the cut-off and calendar of the file type)
      bus_date        TYPE d,
      "! When the payment run / generation produced the file (UTC; evidences milestone PAYRUN)
      gen_at          TYPE timestampl,
      "! Native key of the file this one replaces (reissue; blank = none or not known)
      predecessor_key TYPE ty_native_key,
      "! Payments the file holds (0 = the number of PAYMENTS)
      pay_count       TYPE i,
      payments        TYPE tt_src_payment,
      link_object     TYPE zif_ca_ops_exc_contract=>ty_link_object,
      link_value      TYPE zif_ca_ops_exc_contract=>ty_link_value,
    END OF ty_src_file.
  TYPES tt_src_file TYPE STANDARD TABLE OF ty_src_file WITH EMPTY KEY.

  "! What a file source returns: the files, how fresh the source is, whether it is complete
  TYPES:
    BEGIN OF ty_file_batch,
      files    TYPE tt_src_file,
      "! The source is complete up to this time (UTC; initial = the end of the window)
      as_of    TYPE timestampl,
      "! X = not everything of the window was returned (the watermark does not move past it)
      partial  TYPE abap_bool,
      reason   TYPE ty_reason,
    END OF ty_file_batch.

  "! An event as an event source (transfer, acknowledgement, scheduler, statement) delivers it
  TYPES:
    BEGIN OF ty_src_event,
      source_event_id TYPE c LENGTH 70,
      event_version   TYPE i,
      native_status   TYPE ty_status,
      "! The file the event is about (its native key; blank = by run key, payment or batch)
      native_key      TYPE ty_native_key,
      "! An acknowledgement of several files: their native keys (ACK_MULTI of the file type)
      covers          TYPE tt_native_key,
      run_date        TYPE d,
      run_id          TYPE c LENGTH 5,
      bukrs           TYPE bukrs,
      pay_key         TYPE ty_pay_key,
      batch_id        TYPE ty_batch_id,
      occurred_at     TYPE timestampl,
      bus_date        TYPE d,
      amount          TYPE ty_amount,
      currency        TYPE ty_currency,
      item_count      TYPE i,
      logsys          TYPE c LENGTH 10,
      sys_client      TYPE c LENGTH 3,
      "! Scheduler: the SAP job (name and count)
      job_name        TYPE c LENGTH 32,
      job_count       TYPE c LENGTH 8,
      link_object     TYPE zif_ca_ops_exc_contract=>ty_link_object,
      link_value      TYPE zif_ca_ops_exc_contract=>ty_link_value,
      info            TYPE c LENGTH 120,
    END OF ty_src_event.
  TYPES tt_src_event TYPE STANDARD TABLE OF ty_src_event WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_event_batch,
      events  TYPE tt_src_event,
      as_of   TYPE timestampl,
      partial TYPE abap_bool,
      reason  TYPE ty_reason,
    END OF ty_event_batch.

  "! A file of the register (ZCA_OPS_PFFILE)
  TYPES:
    BEGIN OF ty_file,
      area             TYPE zif_ca_ops_types=>ty_area,
      file_id          TYPE ty_file_id,
      file_type        TYPE ty_file_type,
      source_id        TYPE ty_source_id,
      native_key       TYPE ty_native_key,
      bukrs            TYPE bukrs,
      run_date         TYPE d,
      run_id           TYPE c LENGTH 5,
      pay_method       TYPE c LENGTH 10,
      house_bank       TYPE c LENGTH 5,
      account_id       TYPE c LENGTH 5,
      bus_date         TYPE d,
      gen_at           TYPE timestampl,
      gen_job          TYPE c LENGTH 32,
      gen_jobcount     TYPE c LENGTH 8,
      predecessor      TYPE ty_file_id,
      pay_count        TYPE i,
      unknown_count    TYPE i,
      pay_partial      TYPE abap_bool,
      stage            TYPE ty_milestone,
      next_ms          TYPE ty_milestone,
      state            TYPE ty_state,
      deadline_at      TYPE timestampl,
      overdue_min      TYPE i,
      calendar_id      TYPE zif_ca_ops_exc_contract=>ty_calendar_id,
      ack_conflict     TYPE abap_bool,
      pay_rejected     TYPE i,
      pay_open         TYPE i,
      late_ms          TYPE ty_milestone,
      late_min         TYPE i,
      eval_state       TYPE ty_flag,
      eval_reason      TYPE ty_reason,
      eval_at          TYPE timestampl,
      last_valid_at    TYPE timestampl,
      last_valid_state TYPE ty_state,
      ticket_ref       TYPE ty_ticket_ref,
      created_at       TYPE timestampl,
      changed_at       TYPE timestampl,
    END OF ty_file.
  TYPES tt_file TYPE STANDARD TABLE OF ty_file WITH EMPTY KEY.

  "! A payment of a file of the register (ZCA_OPS_PFPAY)
  TYPES:
    BEGIN OF ty_payment,
      area           TYPE zif_ca_ops_types=>ty_area,
      file_id        TYPE ty_file_id,
      pay_key        TYPE ty_pay_key,
      bukrs          TYPE bukrs,
      currency       TYPE ty_currency,
      amount         TYPE ty_amount,
      amount_known   TYPE abap_bool,
      partner_masked TYPE c LENGTH 20,
      pay_doc        TYPE c LENGTH 24,
      pay_method     TYPE c LENGTH 10,
      batch_id       TYPE ty_batch_id,
      ack_outcome    TYPE ty_outcome,
      ack_at         TYPE timestampl,
      other_file     TYPE ty_file_id,
    END OF ty_payment.
  TYPES tt_payment TYPE STANDARD TABLE OF ty_payment WITH EMPTY KEY.

  "! An evidence row of a file (ZCA_OPS_PFEVT)
  TYPES:
    BEGIN OF ty_event,
      area            TYPE zif_ca_ops_types=>ty_area,
      event_key       TYPE ty_event_key,
      file_id         TYPE ty_file_id,
      milestone       TYPE ty_milestone,
      outcome         TYPE ty_outcome,
      native_status   TYPE ty_status,
      source_id       TYPE ty_source_id,
      source_type     TYPE ty_source_type,
      logsys          TYPE c LENGTH 10,
      sys_client      TYPE c LENGTH 3,
      bukrs           TYPE bukrs,
      native_key      TYPE ty_native_key,
      source_event_id TYPE c LENGTH 70,
      event_version   TYPE i,
      occurred_at     TYPE timestampl,
      observed_at     TYPE timestampl,
      bus_date        TYPE d,
      amount          TYPE ty_amount,
      currency        TYPE ty_currency,
      item_count      TYPE i,
      ack_scope       TYPE ty_flag,
      batch_id        TYPE ty_batch_id,
      pay_key         TYPE ty_pay_key,
      corr_quality    TYPE zif_ca_ops_exc_contract=>ty_quality,
      repeat_no       TYPE i,
      link_object     TYPE zif_ca_ops_exc_contract=>ty_link_object,
      link_value      TYPE zif_ca_ops_exc_contract=>ty_link_value,
      info            TYPE c LENGTH 120,
      created_at      TYPE timestampl,
    END OF ty_event.
  TYPES tt_event TYPE STANDARD TABLE OF ty_event WITH EMPTY KEY.

  "! Status of a milestone of a file (ZCA_OPS_PFMST)
  TYPES:
    BEGIN OF ty_ms,
      area         TYPE zif_ca_ops_types=>ty_area,
      file_id      TYPE ty_file_id,
      milestone    TYPE ty_milestone,
      seq          TYPE i,
      required     TYPE abap_bool,
      status       TYPE ty_ms_status,
      outcome      TYPE ty_outcome,
      due_at       TYPE timestampl,
      observed_at  TYPE timestampl,
      late_min     TYPE i,
      event_key    TYPE ty_event_key,
      evaluated_at TYPE timestampl,
    END OF ty_ms.
  TYPES tt_ms TYPE STANDARD TABLE OF ty_ms WITH EMPTY KEY.

  "! State of a source (ZCA_OPS_PFSRC)
  TYPES:
    BEGIN OF ty_source,
      area           TYPE zif_ca_ops_types=>ty_area,
      source_id      TYPE ty_source_id,
      role           TYPE ty_role,
      watermark      TYPE timestampl,
      as_of          TYPE timestampl,
      last_run_at    TYPE timestampl,
      last_ok_at     TYPE timestampl,
      status         TYPE ty_flag,
      reason         TYPE ty_reason,
      read_count     TYPE i,
      unmapped_count TYPE i,
    END OF ty_source.
  TYPES tt_source TYPE STANDARD TABLE OF ty_source WITH EMPTY KEY.

  "! Expected versus observed of a business day (ZCA_OPS_PFDAY)
  TYPES:
    BEGIN OF ty_day,
      area              TYPE zif_ca_ops_types=>ty_area,
      file_type         TYPE ty_file_type,
      bus_date          TYPE d,
      day_kind          TYPE ty_flag,
      expected          TYPE i,
      observed          TYPE i,
      result            TYPE ty_day_result,
      reason            TYPE ty_reason,
      as_of             TYPE timestampl,
      watermark         TYPE timestampl,
      completeness      TYPE ty_flag,
      eval_at           TYPE timestampl,
      last_valid_result TYPE ty_day_result,
      last_valid_at     TYPE timestampl,
    END OF ty_day.
  TYPES tt_day TYPE STANDARD TABLE OF ty_day WITH EMPTY KEY.

  "! Amounts of a file per currency (aggregated in the database; never summed across currencies)
  TYPES:
    BEGIN OF ty_total,
      file_id       TYPE ty_file_id,
      currency      TYPE ty_currency,
      pay_count     TYPE i,
      amount        TYPE ty_amount,
      unknown_count TYPE i,
      dup_count     TYPE i,
      dup_amount    TYPE ty_amount,
    END OF ty_total.
  TYPES tt_total TYPE STANDARD TABLE OF ty_total WITH EMPTY KEY.

  "! Result of the lifecycle of one file (ZCL_CA_OPS_PF_LIFECYCLE)
  TYPES:
    BEGIN OF ty_eval,
      milestones   TYPE tt_ms,
      "! Last milestone reached in order (where the process stopped) and the next required one not reached
      stage        TYPE ty_milestone,
      next_ms      TYPE ty_milestone,
      state        TYPE ty_state,
      deadline_at  TYPE timestampl,
      overdue_min  TYPE i,
      eval_state   TYPE ty_flag,
      eval_reason  TYPE ty_reason,
      "! Payment-level acknowledgement: accepted, rejected and not acknowledged payments
      pay_accepted TYPE i,
      pay_rejected TYPE i,
      pay_open     TYPE i,
      "! The bank sent accepted and rejected for the same scope
      conflict     TYPE abap_bool,
      "! The first milestone reached late (blank = none) and by how many minutes
      late_ms      TYPE ty_milestone,
      late_min     TYPE i,
    END OF ty_eval.

  "! A ticket for the ticket sink. Build Q (company-code isolation): one ticket per file, carrying the file's own
  "! company code only - never a payment, a payee or another company code's data
  TYPES:
    BEGIN OF ty_ticket,
      area         TYPE zif_ca_ops_types=>ty_area,
      file_type    TYPE ty_file_type,
      file_id      TYPE ty_file_id,
      native_key   TYPE ty_native_key,
      milestone    TYPE ty_milestone,
      overdue      TYPE i,
      text         TYPE zif_ca_ops_types=>ty_message,
      company_code TYPE bukrs,
    END OF ty_ticket.
  TYPES:
    BEGIN OF ty_ticket_result,
      status TYPE ty_flag,
      ref    TYPE ty_ticket_ref,
      text   TYPE zif_ca_ops_types=>ty_message,
    END OF ty_ticket_result.

  "! Result of the ingestion of one file type (report ZCA_OPS_PF_RUN)
  TYPES:
    BEGIN OF ty_run_result,
      file_type   TYPE ty_file_type,
      files_read  TYPE i,
      files_new   TYPE i,
      events_read TYPE i,
      events_new  TYPE i,
      evaluated   TYPE i,
      not_eval    TYPE i,
      tickets     TYPE i,
      purged      TYPE i,
      messages    TYPE string_table,
    END OF ty_run_result.
  TYPES tt_run_result TYPE STANDARD TABLE OF ty_run_result WITH EMPTY KEY.

ENDINTERFACE.
