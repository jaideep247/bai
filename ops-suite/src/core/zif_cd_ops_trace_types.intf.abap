*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_trace_types.intf.abap
*& Purpose:
*& Types and constants of the read-only 360 degree payment trace: input
*& keys, stages, evidence statuses, gap reasons, verdicts, parameters of
*& ZCA_PARAM, configured-source specifications (validated against the
*& DDIC at run time), DAO row types and the timeline row shown to support.
*& Modification log:
*& 2026-11-06 | Initial version (360 degree payment trace).
*& 2026-11-06 | Cheque company code, file name (digest check), partner mismatch reason.
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Return / NOC reasons: TY_RETURN-RLGRD, NOC stage and lot item (DFKKNRP), messages 739-741.
*& 2026-11-07 | Parameter TRACE_REVERSAL_AUGRD removed: GC_REVERSAL_AUGRD '05' (only reversal reason).
*& 2026-11-07 | Comments: TRACE_ parameters in ZCA_PARAM, area CD_OPS (ZCD_OPS_PARAM retired).
*& 2026-11-07 | TY_CHECK-BANCD (cheque encashment date) for the in-flight check A_INFLIGHT.
*& 2026-11-07 | In-flight evidence (user rules): TY_CHECK-STATE (DFKKCR-STATE, confirmed) replaces
*&            | BANCD; TY_BANK_LINE-VORGC / VGEXT (BAI / ISO code); TY_RETURN-AMOUNT (DFKKRP, VERIFY-DDIC).
*& 2026-11-07 | TY_BANK_LINE-BUKRS / HBKID / HKTID (statement account, FEBKO) and message 749: cheque
*&            | link by number and house bank account (design review, ZCL_CD_OPS_CHEQUE_LINK).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment trace - types and constants</p>
INTERFACE zif_cd_ops_trace_types
  PUBLIC.

  TYPES ty_stage        TYPE c LENGTH 15.
  TYPES ty_augrd        TYPE c LENGTH 2.
  TYPES ty_status       TYPE c LENGTH 15.
  TYPES ty_reason       TYPE c LENGTH 30.
  TYPES ty_verdict      TYPE c LENGTH 15.
  TYPES ty_attempt_kind TYPE c LENGTH 10.
  "! A65: width of OPBEL / AUGBL / DOC1R (VERIFY-SE11: OPBEL_KK, AUGBL_KK, DOC1R CHAR 12)
  TYPES ty_docno        TYPE c LENGTH 12.
  TYPES tt_docno        TYPE SORTED TABLE OF ty_docno WITH UNIQUE KEY table_line.
  "! FIN number (ZCD_PAYM_REQ_LOG FIN field = DFKKOP-ZZ_FIN_TRANS_NUM; width VERIFY-SE11)
  TYPES ty_fin          TYPE c LENGTH 35.
  TYPES ty_source       TYPE c LENGTH 10.
  "! Bank reference: FEBEP-CHECT, DFKKCR-ZTNUM
  TYPES ty_ref          TYPE c LENGTH 35.
  TYPES tt_ref          TYPE SORTED TABLE OF ty_ref WITH UNIQUE KEY table_line.
  TYPES ty_bukrs        TYPE c LENGTH 4.
  TYPES ty_partner      TYPE c LENGTH 10.
  TYPES ty_tabname      TYPE c LENGTH 30.
  TYPES ty_fieldname    TYPE c LENGTH 30.
  TYPES ty_key_value    TYPE c LENGTH 70.
  TYPES ty_record_key   TYPE c LENGTH 120.
  TYPES ty_file_ref     TYPE c LENGTH 70.
  TYPES tt_file_ref     TYPE SORTED TABLE OF ty_file_ref WITH UNIQUE KEY table_line.
  TYPES ty_file_id      TYPE x LENGTH 16.
  TYPES tt_file_id      TYPE SORTED TABLE OF ty_file_id WITH UNIQUE KEY table_line.
  TYPES ty_pymet        TYPE c LENGTH 1.
  TYPES ty_kind         TYPE c LENGTH 1.

  " ---------------------------------------------------------------- stages
  "! Stages of one payment, in timeline order (REQUEST, SAP_ITEM and CLEAR_HISTORY belong
  "! to the request; PAYMENT .. GL are repeated for every payment attempt)
  CONSTANTS:
    BEGIN OF gc_stage,
      request    TYPE ty_stage VALUE 'REQUEST',
      sap_item   TYPE ty_stage VALUE 'SAP_ITEM',
      history    TYPE ty_stage VALUE 'CLEAR_HISTORY',
      payment    TYPE ty_stage VALUE 'PAYMENT',
      file       TYPE ty_stage VALUE 'FILE_GENERATED',
      prism      TYPE ty_stage VALUE 'PRISM_HANDOFF',
      bank_ack   TYPE ty_stage VALUE 'BANK_ACK',
      settlement TYPE ty_stage VALUE 'SETTLEMENT',
      "! NOC (notification of change) evidence of the attempt - informational, never decides
      "! the verdict (DFKKNRP by INFOF; return / NOC correction 2026-11-06)
      noc        TYPE ty_stage VALUE 'NOC',
      fica       TYPE ty_stage VALUE 'FICA_CLEARING',
      gl         TYPE ty_stage VALUE 'GL',
    END OF gc_stage.

  "! Evidence status of a stage row. There is no PENDING: no deterministic SLA rule exists
  "! per stage yet (Payment_Trace.md, proposed)
  CONSTANTS:
    BEGIN OF gc_status,
      verified       TYPE ty_status VALUE 'VERIFIED',
      missing        TYPE ty_status VALUE 'MISSING',
      ambiguous      TYPE ty_status VALUE 'AMBIGUOUS',
      unavailable    TYPE ty_status VALUE 'UNAVAILABLE',
      "! Positive evidence of a failure (NACK, return, terminal cheque status)
      failed         TYPE ty_status VALUE 'FAILED',
      not_applicable TYPE ty_status VALUE 'NOT_APPLICABLE',
    END OF gc_status.

  CONSTANTS:
    BEGIN OF gc_reason,
      not_configured   TYPE ty_reason VALUE 'SOURCE_NOT_CONFIGURED',
      not_readable     TYPE ty_reason VALUE 'SOURCE_NOT_READABLE',
      not_authorised   TYPE ty_reason VALUE 'NOT_AUTHORISED',
      history_missing  TYPE ty_reason VALUE 'REVERSAL_HISTORY_MISSING',
      multiple         TYPE ty_reason VALUE 'MULTIPLE_MATCHES',
      no_record        TYPE ty_reason VALUE 'NO_RECORD',
      no_success       TYPE ty_reason VALUE 'NO_SUCCESS_ROW',
      no_link          TYPE ty_reason VALUE 'NO_LINK_KEY',
      row_cap          TYPE ty_reason VALUE 'ROW_CAP_REACHED',
      not_monitored    TYPE ty_reason VALUE 'FILE_NOT_MONITORED',
      ack_file_level   TYPE ty_reason VALUE 'ACK_FILE_LEVEL',
      ack_payment      TYPE ty_reason VALUE 'ACK_PAYMENT_LEVEL',
      nack             TYPE ty_reason VALUE 'NACK_REJECTED',
      no_ack_method    TYPE ty_reason VALUE 'NO_ACK_FOR_METHOD',
      returned         TYPE ty_reason VALUE 'RETURNED',
      "! Returns lot items of one clearing reference carry different return reasons (RLGRD)
      return_reason_ambiguous TYPE ty_reason VALUE 'RETURN_REASON_AMBIGUOUS',
      noc_item         TYPE ty_reason VALUE 'NOC_ITEM',
      no_noc           TYPE ty_reason VALUE 'NO_NOC_ITEM',
      retrieval        TYPE ty_reason VALUE 'RETRIEVAL_LOGGED',
      cheque_terminal  TYPE ty_reason VALUE 'CHEQUE_TERMINAL_STATUS',
      cheque_status    TYPE ty_reason VALUE 'CHEQUE_STATUS',
      encashed         TYPE ty_reason VALUE 'ENCASHED',
      settled          TYPE ty_reason VALUE 'BANK_LINE',
      cleared          TYPE ty_reason VALUE 'CLEARED',
      clearing_reset   TYPE ty_reason VALUE 'CLEARING_RESET',
      gl_line          TYPE ty_reason VALUE 'GL_CLEARING_LINE',
      no_fikey         TYPE ty_reason VALUE 'NO_FIKEY',
      not_summarised   TYPE ty_reason VALUE 'NOT_SUMMARISED',
      not_transferred  TYPE ty_reason VALUE 'GL_NOT_TRANSFERRED',
      transferred      TYPE ty_reason VALUE 'GL_TRANSFERRED',
      no_earlier       TYPE ty_reason VALUE 'NO_EARLIER_CLEARING',
      earlier_found    TYPE ty_reason VALUE 'EARLIER_CLEARING_FOUND',
      partner_legacy   TYPE ty_reason VALUE 'PARTNER_WITHOUT_SOURCE',
      partner_mismatch TYPE ty_reason VALUE 'PARTNER_MISMATCH',
      success_row      TYPE ty_reason VALUE 'SUCCESS_ROW',
      open_item        TYPE ty_reason VALUE 'OPEN_ITEM',
      payment_run      TYPE ty_reason VALUE 'PAYMENT_RUN',
      cheque_issued    TYPE ty_reason VALUE 'CHEQUE_ISSUED',
      file_generated   TYPE ty_reason VALUE 'FILE_GENERATED',
      sent_to_prism    TYPE ty_reason VALUE 'SENT_TO_PRISM',
    END OF gc_reason.

  "! Overall verdict: COMPLETE only when every applicable stage of every current attempt,
  "! the request and the clearing history are VERIFIED
  CONSTANTS:
    BEGIN OF gc_verdict,
      complete   TYPE ty_verdict VALUE 'COMPLETE',
      incomplete TYPE ty_verdict VALUE 'INCOMPLETE',
      failed     TYPE ty_verdict VALUE 'FAILED',
      ambiguous  TYPE ty_verdict VALUE 'AMBIGUOUS',
      not_found  TYPE ty_verdict VALUE 'NOT_FOUND',
    END OF gc_verdict.

  "! CURRENT = clearing reference on the item now; HISTORICAL = earlier clearing reference
  "! from the clearing-reset history (reversed / reissued); UNPAID = item not cleared
  CONSTANTS:
    BEGIN OF gc_attempt,
      current    TYPE ty_attempt_kind VALUE 'CURRENT',
      historical TYPE ty_attempt_kind VALUE 'HISTORICAL',
      unpaid     TYPE ty_attempt_kind VALUE 'UNPAID',
    END OF gc_attempt.

  "! Collections vs disbursements (TFK042Z-XEINZ), unknown when no payment method row
  CONSTANTS:
    BEGIN OF gc_kind,
      collection   TYPE ty_kind VALUE 'C',
      disbursement TYPE ty_kind VALUE 'D',
      unknown      TYPE ty_kind VALUE ' ',
    END OF gc_kind.

  " ---------------------------------------------------------------- parameters
  "! ZCA_PARAM names. TRACE_SRC_* hold a source specification
  "! TABLE=..;KEY=..;KEY2=..;REF=..;STATUS=..;DATE=..;TIME=..;INFO=.. (names VERIFY-SE11,
  "! validated against the DDIC and ZCD_FMON_TABWL at run time; blank = not configured)
  CONSTANTS:
    BEGIN OF gc_param,
      max_rows          TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_MAX_ROWS',
      src_request       TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_SRC_REQUEST',
      src_history       TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_SRC_HISTORY',
      src_regut         TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_SRC_REGUT',
      src_ack           TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_SRC_ACK',
      src_chq_hist      TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_SRC_CHQ_HIST',
      bp_source_field   TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_BP_SOURCE_FIELD',
      success_value     TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_PRQ_SUCCESS',
      gl_awtyp          TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_GL_AWTYP',
      cheque_methods    TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_CHECK_METHODS',
      no_ack_methods    TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_NO_ACK_METHODS',
      ack_nack_values   TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_ACK_NACK_VALUES',
      chq_failed_values TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_CHQ_FAILED',
      bank_lookback     TYPE zif_cd_ops_types=>ty_param_name VALUE 'TRACE_BANK_LOOKBACK_DAYS',
    END OF gc_param.

  "! Defaults: SUCCESS / ZZ_STATUS confirmed (USAA_Known_Tables); AWTYP FKKSU,
  "! cheque method C and cheque terminal statuses 3 / 4 / 9 (ZECT_STATUS) from the reference
  CONSTANTS:
    BEGIN OF gc_default,
      max_rows          TYPE i VALUE 50,
      success_value     TYPE string VALUE `SUCCESS`,
      gl_awtyp          TYPE string VALUE `FKKSU`,
      cheque_methods    TYPE string VALUE `C`,
      chq_failed_values TYPE string VALUE `3,4,9`,
      ack_nack_values   TYPE string VALUE `NACK,REJECTED,R`,
      bank_lookback     TYPE i VALUE 5,
    END OF gc_default.

  "! Clearing reason of a reversal (DFKKOP-AUGRD, VERIFY-SE11): 05 is the only reversal reason
  "! (user decision 2026-11-07); literal '05' in ZR_CD_TrxFlow, compared by the parity check
  CONSTANTS gc_reversal_augrd TYPE ty_augrd VALUE '05'.

  "! Keys of a source specification
  CONSTANTS:
    BEGIN OF gc_spec,
      table  TYPE string VALUE `TABLE`,
      key    TYPE string VALUE `KEY`,
      key2   TYPE string VALUE `KEY2`,
      ref    TYPE string VALUE `REF`,
      status TYPE string VALUE `STATUS`,
      date   TYPE string VALUE `DATE`,
      time   TYPE string VALUE `TIME`,
      info   TYPE string VALUE `INFO`,
    END OF gc_spec.
  CONSTANTS gc_spec_pair_sep TYPE c LENGTH 1 VALUE ';'.
  CONSTANTS gc_spec_value_sep TYPE c LENGTH 1 VALUE '='.
  CONSTANTS gc_list_sep TYPE c LENGTH 1 VALUE ','.
  CONSTANTS gc_key_sep TYPE c LENGTH 1 VALUE '/'.
  "! Masking: characters kept at the end, mask character
  CONSTANTS gc_mask_keep TYPE i VALUE 4.
  CONSTANTS gc_mask_char TYPE c LENGTH 1 VALUE '*'.

  "! Source tables named on timeline rows (standard tables of the confirmed join paths)
  CONSTANTS:
    BEGIN OF gc_table,
      dfkkop  TYPE ty_tabname VALUE 'DFKKOP',
      dfkkko  TYPE ty_tabname VALUE 'DFKKKO',
      dpayh   TYPE ty_tabname VALUE 'DPAYH',
      dfkkcr  TYPE ty_tabname VALUE 'DFKKCR',
      febep   TYPE ty_tabname VALUE 'FEBEP',
      dfkkrp  TYPE ty_tabname VALUE 'DFKKRP',
      dfkknrp TYPE ty_tabname VALUE 'DFKKNRP',
      rtrv    TYPE ty_tabname VALUE 'ZCD_ACH_RTRV_LOG',
      fmon    TYPE ty_tabname VALUE 'ZCD_FMON_EVENT',
      bkpf    TYPE ty_tabname VALUE 'BKPF',
      bseg    TYPE ty_tabname VALUE 'BSEG',
      sumc    TYPE ty_tabname VALUE 'DFKKSUMC',
      but000  TYPE ty_tabname VALUE 'BUT000',
    END OF gc_table.
  CONSTANTS gc_utc TYPE tznzone VALUE 'UTC'.

  " ---------------------------------------------------------------- input / output
  TYPES:
    BEGIN OF ty_trace_input,
      fin          TYPE ty_fin,
      source       TYPE ty_source,
      clearing_doc TYPE ty_docno,
      check_no     TYPE ty_ref,
    END OF ty_trace_input.

  "! One row of the evidence timeline
  TYPES:
    BEGIN OF ty_trace_row,
      attempt       TYPE i,
      attempt_kind  TYPE ty_attempt_kind,
      clearing_ref  TYPE ty_docno,
      seq           TYPE i,
      stage         TYPE ty_stage,
      status        TYPE ty_status,
      light         TYPE c LENGTH 1,
      first_gap     TYPE abap_bool,
      reason        TYPE ty_reason,
      source_table  TYPE ty_tabname,
      record_key    TYPE ty_record_key,
      bukrs         TYPE ty_bukrs,
      evidence_date TYPE d,
      evidence_time TYPE t,
      time_zone     TYPE tznzone,
      detail        TYPE string,
    END OF ty_trace_row.
  TYPES tt_trace_row TYPE STANDARD TABLE OF ty_trace_row WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_trace_result,
      input             TYPE ty_trace_input,
      verdict           TYPE ty_verdict,
      first_gap_stage   TYPE ty_stage,
      first_gap_attempt TYPE i,
      attempts          TYPE i,
      rows              TYPE tt_trace_row,
    END OF ty_trace_result.

  " ---------------------------------------------------------------- configured sources
  TYPES:
    BEGIN OF ty_source_cfg,
      param        TYPE zif_cd_ops_types=>ty_param_name,
      table_name   TYPE ty_tabname,
      key_field    TYPE ty_fieldname,
      key2_field   TYPE ty_fieldname,
      ref_field    TYPE ty_fieldname,
      status_field TYPE ty_fieldname,
      date_field   TYPE ty_fieldname,
      time_field   TYPE ty_fieldname,
      info_field   TYPE ty_fieldname,
    END OF ty_source_cfg.

  TYPES:
    BEGIN OF ty_cfg_key,
      key1 TYPE ty_key_value,
      key2 TYPE ty_key_value,
    END OF ty_cfg_key.

  "! Row of a configured source (aliases KEY1, KEY2, REF, STATUS, EV_DATE, EV_TIME, INFO)
  TYPES:
    BEGIN OF ty_cfg_row,
      key1    TYPE ty_key_value,
      key2    TYPE ty_key_value,
      ref     TYPE ty_key_value,
      status  TYPE c LENGTH 40,
      ev_date TYPE c LENGTH 8,
      ev_time TYPE c LENGTH 6,
      info    TYPE ty_key_value,
    END OF ty_cfg_row.
  TYPES tt_cfg_row TYPE STANDARD TABLE OF ty_cfg_row WITH EMPTY KEY.

  " ---------------------------------------------------------------- standard-table rows
  TYPES tt_partner TYPE SORTED TABLE OF ty_partner WITH UNIQUE KEY table_line.

  "! Open item (DFKKOP). VERIFY-SE11: PYMET, AUGRD, AUGDT
  TYPES:
    BEGIN OF ty_item,
      opbel TYPE ty_docno,
      opupw TYPE n LENGTH 3,
      opupk TYPE n LENGTH 4,
      opupz TYPE n LENGTH 4,
      bukrs TYPE ty_bukrs,
      gpart TYPE ty_partner,
      betrh TYPE zif_cd_ops_types=>ty_amount,
      waers TYPE zif_cd_ops_types=>ty_currency,
      budat TYPE d,
      pymet TYPE ty_pymet,
      augbl TYPE ty_docno,
      augdt TYPE d,
      augrd TYPE ty_augrd,
      fin   TYPE ty_fin,
    END OF ty_item.
  TYPES tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  "! Document header (DFKKKO). VERIFY-SE11: STBEL (reversal document), CPUDT, CPUTM
  TYPES:
    BEGIN OF ty_doc_header,
      opbel TYPE ty_docno,
      fikey TYPE c LENGTH 12,
      stbel TYPE ty_docno,
      budat TYPE d,
      cpudt TYPE d,
      cputm TYPE t,
    END OF ty_doc_header.
  "! Sweep: secondary key BY_OPBEL - the trace reads headers by document number
  TYPES tt_doc_header TYPE STANDARD TABLE OF ty_doc_header WITH EMPTY KEY
                      WITH NON-UNIQUE SORTED KEY by_opbel COMPONENTS opbel.

  TYPES:
    BEGIN OF ty_payment_run,
      doc1r  TYPE ty_docno,
      laufd  TYPE d,
      laufi  TYPE c LENGTH 6,
      status TYPE c LENGTH 20,
    END OF ty_payment_run.
  TYPES tt_payment_run TYPE STANDARD TABLE OF ty_payment_run WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_check,
      ztnum    TYPE ty_ref,
      bukrs    TYPE ty_bukrs,
      hbkid    TYPE c LENGTH 5,
      hktid    TYPE c LENGTH 5,
      doc1r    TYPE ty_docno,
      amount   TYPE zif_cd_ops_types=>ty_amount,
      crstatus TYPE c LENGTH 20,
      "! Cheque status DFKKCR-STATE (confirmed 2026-11-07: B cashed, V voided, blank open);
      "! read by get_checks_by_doc
      state    TYPE c LENGTH 1,
    END OF ty_check.
  TYPES tt_check TYPE STANDARD TABLE OF ty_check WITH EMPTY KEY.

  "! Bank statement line (FEBEP) with the account of its statement (FEBKO). VERIFY-SE11: KWBTR
  TYPES:
    BEGIN OF ty_bank_line,
      kukey TYPE n LENGTH 8,
      esnum TYPE n LENGTH 5,
      chect TYPE ty_ref,
      budat TYPE d,
      kwbtr TYPE zif_cd_ops_types=>ty_amount,
      "! BAI type code of the line (FEBEP-VORGC, as the EBS line read; VERIFY-DDIC there)
      vorgc TYPE c LENGTH 3,
      "! External transaction (FEBEP-VGEXT): ISO code of a CAMT import (ZCL_CD_EBS_SRC_FEB=>LINE_CODE)
      vgext TYPE c LENGTH 27,
      "! Statement account (FEBKO-BUKRS / HBKID / HKTID of the line's KUKEY): a cheque line fits
      "! only a cheque of this house bank account (ZCL_CD_OPS_CHEQUE_LINK)
      bukrs TYPE ty_bukrs,
      hbkid TYPE c LENGTH 5,
      hktid TYPE c LENGTH 5,
    END OF ty_bank_line.
  TYPES tt_bank_line TYPE STANDARD TABLE OF ty_bank_line WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_return,
      selw1     TYPE ty_docno,
      opbel     TYPE ty_docno,
      lot_stars TYPE c LENGTH 20,
      "! Return reason DFKKRP-RLGRD (VERIFY-SE11; code only - no text table read)
      rlgrd     TYPE c LENGTH 3,
      "! Amount of the returns lot item (DFKKRP-BETRW, VERIFY-DDIC; compared with the return line)
      amount    TYPE zif_cd_ops_types=>ty_amount,
    END OF ty_return.
  TYPES tt_return TYPE STANDARD TABLE OF ty_return WITH EMPTY KEY.

  "! DFKKNRP-INFOF (CHAR 50): payment document (AUGBL) or payment reference (confirmed
  "! 2026-11-06; exact content VERIFY-SE11)
  TYPES ty_infof TYPE c LENGTH 50.
  TYPES tt_infof TYPE SORTED TABLE OF ty_infof WITH UNIQUE KEY table_line.

  "! NOC lot item (DFKKNRP: KEYN1 lot, POSNA item, INFOF, NOC reason FLGRD - VERIFY-SE11)
  TYPES:
    BEGIN OF ty_noc,
      keyn1 TYPE c LENGTH 12,
      posna TYPE n LENGTH 6,
      infof TYPE ty_infof,
      flgrd TYPE c LENGTH 3,
    END OF ty_noc.
  TYPES tt_noc TYPE STANDARD TABLE OF ty_noc WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_retrieval,
      augbl  TYPE ty_docno,
      status TYPE c LENGTH 40,
    END OF ty_retrieval.
  TYPES tt_retrieval TYPE STANDARD TABLE OF ty_retrieval WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_fmon_file,
      file_id       TYPE ty_file_id,
      iface_id      TYPE c LENGTH 20,
      file_ref      TYPE ty_file_ref,
      file_name     TYPE c LENGTH 255,
      business_date TYPE d,
      stage         TYPE c LENGTH 20,
      outcome       TYPE c LENGTH 20,
    END OF ty_fmon_file.
  TYPES tt_fmon_file TYPE STANDARD TABLE OF ty_fmon_file WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_fmon_event,
      file_id  TYPE ty_file_id,
      event_no TYPE i,
      stage    TYPE c LENGTH 20,
      event_at TYPE timestampl,
      src_id   TYPE c LENGTH 10,
      src_key  TYPE ty_file_ref,
    END OF ty_fmon_event.
  TYPES tt_fmon_event TYPE STANDARD TABLE OF ty_fmon_event WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_fikey,
      fikey TYPE c LENGTH 12,
      bukrs TYPE ty_bukrs,
    END OF ty_fikey.
  TYPES tt_fikey TYPE SORTED TABLE OF ty_fikey WITH UNIQUE KEY fikey bukrs.

  "! G/L document of the transfer (BKPF). VERIFY-SE11: CPUDT, CPUTM
  TYPES:
    BEGIN OF ty_gl_doc,
      bukrs TYPE ty_bukrs,
      belnr TYPE c LENGTH 10,
      gjahr TYPE n LENGTH 4,
      awkey TYPE c LENGTH 20,
      budat TYPE d,
      cpudt TYPE d,
      cputm TYPE t,
      stblg TYPE c LENGTH 10,
    END OF ty_gl_doc.
  TYPES tt_gl_doc TYPE STANDARD TABLE OF ty_gl_doc WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_gl_key,
      bukrs TYPE ty_bukrs,
      belnr TYPE c LENGTH 10,
      gjahr TYPE n LENGTH 4,
    END OF ty_gl_key.
  TYPES tt_gl_key TYPE SORTED TABLE OF ty_gl_key WITH UNIQUE KEY bukrs belnr gjahr.

  "! Clearing-account line (BSEG) whose XREF2 carries the clearing reference
  TYPES:
    BEGIN OF ty_gl_line,
      bukrs TYPE ty_bukrs,
      belnr TYPE c LENGTH 10,
      gjahr TYPE n LENGTH 4,
      buzei TYPE n LENGTH 3,
      hkont TYPE c LENGTH 10,
      xref2 TYPE c LENGTH 12,
      augbl TYPE c LENGTH 10,
      augdt TYPE d,
    END OF ty_gl_line.
  TYPES tt_gl_line TYPE STANDARD TABLE OF ty_gl_line WITH EMPTY KEY.

  " ---------------------------------------------------------------- messages (ZCD_OPS)
  CONSTANTS:
    BEGIN OF gc_msg,
      request_row       TYPE zif_cd_ops_types=>ty_msgno VALUE '701',
      no_success_row    TYPE zif_cd_ops_types=>ty_msgno VALUE '702',
      not_configured    TYPE zif_cd_ops_types=>ty_msgno VALUE '703',
      not_readable      TYPE zif_cd_ops_types=>ty_msgno VALUE '704',
      not_authorised    TYPE zif_cd_ops_types=>ty_msgno VALUE '705',
      item_row          TYPE zif_cd_ops_types=>ty_msgno VALUE '706',
      partner_ambiguous TYPE zif_cd_ops_types=>ty_msgno VALUE '707',
      history_found     TYPE zif_cd_ops_types=>ty_msgno VALUE '708',
      history_missing   TYPE zif_cd_ops_types=>ty_msgno VALUE '709',
      no_earlier        TYPE zif_cd_ops_types=>ty_msgno VALUE '710',
      payment_run       TYPE zif_cd_ops_types=>ty_msgno VALUE '711',
      cheque_row        TYPE zif_cd_ops_types=>ty_msgno VALUE '712',
      file_row          TYPE zif_cd_ops_types=>ty_msgno VALUE '713',
      fmon_event        TYPE zif_cd_ops_types=>ty_msgno VALUE '714',
      not_monitored     TYPE zif_cd_ops_types=>ty_msgno VALUE '715',
      ack_row           TYPE zif_cd_ops_types=>ty_msgno VALUE '716',
      bank_line         TYPE zif_cd_ops_types=>ty_msgno VALUE '717',
      returned          TYPE zif_cd_ops_types=>ty_msgno VALUE '718',
      retrieval         TYPE zif_cd_ops_types=>ty_msgno VALUE '719',
      cheque_status     TYPE zif_cd_ops_types=>ty_msgno VALUE '720',
      cleared           TYPE zif_cd_ops_types=>ty_msgno VALUE '721',
      clearing_reset    TYPE zif_cd_ops_types=>ty_msgno VALUE '722',
      gl_doc            TYPE zif_cd_ops_types=>ty_msgno VALUE '723',
      gl_missing        TYPE zif_cd_ops_types=>ty_msgno VALUE '724',
      no_fikey          TYPE zif_cd_ops_types=>ty_msgno VALUE '725',
      not_applicable    TYPE zif_cd_ops_types=>ty_msgno VALUE '726',
      no_link           TYPE zif_cd_ops_types=>ty_msgno VALUE '727',
      gl_line           TYPE zif_cd_ops_types=>ty_msgno VALUE '730',
      not_summarised    TYPE zif_cd_ops_types=>ty_msgno VALUE '732',
      stage_missing     TYPE zif_cd_ops_types=>ty_msgno VALUE '733',
      partner_legacy    TYPE zif_cd_ops_types=>ty_msgno VALUE '737',
      partner_mismatch  TYPE zif_cd_ops_types=>ty_msgno VALUE '738',
      return_reasons    TYPE zif_cd_ops_types=>ty_msgno VALUE '739',
      noc_item          TYPE zif_cd_ops_types=>ty_msgno VALUE '740',
      no_noc            TYPE zif_cd_ops_types=>ty_msgno VALUE '741',
      "! A statement line fits several cheques of one house bank account (ZCL_CD_OPS_CHEQUE_LINK)
      cheque_ambiguous  TYPE zif_cd_ops_types=>ty_msgno VALUE '749',
    END OF gc_msg.

ENDINTERFACE.
