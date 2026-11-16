*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_ingest.clas.abap
*& Purpose:
*& Ingestion and evaluation of the payment file lifecycle (report
*& ZCA_OPS_PF_RUN; docs/PAYMENT_FILE_LIFECYCLE.md section 6): per active
*& file type of the area, the adapters of its configuration rows
*& (ZCA_OPS_PFADP, created through ZCL_CA_OPS_FACTORY=>GET_PLUGIN with
*& the interface of their role) are read from their watermark minus
*& PF_OVERLAP_MIN; files and payments are registered (identity = file
*& type and native key; partner masked; at most PF_MAX_PAYMENTS kept),
*& a reissue is linked to its predecessor (named by the source, or the
*& same payments in an earlier file - both payments marked: duplicate
*& exposure), every record of an event source is mapped through
*& ZCA_OPS_PFMAP (unmapped = information), matched to its file (native
*& key, the files it covers, payment, batch, run, or a scheduler job by
*& its business date - quality confirmed / probable / unmatched) and
*& stored once (event key = SHA-1 of source, record ID, version, file,
*& payment). A source that fails is recorded as not evaluated with its
*& reason and its watermark stays. Then every file under watch is
*& evaluated (ZCL_CA_OPS_PF_LIFECYCLE) with the health of the sources of
*& its milestones, an overdue file is handed to the ticket sink once, and
*& every day of the watch is evaluated (expected versus observed). One
*& unit of work per file type; the register older than PF_RETENTION_DAYS
*& is removed. Test mode writes nothing. Read-only towards business data.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file ingestion and evaluation</p>
CLASS zcl_ca_ops_pf_ingest DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Ingest and evaluate the file types of an area
    "! @parameter iv_file_type | One file type (blank = every active file type)
    "! @parameter iv_test_mode | X = nothing is written
    "! @raising zcx_ca_ops_error | 041 not authorised, 352 module not licensed (LIC_ENFORCE X), 010 not saved
    METHODS run
      IMPORTING
        iv_area           TYPE zif_ca_ops_types=>ty_area
        iv_file_type      TYPE zif_ca_ops_pf_types=>ty_file_type OPTIONAL
        iv_test_mode      TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_results) TYPE zif_ca_ops_pf_types=>tt_run_result
      RAISING
        zcx_ca_ops_error.

    "! The event key of an observation (SHA-1 of source, record ID, version, file and payment)
    CLASS-METHODS event_key
      IMPORTING
        iv_area       TYPE zif_ca_ops_types=>ty_area
        is_event      TYPE zif_ca_ops_pf_types=>ty_event
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_pf_types=>ty_event_key.

    "! The source role whose events evidence a milestone when no mapping row says otherwise
    CLASS-METHODS default_role
      IMPORTING
        iv_milestone   TYPE zif_ca_ops_pf_types=>ty_milestone
      RETURNING
        VALUE(rv_role) TYPE zif_ca_ops_pf_types=>ty_role.

  PRIVATE SECTION.
    "! An adapter of the file type and its instance (or why it cannot be used)
    TYPES:
      BEGIN OF ty_adp,
        row      TYPE zif_ca_ops_pf_types=>ty_adapter,
        instance TYPE REF TO object,
        problem  TYPE zif_ca_ops_pf_types=>ty_reason,
      END OF ty_adp.
    TYPES tt_adp TYPE STANDARD TABLE OF ty_adp WITH EMPTY KEY.

    DATA mv_area TYPE zif_ca_ops_types=>ty_area.
    DATA mv_test TYPE abap_bool.
    DATA mv_now TYPE timestampl.
    DATA mv_today TYPE d.
    DATA mo_dao TYPE REF TO zif_ca_ops_pf_dao.
    DATA mo_lifecycle TYPE REF TO zcl_ca_ops_pf_lifecycle.
    DATA ms_type TYPE zif_ca_ops_pf_types=>ty_type_cfg.
    DATA mt_stages TYPE zif_ca_ops_pf_types=>tt_stage.
    DATA mt_maps TYPE zif_ca_ops_pf_types=>tt_map.
    DATA mt_adp TYPE tt_adp.
    "! Files under watch and those read in this run (key file ID)
    DATA mt_files TYPE SORTED TABLE OF zif_ca_ops_pf_types=>ty_file WITH UNIQUE KEY file_id.
    DATA mt_payments TYPE zif_ca_ops_pf_types=>tt_payment.
    DATA mt_sources TYPE zif_ca_ops_pf_types=>tt_source.
    DATA mt_new_events TYPE zif_ca_ops_pf_types=>tt_event.
    DATA ms_result TYPE zif_ca_ops_pf_types=>ty_run_result.
    DATA mv_open_from TYPE d.
    "! Files whose payments are in MT_PAYMENTS (only their payments are replaced on save)
    DATA mt_pay_ids TYPE zif_ca_ops_pf_types=>tt_file_id.

    METHODS ingest_type
      RAISING
        zcx_ca_ops_error.

    METHODS create_adapters.

    METHODS adapter
      IMPORTING
        iv_role       TYPE zif_ca_ops_pf_types=>ty_role
      RETURNING
        VALUE(rs_adp) TYPE ty_adp.

    "! The read window of a source: watermark minus the overlap, else the look-back
    METHODS request
      IMPORTING
        is_row            TYPE zif_ca_ops_pf_types=>ty_adapter
      RETURNING
        VALUE(rs_request) TYPE zif_ca_ops_pf_types=>ty_request.

    METHODS read_files
      RAISING
        zcx_ca_ops_error.

    METHODS register_files
      IMPORTING
        is_adp   TYPE ty_adp
        is_batch TYPE zif_ca_ops_pf_types=>ty_file_batch
      RAISING
        zcx_ca_ops_error.

    "! Payments the files read share with other files of the area: both marked, the later file linked
    METHODS link_reissues.

    METHODS read_events.

    "! Map and match the records of one event source to files
    METHODS match_events
      IMPORTING
        is_adp   TYPE ty_adp
        is_batch TYPE zif_ca_ops_pf_types=>ty_event_batch.

    METHODS files_of_event
      IMPORTING
        is_event        TYPE zif_ca_ops_pf_types=>ty_src_event
      EXPORTING
        et_files        TYPE zif_ca_ops_pf_types=>tt_file_id
        ev_quality      TYPE zif_ca_ops_exc_contract=>ty_quality.

    METHODS evaluate_files
      RAISING
        zcx_ca_ops_error.

    METHODS health
      RETURNING
        VALUE(rt_health) TYPE zcl_ca_ops_pf_lifecycle=>tt_health.

    METHODS evaluate_days
      RAISING
        zcx_ca_ops_error.

    "! State of a source after a read (failed: the watermark stays)
    METHODS source_done
      IMPORTING
        is_row     TYPE zif_ca_ops_pf_types=>ty_adapter
        is_request TYPE zif_ca_ops_pf_types=>ty_request
        iv_status  TYPE zif_ca_ops_pf_types=>ty_flag
        iv_as_of   TYPE timestampl OPTIONAL
        iv_reason  TYPE clike OPTIONAL
        iv_count   TYPE i OPTIONAL
        iv_unmapped TYPE i OPTIONAL.

    METHODS source_of
      IMPORTING
        iv_source_id     TYPE zif_ca_ops_pf_types=>ty_source_id
      RETURNING
        VALUE(rs_source) TYPE zif_ca_ops_pf_types=>ty_source.

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    METHODS note
      IMPORTING
        iv_msgno TYPE zif_ca_ops_types=>ty_msgno
        iv_v1    TYPE simple OPTIONAL
        iv_v2    TYPE simple OPTIONAL
        iv_v3    TYPE simple OPTIONAL
        iv_v4    TYPE simple OPTIONAL.

    CLASS-METHODS new_id
      RETURNING
        VALUE(rv_id) TYPE zif_ca_ops_pf_types=>ty_file_id
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_pf_ingest IMPLEMENTATION.

  METHOD run.
    zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                            iv_area     = iv_area ).
    " licence of the module (refused only under LIC_ENFORCE = X: 352, nothing read or written)
    zcl_ca_ops_factory=>get_license( )->gate( iv_module = zif_ca_ops_lic_types=>gc_module-cashops
                                              iv_area   = iv_area
                                              iv_entry  = 'ZCA_OPS_PF_RUN' ).
    mv_area = iv_area.
    mv_test = iv_test_mode.
    mo_dao = zcl_ca_ops_factory=>get_pf_dao( ).
    DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).
    mv_now = lo_clock->now( ).
    mv_today = lo_clock->today( ).
    mt_maps = mo_dao->get_maps( iv_area ).
    mt_sources = mo_dao->get_sources( iv_area ).
    DATA(lv_retention) = int_param( iv_name    = zif_ca_ops_pf_types=>gc_param-retention
                                    iv_default = zif_ca_ops_pf_types=>gc_default-retention ).

    LOOP AT mo_dao->get_file_types( iv_area = iv_area iv_file_type = iv_file_type ) INTO ms_type.
      CLEAR: ms_result, mt_adp, mt_files, mt_payments, mt_new_events, mt_pay_ids.
      ms_result-file_type = ms_type-file_type.
      ingest_type( ).
      IF mv_test = abap_false.
        IF lv_retention > 0.
          ms_result-purged = mo_dao->delete_before( iv_area      = iv_area
                                                    iv_file_type = ms_type-file_type
                                                    iv_before    = CONV d( mv_today - lv_retention ) ).
        ENDIF.
        " one file type, one unit of work: a later type's failure never undoes this one
        mo_dao->commit( ).
      ENDIF.
      note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-summary
               iv_v1    = ms_type-file_type
               iv_v2    = ms_result-files_read
               iv_v3    = ms_result-files_new
               iv_v4    = ms_result-evaluated ).
      INSERT ms_result INTO TABLE rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD ingest_type.
    mt_stages = mo_dao->get_stages( iv_area = mv_area iv_file_type = ms_type-file_type ).
    " an offset deadline needs its basis among the milestones (else it never gets a deadline)
    LOOP AT mt_stages ASSIGNING FIELD-SYMBOL(<ls_stage>) WHERE due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset.
      IF <ls_stage>-basis <> zif_ca_ops_pf_types=>gc_milestone-payrun
         AND NOT line_exists( mt_stages[ milestone = <ls_stage>-basis ] ).
        note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-basis_missing
              iv_v1    = <ls_stage>-milestone
              iv_v2    = ms_type-file_type
              iv_v3    = <ls_stage>-basis ).
      ENDIF.
    ENDLOOP.
    create_adapters( ).
    DATA(ls_calendar) = adapter( zif_ca_ops_pf_types=>gc_role-calendar ).
    mo_lifecycle = NEW #( io_calendar = COND #( WHEN ls_calendar-instance IS BOUND
                                                THEN CAST zif_ca_ops_pf_calendar( ls_calendar-instance ) ) ).
    DATA(lv_open) = COND i( WHEN ms_type-open_days > 0 THEN ms_type-open_days
                            ELSE int_param( iv_name    = zif_ca_ops_pf_types=>gc_param-open_days
                                            iv_default = zif_ca_ops_pf_types=>gc_default-open_days ) ).
    mv_open_from = mv_today - lv_open.
    " the files under watch: the working set every source is matched against
    LOOP AT mo_dao->files_since( iv_area      = mv_area
                                 iv_file_type = ms_type-file_type
                                 iv_from      = mv_open_from
                                 iv_max       = 100000 ) ASSIGNING FIELD-SYMBOL(<ls_file>).
      INSERT <ls_file> INTO TABLE mt_files.
    ENDLOOP.
    mt_pay_ids = VALUE #( FOR ls_f IN mt_files ( ls_f-file_id ) ).
    mt_payments = mo_dao->get_payments( iv_area = mv_area it_file_ids = mt_pay_ids ).
    read_files( ).
    read_events( ).
    IF mv_test = abap_false AND mt_new_events IS NOT INITIAL.
      ms_result-events_new = mo_dao->insert_events( mt_new_events ).
    ENDIF.
    evaluate_files( ).
    evaluate_days( ).
  ENDMETHOD.


  METHOD create_adapters.
    LOOP AT mo_dao->get_adapters( iv_area = mv_area iv_file_type = ms_type-file_type ) ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(ls_adp) = VALUE ty_adp( row = <ls_row> ).
      DATA(lv_intf) = SWITCH zif_ca_ops_types=>ty_class_name( <ls_row>-role
                        WHEN zif_ca_ops_pf_types=>gc_role-file     THEN zif_ca_ops_pf_types=>gc_intf-file
                        WHEN zif_ca_ops_pf_types=>gc_role-transfer THEN zif_ca_ops_pf_types=>gc_intf-transfer
                        WHEN zif_ca_ops_pf_types=>gc_role-ack      THEN zif_ca_ops_pf_types=>gc_intf-ack
                        WHEN zif_ca_ops_pf_types=>gc_role-sched    THEN zif_ca_ops_pf_types=>gc_intf-sched
                        WHEN zif_ca_ops_pf_types=>gc_role-stmt     THEN zif_ca_ops_pf_types=>gc_intf-stmt
                        WHEN zif_ca_ops_pf_types=>gc_role-ticket   THEN zif_ca_ops_pf_types=>gc_intf-ticket
                        WHEN zif_ca_ops_pf_types=>gc_role-calendar THEN zif_ca_ops_pf_types=>gc_intf-calendar ).
      TRY.
          IF lv_intf IS INITIAL.
            RAISE EXCEPTION TYPE zcx_ca_ops_error
              MESSAGE e386(zca_ops) WITH <ls_row>-role <ls_row>-file_type <ls_row>-class_name <ls_row>-role.
          ENDIF.
          " the interface of the role is checked by RTTI before the class is created
          ls_adp-instance = zcl_ca_ops_factory=>get_plugin( iv_class_name = <ls_row>-class_name
                                                            iv_interface  = lv_intf ).
          CAST zif_ca_ops_pf_adapter( ls_adp-instance )->configure( <ls_row> ).
        CATCH zcx_ca_ops_error INTO DATA(lx_error).
          CLEAR ls_adp-instance.
          ls_adp-problem = lx_error->get_text( ).
          note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-not_adapter
                   iv_v1    = <ls_row>-role
                   iv_v2    = <ls_row>-file_type
                   iv_v3    = <ls_row>-class_name
                   iv_v4    = ls_adp-problem ).
      ENDTRY.
      INSERT ls_adp INTO TABLE mt_adp.
    ENDLOOP.
  ENDMETHOD.


  METHOD adapter.
    READ TABLE mt_adp WITH KEY row-role = iv_role INTO rs_adp.
  ENDMETHOD.


  METHOD request.
    DATA(ls_source) = source_of( is_row-source_id ).
    rs_request = VALUE #( area      = mv_area
                          file_type = ms_type-file_type
                          adapter   = is_row
                          to_ts     = mv_now
                          max       = 50000
                          files     = VALUE #( FOR ls_f IN mt_files ( native_key = ls_f-native_key
                                                                      bukrs      = ls_f-bukrs
                                                                      run_date   = ls_f-run_date
                                                                      run_id     = ls_f-run_id
                                                                      bus_date   = ls_f-bus_date
                                                                      gen_at     = ls_f-gen_at ) ) ).
    IF ls_source-watermark IS INITIAL.
      rs_request-first = abap_true.
      rs_request-from_ts = zcl_ca_ops_pf_lifecycle=>add_minutes(
                             iv_ts      = mv_now
                             iv_minutes = - int_param( iv_name    = zif_ca_ops_pf_types=>gc_param-lookback
                                                       iv_default = zif_ca_ops_pf_types=>gc_default-lookback ) * 1440 ).
    ELSE.
      " bounded overlap: late and out-of-order records of the source are read again and stored once
      rs_request-from_ts = zcl_ca_ops_pf_lifecycle=>add_minutes(
                             iv_ts      = ls_source-watermark
                             iv_minutes = - int_param( iv_name    = zif_ca_ops_pf_types=>gc_param-overlap
                                                       iv_default = zif_ca_ops_pf_types=>gc_default-overlap ) ).
    ENDIF.
  ENDMETHOD.


  METHOD read_files.
    DATA(ls_adp) = adapter( zif_ca_ops_pf_types=>gc_role-file ).
    IF ls_adp IS INITIAL.
      note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-no_file_source iv_v1 = ms_type-file_type iv_v2 = mv_area ).
      RETURN.
    ENDIF.
    DATA(ls_request) = request( ls_adp-row ).
    IF ls_adp-instance IS NOT BOUND.
      source_done( is_row = ls_adp-row is_request = ls_request iv_status = zif_ca_ops_pf_types=>gc_src_status-failed
                   iv_reason = ls_adp-problem ).
      RETURN.
    ENDIF.
    TRY.
        DATA(ls_batch) = CAST zif_ca_ops_pf_file_src( ls_adp-instance )->read_files( ls_request ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " a failed query is "not evaluated", never "no files": the watermark stays
        source_done( is_row = ls_adp-row is_request = ls_request iv_status = zif_ca_ops_pf_types=>gc_src_status-failed
                     iv_reason = lx_error->get_text( ) ).
        note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-not_evaluated
                 iv_v1    = ls_adp-row-source_id
                 iv_v2    = ms_type-file_type
                 iv_v3    = lx_error->get_text( ) ).
        RETURN.
    ENDTRY.
    register_files( is_adp = ls_adp is_batch = ls_batch ).
    link_reissues( ).
    source_done( is_row    = ls_adp-row
                 is_request = ls_request
                 iv_status = COND #( WHEN ls_batch-partial = abap_true THEN zif_ca_ops_pf_types=>gc_src_status-partial
                                     ELSE zif_ca_ops_pf_types=>gc_src_status-read )
                 iv_as_of  = ls_batch-as_of
                 iv_reason = ls_batch-reason
                 iv_count  = lines( ls_batch-files ) ).
  ENDMETHOD.


  METHOD register_files.
    DATA lt_keys TYPE zif_ca_ops_pf_types=>tt_native_key.
    DATA lt_changed TYPE zif_ca_ops_pf_types=>tt_file.
    DATA lt_ids TYPE zif_ca_ops_pf_types=>tt_file_id.
    DATA lt_payments TYPE zif_ca_ops_pf_types=>tt_payment.

    DATA(lv_max_pay) = int_param( iv_name = zif_ca_ops_pf_types=>gc_param-max_pay
                                  iv_default = zif_ca_ops_pf_types=>gc_default-max_pay ).
    lt_keys = VALUE #( FOR ls_s IN is_batch-files ( ls_s-native_key ) ).
    INSERT LINES OF VALUE zif_ca_ops_pf_types=>tt_native_key( FOR ls_p IN is_batch-files WHERE ( predecessor_key IS NOT INITIAL )
                                                                ( ls_p-predecessor_key ) ) INTO TABLE lt_keys.
    DATA(lt_known) = mo_dao->files_by_key( iv_area = mv_area iv_file_type = ms_type-file_type it_native_keys = lt_keys ).
    DATA(lt_more) = VALUE zif_ca_ops_pf_types=>tt_file_id( ).
    LOOP AT lt_known ASSIGNING FIELD-SYMBOL(<ls_known>).
      INSERT <ls_known> INTO TABLE mt_files.
      IF NOT line_exists( mt_pay_ids[ table_line = <ls_known>-file_id ] ).
        INSERT <ls_known>-file_id INTO TABLE lt_more.
      ENDIF.
    ENDLOOP.
    " a known file outside the watch (a predecessor): its payments too, so that a save never loses them
    IF lt_more IS NOT INITIAL.
      INSERT LINES OF mo_dao->get_payments( iv_area = mv_area it_file_ids = lt_more ) INTO TABLE mt_payments.
      INSERT LINES OF lt_more INTO TABLE mt_pay_ids.
    ENDIF.

    LOOP AT is_batch-files ASSIGNING FIELD-SYMBOL(<ls_src>).
      ms_result-files_read += 1.
      READ TABLE lt_known WITH KEY native_key = <ls_src>-native_key INTO DATA(ls_file).
      IF sy-subrc <> 0.
        CLEAR ls_file.
        ls_file = VALUE #( area       = mv_area
                           file_id    = new_id( )
                           file_type  = ms_type-file_type
                           source_id  = is_adp-row-source_id
                           native_key = <ls_src>-native_key
                           state      = zif_ca_ops_pf_types=>gc_state-open
                           created_at = mv_now ).
        ms_result-files_new += 1.
      ENDIF.
      ls_file-bukrs       = <ls_src>-bukrs.
      ls_file-run_date    = <ls_src>-run_date.
      ls_file-run_id      = <ls_src>-run_id.
      ls_file-pay_method  = <ls_src>-pay_method.
      ls_file-house_bank  = <ls_src>-house_bank.
      ls_file-account_id  = <ls_src>-account_id.
      ls_file-calendar_id = ms_type-calendar_id.
      ls_file-changed_at  = mv_now.
      IF <ls_src>-gen_at IS NOT INITIAL.
        ls_file-gen_at = <ls_src>-gen_at.
      ENDIF.
      ls_file-bus_date = COND #( WHEN <ls_src>-bus_date IS NOT INITIAL THEN <ls_src>-bus_date
                                 WHEN ls_file-bus_date IS NOT INITIAL THEN ls_file-bus_date
                                 WHEN ls_file-gen_at IS NOT INITIAL
                                   THEN mo_lifecycle->business_date( is_type = ms_type iv_gen_at = ls_file-gen_at )
                                 ELSE mo_lifecycle->business_date( is_type = ms_type iv_gen_at = mv_now ) ).
      IF <ls_src>-predecessor_key IS NOT INITIAL.
        READ TABLE lt_known WITH KEY native_key = <ls_src>-predecessor_key ASSIGNING FIELD-SYMBOL(<ls_pred>).
        IF sy-subrc = 0.
          ls_file-predecessor = <ls_pred>-file_id.
        ENDIF.
      ENDIF.
      " payments: partner masked, at most PF_MAX_PAYMENTS kept (the rest counted only)
      DATA(lv_kept) = 0.
      DATA(lv_unknown) = 0.
      LOOP AT <ls_src>-payments ASSIGNING FIELD-SYMBOL(<ls_pay>).
        IF lv_kept >= lv_max_pay.
          EXIT.
        ENDIF.
        lv_kept += 1.
        IF <ls_pay>-amount_known = abap_false.
          lv_unknown += 1.
        ENDIF.
        INSERT VALUE #( area           = mv_area
                        file_id        = ls_file-file_id
                        pay_key        = <ls_pay>-pay_key
                        bukrs          = <ls_pay>-bukrs
                        currency       = <ls_pay>-currency
                        amount         = <ls_pay>-amount
                        amount_known   = <ls_pay>-amount_known
                        partner_masked = zcl_ca_ops_link_query=>mask( iv_value       = <ls_pay>-partner
                                                                      iv_sensitivity = zif_ca_ops_link_types=>gc_sensitivity-masked )
                        pay_doc        = <ls_pay>-pay_doc
                        pay_method     = <ls_pay>-pay_method
                        batch_id       = <ls_pay>-batch_id ) INTO TABLE lt_payments.
      ENDLOOP.
      ls_file-pay_count = nmax( val1 = <ls_src>-pay_count val2 = lines( <ls_src>-payments ) ).
      ls_file-pay_partial = xsdbool( ls_file-pay_count > lv_kept ).
      ls_file-unknown_count = lv_unknown + ls_file-pay_count - lv_kept.
      IF ls_file-pay_partial = abap_true.
        note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-pay_cut iv_v1 = ls_file-native_key iv_v2 = lv_max_pay ).
      ENDIF.
      INSERT ls_file-file_id INTO TABLE lt_ids.
      INSERT ls_file INTO TABLE lt_changed.
      " the file source evidences the payment run: one observation per file, its first time kept
      DATA(ls_event) = VALUE zif_ca_ops_pf_types=>ty_event(
                         area            = mv_area
                         file_id         = ls_file-file_id
                         milestone       = zif_ca_ops_pf_types=>gc_milestone-payrun
                         outcome         = zif_ca_ops_pf_types=>gc_outcome-ok
                         source_id       = is_adp-row-source_id
                         source_type     = COND #( WHEN is_adp-row-source_type IS NOT INITIAL THEN is_adp-row-source_type
                                                   ELSE zif_ca_ops_pf_types=>gc_source_type-sap )
                         bukrs           = ls_file-bukrs
                         native_key      = ls_file-native_key
                         source_event_id = ls_file-native_key
                         event_version   = 1
                         occurred_at     = COND #( WHEN ls_file-gen_at IS NOT INITIAL THEN ls_file-gen_at ELSE mv_now )
                         observed_at     = mv_now
                         bus_date        = ls_file-bus_date
                         item_count      = ls_file-pay_count
                         ack_scope       = zif_ca_ops_pf_types=>gc_ack_level-file
                         corr_quality    = zif_ca_ops_exc_contract=>gc_quality-confirmed
                         link_object     = <ls_src>-link_object
                         link_value      = <ls_src>-link_value
                         created_at      = mv_now ).
      ls_event-event_key = event_key( iv_area = mv_area is_event = ls_event ).
      INSERT ls_event INTO TABLE mt_new_events.
    ENDLOOP.

    " the working set: replaced by what was read
    LOOP AT lt_changed ASSIGNING FIELD-SYMBOL(<ls_changed>).
      DELETE mt_files WHERE file_id = <ls_changed>-file_id.
      INSERT <ls_changed> INTO TABLE mt_files.
    ENDLOOP.
    LOOP AT lt_ids ASSIGNING FIELD-SYMBOL(<lv_id>).
      DELETE mt_payments WHERE file_id = <lv_id>.
    ENDLOOP.
    INSERT LINES OF lt_payments INTO TABLE mt_payments.
    INSERT LINES OF lt_ids INTO TABLE mt_pay_ids.
  ENDMETHOD.


  METHOD link_reissues.
    DATA(lt_elsewhere) = mo_dao->payments_elsewhere( iv_area = mv_area it_payments = mt_payments ).
    LOOP AT lt_elsewhere ASSIGNING FIELD-SYMBOL(<ls_other>).
      LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_pay>) WHERE pay_key = <ls_other>-pay_key
                                                             AND file_id <> <ls_other>-file_id.
        <ls_pay>-other_file = <ls_other>-file_id.
        DATA(lv_this) = <ls_pay>-file_id.
        " the earlier file's payment is marked too (when it is in the working set)
        LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_mirror>) WHERE pay_key = <ls_other>-pay_key
                                                                  AND file_id = <ls_other>-file_id.
          <ls_mirror>-other_file = lv_this.
        ENDLOOP.
        READ TABLE mt_files WITH TABLE KEY file_id = lv_this ASSIGNING FIELD-SYMBOL(<ls_file>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        READ TABLE mt_files WITH TABLE KEY file_id = <ls_other>-file_id ASSIGNING FIELD-SYMBOL(<ls_earlier>).
        " the later file of the two replaces the earlier one (same payments in a new file)
        IF sy-subrc = 0 AND <ls_file>-predecessor IS INITIAL AND <ls_earlier>-predecessor <> lv_this
           AND <ls_earlier>-created_at <= <ls_file>-created_at.
          <ls_file>-predecessor = <ls_earlier>-file_id.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_events.
    LOOP AT mt_adp ASSIGNING FIELD-SYMBOL(<ls_adp>)
         WHERE row-role = zif_ca_ops_pf_types=>gc_role-transfer OR row-role = zif_ca_ops_pf_types=>gc_role-ack
            OR row-role = zif_ca_ops_pf_types=>gc_role-sched OR row-role = zif_ca_ops_pf_types=>gc_role-stmt.
      DATA(ls_request) = request( <ls_adp>-row ).
      IF <ls_adp>-instance IS NOT BOUND.
        source_done( is_row = <ls_adp>-row is_request = ls_request iv_status = zif_ca_ops_pf_types=>gc_src_status-failed
                     iv_reason = <ls_adp>-problem ).
        CONTINUE.
      ENDIF.
      TRY.
          DATA(ls_batch) = CAST zif_ca_ops_pf_event_src( <ls_adp>-instance )->read_events( ls_request ).
        CATCH zcx_ca_ops_error INTO DATA(lx_error).
          source_done( is_row = <ls_adp>-row is_request = ls_request iv_status = zif_ca_ops_pf_types=>gc_src_status-failed
                       iv_reason = lx_error->get_text( ) ).
          note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-not_evaluated
                   iv_v1    = <ls_adp>-row-source_id
                   iv_v2    = ms_type-file_type
                   iv_v3    = lx_error->get_text( ) ).
          CONTINUE.
      ENDTRY.
      DATA(lv_before) = lines( mt_new_events ).
      match_events( is_adp = <ls_adp> is_batch = ls_batch ).
      ms_result-events_read += lines( ls_batch-events ).
      source_done( is_row      = <ls_adp>-row
                   is_request  = ls_request
                   iv_status   = COND #( WHEN ls_batch-partial = abap_true THEN zif_ca_ops_pf_types=>gc_src_status-partial
                                         ELSE zif_ca_ops_pf_types=>gc_src_status-read )
                   iv_as_of    = ls_batch-as_of
                   iv_reason   = ls_batch-reason
                   iv_count    = lines( ls_batch-events )
                   iv_unmapped = REDUCE i( INIT n = 0
                                           FOR ls_e IN mt_new_events FROM lv_before + 1
                                           WHERE ( outcome = zif_ca_ops_pf_types=>gc_outcome-info )
                                           NEXT n = n + 1 ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD match_events.
    DATA lt_ids TYPE zif_ca_ops_pf_types=>tt_native_key.
    DATA lt_reported TYPE SORTED TABLE OF zif_ca_ops_pf_types=>ty_status WITH UNIQUE KEY table_line.

    lt_ids = VALUE #( FOR ls_s IN is_batch-events ( CONV #( ls_s-source_event_id ) ) ).
    DATA(lt_earlier) = mo_dao->events_by_source_id( iv_area      = mv_area
                                                    iv_source_id = is_adp-row-source_id
                                                    it_ids       = lt_ids ).
    LOOP AT is_batch-events ASSIGNING FIELD-SYMBOL(<ls_src>).
      READ TABLE mt_maps WITH TABLE KEY source_id = is_adp-row-source_id status = <ls_src>-native_status
           ASSIGNING FIELD-SYMBOL(<ls_map>).
      DATA(lv_mapped) = xsdbool( sy-subrc = 0 ).
      DATA(ls_event) = VALUE zif_ca_ops_pf_types=>ty_event(
                         area            = mv_area
                         source_id       = is_adp-row-source_id
                         source_type     = is_adp-row-source_type
                         native_status   = <ls_src>-native_status
                         logsys          = <ls_src>-logsys
                         sys_client      = <ls_src>-sys_client
                         bukrs           = <ls_src>-bukrs
                         native_key      = <ls_src>-native_key
                         source_event_id = <ls_src>-source_event_id
                         event_version   = <ls_src>-event_version
                         occurred_at     = <ls_src>-occurred_at
                         observed_at     = mv_now
                         bus_date        = <ls_src>-bus_date
                         amount          = <ls_src>-amount
                         currency        = <ls_src>-currency
                         item_count      = <ls_src>-item_count
                         batch_id        = <ls_src>-batch_id
                         pay_key         = <ls_src>-pay_key
                         ack_scope       = COND #( WHEN <ls_src>-pay_key IS NOT INITIAL THEN zif_ca_ops_pf_types=>gc_ack_level-payment
                                                   WHEN <ls_src>-batch_id IS NOT INITIAL THEN zif_ca_ops_pf_types=>gc_ack_level-batch
                                                   ELSE zif_ca_ops_pf_types=>gc_ack_level-file )
                         link_object     = <ls_src>-link_object
                         link_value      = <ls_src>-link_value
                         info            = <ls_src>-info
                         created_at      = mv_now ).
      IF lv_mapped = abap_true.
        ls_event-milestone = <ls_map>-milestone.
        ls_event-outcome   = <ls_map>-outcome.
      ELSE.
        " an unmapped value is evidence that moves nothing - said once per value and run
        ls_event-outcome = zif_ca_ops_pf_types=>gc_outcome-info.
        INSERT <ls_src>-native_status INTO TABLE lt_reported.
        IF sy-subrc = 0.
          note( iv_msgno = zif_ca_ops_pf_types=>gc_msg-unmapped iv_v1 = <ls_src>-native_status
                   iv_v2 = is_adp-row-source_id ).
        ENDIF.
      ENDIF.
      " a repeated bank reference: the number of earlier observations of the same record ID
      ls_event-repeat_no = REDUCE i( INIT n = 0
                                     FOR ls_e IN lt_earlier WHERE ( source_event_id = <ls_src>-source_event_id
                                                                    AND event_version <> <ls_src>-event_version )
                                     NEXT n = n + 1 ).
      files_of_event( EXPORTING is_event   = <ls_src>
                      IMPORTING et_files   = DATA(lt_files)
                                ev_quality = ls_event-corr_quality ).
      IF lt_files IS INITIAL.
        ls_event-event_key = event_key( iv_area = mv_area is_event = ls_event ).
        INSERT ls_event INTO TABLE mt_new_events.
        CONTINUE.
      ENDIF.
      LOOP AT lt_files ASSIGNING FIELD-SYMBOL(<lv_file_id>).
        ls_event-file_id = <lv_file_id>.
        READ TABLE mt_files WITH TABLE KEY file_id = <lv_file_id> ASSIGNING FIELD-SYMBOL(<ls_file>).
        IF sy-subrc = 0.
          ls_event-native_key = <ls_file>-native_key.
          " the job that generated the file (scheduler)
          IF <ls_src>-job_name IS NOT INITIAL AND ls_event-milestone = zif_ca_ops_pf_types=>gc_milestone-generated.
            <ls_file>-gen_job      = <ls_src>-job_name.
            <ls_file>-gen_jobcount = <ls_src>-job_count.
          ENDIF.
        ENDIF.
        ls_event-event_key = event_key( iv_area = mv_area is_event = ls_event ).
        INSERT ls_event INTO TABLE mt_new_events.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD files_of_event.
    CLEAR: et_files, ev_quality.
    ev_quality = zif_ca_ops_exc_contract=>gc_quality-confirmed.
    " an acknowledgement of several files, else the file it names
    DATA(lt_keys) = is_event-covers.
    IF is_event-native_key IS NOT INITIAL.
      INSERT is_event-native_key INTO TABLE lt_keys.
    ENDIF.
    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<lv_key>).
      LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE native_key = <lv_key>.
        INSERT <ls_file>-file_id INTO TABLE et_files.
      ENDLOOP.
    ENDLOOP.
    IF et_files IS NOT INITIAL OR lt_keys IS NOT INITIAL.
      IF et_files IS INITIAL.
        ev_quality = zif_ca_ops_exc_contract=>gc_quality-unmatched.
      ENDIF.
      RETURN.
    ENDIF.
    " a payment or a batch of a file under watch
    IF is_event-pay_key IS NOT INITIAL OR is_event-batch_id IS NOT INITIAL.
      LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_pay>)
           WHERE ( pay_key = is_event-pay_key AND pay_key IS NOT INITIAL )
              OR ( batch_id = is_event-batch_id AND batch_id IS NOT INITIAL ).
        INSERT <ls_pay>-file_id INTO TABLE et_files.
      ENDLOOP.
      IF et_files IS INITIAL.
        ev_quality = zif_ca_ops_exc_contract=>gc_quality-unmatched.
      ENDIF.
      RETURN.
    ENDIF.
    " the files of a payment run (company code when given)
    IF is_event-run_date IS NOT INITIAL AND is_event-run_id IS NOT INITIAL.
      LOOP AT mt_files ASSIGNING <ls_file> WHERE run_date = is_event-run_date AND run_id = is_event-run_id
                                             AND ( bukrs = is_event-bukrs OR bukrs IS INITIAL ).
        INSERT <ls_file>-file_id INTO TABLE et_files.
      ENDLOOP.
      IF is_event-bukrs IS INITIAL AND et_files IS NOT INITIAL.
        ev_quality = zif_ca_ops_exc_contract=>gc_quality-probable.
      ELSEIF et_files IS INITIAL.
        ev_quality = zif_ca_ops_exc_contract=>gc_quality-unmatched.
      ENDIF.
      RETURN.
    ENDIF.
    " a job names no file: the files of its business date without generation evidence yet (probable)
    IF is_event-job_name IS NOT INITIAL.
      LOOP AT mt_files ASSIGNING <ls_file> WHERE bus_date = is_event-bus_date AND gen_job IS INITIAL.
        INSERT <ls_file>-file_id INTO TABLE et_files.
      ENDLOOP.
      LOOP AT mt_files ASSIGNING <ls_file> WHERE gen_job = is_event-job_name AND gen_jobcount = is_event-job_count.
        INSERT <ls_file>-file_id INTO TABLE et_files.
      ENDLOOP.
    ENDIF.
    ev_quality = COND #( WHEN et_files IS INITIAL THEN zif_ca_ops_exc_contract=>gc_quality-unmatched
                         ELSE zif_ca_ops_exc_contract=>gc_quality-probable ).
  ENDMETHOD.


  METHOD evaluate_files.
    DATA lt_ids TYPE zif_ca_ops_pf_types=>tt_file_id.
    DATA lt_ms TYPE zif_ca_ops_pf_types=>tt_ms.

    lt_ids = VALUE #( FOR ls_f IN mt_files WHERE ( bus_date >= mv_open_from ) ( ls_f-file_id ) ).
    IF lt_ids IS INITIAL.
      RETURN.
    ENDIF.
    " the stored evidence and this run's new observations (test mode: not stored, still evaluated)
    DATA(lt_events) = mo_dao->get_events( iv_area = mv_area it_file_ids = lt_ids ).
    LOOP AT mt_new_events ASSIGNING FIELD-SYMBOL(<ls_new>) WHERE file_id IS NOT INITIAL.
      IF NOT line_exists( lt_events[ event_key = <ls_new>-event_key ] ).
        INSERT <ls_new> INTO TABLE lt_events.
      ENDIF.
    ENDLOOP.
    DATA(lt_health) = health( ).
    DATA(ls_ticket) = adapter( zif_ca_ops_pf_types=>gc_role-ticket ).

    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE bus_date >= mv_open_from.
      DATA(lt_file_events) = VALUE zif_ca_ops_pf_types=>tt_event( FOR ls_e IN lt_events WHERE ( file_id = <ls_file>-file_id )
                                                                  ( ls_e ) ).
      DATA(lt_file_pays) = VALUE zif_ca_ops_pf_types=>tt_payment( FOR ls_p IN mt_payments WHERE ( file_id = <ls_file>-file_id )
                                                                  ( ls_p ) ).
      DATA(ls_eval) = mo_lifecycle->evaluate( is_type     = ms_type
                                              it_stages   = mt_stages
                                              is_file     = <ls_file>
                                              it_events   = lt_file_events
                                              it_payments = lt_file_pays
                                              it_health   = lt_health
                                              iv_now      = mv_now ).
      ms_result-evaluated += 1.
      <ls_file>-stage       = ls_eval-stage.
      <ls_file>-next_ms     = ls_eval-next_ms.
      <ls_file>-state       = ls_eval-state.
      <ls_file>-deadline_at = ls_eval-deadline_at.
      <ls_file>-overdue_min = ls_eval-overdue_min.
      <ls_file>-eval_state  = ls_eval-eval_state.
      <ls_file>-eval_reason = ls_eval-eval_reason.
      <ls_file>-eval_at     = mv_now.
      <ls_file>-ack_conflict = ls_eval-conflict.
      <ls_file>-pay_rejected = ls_eval-pay_rejected.
      <ls_file>-pay_open     = ls_eval-pay_open.
      <ls_file>-late_ms      = ls_eval-late_ms.
      <ls_file>-late_min     = ls_eval-late_min.
      " a file another file replaced stays visible as REPLACED (a late answer for it is still evaluated)
      IF line_exists( mt_files[ predecessor = <ls_file>-file_id ] ).
        <ls_file>-state = zif_ca_ops_pf_types=>gc_state-replaced.
      ENDIF.
      IF ls_eval-eval_state = zif_ca_ops_pf_types=>gc_eval-complete OR ls_eval-eval_state = zif_ca_ops_pf_types=>gc_eval-partial.
        <ls_file>-last_valid_at    = mv_now.
        <ls_file>-last_valid_state = <ls_file>-state.
      ELSE.
        ms_result-not_eval += 1.
      ENDIF.
      INSERT LINES OF ls_eval-milestones INTO TABLE lt_ms.
      " payment-level answers on the payments (affected payments facet)
      LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_pay>) WHERE file_id = <ls_file>-file_id.
        LOOP AT lt_file_events ASSIGNING FIELD-SYMBOL(<ls_ack>)
             WHERE milestone = zif_ca_ops_pf_types=>gc_milestone-accepted
               AND ( pay_key = <ls_pay>-pay_key OR ( batch_id = <ls_pay>-batch_id AND batch_id IS NOT INITIAL ) )
               AND outcome <> zif_ca_ops_pf_types=>gc_outcome-info.
          IF <ls_ack>-occurred_at >= <ls_pay>-ack_at.
            <ls_pay>-ack_outcome = <ls_ack>-outcome.
            <ls_pay>-ack_at      = <ls_ack>-occurred_at.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
      " an overdue file is handed to the ticket sink once (delivered sink: log only)
      IF ls_ticket-instance IS BOUND AND <ls_file>-overdue_min > 0 AND <ls_file>-ticket_ref IS INITIAL
         AND <ls_file>-state <> zif_ca_ops_pf_types=>gc_state-replaced.
        DATA(ls_answer) = CAST zif_ca_ops_pf_ticket_sink( ls_ticket-instance )->raise_ticket(
                            VALUE #( area       = mv_area
                                     file_type  = ms_type-file_type
                                     file_id    = <ls_file>-file_id
                                     native_key = <ls_file>-native_key
                                     milestone  = <ls_file>-next_ms
                                     overdue    = <ls_file>-overdue_min ) ).
        IF ls_answer-status <> zif_ca_ops_pf_types=>gc_ticket-failed.
          <ls_file>-ticket_ref = ls_answer-ref.
          ms_result-tickets += 1.
        ENDIF.
        INSERT ls_answer-text INTO TABLE ms_result-messages.
      ENDIF.
    ENDLOOP.

    IF mv_test = abap_false.
      mo_dao->save_files( VALUE #( FOR ls_f IN mt_files ( ls_f ) ) ).
      mo_dao->save_payments( iv_area = mv_area it_file_ids = mt_pay_ids it_payments = mt_payments ).
      mo_dao->save_milestones( iv_area = mv_area it_file_ids = lt_ids it_milestones = lt_ms ).
    ENDIF.
  ENDMETHOD.


  METHOD health.
    " the sources whose mapping rows evidence a milestone (the file source: the payment run)
    LOOP AT mt_adp ASSIGNING FIELD-SYMBOL(<ls_adp>) WHERE row-role <> zif_ca_ops_pf_types=>gc_role-ticket
                                                      AND row-role <> zif_ca_ops_pf_types=>gc_role-calendar.
      DATA(ls_source) = source_of( <ls_adp>-row-source_id ).
      DATA(lv_stale) = COND i( WHEN ms_type-stale_min > 0 THEN ms_type-stale_min
                               ELSE int_param( iv_name    = zif_ca_ops_pf_types=>gc_param-stale_min
                                               iv_default = zif_ca_ops_pf_types=>gc_default-stale_min ) ).
      DATA(lv_eval) = COND zif_ca_ops_pf_types=>ty_flag(
                        WHEN ls_source-status = zif_ca_ops_pf_types=>gc_src_status-failed
                          THEN zif_ca_ops_pf_types=>gc_eval-not_evaluated
                        WHEN ls_source-as_of IS INITIAL
                          OR zcl_ca_ops_pf_lifecycle=>add_minutes( iv_ts = ls_source-as_of iv_minutes = lv_stale ) < mv_now
                          THEN zif_ca_ops_pf_types=>gc_eval-stale ).
      IF lv_eval IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_reason) = COND zif_ca_ops_pf_types=>ty_reason(
                          WHEN lv_eval = zif_ca_ops_pf_types=>gc_eval-not_evaluated THEN ls_source-reason
                          ELSE zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-stale
                                                      iv_v1    = <ls_adp>-row-source_id
                                                      iv_v2    = ms_type-file_type
                                                      iv_v3    = ls_source-as_of
                                                      iv_v4    = lv_stale ) ).
      DATA(lt_milestones) = VALUE zif_ca_ops_pf_types=>tt_native_key( ).
      IF <ls_adp>-row-role = zif_ca_ops_pf_types=>gc_role-file.
        INSERT CONV #( zif_ca_ops_pf_types=>gc_milestone-payrun ) INTO TABLE lt_milestones.
      ENDIF.
      LOOP AT mt_maps ASSIGNING FIELD-SYMBOL(<ls_map>) WHERE source_id = <ls_adp>-row-source_id
                                                         AND milestone IS NOT INITIAL.
        INSERT CONV #( <ls_map>-milestone ) INTO TABLE lt_milestones.
      ENDLOOP.
      LOOP AT lt_milestones ASSIGNING FIELD-SYMBOL(<lv_ms>).
        READ TABLE rt_health WITH TABLE KEY milestone = CONV zif_ca_ops_pf_types=>ty_milestone( <lv_ms> )
             ASSIGNING FIELD-SYMBOL(<ls_health>).
        IF sy-subrc <> 0.
          INSERT VALUE #( milestone = <lv_ms> eval = lv_eval reason = lv_reason ) INTO TABLE rt_health.
        ELSEIF lv_eval = zif_ca_ops_pf_types=>gc_eval-not_evaluated.
          " not evaluated outranks stale
          <ls_health>-eval   = lv_eval.
          <ls_health>-reason = lv_reason.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD evaluate_days.
    DATA lt_days TYPE zif_ca_ops_pf_types=>tt_day.
    DATA(ls_file_src) = adapter( zif_ca_ops_pf_types=>gc_role-file ).
    DATA(ls_source) = source_of( ls_file_src-row-source_id ).
    IF ls_file_src IS INITIAL.
      ls_source-status = zif_ca_ops_pf_types=>gc_src_status-failed.
      ls_source-reason = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-no_file_source
                                                iv_v1    = ms_type-file_type
                                                iv_v2    = mv_area ).
    ENDIF.
    DATA(lv_stale) = COND i( WHEN ms_type-stale_min > 0 THEN ms_type-stale_min
                             ELSE int_param( iv_name    = zif_ca_ops_pf_types=>gc_param-stale_min
                                             iv_default = zif_ca_ops_pf_types=>gc_default-stale_min ) ).
    " the day's expectation is due at the first clock deadline of the type's milestones, else at the end of the day
    DATA(ls_first_clock) = VALUE zif_ca_ops_pf_types=>ty_stage( ).
    LOOP AT mt_stages ASSIGNING FIELD-SYMBOL(<ls_stage>) WHERE due_kind = zif_ca_ops_pf_types=>gc_due_kind-clock.
      IF ls_first_clock IS INITIAL
         OR zcl_ca_ops_pf_lifecycle=>rank( <ls_stage>-milestone ) < zcl_ca_ops_pf_lifecycle=>rank( ls_first_clock-milestone ).
        ls_first_clock = <ls_stage>.
      ENDIF.
    ENDLOOP.
    DATA(lt_previous) = mo_dao->get_days( iv_area = mv_area iv_file_type = ms_type-file_type iv_from = mv_open_from ).
    DATA(lv_date) = mv_open_from.
    WHILE lv_date <= mv_today.
      DATA(lv_due) = mo_lifecycle->clock_due( is_type = ms_type
                                              iv_date = lv_date
                                              iv_days = COND #( WHEN ls_first_clock IS INITIAL THEN 0
                                                                ELSE ls_first_clock-day_offset )
                                              iv_time = COND #( WHEN ls_first_clock IS INITIAL
                                                                THEN zif_ca_ops_types=>gc_time-day_end
                                                                ELSE ls_first_clock-due_time ) ).
      DATA(lv_observed) = REDUCE i( INIT n = 0
                                    FOR ls_f IN mt_files WHERE ( bus_date = lv_date AND predecessor IS INITIAL )
                                    NEXT n = n + 1 ).
      DATA(ls_day) = mo_lifecycle->evaluate_day( is_type      = ms_type
                                                 is_input     = VALUE #( bus_date      = lv_date
                                                                         observed      = lv_observed
                                                                         source_status = ls_source-status
                                                                         source_reason = ls_source-reason
                                                                         as_of         = ls_source-as_of
                                                                         watermark     = ls_source-watermark
                                                                         due_at        = lv_due )
                                                 iv_stale_min = lv_stale
                                                 iv_now       = mv_now ).
      " a day that could not be evaluated keeps its last valid result
      DATA(ls_before) = VALUE #( lt_previous[ bus_date = lv_date ] OPTIONAL ).
      IF ls_day-completeness = zif_ca_ops_pf_types=>gc_eval-complete.
        ls_day-last_valid_result = ls_day-result.
        ls_day-last_valid_at     = mv_now.
      ELSE.
        ls_day-last_valid_result = ls_before-last_valid_result.
        ls_day-last_valid_at     = ls_before-last_valid_at.
      ENDIF.
      INSERT ls_day INTO TABLE lt_days.
      lv_date += 1.
    ENDWHILE.
    IF mv_test = abap_false.
      mo_dao->save_days( lt_days ).
    ENDIF.
  ENDMETHOD.


  METHOD source_done.
    DATA(ls_source) = source_of( is_row-source_id ).
    ls_source-area        = mv_area.
    ls_source-source_id   = is_row-source_id.
    ls_source-role        = is_row-role.
    ls_source-last_run_at = mv_now.
    ls_source-status      = iv_status.
    ls_source-reason      = iv_reason.
    IF iv_status <> zif_ca_ops_pf_types=>gc_src_status-failed.
      ls_source-last_ok_at     = mv_now.
      ls_source-read_count     = iv_count.
      ls_source-unmapped_count = iv_unmapped.
      ls_source-as_of = COND #( WHEN iv_as_of IS NOT INITIAL THEN iv_as_of ELSE is_request-to_ts ).
      " a partial read keeps its watermark: the rest is read next time
      IF iv_status = zif_ca_ops_pf_types=>gc_src_status-read.
        ls_source-watermark = is_request-to_ts.
      ENDIF.
    ENDIF.
    DELETE mt_sources WHERE source_id = is_row-source_id.
    INSERT ls_source INTO TABLE mt_sources.
    IF mv_test = abap_false.
      TRY.
          mo_dao->save_source( ls_source ).
        CATCH zcx_ca_ops_error INTO DATA(lx_error).
          INSERT lx_error->get_text( ) INTO TABLE ms_result-messages.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD source_of.
    rs_source = VALUE #( mt_sources[ source_id = iv_source_id ] OPTIONAL ).
  ENDMETHOD.


  METHOD event_key.
    rv_key = zcl_ca_ops_cfg_version=>of_lines( VALUE #(
               ( |{ iv_area }\|{ is_event-source_id }\|{ is_event-source_event_id }\|{ is_event-event_version }\||
              && |{ is_event-native_key }\|{ is_event-pay_key }\|{ is_event-milestone }| ) ) ).
  ENDMETHOD.


  METHOD default_role.
    rv_role = SWITCH #( iv_milestone
                        WHEN zif_ca_ops_pf_types=>gc_milestone-payrun    THEN zif_ca_ops_pf_types=>gc_role-file
                        WHEN zif_ca_ops_pf_types=>gc_milestone-generated THEN zif_ca_ops_pf_types=>gc_role-sched
                        WHEN zif_ca_ops_pf_types=>gc_milestone-pickup
                          OR zif_ca_ops_pf_types=>gc_milestone-delivered THEN zif_ca_ops_pf_types=>gc_role-transfer
                        WHEN zif_ca_ops_pf_types=>gc_milestone-receipt
                          OR zif_ca_ops_pf_types=>gc_milestone-accepted  THEN zif_ca_ops_pf_types=>gc_role-ack
                        WHEN zif_ca_ops_pf_types=>gc_milestone-settled   THEN zif_ca_ops_pf_types=>gc_role-stmt ).
  ENDMETHOD.


  METHOD int_param.
    rv_value = zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                           iv_name    = iv_name
                                           iv_default = iv_default ).
  ENDMETHOD.


  METHOD note.
    INSERT zcl_ca_ops_util=>text( iv_msgno = iv_msgno iv_v1 = iv_v1 iv_v2 = iv_v2 iv_v3 = iv_v3 iv_v4 = iv_v4 )
           INTO TABLE ms_result-messages.
  ENDMETHOD.


  METHOD new_id.
    TRY.
        rv_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e001(zca_ops)
          EXPORTING
            previous = lx_uuid.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
