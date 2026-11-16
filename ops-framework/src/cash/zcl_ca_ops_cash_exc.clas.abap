*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_exc.clas.abap
*& Purpose:
*& Exception builder of the FI-CA cash operations checks: the typed
*& exception ZIF_CA_OPS_CASH_TYPES=>TY_EXCEPTION (count, amount per
*& currency, oldest item and age, next cutoff, owner, stage, evaluation,
*& evidence keys at source grain) and its ONE mapping into today's finding
*& fields (TO_FINDING): amount / currency / company code / business date as
*& stored columns, stage as rule, the rule's parameter as configuration
*& rule, the message with count and amount, and labelled detail and
*& context lines for the rest. Build K's shared exception contract replaces
*& only TO_FINDING (docs/FICA_CASH_OPERATIONS.md section 6); the checks
*& fill the typed exception and never a finding directly. Pure logic.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | Exception contract (build K merge, D-K1 accepted): TO_FINDING fills ITEM_COUNT (an absence: 0 and
*&            | UNKNOWN_COUNT 1 - the items are not known; items without any amount: all unknown), DEADLINE_AT
*&            | (the next cutoff in UTC) and CALENDAR_ID, STAGE, RESP_USER / RESP_TEAM / RESP_SOURCE (C control,
*&            | P business process, N none - the owner rule of the context); EVIDENCE_ROWS turns the evidence
*&            | keys into typed rows of ZIF_CA_OPS_EXC_CONTRACT with their link registry objects. The earlier
*&            | mapping is unchanged.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - exception builder</p>
"! Mapping (today): CHECK_CODE, SEVERITY, RULE_ID = stage, OBJECT_TYPE / OBJECT_KEY (source grain + company code +
"! currency), REFERENCE = source tables, BUKRS, AMOUNT / CURRENCY (one currency per finding), BUS_DATE = oldest item
"! (age = run date - BUS_DATE), CFG_RULE = rule parameter, MESSAGE = count / amount / key, DETAILS = stage and
"! evaluation, count and amount, oldest and age, next cutoff, owner, evidence keys, source; CONTEXT (alert e-mail) =
"! the same lines without amounts; ITEM_COUNT, ACCOUNT, PAY_METHOD for the alert e-mail.
CLASS zcl_ca_ops_cash_exc DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! The finding of a cash exception (the single mapping into ZIF_CA_OPS_TYPES=>TY_FINDING)
    CLASS-METHODS to_finding
      IMPORTING
        is_exc            TYPE zif_ca_ops_cash_types=>ty_exception
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! The typed evidence rows of an exception (exception contract): one row per evidence key, its link registry
    "! object where the key names one (LAUFD/LAUFI, OPBEL, KUKEY, FIKEY, JOBNAME/JOBCOUNT)
    CLASS-METHODS evidence_rows
      IMPORTING
        is_exc             TYPE zif_ca_ops_cash_types=>ty_exception
        iv_evid_key        TYPE zif_ca_ops_exc_contract=>ty_evid_key
      RETURNING
        VALUE(rt_evidence) TYPE zif_ca_ops_exc_contract=>tt_evidence.

    "! Days from the oldest item to the day (0 = no date or not older)
    CLASS-METHODS age_days
      IMPORTING
        iv_oldest      TYPE d
        iv_today       TYPE d
      RETURNING
        VALUE(rv_days) TYPE i.

    "! Object key at source grain: the object's key parts, company code and currency joined by /
    CLASS-METHODS object_key
      IMPORTING
        iv_id         TYPE clike
        iv_sub        TYPE clike OPTIONAL
        iv_company    TYPE bukrs OPTIONAL
        iv_currency   TYPE zif_ca_ops_types=>ty_currency OPTIONAL
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.

    "! Amount and currency as shown in messages (thousands separators, two decimals)
    CLASS-METHODS amount_text
      IMPORTING
        iv_amount      TYPE zif_ca_ops_cash_types=>ty_amount
        iv_currency    TYPE zif_ca_ops_types=>ty_currency
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    CONSTANTS gc_separator TYPE c LENGTH 1 VALUE '/'.
    "! Link registry objects of the evidence keys (config/links: S4CORE and the FICA package)
    CONSTANTS:
      BEGIN OF gc_link,
        payment_run TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'FICA_PAYMENT_RUN',
        document    TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'FICA_DOC_HEADER',
        statement   TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'S4_BANK_STMT_HDR',
        recon_key   TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'FICA_SUMMARY_RECORD',
        job         TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'S4_BACKGROUND_JOB',
      END OF gc_link.

    "! Labelled lines of the exception; with iv_amounts the count / amount line too (DETAILS), else not (CONTEXT)
    CLASS-METHODS labelled_lines
      IMPORTING
        is_exc         TYPE zif_ca_ops_cash_types=>ty_exception
        iv_amounts     TYPE abap_bool
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS cutoff_line
      IMPORTING
        is_cutoff      TYPE zif_ca_ops_cash_types=>ty_cutoff
      RETURNING
        VALUE(rv_line) TYPE string.

    CLASS-METHODS owner_line
      IMPORTING
        is_exc         TYPE zif_ca_ops_cash_types=>ty_exception
      RETURNING
        VALUE(rv_line) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_cash_exc IMPLEMENTATION.

  METHOD to_finding.
    rs_finding = VALUE #(
      object_type   = is_exc-object_type
      object_key    = is_exc-object_key
      rule_id       = is_exc-stage
      check_code    = is_exc-check_code
      severity      = is_exc-severity
      action        = COND #( WHEN is_exc-severity = zif_ca_ops_types=>gc_severity-info
                                 OR is_exc-evaluation = zif_ca_ops_cash_types=>gc_evaluation-not_evaluated
                              THEN zif_ca_ops_types=>gc_action-notify
                              ELSE zif_ca_ops_types=>gc_action-exception )
      amount        = is_exc-amount
      currency      = is_exc-currency
      reference     = is_exc-source
      message       = zcl_ca_ops_util=>text( iv_msgno = is_exc-msgno
                                             iv_v1    = is_exc-msgv1
                                             iv_v2    = is_exc-msgv2
                                             iv_v3    = is_exc-msgv3
                                             iv_v4    = is_exc-msgv4 )
      details       = labelled_lines( is_exc = is_exc iv_amounts = abap_true )
      context       = labelled_lines( is_exc = is_exc iv_amounts = abap_false )
      business_date = is_exc-oldest
      company_code  = is_exc-company_code
      account       = is_exc-account
      pay_method    = is_exc-pay_method
      item_count    = is_exc-item_count
      cfg_rule      = is_exc-rule_param ).
    " exception contract (docs/EXCEPTION_CONTRACT.md section 3): an absence has no known items; items counted
    " without any amount (e.g. the accounts of a stale statement import) have unknown amounts
    rs_finding-unknown_count = COND #( WHEN is_exc-item_count <= 0
                                         THEN 1
                                       WHEN is_exc-amount = 0 AND is_exc-currency IS INITIAL
                                         THEN is_exc-item_count ).
    rs_finding-stage       = is_exc-stage.
    rs_finding-calendar_id = is_exc-cutoff-calendar_id.
    IF is_exc-cutoff-known = abap_true.
      DATA lv_deadline TYPE timestamp.
      CONVERT DATE is_exc-cutoff-date TIME is_exc-cutoff-time INTO TIME STAMP lv_deadline
              TIME ZONE is_exc-cutoff-time_zone.
      rs_finding-deadline_at = lv_deadline.
    ENDIF.
    rs_finding-resp_user   = is_exc-owner-owner.
    rs_finding-resp_team   = is_exc-owner-team.
    rs_finding-resp_source = COND #( WHEN is_exc-owner-control_id IS NOT INITIAL
                                       THEN zif_ca_ops_exc_contract=>gc_resp_source-control
                                     WHEN is_exc-owner-owner IS NOT INITIAL
                                       THEN zif_ca_ops_exc_contract=>gc_resp_source-process
                                     ELSE zif_ca_ops_exc_contract=>gc_resp_source-none ).
  ENDMETHOD.


  METHOD evidence_rows.
    DATA lv_seq TYPE i.
    LOOP AT is_exc-evidence ASSIGNING FIELD-SYMBOL(<ls_key>).
      lv_seq += 1.
      SPLIT <ls_key>-name AT gc_separator INTO TABLE DATA(lt_names).
      SPLIT <ls_key>-value AT gc_separator INTO TABLE DATA(lt_values).
      DATA(lt_pairs) = VALUE zif_ca_ops_link_types=>tt_pair( ).
      LOOP AT lt_names ASSIGNING FIELD-SYMBOL(<lv_name>).
        INSERT VALUE #( fieldname = <lv_name> value = VALUE #( lt_values[ sy-tabix ] OPTIONAL ) ) INTO TABLE lt_pairs.
      ENDLOOP.
      INSERT VALUE #( evid_key    = iv_evid_key
                      seq         = lv_seq
                      kind        = zif_ca_ops_exc_contract=>gc_kind-sap
                      ev_type     = SWITCH #( <ls_key>-name
                                      WHEN zif_ca_ops_cash_types=>gc_key-run       THEN zif_ca_ops_exc_contract=>gc_type-run
                                      WHEN zif_ca_ops_cash_types=>gc_key-job       THEN zif_ca_ops_exc_contract=>gc_type-job
                                      WHEN zif_ca_ops_cash_types=>gc_key-document
                                        OR zif_ca_ops_cash_types=>gc_key-payment
                                        OR zif_ca_ops_cash_types=>gc_key-clearing  THEN zif_ca_ops_exc_contract=>gc_type-pay_doc
                                      WHEN zif_ca_ops_cash_types=>gc_key-statement THEN zif_ca_ops_exc_contract=>gc_type-statement
                                      ELSE zif_ca_ops_exc_contract=>gc_type-event )
                      label       = |{ is_exc-check_code } { is_exc-stage }|
                      native_key  = |{ <ls_key>-name }={ <ls_key>-value }|
                      link_object = SWITCH #( <ls_key>-name
                                      WHEN zif_ca_ops_cash_types=>gc_key-run       THEN gc_link-payment_run
                                      WHEN zif_ca_ops_cash_types=>gc_key-document  THEN gc_link-document
                                      WHEN zif_ca_ops_cash_types=>gc_key-statement THEN gc_link-statement
                                      WHEN zif_ca_ops_cash_types=>gc_key-recon_key THEN gc_link-recon_key
                                      WHEN zif_ca_ops_cash_types=>gc_key-job       THEN gc_link-job )
                      link_value  = zcl_ca_ops_exc_contract=>link_value( lt_pairs )
                      quality     = zif_ca_ops_exc_contract=>gc_quality-confirmed
                      source_id   = is_exc-source(10) ) INTO TABLE rt_evidence.
    ENDLOOP.
  ENDMETHOD.


  METHOD age_days.
    IF iv_oldest IS NOT INITIAL AND iv_today > iv_oldest.
      rv_days = iv_today - iv_oldest.
    ENDIF.
  ENDMETHOD.


  METHOD object_key.
    DATA(lv_key) = condense( CONV string( iv_id ) ).
    IF iv_sub IS NOT INITIAL.
      lv_key = |{ lv_key }{ gc_separator }{ condense( CONV string( iv_sub ) ) }|.
    ENDIF.
    IF iv_company IS NOT INITIAL OR iv_currency IS NOT INITIAL.
      lv_key = |{ lv_key }{ gc_separator }{ iv_company }{ gc_separator }{ iv_currency }|.
    ENDIF.
    rv_key = lv_key.
  ENDMETHOD.


  METHOD amount_text.
    rv_text = condense( |{ zcl_ca_ops_util=>format_amount( CONV decfloat34( iv_amount ) ) } { iv_currency }| ).
  ENDMETHOD.


  METHOD labelled_lines.
    DATA lt_lines TYPE string_table.

    INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_stage
                                  iv_v1    = is_exc-stage
                                  iv_v2    = is_exc-evaluation ) INTO TABLE lt_lines.
    IF iv_amounts = abap_true.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_amount
                                    iv_v1    = is_exc-item_count
                                    iv_v2    = zcl_ca_ops_util=>format_amount( CONV decfloat34( is_exc-amount ) )
                                    iv_v3    = is_exc-currency ) INTO TABLE lt_lines.
    ENDIF.
    IF is_exc-oldest IS NOT INITIAL.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_oldest
                                    iv_v1    = |{ is_exc-oldest DATE = ISO }|
                                    iv_v2    = is_exc-age_days ) INTO TABLE lt_lines.
    ENDIF.
    INSERT cutoff_line( is_exc-cutoff ) INTO TABLE lt_lines.
    INSERT owner_line( is_exc ) INTO TABLE lt_lines.
    LOOP AT is_exc-evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>).
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_evidence
                                    iv_v1    = <ls_evidence>-name
                                    iv_v2    = <ls_evidence>-value ) INTO TABLE lt_lines.
    ENDLOOP.
    INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_source
                                  iv_v1    = is_exc-source
                                  iv_v2    = is_exc-rule_param ) INTO TABLE lt_lines.
    IF iv_amounts = abap_true AND is_exc-note IS NOT INITIAL.
      INSERT is_exc-note INTO TABLE lt_lines.
    ENDIF.
    rv_text = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD cutoff_line.
    IF is_cutoff-known = abap_true.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_cutoff
                                       iv_v1    = |{ is_cutoff-date DATE = ISO }|
                                       iv_v2    = |{ is_cutoff-time TIME = ISO }|
                                       iv_v3    = is_cutoff-time_zone ).
    ELSE.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_cutoff_open
                                       iv_v1    = zif_ca_ops_cash_types=>gc_param-calendar
                                       iv_v2    = zif_ca_ops_cash_types=>gc_source-control ).
    ENDIF.
  ENDMETHOD.


  METHOD owner_line.
    IF is_exc-owner-owner IS INITIAL AND is_exc-owner-team IS INITIAL.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_no_owner
                                       iv_v1    = is_exc-check_code ).
    ELSE.
      rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_owner
                                       iv_v1    = is_exc-owner-owner
                                       iv_v2    = is_exc-owner-backup
                                       iv_v3    = is_exc-owner-team
                                       iv_v4    = is_exc-owner-control_id ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
