*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_adapter_feb.clas.abap
*& Purpose:
*& Source adapter for imported bank statements (ZCD_FMON_SRC row with
*& ADAPTER_CLASS = ZCL_CD_FMON_ADAPTER_FEB). For every inbound statement
*& interface with a bank key and every working business date of the window it
*& reads the statement evidence of EBS (ZIF_CD_EBS_STMT_EVIDENCE: payment
*& engine accounts expected / imported, entries not posted) for the statement
*& date and reports the interface's file instance as received (some accounts
*& imported), FILE_LOADED, PARTIALLY_PROCESSED (entries not posted) or
*& FULLY_PROCESSED. Read-only; no SQL of its own; no application log.
*& Modification log:
*& 2026-11-07 | Initial version (BAI processing deadline: received / imported / processed evidence).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - source adapter for imported statements</p>
"! Mapping of a statement to the interface's file instance (FMON_FILE_MONITORING.md B1b):
"! <ul><li>bank: ZCD_FMON_IFACE-BANK_KEY = ZCD_EBS_ACCT-BANK_KEY (house bank accounts of the bank);</li>
"! <li>date: business date B (a working day of the interface's factory calendar) - statement
"! date = the FMON_FEB_STMT_OFFSET-th working day before B (default 1: prior-day statement);</li>
"! <li>reference: the one file instance of the interface and B already registered by another
"! source (PRISM, load log), else the adapter's own reference FEB/&lt;bank&gt;/&lt;statement date&gt;.</li></ul>
"! States: no account imported = evidence only (no stage); some = FILE_RECEIVED; all imported =
"! FILE_LOADED when the posting state is not read or the read was truncated, PARTIALLY_PROCESSED
"! with the entries not posted as unprocessed count, else FULLY_PROCESSED.
"! ZCD_FMON_SRC: IFACE_ID blank = every active inbound STATEMENT interface with a bank key;
"! ZCD_FMON_SRCMAP is not used (the stage follows from the evidence).
CLASS zcl_cd_fmon_adapter_feb DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_adapter.

  PRIVATE SECTION.
    "! One interface and business date to report, with the statement date it waits for
    TYPES:
      BEGIN OF ty_target,
        iface_id      TYPE zif_cd_fmon_types=>ty_iface_id,
        bank_key      TYPE zif_cd_fmon_types=>ty_bank_key,
        business_date TYPE d,
        stmt_date     TYPE d,
      END OF ty_target.
    TYPES tt_target TYPE STANDARD TABLE OF ty_target WITH EMPTY KEY.

    "! Interfaces of the source row and their working business dates in the window
    METHODS targets
      IMPORTING
        is_request        TYPE zif_cd_fmon_types=>ty_read_request
      RETURNING
        VALUE(rt_targets) TYPE tt_target
      RAISING
        zcx_cd_ops_error.

    "! The iv_offset-th working day before iv_date (iv_offset 0 = iv_date); initial when none
    "! is found within GC_FEB_MAX_BACK_DAYS calendar days
    METHODS statement_date
      IMPORTING
        iv_date        TYPE d
        iv_calendar_id TYPE zif_cd_fmon_types=>ty_fcal_id
        iv_offset      TYPE i
      RETURNING
        VALUE(rv_date) TYPE d
      RAISING
        zcx_cd_ops_error.

    "! Registered instance of the interface and business date (exactly one) or the own reference
    CLASS-METHODS file_ref
      IMPORTING
        is_target     TYPE ty_target
        it_registry   TYPE zif_cd_fmon_types=>tt_file
      RETURNING
        VALUE(rv_ref) TYPE zif_cd_fmon_types=>ty_file_ref.

    CLASS-METHODS to_record
      IMPORTING
        is_src           TYPE zif_cd_fmon_types=>ty_src
        is_target        TYPE ty_target
        is_evidence      TYPE zif_cd_ebs_stmt_evidence=>ty_evidence
        iv_ref           TYPE zif_cd_fmon_types=>ty_file_ref
        iv_now           TYPE timestampl
      RETURNING
        VALUE(rs_record) TYPE zif_cd_fmon_types=>ty_src_record.

ENDCLASS.



