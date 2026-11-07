*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_btc_seq.clas.abap
*& Purpose:
*& Evidence kind "bank code lifecycle": every bank statement line of the
*& payment reference (FEBEP-CHECT = AUGBL) gets its role from its scheme
*& and code (ZCD_HCK_BTCROLE per flow + method class; scheme from the
*& statement format, one derivation with EBS: ZCL_CD_EBS_SRC_FEB=>
*& LINE_CODE); the roles ordered by statement date / statement / line are
*& matched (PCRE, whole value) against ZCD_HCK_SEQOUT in SEQ order; the
*& first match gives the outcome. Found = outcome in PARAM1 (comma list,
*& required). Anomalies (own findings, payment never aged): no pattern
*& matches (UNEXPECTED_SEQUENCE); returns lot items (DFKKRP) other than
*& EXPECTED_DFKKRP, a lot without a return line, or the amount of the last
*& compared line differing from the lot (RETURN_INCONSISTENT); a pending
*& outcome older than MAX_AGE_DAYS after its last line
*& (PENDING_OUTCOME_MISSING). A line whose code has no role is ignored only
*& when it carries no amount or its code is an approved informational
*& exclusion of its scheme (ZCA_PARAM HCK_BTC_INFO_<scheme>); any other
*& unmapped line is a relevant event: lifecycle INDETERMINATE (never
*& found) and BTC_ROLE_MISSING (E) naming code, date, amount, flow / class.
*& Cheques (PARAM2 = ZTNUM): the lines are linked by FEBEP-CHECT = the
*& last PARAM3 (13) characters of DFKKCR-ZTNUM on a statement of the
*& cheque's paying house bank account (shared ZCL_CD_HCK_EV_SUPPORT=>
*& LINES_BY_CHEQUE; a line of several cheques of one account is attributed
*& to none, CHEQUE_LINK_AMBIGUOUS, lifecycle not evaluated), an outcome row may require
*& a register state (DFKKCR-STATE, cheque by DFKKCR-DOC1R = AUGBL) and may
*& raise its own finding (e.g. CHEQUE_CLARIFICATION, MANUAL_CLEARING_
*& REQUIRED), and a line of a role compared with R must carry the payment
*& amount (DPAYH-RWBTR of the AUGBL; CHEQUE_AMOUNT_MISMATCH). One read each of lines, lots, cheques and
*& configuration per run. Read-only: nothing is cleared (FPCHR is manual).
*& Modification log:
*& 2026-11-07 | Initial version (user correction of rule 4: lifecycle of BAI / ISO codes per payment).
*& 2026-11-07 | Cheque lifecycle 581 / 255 / corrections: cheque-number link, register state, outcome
*&            | finding, register amount (user facts on disbursement cheques).
*& 2026-11-07 | Design review: unmapped monetary codes no longer disappear - INDETERMINATE +
*&            | BTC_ROLE_MISSING; approved informational exclusions per scheme (HCK_BTC_INFO_<scheme>).
*& 2026-11-07 | Design review: cheque lines by suffix AND house bank account (shared reader, every
*&            | eligible cheque kept); ambiguous line = CHEQUE_LINK_AMBIGUOUS; cheque_links removed.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - outcome of the bank code sequence of a payment</p>
CLASS zcl_cd_hck_ev_btc_seq DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

  PRIVATE SECTION.
    "! One statement line of the payment with its role
    TYPES:
      BEGIN OF ty_step,
        budat   TYPE d,
        kukey   TYPE n LENGTH 8,
        esnum   TYPE n LENGTH 5,
        role    TYPE zif_cd_hck_runtime_types=>ty_btc_role,
        code    TYPE zif_cd_hck_runtime_types=>ty_btc_code,
        amount  TYPE zif_cd_ops_types=>ty_amount,
        compare TYPE c LENGTH 1,
      END OF ty_step.
    TYPES tt_step TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.

    "! Returns lot items (DFKKRP) of a payment document
    TYPES:
      BEGIN OF ty_lot,
        doc1r  TYPE zif_cd_hck_runtime_types=>ty_docno,
        items  TYPE i,
        amount TYPE zif_cd_ops_types=>ty_amount,
      END OF ty_lot.
    TYPES tt_lot TYPE HASHED TABLE OF ty_lot WITH UNIQUE KEY doc1r.

    "! Cheque register of a payment document (cheque link only; DFKKCR-DOC1R = AUGBL) with the
    "! payment amount (DPAYH) the cashed line is compared with
    TYPES:
      BEGIN OF ty_register,
        doc1r  TYPE zif_cd_hck_runtime_types=>ty_docno,
        state  TYPE string,
        amount TYPE zif_cd_ops_types=>ty_amount,
        ztnum  TYPE string,
      END OF ty_register.
    TYPES tt_register TYPE HASHED TABLE OF ty_register WITH UNIQUE KEY doc1r.

    "! Approved informational codes of a scheme (HCK_BTC_INFO_<scheme>), read once per collect
    TYPES:
      BEGIN OF ty_info,
        scheme TYPE zif_cd_hck_runtime_types=>ty_scheme,
        codes  TYPE string_table,
      END OF ty_info.
    TYPES tt_info TYPE HASHED TABLE OF ty_info WITH UNIQUE KEY scheme.

    DATA mt_outcomes TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.
    DATA mt_targets TYPE string_table.
    DATA mt_info TYPE tt_info.
    DATA mv_today TYPE d.

    "! The code is an approved informational exclusion of its scheme (never concerns the payment)
    METHODS is_informational
      IMPORTING
        iv_scheme     TYPE zif_cd_hck_runtime_types=>ty_scheme
        iv_code       TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    METHODS evaluate
      IMPORTING
        is_payment         TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        it_steps           TYPE tt_step
        is_lot             TYPE ty_lot
        is_register        TYPE ty_register
      RETURNING
        VALUE(rs_evidence) TYPE zif_cd_hck_runtime_types=>ty_evidence.

    "! The first active outcome of the flow + class whose pattern matches the whole sequence and
    "! whose register state list (if any) contains the register state
    METHODS match
      IMPORTING
        is_payment        TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        iv_sequence       TYPE string
        is_register       TYPE ty_register
      RETURNING
        VALUE(rs_outcome) TYPE zif_cd_hck_runtime_types=>ty_seq_outcome.

    "! The last line of a role compared with the register differs from the cheque amount
    CLASS-METHODS register_mismatch
      IMPORTING
        it_steps       TYPE tt_step
        is_register    TYPE ty_register
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Lot items expected differ, lot without line or amount differs: the detail, else blank
    CLASS-METHODS lot_mismatch
      IMPORTING
        is_outcome     TYPE zif_cd_hck_runtime_types=>ty_seq_outcome
        it_steps       TYPE tt_step
        is_lot         TYPE ty_lot
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_hck_ev_btc_seq IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA lt_lots TYPE tt_lot.
    DATA lt_steps TYPE tt_step.
    DATA lt_register TYPE tt_register.
    DATA ls_lines TYPE zcl_cd_hck_ev_support=>ty_doc_lines.
    DATA ls_cheque TYPE zcl_cd_hck_ev_support=>ty_cheque_lines.
    DATA lt_unmapped TYPE string_table.
    CLEAR mt_info.
    mt_targets = zcl_cd_hck_ev_support=>tokens(
                   zcl_cd_hck_ev_support=>required_param( iv_value = is_rule-param1
                                                          iv_name  = zif_cd_hck_runtime_types=>gc_rule_param-param1
                                                          is_rule  = is_rule ) ).
    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_runtime_dao( ).
    DATA(lt_roles) = lo_dao->get_btc_roles( ).
    mt_outcomes = lo_dao->get_seq_outcomes( ).
    " An invalid pattern is never 'no match': the kind is unusable (CLEARING_RULE_INVALID)
    LOOP AT mt_outcomes ASSIGNING FIELD-SYMBOL(<ls_outcome>).
      IF zcl_cd_ops_util=>pcre_valid( <ls_outcome>-seq_pattern ) = abap_false.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e666(zcd_ops) WITH <ls_outcome>-seq_pattern
                                     |{ <ls_outcome>-flow }{ <ls_outcome>-method_class }/{ <ls_outcome>-seq }|.
      ENDIF.
    ENDLOOP.
    mv_today = zcl_cd_ops_factory=>get_clock( )->today( ).

    " Statement link: payment document (default) or the cheque number suffix on the cheque's house
    " bank account (PARAM2 = ZTNUM)
    IF to_upper( condense( CONV string( is_rule-param2 ) ) ) = zif_cd_hck_runtime_types=>gc_link_cheque.
      ls_cheque = zcl_cd_hck_ev_support=>lines_by_cheque(
                    it_payments = it_payments
                    iv_length   = nmax( val1 = 1
                                        val2 = zcl_cd_hck_param=>int(
                                                 iv_value   = is_rule-param3
                                                 iv_default = zif_cd_hck_runtime_types=>gc_check_default-ztnum_suffix ) )
                    iv_max_rows = iv_max_rows ).
      ls_lines-lines  = ls_cheque-lines.
      ls_lines-capped = ls_cheque-capped.
      " Register state as maintained (blank = open); the first cheque of a document is its register
      LOOP AT ls_cheque-checks ASSIGNING FIELD-SYMBOL(<ls_check>).
        INSERT VALUE #( doc1r = <ls_check>-doc1r
                        state = COND #( WHEN <ls_check>-state IS INITIAL THEN zif_cd_hck_runtime_types=>gc_state_blank
                                        ELSE to_upper( CONV string( <ls_check>-state ) ) )
                        ztnum = condense( CONV string( <ls_check>-ztnum ) ) ) INTO TABLE lt_register.
      ENDLOOP.
    ELSE.
      ls_lines = zcl_cd_hck_ev_support=>lines_by_doc( it_payments = it_payments
                                                      iv_max_rows = iv_max_rows ).
    ENDIF.
    rs_result-capped = ls_lines-capped.
    rs_result-source = zif_cd_ops_trace_types=>gc_table-febep.
    LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_returns( zcl_cd_hck_ev_support=>docnos( it_payments ) )
         ASSIGNING FIELD-SYMBOL(<ls_return>).
      READ TABLE lt_lots ASSIGNING FIELD-SYMBOL(<ls_lot>) WITH TABLE KEY doc1r = <ls_return>-selw1.
      IF sy-subrc <> 0.
        INSERT VALUE #( doc1r = <ls_return>-selw1 ) INTO TABLE lt_lots ASSIGNING <ls_lot>.
      ENDIF.
      <ls_lot>-items  = <ls_lot>-items + 1.
      <ls_lot>-amount = <ls_lot>-amount + abs( <ls_return>-amount ).
    ENDLOOP.

    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      CLEAR: lt_steps, lt_unmapped.
      " A statement line of several cheques of one account: the lifecycle cannot be told
      READ TABLE ls_cheque-ambiguous ASSIGNING FIELD-SYMBOL(<ls_ambiguous>) WITH TABLE KEY doc1r = <ls_payment>-doc1r.
      IF sy-subrc = 0.
        INSERT VALUE #( doc1r    = <ls_payment>-doc1r
                        anomaly  = zif_cd_hck_runtime_types=>gc_code-cheque_ambiguous
                        severity = zif_cd_ops_types=>gc_severity-error
                        detail   = <ls_ambiguous>-detail ) INTO TABLE rs_result-evidence.
        CONTINUE.
      ENDIF.
      LOOP AT ls_lines-lines USING KEY by_doc ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE doc1r = <ls_payment>-doc1r.
        DATA(ls_code) = zcl_cd_ebs_src_feb=>line_code( iv_vorgc = <ls_line>-line-vorgc
                                                       iv_vgext = <ls_line>-line-vgext ).
        READ TABLE lt_roles ASSIGNING FIELD-SYMBOL(<ls_role>)
             WITH TABLE KEY flow         = <ls_payment>-flow
                            method_class = <ls_payment>-class
                            scheme       = ls_code-scheme
                            btc_code     = ls_code-btc_code.
        IF sy-subrc <> 0.
          " No role: a line without amount or an approved informational code is not part of the
          " lifecycle; any other line on the reference is an event the role table does not know
          IF <ls_line>-line-kwbtr <> 0
             AND is_informational( iv_scheme = ls_code-scheme iv_code = ls_code-btc_code ) = abap_false.
            INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_role_missing
                                          iv_v1    = |{ ls_code-scheme } { ls_code-btc_code }|
                                          iv_v2    = |{ <ls_line>-line-budat DATE = ISO }|
                                          iv_v3    = |{ <ls_line>-line-kwbtr STYLE = SIMPLE }|
                                          iv_v4    = |{ <ls_payment>-flow }{ <ls_payment>-class }| )
              INTO TABLE lt_unmapped.
          ENDIF.
          CONTINUE.
        ENDIF.
        INSERT VALUE #( budat   = <ls_line>-line-budat
                        kukey   = <ls_line>-line-kukey
                        esnum   = <ls_line>-line-esnum
                        role    = <ls_role>-role
                        code    = ls_code-btc_code
                        amount  = abs( <ls_line>-line-kwbtr )
                        compare = <ls_role>-compare_amount ) INTO TABLE lt_steps.
      ENDLOOP.
      " An unmapped monetary line: the lifecycle is INDETERMINATE (never CLEARED / RETURNED) and the
      " role table needs the row
      IF lt_unmapped IS NOT INITIAL.
        INSERT VALUE #( doc1r    = <ls_payment>-doc1r
                        hits     = lines( lt_steps )
                        anomaly  = zif_cd_hck_runtime_types=>gc_code-btc_role_missing
                        severity = zif_cd_ops_types=>gc_severity-error
                        detail   = |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_indeterminate
                                                             iv_v1    = zif_cd_hck_runtime_types=>gc_outcome-indeterminate ) } | &&
                                   concat_lines_of( table = lt_unmapped sep = zif_cd_hck_runtime_types=>gc_role_sep ) )
          INTO TABLE rs_result-evidence.
        CONTINUE.
      ENDIF.
      " The lifecycle in statement order: statement date, statement, line
      SORT lt_steps BY budat kukey esnum.
      " Cheque link: DFKKCR-DOC1R = AUGBL; the amount compared is the payment amount (DPAYH-RWBTR of
      " the same AUGBL), so no unconfirmed register amount field is needed
      DATA(ls_register) = VALUE ty_register( lt_register[ doc1r = <ls_payment>-doc1r ] OPTIONAL ).
      ls_register-amount = abs( <ls_payment>-amount ).
      DATA(ls_evidence) = evaluate( is_payment  = <ls_payment>
                                    it_steps    = lt_steps
                                    is_lot      = VALUE #( lt_lots[ doc1r = <ls_payment>-doc1r ] OPTIONAL )
                                    is_register = ls_register ).
      IF ls_evidence IS NOT INITIAL.
        INSERT ls_evidence INTO TABLE rs_result-evidence.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD evaluate.
    DATA lt_roles TYPE string_table.
    DATA lt_codes TYPE string_table.
    IF it_steps IS INITIAL.
      " No line with a role: no evidence - unless a returns lot exists without its return line
      IF is_lot-items > 0.
        rs_evidence = VALUE #( doc1r    = is_payment-doc1r
                               anomaly  = zif_cd_hck_runtime_types=>gc_code-return_inconsist
                               severity = zif_cd_ops_types=>gc_severity-error
                               detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_lot_no_line
                                                                 iv_v1    = is_lot-items ) ).
      ENDIF.
      RETURN.
    ENDIF.
    LOOP AT it_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
      INSERT CONV string( <ls_step>-role ) INTO TABLE lt_roles.
      INSERT |{ <ls_step>-code } { <ls_step>-budat DATE = ISO }| INTO TABLE lt_codes.
    ENDLOOP.
    DATA(lv_sequence) = concat_lines_of( table = lt_roles sep = zif_cd_hck_runtime_types=>gc_role_sep ).
    rs_evidence-doc1r  = is_payment-doc1r.
    rs_evidence-hits   = lines( it_steps ).
    rs_evidence-detail = zcl_cd_ops_util=>text(
                           iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_sequence
                           iv_tail  = |{ lv_sequence } ({ concat_lines_of( table = lt_codes
                                                                           sep   = zif_cd_hck_runtime_types=>gc_role_sep ) })| ).

    IF is_register-ztnum IS NOT INITIAL.
      rs_evidence-detail = |{ rs_evidence-detail } | &&
                           |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_cheque
                                                     iv_v1    = is_register-ztnum
                                                     iv_v2    = is_register-state ) }|.
    ENDIF.
    DATA(ls_outcome) = match( is_payment = is_payment iv_sequence = lv_sequence is_register = is_register ).
    IF ls_outcome IS INITIAL.
      rs_evidence-anomaly  = zif_cd_hck_runtime_types=>gc_code-unexpected_seq.
      rs_evidence-severity = zif_cd_ops_types=>gc_severity-error.
      rs_evidence-detail   = |{ rs_evidence-detail } { zcl_cd_ops_util=>text( zif_cd_hck_runtime_types=>gc_msg-ev_no_pattern ) }|.
      RETURN.
    ENDIF.
    rs_evidence-detail = |{ rs_evidence-detail } | &&
                         |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_outcome
                                                   iv_v1    = ls_outcome-outcome
                                                   iv_v2    = ls_outcome-seq ) }|.
    rs_evidence-found    = xsdbool( line_exists( mt_targets[ table_line = to_upper( condense( CONV string( ls_outcome-outcome ) ) ) ] ) ).
    rs_evidence-severity = COND #( WHEN ls_outcome-severity IS INITIAL THEN zif_cd_ops_types=>gc_severity-error
                                   ELSE ls_outcome-severity ).

    " An outcome that is itself a finding (clarification, manual clearing): its description says why
    IF ls_outcome-finding IS NOT INITIAL.
      rs_evidence-anomaly = ls_outcome-finding.
      rs_evidence-detail  = |{ rs_evidence-detail } { ls_outcome-description }|.
      RETURN.
    ENDIF.
    DATA(lv_mismatch) = lot_mismatch( is_outcome = ls_outcome it_steps = it_steps is_lot = is_lot ).
    IF lv_mismatch IS NOT INITIAL.
      rs_evidence-anomaly = zif_cd_hck_runtime_types=>gc_code-return_inconsist.
      rs_evidence-detail  = |{ rs_evidence-detail } { lv_mismatch }|.
      RETURN.
    ENDIF.
    lv_mismatch = register_mismatch( it_steps = it_steps is_register = is_register ).
    IF lv_mismatch IS NOT INITIAL.
      rs_evidence-found    = abap_false.
      rs_evidence-anomaly  = zif_cd_hck_runtime_types=>gc_code-cheque_amount.
      rs_evidence-severity = zif_cd_ops_types=>gc_severity-error.
      rs_evidence-detail   = |{ rs_evidence-detail } { lv_mismatch }|.
      RETURN.
    ENDIF.

    " A pending outcome (e.g. redeposit) may stay MAX_AGE_DAYS after its last line
    DATA(lv_age) = mv_today - it_steps[ lines( it_steps ) ]-budat.
    IF ls_outcome-max_age_days > 0 AND lv_age > ls_outcome-max_age_days.
      rs_evidence-found   = abap_false.
      rs_evidence-anomaly = zif_cd_hck_runtime_types=>gc_code-pending_overdue.
      rs_evidence-detail  = |{ rs_evidence-detail } | &&
                            |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_pending_age
                                                      iv_v1    = lv_age
                                                      iv_v2    = ls_outcome-max_age_days ) }|.
    ENDIF.
  ENDMETHOD.


  METHOD is_informational.
    READ TABLE mt_info ASSIGNING FIELD-SYMBOL(<ls_info>) WITH TABLE KEY scheme = iv_scheme.
    IF sy-subrc <> 0.
      INSERT VALUE #( scheme = iv_scheme
                      codes  = zcl_cd_hck_ev_support=>tokens( zcl_cd_ops_factory=>get_params( )->get_param(
                                 iv_name = CONV #( |{ zif_cd_hck_runtime_types=>gc_param_prefix-btc_info }{ iv_scheme }| ) ) ) )
        INTO TABLE mt_info ASSIGNING <ls_info>.
    ENDIF.
    rv_yes = xsdbool( line_exists( <ls_info>-codes[ table_line = to_upper( condense( CONV string( iv_code ) ) ) ] ) ).
  ENDMETHOD.


  METHOD match.
    LOOP AT mt_outcomes ASSIGNING FIELD-SYMBOL(<ls_outcome>)
         WHERE flow = is_payment-flow AND method_class = is_payment-class.
      IF <ls_outcome>-reg_state IS NOT INITIAL.
        DATA(lt_states) = zcl_cd_hck_ev_support=>tokens( <ls_outcome>-reg_state ).
        IF NOT line_exists( lt_states[ table_line = is_register-state ] ).
          CONTINUE.
        ENDIF.
      ENDIF.
      IF zcl_cd_ops_util=>pcre_match( iv_value = iv_sequence iv_pattern = <ls_outcome>-seq_pattern ) = abap_true.
        rs_outcome = <ls_outcome>.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD lot_mismatch.
    IF is_outcome-expected_dfkkrp IS NOT INITIAL AND is_lot-items <> CONV i( is_outcome-expected_dfkkrp ).
      rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_lot_count
                                       iv_v1    = is_lot-items
                                       iv_v2    = is_outcome-expected_dfkkrp ).
      RETURN.
    ENDIF.
    IF is_lot-items = 0.
      RETURN.
    ENDIF.
    " The last line whose role is compared (e.g. the final return) carries the returned amount
    DATA(lv_index) = lines( it_steps ).
    WHILE lv_index > 0.
      DATA(ls_step) = it_steps[ lv_index ].
      IF ls_step-compare = zif_cd_hck_runtime_types=>gc_compare-returns_lot.
        IF ls_step-amount <> is_lot-amount.
          rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_amount_differs
                                           iv_v1    = |{ ls_step-amount STYLE = SIMPLE }|
                                           iv_v2    = |{ is_lot-amount STYLE = SIMPLE }| ).
        ENDIF.
        RETURN.
      ENDIF.
      lv_index = lv_index - 1.
    ENDWHILE.
  ENDMETHOD.



  METHOD register_mismatch.
    IF is_register-ztnum IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_index) = lines( it_steps ).
    WHILE lv_index > 0.
      DATA(ls_step) = it_steps[ lv_index ].
      IF ls_step-compare = zif_cd_hck_runtime_types=>gc_compare-register.
        IF ls_step-amount <> is_register-amount.
          rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_cheque_amount
                                           iv_v1    = |{ ls_step-amount STYLE = SIMPLE }|
                                           iv_v2    = |{ is_register-amount STYLE = SIMPLE }| ).
        ENDIF.
        RETURN.
      ENDIF.
      lv_index = lv_index - 1.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
