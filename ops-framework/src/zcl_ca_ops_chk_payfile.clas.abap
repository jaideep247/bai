*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_payfile.clas.abap
*& Purpose:
*& Registered check of the payment file lifecycle (catalogue process
*& FICA_PAYFILE_ACK, module CASHOPS; docs/PAYMENT_FILE_LIFECYCLE.md
*& section 8): per active file type of the area whose business process is
*& in effect, the files under watch as the last ingestion evaluated them
*& (ZCA_OPS_PFFILE / PFMST), one finding per file and currency where the
*& file stopped - the first required milestone MISSING past its deadline
*& (flagship PF_ACK_MISSING: generated, no acceptance of the bank),
*& FAILED (job / transfer), REJECTED or PARTIAL - plus conflicting
*& answers of the bank, a reissue after the original reached the bank
*& (PF_DUP_EXPOSURE) and an answer for the original after its reissue
*& (PF_ORIG_ACK_AFTER_REISSUE), a milestone reached late (information),
*& business days with fewer files than expected, sources that failed (not
*& evaluated - the check is then partial, nothing is auto-resolved) and
*& stale days. Every finding carries the exception contract: payments,
*& gross amount in one currency (never summed across currencies), payments
*& without a known amount, duplicate exposure apart from the gross, the
*& deadline and its calendar, the stage reached, the responsible owner
*& from the configuration (ZIF_CA_OPS_OWNER) and typed evidence rows
*& (SAP run, job, payment documents; transfer records; bank answers;
*& statement lines). Severity: W within the grace minutes, E after, B from
*& PF_BREACH_RED_MIN minutes or the amount limit of its currency and
*& company code (PF_AMOUNT_RED_<area> / PF_AMOUNT_RED). Reads only through
*& ZIF_CA_OPS_PF_DAO; writes nothing.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - check: payment file lifecycle</p>
"! A job failure is one finding (PF_JOB_FAILED, reference = the job monitor's object key of the job, name / count;
"! docs/PAYMENT_FILE_LIFECYCLE.md section 7), never a second "not generated" finding of the same file.
CLASS zcl_ca_ops_chk_payfile DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.
    INTERFACES zif_ca_ops_check_config.

    "! Amount limit of a currency and company code from a limit list ("[company code:]currency amount, ...";
    "! a company-code entry wins over the currency entry; 0 = none)
    CLASS-METHODS amount_limit
      IMPORTING
        iv_list         TYPE clike
        iv_currency     TYPE clike
        iv_bukrs        TYPE clike
      RETURNING
        VALUE(rv_limit) TYPE zif_ca_ops_pf_types=>ty_amount.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_limits,
        grace     TYPE i,
        red_min   TYPE i,
        max_finds TYPE i,
        max_evid  TYPE i,
        open_days TYPE i,
        amounts   TYPE string,
      END OF ty_limits.

    "! A finding to be built for a file: code, message and the figures it stands for
    TYPES:
      BEGIN OF ty_issue,
        code      TYPE zif_ca_ops_types=>ty_check_code,
        msgno     TYPE zif_ca_ops_types=>ty_msgno,
        milestone TYPE zif_ca_ops_pf_types=>ty_milestone,
        due_at    TYPE timestampl,
        overdue   TYPE i,
        "! B / E / W / I fixed by the code (blank = by deadline and amount)
        severity  TYPE zif_ca_ops_types=>ty_severity,
        "! X = the finding carries the duplicate exposure, not the gross (related findings count the gross once)
        exposure  TYPE abap_bool,
        other     TYPE zif_ca_ops_pf_types=>ty_native_key,
      END OF ty_issue.
    TYPES tt_issue TYPE STANDARD TABLE OF ty_issue WITH EMPTY KEY.

    DATA ms_limits TYPE ty_limits.
    DATA mo_dao TYPE REF TO zif_ca_ops_pf_dao.
    DATA ms_check TYPE zif_ca_ops_chk_types=>ty_check.
    "! Milestones of the file type in evaluation (grace minutes of a milestone)
    DATA mt_stages TYPE zif_ca_ops_pf_types=>tt_stage.

    METHODS limits
      IMPORTING
        iv_area          TYPE zif_ca_ops_types=>ty_area
      RETURNING
        VALUE(rs_limits) TYPE ty_limits.

    "! What is wrong with a file (where it stopped, conflicts, reissue)
    METHODS issues
      IMPORTING
        is_file          TYPE zif_ca_ops_pf_types=>ty_file
        it_milestones    TYPE zif_ca_ops_pf_types=>tt_ms
        it_files         TYPE zif_ca_ops_pf_types=>tt_file
      RETURNING
        VALUE(rt_issues) TYPE tt_issue.

    "! Findings and evidence of the issues of one file (one per currency)
    METHODS file_findings
      IMPORTING
        is_type     TYPE zif_ca_ops_pf_types=>ty_type_cfg
        is_file     TYPE zif_ca_ops_pf_types=>ty_file
        it_issues   TYPE tt_issue
        it_totals   TYPE zif_ca_ops_pf_types=>tt_total
        it_events   TYPE zif_ca_ops_pf_types=>tt_event
        it_payments TYPE zif_ca_ops_pf_types=>tt_payment
      CHANGING
        cs_result   TYPE zif_ca_ops_chk_types=>ty_result.

    "! Typed evidence rows of a file
    METHODS evidence
      IMPORTING
        iv_key             TYPE zif_ca_ops_exc_contract=>ty_evid_key
        is_file            TYPE zif_ca_ops_pf_types=>ty_file
        it_events          TYPE zif_ca_ops_pf_types=>tt_event
        it_payments        TYPE zif_ca_ops_pf_types=>tt_payment
      RETURNING
        VALUE(rt_evidence) TYPE zif_ca_ops_exc_contract=>tt_evidence.

    "! Findings of the business days and of the sources of a file type
    METHODS day_findings
      IMPORTING
        is_type   TYPE zif_ca_ops_pf_types=>ty_type_cfg
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS severity
      IMPORTING
        is_issue           TYPE ty_issue
        is_file            TYPE zif_ca_ops_pf_types=>ty_file
        iv_grace           TYPE i
        iv_amount          TYPE zif_ca_ops_pf_types=>ty_amount
        iv_currency        TYPE clike
      RETURNING
        VALUE(rv_severity) TYPE zif_ca_ops_types=>ty_severity.

    "! Object key: file type / native key [/ currency] within 70 characters (the currency is never cut)
    CLASS-METHODS object_key
      IMPORTING
        is_file       TYPE zif_ca_ops_pf_types=>ty_file
        iv_currency   TYPE clike
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.

    CLASS-METHODS time_text
      IMPORTING
        iv_ts          TYPE timestampl
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_chk_payfile IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    ms_check = is_check.
    mo_dao = zcl_ca_ops_factory=>get_pf_dao( ).
    ms_limits = limits( is_check-area ).
    DATA(lt_off) = zcl_ca_ops_factory=>get_catalog( )->inactive_onboarded( iv_area = is_check-area
                                                                           iv_date = is_context-today ).
    LOOP AT mo_dao->get_file_types( is_check-area ) ASSIGNING FIELD-SYMBOL(<ls_type>).
      " a file type of a business process not in effect is not monitored (process catalogue)
      IF <ls_type>-process_id IS NOT INITIAL AND line_exists( lt_off[ table_line = <ls_type>-process_id ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_open) = COND i( WHEN <ls_type>-open_days > 0 THEN <ls_type>-open_days ELSE ms_limits-open_days ).
      mt_stages = mo_dao->get_stages( iv_area = is_check-area iv_file_type = <ls_type>-file_type ).
      DATA(lt_files) = mo_dao->files_since( iv_area      = is_check-area
                                            iv_file_type = <ls_type>-file_type
                                            iv_from      = CONV d( is_context-today - lv_open )
                                            iv_max       = 100000 ).
      DATA(lt_ids) = VALUE zif_ca_ops_pf_types=>tt_file_id( FOR ls_f IN lt_files ( ls_f-file_id ) ).
      DATA(lt_ms) = mo_dao->get_milestones( iv_area = is_check-area it_file_ids = lt_ids ).
      DATA(lt_flagged) = VALUE zif_ca_ops_pf_types=>tt_file_id( ).
      LOOP AT lt_files ASSIGNING FIELD-SYMBOL(<ls_file>).
        rs_result-item_count += 1.
        IF <ls_file>-eval_state = zif_ca_ops_pf_types=>gc_eval-not_evaluated
           OR <ls_file>-eval_state = zif_ca_ops_pf_types=>gc_eval-stale.
          " its sources cannot say: no verdict, and its earlier exceptions stay open
          rs_result-partial = abap_true.
        ENDIF.
        IF issues( is_file = <ls_file> it_milestones = lt_ms it_files = lt_files ) IS NOT INITIAL.
          INSERT <ls_file>-file_id INTO TABLE lt_flagged.
        ENDIF.
      ENDLOOP.
      " the figures and the evidence only of the files with a finding (aggregated in the database)
      DATA(lt_totals) = mo_dao->get_totals( iv_area = is_check-area it_file_ids = lt_flagged ).
      DATA(lt_events) = mo_dao->get_events( iv_area = is_check-area it_file_ids = lt_flagged ).
      DATA(lt_payments) = mo_dao->get_payments( iv_area = is_check-area it_file_ids = lt_flagged ).
      DATA(lv_count) = 0.
      DATA(lv_more) = 0.
      LOOP AT lt_files ASSIGNING <ls_file>.
        IF NOT line_exists( lt_flagged[ table_line = <ls_file>-file_id ] ).
          CONTINUE.
        ENDIF.
        IF lv_count >= ms_limits-max_finds.
          lv_more += 1.
          CONTINUE.
        ENDIF.
        lv_count += 1.
        file_findings( EXPORTING is_type     = <ls_type>
                                 is_file     = <ls_file>
                                 it_issues   = issues( is_file = <ls_file> it_milestones = lt_ms it_files = lt_files )
                                 it_totals   = lt_totals
                                 it_events   = lt_events
                                 it_payments = lt_payments
                       CHANGING  cs_result   = rs_result ).
      ENDLOOP.
      IF lv_more > 0.
        " the unlisted files are unknown, not resolved
        rs_result-partial = abap_true.
        INSERT VALUE #( object_type = zif_ca_ops_pf_types=>gc_object_type-file
                        object_key  = <ls_type>-file_type
                        rule_id     = zif_ca_ops_pf_types=>gc_rule_id
                        check_code  = zif_ca_ops_pf_types=>gc_code-more
                        severity    = zif_ca_ops_types=>gc_severity-warning
                        message     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-more
                                                             iv_v1    = <ls_type>-file_type
                                                             iv_v2    = lv_more ) ) INTO TABLE rs_result-findings.
      ENDIF.
      day_findings( EXPORTING is_type   = <ls_type>
                    CHANGING  cs_result = rs_result ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_check_config~config_lines.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_pf_dao( ).
    INSERT zcl_ca_ops_cfg_version=>line( iv_kind = 'PF_PARAM' is_row = limits( is_check-area ) ) INTO TABLE rt_lines.
    LOOP AT lo_dao->get_file_types( is_check-area ) ASSIGNING FIELD-SYMBOL(<ls_type>).
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = 'PFTYP' is_row = <ls_type> ) INTO TABLE rt_lines.
      LOOP AT lo_dao->get_stages( iv_area = is_check-area iv_file_type = <ls_type>-file_type ) ASSIGNING FIELD-SYMBOL(<ls_stage>).
        INSERT zcl_ca_ops_cfg_version=>line( iv_kind = 'PFSTG' is_row = <ls_stage> ) INTO TABLE rt_lines.
      ENDLOOP.
      LOOP AT lo_dao->get_adapters( iv_area = is_check-area iv_file_type = <ls_type>-file_type ) ASSIGNING FIELD-SYMBOL(<ls_adp>).
        INSERT zcl_ca_ops_cfg_version=>line( iv_kind = 'PFADP' is_row = <ls_adp> ) INTO TABLE rt_lines.
      ENDLOOP.
    ENDLOOP.
    LOOP AT lo_dao->get_maps( is_check-area ) ASSIGNING FIELD-SYMBOL(<ls_map>).
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = 'PFMAP' is_row = <ls_map> ) INTO TABLE rt_lines.
    ENDLOOP.
  ENDMETHOD.


  METHOD limits.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    rs_limits-grace = zcl_ca_ops_util=>param_int( io_params = lo_params iv_name = zif_ca_ops_pf_types=>gc_param-grace_min
                                                  iv_default = zif_ca_ops_pf_types=>gc_default-grace_min ).
    rs_limits-red_min = zcl_ca_ops_util=>param_int( io_params = lo_params iv_name = zif_ca_ops_pf_types=>gc_param-red_min
                                                    iv_default = zif_ca_ops_pf_types=>gc_default-red_min ).
    rs_limits-max_finds = zcl_ca_ops_util=>param_int( io_params = lo_params iv_name = zif_ca_ops_pf_types=>gc_param-max_finds
                                                      iv_default = zif_ca_ops_pf_types=>gc_default-max_finds ).
    rs_limits-max_evid = zcl_ca_ops_util=>param_int( io_params = lo_params iv_name = zif_ca_ops_pf_types=>gc_param-max_evid
                                                     iv_default = zif_ca_ops_pf_types=>gc_default-max_evid ).
    rs_limits-open_days = zcl_ca_ops_util=>param_int( io_params = lo_params iv_name = zif_ca_ops_pf_types=>gc_param-open_days
                                                      iv_default = zif_ca_ops_pf_types=>gc_default-open_days ).
    " the area's own limits first (PF_AMOUNT_RED_<area>), else the product-wide list
    rs_limits-amounts = lo_params->get_param( iv_name = CONV #( |{ zif_ca_ops_pf_types=>gc_param_prefix-amount_red }{ iv_area }| ) ).
    IF rs_limits-amounts IS INITIAL.
      rs_limits-amounts = lo_params->get_param( iv_name = zif_ca_ops_pf_types=>gc_param-amount_red ).
    ENDIF.
  ENDMETHOD.


  METHOD issues.
    " where the file stopped: the first required milestone that is not reached
    IF is_file-state <> zif_ca_ops_pf_types=>gc_state-replaced.
      LOOP AT it_milestones ASSIGNING FIELD-SYMBOL(<ls_ms>) WHERE file_id = is_file-file_id AND required = abap_true.
        DATA(ls_issue) = VALUE ty_issue( milestone = <ls_ms>-milestone due_at = <ls_ms>-due_at
                                         overdue = is_file-overdue_min ).
        CASE <ls_ms>-status.
          WHEN zif_ca_ops_pf_types=>gc_ms_status-reached OR zif_ca_ops_pf_types=>gc_ms_status-late
            OR zif_ca_ops_pf_types=>gc_ms_status-implied.
            CONTINUE.
          WHEN zif_ca_ops_pf_types=>gc_ms_status-missing.
            ls_issue-code = SWITCH #( <ls_ms>-milestone
                              WHEN zif_ca_ops_pf_types=>gc_milestone-accepted  THEN zif_ca_ops_pf_types=>gc_code-ack_missing
                              WHEN zif_ca_ops_pf_types=>gc_milestone-receipt   THEN zif_ca_ops_pf_types=>gc_code-receipt_missing
                              WHEN zif_ca_ops_pf_types=>gc_milestone-pickup
                                OR zif_ca_ops_pf_types=>gc_milestone-delivered THEN zif_ca_ops_pf_types=>gc_code-not_transferred
                              WHEN zif_ca_ops_pf_types=>gc_milestone-generated THEN zif_ca_ops_pf_types=>gc_code-not_generated
                              ELSE zif_ca_ops_pf_types=>gc_code-not_settled ).
            ls_issue-msgno = SWITCH #( <ls_ms>-milestone
                               WHEN zif_ca_ops_pf_types=>gc_milestone-accepted  THEN zif_ca_ops_pf_types=>gc_msg-ack_missing
                               WHEN zif_ca_ops_pf_types=>gc_milestone-receipt   THEN zif_ca_ops_pf_types=>gc_msg-receipt_missing
                               WHEN zif_ca_ops_pf_types=>gc_milestone-pickup
                                 OR zif_ca_ops_pf_types=>gc_milestone-delivered THEN zif_ca_ops_pf_types=>gc_msg-not_transferred
                               ELSE zif_ca_ops_pf_types=>gc_msg-ms_missing ).
          WHEN zif_ca_ops_pf_types=>gc_ms_status-failed.
            IF <ls_ms>-milestone = zif_ca_ops_pf_types=>gc_milestone-generated.
              ls_issue-code  = zif_ca_ops_pf_types=>gc_code-job_failed.
              ls_issue-msgno = zif_ca_ops_pf_types=>gc_msg-job_failed.
            ELSE.
              ls_issue-code  = zif_ca_ops_pf_types=>gc_code-transfer_failed.
              ls_issue-msgno = zif_ca_ops_pf_types=>gc_msg-transfer_failed.
            ENDIF.
            ls_issue-severity = zif_ca_ops_types=>gc_severity-error.
          WHEN zif_ca_ops_pf_types=>gc_ms_status-rejected.
            ls_issue-code     = zif_ca_ops_pf_types=>gc_code-rejected.
            ls_issue-msgno    = zif_ca_ops_pf_types=>gc_msg-rejected.
            ls_issue-severity = zif_ca_ops_types=>gc_severity-error.
          WHEN zif_ca_ops_pf_types=>gc_ms_status-partial.
            ls_issue-code     = zif_ca_ops_pf_types=>gc_code-partial.
            ls_issue-msgno    = zif_ca_ops_pf_types=>gc_msg-partial.
            ls_issue-severity = zif_ca_ops_types=>gc_severity-error.
          WHEN OTHERS.
            " pending (deadline not passed) or unknown (its source failed / is stale): no verdict
            EXIT.
        ENDCASE.
        INSERT ls_issue INTO TABLE rt_issues.
        EXIT.
      ENDLOOP.
    ENDIF.

    IF is_file-ack_conflict = abap_true.
      INSERT VALUE #( code = zif_ca_ops_pf_types=>gc_code-conflict msgno = zif_ca_ops_pf_types=>gc_msg-conflict
                      milestone = zif_ca_ops_pf_types=>gc_milestone-accepted
                      severity = zif_ca_ops_types=>gc_severity-error ) INTO TABLE rt_issues.
    ENDIF.
    IF is_file-late_ms IS NOT INITIAL AND rt_issues IS INITIAL.
      INSERT VALUE #( code = zif_ca_ops_pf_types=>gc_code-late msgno = zif_ca_ops_pf_types=>gc_msg-late
                      milestone = is_file-late_ms overdue = is_file-late_min
                      severity = zif_ca_ops_types=>gc_severity-info ) INTO TABLE rt_issues.
    ENDIF.

    " reissue: the original reached the bank (possible duplicate payments), or the bank answered for it after
    IF is_file-predecessor IS NOT INITIAL.
      READ TABLE it_files WITH KEY file_id = is_file-predecessor ASSIGNING FIELD-SYMBOL(<ls_pred>).
      IF sy-subrc = 0.
        LOOP AT it_milestones ASSIGNING <ls_ms> WHERE file_id = <ls_pred>-file_id
                                                  AND ( status = zif_ca_ops_pf_types=>gc_ms_status-reached
                                                     OR status = zif_ca_ops_pf_types=>gc_ms_status-late
                                                     OR status = zif_ca_ops_pf_types=>gc_ms_status-implied )
                                                  AND ( milestone = zif_ca_ops_pf_types=>gc_milestone-delivered
                                                     OR milestone = zif_ca_ops_pf_types=>gc_milestone-receipt
                                                     OR milestone = zif_ca_ops_pf_types=>gc_milestone-accepted ).
          INSERT VALUE #( code = zif_ca_ops_pf_types=>gc_code-dup_exposure msgno = zif_ca_ops_pf_types=>gc_msg-dup_exposure
                          milestone = <ls_ms>-milestone severity = zif_ca_ops_types=>gc_severity-block
                          exposure = abap_true other = <ls_pred>-native_key ) INTO TABLE rt_issues.
          EXIT.
        ENDLOOP.
      ENDIF.
    ENDIF.
    IF is_file-state = zif_ca_ops_pf_types=>gc_state-replaced.
      LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_next>) WHERE predecessor = is_file-file_id.
        LOOP AT it_milestones ASSIGNING <ls_ms> WHERE file_id = is_file-file_id
                                                  AND observed_at > <ls_next>-created_at
                                                  AND ( milestone = zif_ca_ops_pf_types=>gc_milestone-receipt
                                                     OR milestone = zif_ca_ops_pf_types=>gc_milestone-accepted ).
          " a late answer for the original after its reissue is recognised, never hidden
          INSERT VALUE #( code = zif_ca_ops_pf_types=>gc_code-orig_ack msgno = zif_ca_ops_pf_types=>gc_msg-orig_ack
                          milestone = <ls_ms>-milestone severity = zif_ca_ops_types=>gc_severity-block
                          exposure = abap_true other = <ls_next>-native_key ) INTO TABLE rt_issues.
          EXIT.
        ENDLOOP.
        EXIT.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD file_findings.
    DATA lt_totals TYPE zif_ca_ops_pf_types=>tt_total.
    lt_totals = VALUE #( FOR ls_t IN it_totals WHERE ( file_id = is_file-file_id ) ( ls_t ) ).
    " payments the file holds beyond those kept: their currency and amount are not known
    DATA(lv_counted) = REDUCE i( INIT n = 0 FOR ls_c IN lt_totals NEXT n = n + ls_c-pay_count ).
    IF lt_totals IS INITIAL.
      INSERT VALUE #( file_id = is_file-file_id pay_count = is_file-pay_count unknown_count = is_file-pay_count )
             INTO TABLE lt_totals.
    ELSEIF is_file-pay_count > lv_counted.
      lt_totals[ 1 ]-unknown_count += is_file-pay_count - lv_counted.
      lt_totals[ 1 ]-pay_count     += is_file-pay_count - lv_counted.
    ENDIF.
    DATA(ls_owner) = zcl_ca_ops_factory=>get_owner( )->resolve( iv_area       = ms_check-area
                                                                iv_check_id   = ms_check-check_id
                                                                iv_check_code = VALUE #( it_issues[ 1 ]-code OPTIONAL )
                                                                iv_rule_id    = zif_ca_ops_pf_types=>gc_rule_id
                                                                iv_process_id = COND #( WHEN is_type-process_id IS NOT INITIAL
                                                                                        THEN is_type-process_id
                                                                                        ELSE ms_check-process_id ) ).
    DATA(lt_job) = VALUE string_table( ).
    IF is_file-gen_job IS NOT INITIAL.
      " the job monitor's object key of the same job (name / count): one search finds both findings
      INSERT |{ is_file-gen_job }{ zif_ca_ops_job_types=>gc_key_separator }{ is_file-gen_jobcount }| INTO TABLE lt_job.
    ENDIF.

    LOOP AT it_issues ASSIGNING FIELD-SYMBOL(<ls_issue>).
      LOOP AT lt_totals ASSIGNING FIELD-SYMBOL(<ls_total>).
        DATA(lv_key) = object_key( is_file = is_file iv_currency = <ls_total>-currency ).
        DATA(lv_evid) = zcl_ca_ops_exc_contract=>evidence_key( iv_area       = ms_check-area
                                                               iv_check_id   = ms_check-check_id
                                                               iv_object_key = |{ <ls_issue>-code }/{ lv_key }|
                                                               iv_bukrs      = is_file-bukrs ).
        " gross on the finding of the file itself, duplicate exposure apart (a correlation group counts it once)
        DATA(lv_gross) = COND zif_ca_ops_pf_types=>ty_amount( WHEN <ls_issue>-exposure = abap_false THEN <ls_total>-amount ).
        DATA(lv_items) = COND i( WHEN <ls_issue>-exposure = abap_false THEN <ls_total>-pay_count
                                 ELSE <ls_total>-dup_count ).
        DATA(lv_amount_text) = |{ <ls_total>-currency } { zcl_ca_ops_util=>format_amount( CONV #( <ls_total>-amount ) ) }|.
        DATA(lv_dup_text) = |{ <ls_total>-currency } { zcl_ca_ops_util=>format_amount( CONV #( <ls_total>-dup_amount ) ) }|.
        DATA(lv_due_text) = time_text( <ls_issue>-due_at ).
        DATA(ls_finding) = VALUE zif_ca_ops_types=>ty_finding(
          object_type   = zif_ca_ops_pf_types=>gc_object_type-file
          object_key    = lv_key
          rule_id       = zif_ca_ops_pf_types=>gc_rule_id
          check_code    = <ls_issue>-code
          action        = zif_ca_ops_types=>gc_action-exception
          amount        = lv_gross
          currency      = <ls_total>-currency
          reference     = COND #( WHEN <ls_issue>-code = zif_ca_ops_pf_types=>gc_code-job_failed AND lt_job IS NOT INITIAL
                                  THEN lt_job[ 1 ] ELSE is_file-native_key )
          company_code  = is_file-bukrs
          business_date = is_file-bus_date
          pay_method    = is_file-pay_method
          account       = COND #( WHEN is_file-house_bank IS NOT INITIAL THEN |{ is_file-house_bank } / { is_file-account_id }| )
          item_count    = lv_items
          event_at      = is_file-gen_at
          unknown_count = <ls_total>-unknown_count
          dup_amount    = COND #( WHEN <ls_issue>-exposure = abap_true THEN <ls_total>-dup_amount )
          deadline_at   = COND #( WHEN <ls_issue>-due_at IS NOT INITIAL THEN <ls_issue>-due_at ELSE is_file-deadline_at )
          calendar_id   = is_type-calendar_id
          stage         = COND #( WHEN is_file-stage IS NOT INITIAL THEN is_file-stage ELSE zif_ca_ops_pf_types=>gc_milestone-payrun )
          resp_user     = ls_owner-user
          resp_team     = ls_owner-team
          resp_source   = ls_owner-source
          evid_key      = lv_evid ).
        ls_finding-severity = COND #( WHEN <ls_issue>-severity = zif_ca_ops_types=>gc_severity-block
                                        OR <ls_issue>-severity = zif_ca_ops_types=>gc_severity-info
                                        THEN <ls_issue>-severity
                                      ELSE severity( is_issue    = <ls_issue>
                                                     is_file     = is_file
                                                     iv_grace    = COND #( LET lv_stage_grace = VALUE #(
                                                                         mt_stages[ milestone = <ls_issue>-milestone ]-grace_min
                                                                         OPTIONAL ) IN
                                                                     WHEN lv_stage_grace > 0 THEN lv_stage_grace
                                                                     ELSE ms_limits-grace )
                                                     iv_amount   = <ls_total>-amount
                                                     iv_currency = <ls_total>-currency ) ).
        ls_finding-message = SWITCH #( <ls_issue>-msgno
          WHEN zif_ca_ops_pf_types=>gc_msg-ack_missing OR zif_ca_ops_pf_types=>gc_msg-receipt_missing
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = lv_due_text
                                        iv_v3 = lv_items iv_v4 = lv_amount_text )
          WHEN zif_ca_ops_pf_types=>gc_msg-not_transferred
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = <ls_issue>-milestone
                                        iv_v3 = lv_due_text iv_v4 = lv_items )
          WHEN zif_ca_ops_pf_types=>gc_msg-ms_missing
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = <ls_issue>-milestone
                                        iv_v3 = lv_due_text iv_v4 = lv_items )
          WHEN zif_ca_ops_pf_types=>gc_msg-job_failed
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key
                                        iv_v2 = VALUE string( lt_job[ 1 ] OPTIONAL ) iv_v3 = lv_items iv_v4 = lv_amount_text )
          WHEN zif_ca_ops_pf_types=>gc_msg-transfer_failed
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = <ls_issue>-milestone
                                        iv_v3 = lv_items iv_v4 = lv_amount_text )
          WHEN zif_ca_ops_pf_types=>gc_msg-rejected
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = lv_items
                                        iv_v3 = lv_amount_text )
          WHEN zif_ca_ops_pf_types=>gc_msg-partial
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key
                                        iv_v2 = is_file-pay_rejected + is_file-pay_open iv_v3 = is_file-pay_count
                                        iv_v4 = lv_amount_text )
          WHEN zif_ca_ops_pf_types=>gc_msg-late
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = <ls_issue>-milestone
                                        iv_v3 = <ls_issue>-overdue )
          WHEN zif_ca_ops_pf_types=>gc_msg-conflict
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = lv_amount_text )
          WHEN zif_ca_ops_pf_types=>gc_msg-dup_exposure
            THEN zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = <ls_issue>-other iv_v2 = is_file-native_key
                                        iv_v3 = lv_dup_text )
          ELSE zcl_ca_ops_util=>text( iv_msgno = <ls_issue>-msgno iv_v1 = is_file-native_key iv_v2 = <ls_issue>-other ) ).
        ls_finding-context = |File: { is_file-native_key }\nFile type: { is_type-file_type }\n|
                          && |Stage reached: { ls_finding-stage }\nStopped before: { <ls_issue>-milestone }\n|
                          && |Deadline: { lv_due_text } (calendar { is_type-calendar_id })\n|
                          && |Payments: { lv_items } (amount unknown: { <ls_total>-unknown_count })\n|
                          && |Owner: { ls_owner-user } { ls_owner-team } ({ ls_owner-source })\n|
                          && |Evaluation: { is_file-eval_state } { is_file-eval_reason }|.
        ls_finding-details = |{ ls_finding-context }\nAmount: { lv_amount_text }\n|
                          && |Duplicate exposure: { lv_dup_text }\n|
                          && |Payment run: { is_file-run_date } / { is_file-run_id }\nJob: { VALUE string( lt_job[ 1 ] OPTIONAL ) }|.
        INSERT ls_finding INTO TABLE cs_result-findings.
        INSERT LINES OF evidence( iv_key = lv_evid is_file = is_file it_events = it_events it_payments = it_payments )
               INTO TABLE cs_result-evidence.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD evidence.
    DATA(lv_seq) = 0.
    " the file itself (the register) and the payment run that produced it
    lv_seq += 1.
    INSERT VALUE #( evid_key = iv_key seq = lv_seq kind = zif_ca_ops_exc_contract=>gc_kind-ops
                    ev_type = zif_ca_ops_exc_contract=>gc_type-file label = is_file-file_type
                    native_key = is_file-native_key observed_at = is_file-eval_at
                    quality = zif_ca_ops_exc_contract=>gc_quality-confirmed source_id = is_file-source_id )
           INTO TABLE rt_evidence.
    " every observation of the file at source grain (SAP job, transfer records, bank answers, statement lines)
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>) WHERE file_id = is_file-file_id.
      IF lv_seq >= ms_limits-max_evid.
        EXIT.
      ENDIF.
      lv_seq += 1.
      INSERT VALUE #( evid_key    = iv_key
                      seq         = lv_seq
                      kind        = COND #( WHEN <ls_event>-source_type IS NOT INITIAL THEN <ls_event>-source_type
                                            ELSE zif_ca_ops_exc_contract=>gc_kind-sap )
                      ev_type     = SWITCH #( <ls_event>-milestone
                                      WHEN zif_ca_ops_pf_types=>gc_milestone-payrun    THEN zif_ca_ops_exc_contract=>gc_type-run
                                      WHEN zif_ca_ops_pf_types=>gc_milestone-generated THEN zif_ca_ops_exc_contract=>gc_type-job
                                      WHEN zif_ca_ops_pf_types=>gc_milestone-pickup
                                        OR zif_ca_ops_pf_types=>gc_milestone-delivered THEN zif_ca_ops_exc_contract=>gc_type-message
                                      WHEN zif_ca_ops_pf_types=>gc_milestone-receipt
                                        OR zif_ca_ops_pf_types=>gc_milestone-accepted  THEN zif_ca_ops_exc_contract=>gc_type-ack
                                      WHEN zif_ca_ops_pf_types=>gc_milestone-settled   THEN zif_ca_ops_exc_contract=>gc_type-statement
                                      ELSE zif_ca_ops_exc_contract=>gc_type-event )
                      label       = |{ <ls_event>-milestone } { <ls_event>-outcome } { <ls_event>-native_status }|
                      native_key  = |{ <ls_event>-source_event_id } v{ <ls_event>-event_version }|
                      link_object = <ls_event>-link_object
                      link_value  = <ls_event>-link_value
                      occurred_at = <ls_event>-occurred_at
                      observed_at = <ls_event>-observed_at
                      quality     = <ls_event>-corr_quality
                      source_id   = <ls_event>-source_id ) INTO TABLE rt_evidence.
    ENDLOOP.
    " the payment documents (FI-CA payment run: run date, run ID and payment document)
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_pay>) WHERE file_id = is_file-file_id AND pay_doc IS NOT INITIAL.
      IF lv_seq >= ms_limits-max_evid.
        EXIT.
      ENDIF.
      lv_seq += 1.
      INSERT VALUE #( evid_key    = iv_key
                      seq         = lv_seq
                      kind        = zif_ca_ops_exc_contract=>gc_kind-sap
                      ev_type     = zif_ca_ops_exc_contract=>gc_type-pay_doc
                      label       = |{ <ls_pay>-currency } { zcl_ca_ops_util=>format_amount( CONV #( <ls_pay>-amount ) ) } |
                                 && |{ <ls_pay>-partner_masked }|
                      native_key  = <ls_pay>-pay_key
                      link_object = zcl_ca_ops_pf_src_dpayh=>gc_link_object
                      link_value  = zcl_ca_ops_exc_contract=>link_value(
                                      VALUE #( ( fieldname = 'LAUFD' value = is_file-run_date )
                                               ( fieldname = 'LAUFI' value = is_file-run_id )
                                               ( fieldname = 'DOC1R' value = <ls_pay>-pay_doc ) ) )
                      occurred_at = is_file-gen_at
                      observed_at = is_file-eval_at
                      quality     = zif_ca_ops_exc_contract=>gc_quality-confirmed
                      source_id   = is_file-source_id ) INTO TABLE rt_evidence.
    ENDLOOP.
  ENDMETHOD.


  METHOD day_findings.
    LOOP AT mo_dao->get_days( iv_area      = is_type-area
                              iv_file_type = is_type-file_type
                              iv_from      = CONV d( zcl_ca_ops_factory=>get_clock( )->today( ) - ms_limits-open_days ) )
         ASSIGNING FIELD-SYMBOL(<ls_day>).
      DATA(lv_key) = |{ is_type-file_type }{ zif_ca_ops_pf_types=>gc_key_separator }{ <ls_day>-bus_date }|.
      CASE <ls_day>-result.
        WHEN zif_ca_ops_pf_types=>gc_day-missing OR zif_ca_ops_pf_types=>gc_day-partial.
          DATA(ls_owner) = zcl_ca_ops_factory=>get_owner( )->resolve( iv_area       = ms_check-area
                                                                      iv_check_id   = ms_check-check_id
                                                                      iv_check_code = zif_ca_ops_pf_types=>gc_code-file_missing
                                                                      iv_process_id = is_type-process_id ).
          INSERT VALUE #( object_type   = zif_ca_ops_pf_types=>gc_object_type-day
                          object_key    = lv_key
                          rule_id       = zif_ca_ops_pf_types=>gc_rule_id
                          check_code    = zif_ca_ops_pf_types=>gc_code-file_missing
                          severity      = zif_ca_ops_types=>gc_severity-error
                          action        = zif_ca_ops_types=>gc_action-exception
                          business_date = <ls_day>-bus_date
                          unknown_count = nmax( val1 = 0 val2 = <ls_day>-expected - <ls_day>-observed )
                          calendar_id   = is_type-calendar_id
                          stage         = zif_ca_ops_pf_types=>gc_milestone-payrun
                          resp_user     = ls_owner-user
                          resp_team     = ls_owner-team
                          resp_source   = ls_owner-source
                          message       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-file_missing
                                                                 iv_v1    = is_type-file_type
                                                                 iv_v2    = <ls_day>-bus_date
                                                                 iv_v3    = <ls_day>-observed
                                                                 iv_v4    = <ls_day>-expected )
                          details       = <ls_day>-reason ) INTO TABLE cs_result-findings.
        WHEN zif_ca_ops_pf_types=>gc_day-stale.
          cs_result-partial = abap_true.
          INSERT VALUE #( object_type   = zif_ca_ops_pf_types=>gc_object_type-day
                          object_key    = lv_key
                          rule_id       = zif_ca_ops_pf_types=>gc_rule_id
                          check_code    = zif_ca_ops_pf_types=>gc_code-stale
                          severity      = zif_ca_ops_types=>gc_severity-warning
                          business_date = <ls_day>-bus_date
                          message       = <ls_day>-reason ) INTO TABLE cs_result-findings.
        WHEN zif_ca_ops_pf_types=>gc_day-not_eval.
          cs_result-partial = abap_true.
      ENDCASE.
    ENDLOOP.
    " a source that failed: not evaluated (never "no files" / "no answer")
    LOOP AT mo_dao->get_adapters( iv_area = is_type-area iv_file_type = is_type-file_type ) ASSIGNING FIELD-SYMBOL(<ls_adp>).
      DATA(ls_source) = mo_dao->get_source( iv_area = is_type-area iv_source_id = <ls_adp>-source_id ).
      IF ls_source-status = zif_ca_ops_pf_types=>gc_src_status-failed.
        cs_result-partial = abap_true.
        INSERT VALUE #( object_type = zif_ca_ops_pf_types=>gc_object_type-source
                        object_key  = |{ is_type-file_type }{ zif_ca_ops_pf_types=>gc_key_separator }{ <ls_adp>-source_id }|
                        rule_id     = zif_ca_ops_pf_types=>gc_rule_id
                        check_code  = zif_ca_ops_pf_types=>gc_code-not_evaluated
                        severity    = zif_ca_ops_types=>gc_severity-warning
                        message     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-not_evaluated
                                                             iv_v1    = <ls_adp>-source_id
                                                             iv_v2    = is_type-file_type
                                                             iv_v3    = ls_source-reason ) ) INTO TABLE cs_result-findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD severity.
    DATA(lv_limit) = amount_limit( iv_list = ms_limits-amounts iv_currency = iv_currency iv_bukrs = is_file-bukrs ).
    DATA(lv_big) = xsdbool( lv_limit > 0 AND abs( iv_amount ) >= lv_limit ).
    IF is_issue-severity IS NOT INITIAL.
      rv_severity = COND #( WHEN lv_big = abap_true THEN zif_ca_ops_types=>gc_severity-block ELSE is_issue-severity ).
      RETURN.
    ENDIF.
    DATA(lv_grace) = COND i( WHEN iv_grace > 0 THEN iv_grace ELSE zif_ca_ops_pf_types=>gc_default-grace_min ).
    rv_severity = COND #( WHEN lv_big = abap_true OR ( ms_limits-red_min > 0 AND is_issue-overdue >= ms_limits-red_min )
                            THEN zif_ca_ops_types=>gc_severity-block
                          WHEN is_issue-overdue < lv_grace THEN zif_ca_ops_types=>gc_severity-warning
                          ELSE zif_ca_ops_types=>gc_severity-error ).
  ENDMETHOD.


  METHOD amount_limit.
    DATA lv_general TYPE zif_ca_ops_pf_types=>ty_amount.
    LOOP AT zcl_ca_ops_util=>split_list( iv_list ) ASSIGNING FIELD-SYMBOL(<lv_entry>).
      DATA(lv_entry) = to_upper( <lv_entry> ).
      DATA(lv_scope) = ``.
      IF lv_entry CS ':'.
        SPLIT lv_entry AT ':' INTO lv_scope lv_entry.
      ENDIF.
      SPLIT condense( lv_entry ) AT space INTO DATA(lv_cur) DATA(lv_value).
      IF lv_cur <> to_upper( condense( CONV string( iv_currency ) ) ) OR lv_value IS INITIAL.
        CONTINUE.
      ENDIF.
      TRY.
          DATA(lv_amount) = CONV zif_ca_ops_pf_types=>ty_amount( condense( lv_value ) ).
        CATCH cx_sy_conversion_error.
          CONTINUE.
      ENDTRY.
      IF lv_scope IS INITIAL.
        lv_general = lv_amount.
      ELSEIF condense( lv_scope ) = condense( CONV string( iv_bukrs ) ).
        rv_limit = lv_amount.
        RETURN.
      ENDIF.
    ENDLOOP.
    rv_limit = lv_general.
  ENDMETHOD.


  METHOD object_key.
    DATA(lv_suffix) = COND string( WHEN iv_currency IS NOT INITIAL THEN |{ zif_ca_ops_pf_types=>gc_key_separator }{ iv_currency }| ).
    DATA(lv_head) = |{ is_file-file_type }{ zif_ca_ops_pf_types=>gc_key_separator }{ is_file-native_key }|.
    DATA(lv_room) = 70 - strlen( lv_suffix ).
    IF strlen( lv_head ) > lv_room.
      lv_head = lv_head(lv_room).
    ENDIF.
    rv_key = lv_head && lv_suffix.
  ENDMETHOD.


  METHOD time_text.
    IF iv_ts IS INITIAL.
      RETURN.
    ENDIF.
    DATA lv_date TYPE d.
    DATA lv_time TYPE t.
    CONVERT TIME STAMP iv_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc INTO DATE lv_date TIME lv_time.
    rv_text = |{ lv_date DATE = ISO } { lv_time TIME = ISO } UTC|.
  ENDMETHOD.

ENDCLASS.