CLASS zcl_cd_fmon_adapter_feb IMPLEMENTATION.

  METHOD zif_cd_fmon_adapter~read.
    DATA ls_request TYPE zif_cd_ebs_stmt_evidence=>ty_request.
    DATA lv_from TYPE d.
    DATA lv_to TYPE d.

    DATA(lt_targets) = targets( is_request ).
    IF lt_targets IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_targets ASSIGNING FIELD-SYMBOL(<ls_target>).
      INSERT CONV zif_cd_ebs_types=>ty_bank_key( <ls_target>-bank_key ) INTO TABLE ls_request-bank_keys.
      INSERT <ls_target>-stmt_date INTO TABLE ls_request-stmt_dates.
      lv_from = COND #( WHEN lv_from IS INITIAL OR <ls_target>-business_date < lv_from
                        THEN <ls_target>-business_date ELSE lv_from ).
      lv_to   = nmax( val1 = lv_to val2 = <ls_target>-business_date ).
    ENDLOOP.
    ls_request-max_rows = is_request-max_rows.

    " One evidence read (one FEBKO, one FEBEP read) and one registry read for every target
    DATA(lt_evidence) = zcl_cd_ebs_factory=>get_stmt_evidence( )->read( ls_request ).
    DATA(lt_registry) = zcl_cd_fmon_factory=>get_dao( )->get_eval_files( iv_date_from  = lv_from
                                                                        iv_date_to    = lv_to
                                                                        iv_open_since = lv_from
                                                                        iv_iface_id   = is_request-src-iface_id ).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).

    LOOP AT lt_targets ASSIGNING <ls_target>.
      READ TABLE lt_evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>)
           WITH TABLE KEY bank_key = CONV zif_cd_ebs_types=>ty_bank_key( <ls_target>-bank_key )
                          stmt_date = <ls_target>-stmt_date.
      " A bank without active payment engine accounts proves nothing either way
      IF sy-subrc <> 0 OR <ls_evidence>-accounts_expected = 0.
        CONTINUE.
      ENDIF.
      INSERT to_record( is_src      = is_request-src
                        is_target   = <ls_target>
                        is_evidence = <ls_evidence>
                        iv_ref      = file_ref( is_target = <ls_target> it_registry = lt_registry )
                        iv_now      = lv_now ) INTO TABLE rt_records.
    ENDLOOP.
  ENDMETHOD.


  METHOD targets.
    DATA lv_date TYPE d.
    DATA lv_calendar TYPE zif_cd_fmon_types=>ty_fcal_id.

    DATA(lo_dao) = zcl_cd_fmon_factory=>get_dao( ).
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(lo_calendar) = zcl_cd_fmon_factory=>get_calendar( ).
    DATA(lv_offset) = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                  iv_name    = zif_cd_fmon_types=>gc_param-feb_stmt_offset
                                                  iv_default = zif_cd_fmon_types=>gc_param_default-feb_stmt_offset ).
    DATA(lv_default_cal) = CONV zif_cd_fmon_types=>ty_fcal_id( lo_params->get_param(
                             iv_name    = zif_cd_fmon_types=>gc_param-factory_cal
                             iv_default = zif_cd_fmon_types=>gc_param_default-factory_cal ) ).
    DATA(lt_cals) = lo_dao->get_calendars( ).

    LOOP AT lo_dao->get_ifaces( ) ASSIGNING FIELD-SYMBOL(<ls_iface>)
         WHERE active = abap_true AND direction = zif_cd_fmon_types=>gc_direction-inbound.
      IF ( is_request-src-iface_id IS NOT INITIAL AND <ls_iface>-iface_id <> is_request-src-iface_id )
         OR ( is_request-src-iface_id IS INITIAL AND <ls_iface>-file_type <> zif_cd_fmon_types=>gc_file_type-statement ).
        CONTINUE.
      ENDIF.
      DATA(lv_bank) = CONV zif_cd_fmon_types=>ty_bank_key( to_upper( condense( <ls_iface>-bank_key ) ) ).
      IF lv_bank IS INITIAL OR lv_bank = zif_cd_fmon_types=>gc_wildcard.
        CONTINUE.
      ENDIF.
      lv_calendar = lv_default_cal.
      LOOP AT lt_cals ASSIGNING FIELD-SYMBOL(<ls_cal>) WHERE iface_id = <ls_iface>-iface_id AND fcal_id IS NOT INITIAL.
        lv_calendar = <ls_cal>-fcal_id.
        EXIT.
      ENDLOOP.
      lv_date = is_request-date_from.
      WHILE lv_date <= is_request-date_to.
        " A non-working day has no statement file of its own (no business date)
        IF lo_calendar->is_working_day( iv_date = lv_date iv_calendar_id = lv_calendar ) = abap_true.
          DATA(lv_stmt_date) = statement_date( iv_date        = lv_date
                                               iv_calendar_id = lv_calendar
                                               iv_offset      = lv_offset ).
          IF lv_stmt_date IS NOT INITIAL.
            INSERT VALUE #( iface_id      = <ls_iface>-iface_id
                            bank_key      = lv_bank
                            business_date = lv_date
                            stmt_date     = lv_stmt_date ) INTO TABLE rt_targets.
          ENDIF.
        ENDIF.
        lv_date += 1.
      ENDWHILE.
    ENDLOOP.
  ENDMETHOD.


  METHOD statement_date.
    DATA lv_found TYPE i.
    IF iv_offset <= 0.
      rv_date = iv_date.
      RETURN.
    ENDIF.
    DATA(lv_date) = iv_date.
    DO zif_cd_fmon_types=>gc_feb_max_back_days TIMES.
      lv_date -= 1.
      IF zcl_cd_fmon_factory=>get_calendar( )->is_working_day( iv_date        = lv_date
                                                               iv_calendar_id = iv_calendar_id ) = abap_true.
        lv_found += 1.
        IF lv_found = iv_offset.
          rv_date = lv_date.
          RETURN.
        ENDIF.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD file_ref.
    DATA lv_count TYPE i.
    DATA lv_other TYPE zif_cd_fmon_types=>ty_file_ref.
    rv_ref = |{ zif_cd_fmon_types=>gc_feb_ref_prefix }{ is_target-bank_key }/{ is_target-stmt_date }|.
    LOOP AT it_registry ASSIGNING FIELD-SYMBOL(<ls_file>) USING KEY by_iface
         WHERE iface_id = is_target-iface_id AND business_date = is_target-business_date.
      IF <ls_file>-file_ref = rv_ref.
        " The adapter's own instance stays its instance
        RETURN.
      ENDIF.
      lv_count += 1.
      lv_other = <ls_file>-file_ref.
    ENDLOOP.
    " One instance registered by another source (PRISM, load log): the statement belongs to it;
    " several: no guess - the own instance (the deadline check reads every instance of the day)
    IF lv_count = 1.
      rv_ref = lv_other.
    ENDIF.
  ENDMETHOD.


  METHOD to_record.
    rs_record-src_id        = is_src-src_id.
    rs_record-iface_id      = is_target-iface_id.
    rs_record-file_ref      = iv_ref.
    rs_record-business_date = is_target-business_date.
    rs_record-event_at      = iv_now.
    rs_record-count_known   = abap_true.
    rs_record-evidence      = CORRESPONDING #( is_evidence ).
    rs_record-evidence-iface_id      = is_target-iface_id.
    rs_record-evidence-business_date = is_target-business_date.
    rs_record-evidence-bank_key      = is_target-bank_key.

    IF is_evidence-accounts_imported = 0.
      " Nothing imported: no stage of its own - the evidence tells the checks what is missing
      rs_record-evidence_only = abap_true.
    ELSEIF is_evidence-accounts_imported < is_evidence-accounts_expected.
      " Statements in SAP prove the file arrived; the import is not complete
      rs_record-stage      = zif_cd_fmon_types=>gc_stage-received.
      rs_record-raw_status = zif_cd_fmon_types=>gc_feb_status-import_partial.
      rs_record-rec_count  = is_evidence-accounts_imported.
    ELSEIF is_evidence-truncated = abap_true OR is_evidence-posting_known = abap_false.
      " Imported; processing cannot be proven (posting state not read, statement read capped)
      rs_record-stage      = zif_cd_fmon_types=>gc_stage-loaded.
      rs_record-raw_status = zif_cd_fmon_types=>gc_feb_status-imported.
      rs_record-rec_count  = is_evidence-lines_total.
    ELSEIF is_evidence-lines_open > 0.
      rs_record-stage       = zif_cd_fmon_types=>gc_stage-partially.
      rs_record-raw_status  = zif_cd_fmon_types=>gc_feb_status-posting_open.
      rs_record-rec_count   = is_evidence-lines_total.
      rs_record-unprocessed = is_evidence-lines_open.
    ELSE.
      rs_record-stage      = zif_cd_fmon_types=>gc_stage-fully.
      rs_record-raw_status = zif_cd_fmon_types=>gc_feb_status-posted.
      rs_record-rec_count  = is_evidence-lines_total.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
