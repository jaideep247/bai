*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_btc_seq.clas.abap
*& Purpose:
*& Evidence kind "bank code lifecycle": every bank statement line of the
*& payment reference (FEBEP-CHECT = AUGBL) gets its role from its scheme
*& and code (posting area ZBTR usage LIFECYCLE per flow + method class; scheme from the
*& statement format, one derivation with EBS: ZCL_CD_EBS_SRC_FEB=>
*& LINE_CODE); the roles ordered by statement date / statement / line are
*& matched (PCRE, whole value) against ZCD_HCK_SEQOUT in SEQ order; the
*& first match gives the outcome. Found = outcome in PARAM1 (comma list,
*& required). The lifecycle of a payment is evaluated once per statement
*& link (PARAM2 / PARAM3) and check run (memo of the collection started by
*& ZCL_CD_HCK_EV_SUPPORT=>START_COLLECTION) and only "found" is derived per
*& PARAM1: rows that differ only in PARAM1 read nothing again.
*& Anomalies (own findings, payment never aged; every anomaly is reported,
*& the primary one first): no pattern matches (UNEXPECTED_SEQUENCE); an
*& outcome that is itself a finding (FINDING); returns lot items (DFKKRP)
*& other than EXPECTED_DFKKRP, a lot without a return line, or the amount
*& of the last compared line differing from the lot (RETURN_INCONSISTENT);
*& the cheque line amount differing from the payment amount
*& (CHEQUE_AMOUNT_MISMATCH, not compared once a later correction line
*& superseded it - compare C); a pending outcome older than MAX_AGE_DAYS
*& after its last line (PENDING_OUTCOME_MISSING). A line whose code has no
*& role is ignored only when it carries no amount or its code is an
*& approved informational exclusion of its scheme (ZCA_PARAM
*& HCK_BTC_INFO_<scheme>); any other unmapped line makes the lifecycle
*& INDETERMINATE (BTC_ROLE_MISSING, E). Cheques (PARAM2 = ZTNUM): lines
*& linked by FEBEP-CHECT = the last PARAM3 (13) characters of DFKKCR-ZTNUM
*& on a statement of the cheque's paying house bank account (shared reader
*& ZCL_CD_HCK_EV_SUPPORT=>LINES_BY_CHEQUE; a line of several cheques of one
*& account is attributed to none, CHEQUE_LINK_AMBIGUOUS); the lifecycle is
*& evaluated per cheque (number within house bank account) and the
*& deciding cheque (newest not voided) gives the payment's outcome, the
*& others are shown with their own outcome and anomalies. An outcome row
*& with a register state (REG_STATE) applies only to a cheque register row
*& in that state; a payment without register row whose matching row needs
*& one is CHEQUE_REGISTER_MISSING. Read-only: nothing is cleared (FPCHR is
*& manual).
*& Modification log:
*& 2026-11-07 | Initial version (user correction of rule 4: lifecycle of BAI / ISO codes per payment).
*& 2026-11-07 | Cheque lifecycle 581 / 255 / corrections: cheque-number link, register state, outcome
*&            | finding, register amount (user facts on disbursement cheques).
*& 2026-11-07 | Design review: unmapped monetary codes no longer disappear - INDETERMINATE +
*&            | BTC_ROLE_MISSING; approved informational exclusions per scheme (HCK_BTC_INFO_<scheme>).
*& 2026-11-07 | Design review: cheque lines by suffix AND house bank account (shared reader, every
*&            | eligible cheque kept); ambiguous line = CHEQUE_LINK_AMBIGUOUS; cheque_links removed.
*& 2026-11-07 | Code review of the cheque lifecycle: correction lines stop the amount comparison; one
*&            | lifecycle per cheque, the live cheque decides; every anomaly reported (outcome
*&            | finding no longer hides lot / amount / age); REG_STATE only against a register row
*&            | (CHEQUE_REGISTER_MISSING); amount from the payment; outcome states tokenised once;
*&            | one evaluation per link and run, found per PARAM1 (memo of the collection).
*& 2026-11-08 | EV_DATE = posting date of the newest line of the lifecycle (basis of the status lag).
*& 2026-11-08 | Comment only: several cheques on one payment document are a defensive path - a stop and
*&            | reissue creates a new payment document and cheque number (user 2026-11-08).
*& 2026-11-08 | Customer posting area: the roles are entries of ZBTR (was ZCD_HCK_BTCROLE) - comment only.
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

    "! The cheque register row the lines belong to (cheque link only)
    TYPES:
      BEGIN OF ty_register,
        exists TYPE abap_bool,
        state  TYPE string,
        ztnum  TYPE string,
      END OF ty_register.

    "! Outcome row with its register states tokenised once per collection
    TYPES:
      BEGIN OF ty_outcome_row,
        flow         TYPE zif_cd_hck_runtime_types=>ty_flow,
        method_class TYPE zif_cd_hck_runtime_types=>ty_method_class,
        seq          TYPE zif_cd_hck_runtime_types=>ty_rule_seq,
        row          TYPE zif_cd_hck_runtime_types=>ty_seq_outcome,
        states       TYPE string_table,
      END OF ty_outcome_row.
    TYPES tt_outcome_row TYPE SORTED TABLE OF ty_outcome_row WITH UNIQUE KEY flow method_class seq.

    "! First outcome row whose pattern matches, or the row that needs a missing register
    TYPES:
      BEGIN OF ty_match,
        found          TYPE abap_bool,
        needs_register TYPE abap_bool,
        row            TYPE zif_cd_hck_runtime_types=>ty_seq_outcome,
      END OF ty_match.

    "! Lifecycle of one payment for one statement link, independent of PARAM1
    TYPES:
      BEGIN OF ty_life,
        outcome  TYPE zif_cd_hck_runtime_types=>ty_outcome,
        "! Never found, whatever the outcome (amount, pending age, indeterminate, ambiguous)
        blocked  TYPE abap_bool,
        evidence TYPE zif_cd_hck_runtime_types=>ty_evidence,
      END OF ty_life.
    TYPES:
      BEGIN OF ty_memo,
        link  TYPE string,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        life  TYPE ty_life,
      END OF ty_memo.
    TYPES tt_memo TYPE HASHED TABLE OF ty_memo WITH UNIQUE KEY link doc1r.
    TYPES tt_link TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    "! Approved informational codes of a scheme (HCK_BTC_INFO_<scheme>)
    TYPES:
      BEGIN OF ty_info,
        scheme TYPE zif_cd_hck_runtime_types=>ty_scheme,
        codes  TYPE string_table,
      END OF ty_info.
    TYPES tt_info TYPE HASHED TABLE OF ty_info WITH UNIQUE KEY scheme.

    "! Memo of the current collection (ZCL_CD_HCK_EV_SUPPORT=>GENERATION): configuration and the
    "! lifecycle of every payment per link, so that rows differing only in PARAM1 read nothing again
    CLASS-DATA gv_generation TYPE i.
    CLASS-DATA gt_roles TYPE zif_cd_hck_runtime_types=>tt_btc_role.
    CLASS-DATA gt_outcomes TYPE tt_outcome_row.
    CLASS-DATA gt_info TYPE tt_info.
    CLASS-DATA gt_memo TYPE tt_memo.
    "! Links whose read reached the row cap
    CLASS-DATA gt_capped TYPE tt_link.
    CLASS-DATA gv_today TYPE d.

    "! Configuration of the collection (read once; an invalid pattern raises every time)
    CLASS-METHODS prepare
      RAISING
        zcx_cd_ops_error.

    "! Lifecycles of payments not yet evaluated for the link (one read each of lines and lots)
    CLASS-METHODS evaluate_batch
      IMPORTING
        it_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment
        iv_link     TYPE string
        iv_cheque   TYPE abap_bool
        iv_length   TYPE i
        iv_max_rows TYPE i.

    "! Roles of the lines of one payment (or one cheque); unmapped monetary lines are listed
    CLASS-METHODS steps_of
      IMPORTING
        is_payment  TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        it_lines    TYPE zcl_cd_hck_ev_support=>tt_doc_line
      EXPORTING
        et_steps    TYPE tt_step
        et_unmapped TYPE string_table.

    CLASS-METHODS evaluate
      IMPORTING
        is_payment     TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        it_steps       TYPE tt_step
        it_unmapped    TYPE string_table
        is_lot         TYPE ty_lot
        is_register    TYPE ty_register
      RETURNING
        VALUE(rs_life) TYPE ty_life.

    "! The payment's lifecycle from its cheques: the deciding cheque's outcome, the other cheques
    "! with their own outcome and anomalies in the detail / further anomalies
    CLASS-METHODS combine
      IMPORTING
        is_live        TYPE ty_life
        it_others      TYPE string_table
        it_other_anoms TYPE zif_cd_hck_runtime_types=>tt_anomaly
      RETURNING
        VALUE(rs_life) TYPE ty_life.

    "! The first active outcome of the flow + class whose pattern matches the whole sequence; a row
    "! with register states applies only to a register row in one of them
    CLASS-METHODS match
      IMPORTING
        is_payment      TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        iv_sequence     TYPE string
        is_register     TYPE ty_register
      RETURNING
        VALUE(rs_match) TYPE ty_match.

    "! The code is an approved informational exclusion of its scheme (never concerns the payment)
    CLASS-METHODS is_informational
      IMPORTING
        iv_scheme     TYPE zif_cd_hck_runtime_types=>ty_scheme
        iv_code       TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! The last line of a role compared with the payment amount differs from it, unless a later
    "! correction line superseded that amount
    CLASS-METHODS register_mismatch
      IMPORTING
        it_steps       TYPE tt_step
        iv_amount      TYPE zif_cd_ops_types=>ty_amount
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
    DATA lt_new TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA(lt_targets) = zcl_cd_hck_ev_support=>tokens(
                         zcl_cd_hck_ev_support=>required_param( iv_value = is_rule-param1
                                                                iv_name  = zif_cd_hck_runtime_types=>gc_rule_param-param1
                                                                is_rule  = is_rule ) ).
    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    prepare( ).

    " Statement link: payment document (default) or the cheque number suffix on the cheque's house
    " bank account (PARAM2 = ZTNUM, PARAM3 suffix length)
    DATA(lv_cheque) = xsdbool( to_upper( condense( CONV string( is_rule-param2 ) ) ) = zif_cd_hck_runtime_types=>gc_link_cheque ).
    DATA(lv_length) = COND i( WHEN lv_cheque = abap_true
                              THEN nmax( val1 = 1
                                         val2 = zcl_cd_hck_param=>int(
                                                  iv_value   = is_rule-param3
                                                  iv_default = zif_cd_hck_runtime_types=>gc_check_default-ztnum_suffix ) ) ).
    DATA(lv_link) = |{ lv_cheque }/{ lv_length }|.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF NOT line_exists( gt_memo[ link = lv_link doc1r = <ls_payment>-doc1r ] ).
        INSERT <ls_payment> INTO TABLE lt_new.
      ENDIF.
    ENDLOOP.
    IF lt_new IS NOT INITIAL.
      evaluate_batch( it_payments = lt_new
                      iv_link     = lv_link
                      iv_cheque   = lv_cheque
                      iv_length   = lv_length
                      iv_max_rows = iv_max_rows ).
    ENDIF.

    rs_result-capped = xsdbool( line_exists( gt_capped[ table_line = lv_link ] ) ).
    rs_result-source = zif_cd_ops_trace_types=>gc_table-febep.
    " Found is the only part that depends on PARAM1
    LOOP AT it_payments ASSIGNING <ls_payment>.
      READ TABLE gt_memo ASSIGNING FIELD-SYMBOL(<ls_memo>) WITH TABLE KEY link = lv_link doc1r = <ls_payment>-doc1r.
      IF sy-subrc <> 0 OR <ls_memo>-life-evidence-doc1r IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(ls_evidence) = <ls_memo>-life-evidence.
      ls_evidence-found = xsdbool( <ls_memo>-life-blocked = abap_false
                                   AND <ls_memo>-life-outcome IS NOT INITIAL
                                   AND line_exists( lt_targets[ table_line = to_upper( condense( CONV string(
                                                                  <ls_memo>-life-outcome ) ) ) ] ) ).
      INSERT ls_evidence INTO TABLE rs_result-evidence.
    ENDLOOP.
  ENDMETHOD.


  METHOD prepare.
    DATA lt_outcomes TYPE tt_outcome_row.
    IF gv_generation = zcl_cd_hck_ev_support=>generation( ) AND gv_today IS NOT INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_runtime_dao( ).
    " An invalid pattern is never 'no match': the kind is unusable (CLEARING_RULE_INVALID)
    LOOP AT lo_dao->get_seq_outcomes( ) ASSIGNING FIELD-SYMBOL(<ls_outcome>).
      IF zcl_cd_ops_util=>pcre_valid( <ls_outcome>-seq_pattern ) = abap_false.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e666(zcd_ops) WITH <ls_outcome>-seq_pattern
                                     |{ <ls_outcome>-flow }{ <ls_outcome>-method_class }/{ <ls_outcome>-seq }|.
      ENDIF.
      INSERT VALUE #( flow         = <ls_outcome>-flow
                      method_class = <ls_outcome>-method_class
                      seq          = <ls_outcome>-seq
                      row          = <ls_outcome>
                      states       = zcl_cd_hck_ev_support=>tokens( <ls_outcome>-reg_state ) ) INTO TABLE lt_outcomes.
    ENDLOOP.
    gt_outcomes = lt_outcomes.
    gt_roles = lo_dao->get_btc_roles( ).
    CLEAR: gt_info, gt_memo, gt_capped.
    gv_today = zcl_cd_ops_factory=>get_clock( )->today( ).
    gv_generation = zcl_cd_hck_ev_support=>generation( ).
  ENDMETHOD.


  METHOD evaluate_batch.
    DATA lt_lots TYPE tt_lot.
    DATA ls_lines TYPE zcl_cd_hck_ev_support=>ty_doc_lines.
    DATA ls_cheque TYPE zcl_cd_hck_ev_support=>ty_cheque_lines.
    DATA lt_doc_lines TYPE zcl_cd_hck_ev_support=>tt_doc_line.
    DATA lt_others TYPE string_table.
    DATA lt_other_anoms TYPE zif_cd_hck_runtime_types=>tt_anomaly.
    DATA lt_checks TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_check WITH NON-UNIQUE KEY doc1r.
    DATA ls_life TYPE ty_life.

    IF iv_cheque = abap_true.
      ls_cheque = zcl_cd_hck_ev_support=>lines_by_cheque( it_payments = it_payments
                                                          iv_length   = iv_length
                                                          iv_max_rows = iv_max_rows ).
      ls_lines-lines  = ls_cheque-lines.
      ls_lines-capped = ls_cheque-capped.
      lt_checks = ls_cheque-checks.
    ELSE.
      ls_lines = zcl_cd_hck_ev_support=>lines_by_doc( it_payments = it_payments
                                                      iv_max_rows = iv_max_rows ).
    ENDIF.
    IF ls_lines-capped = abap_true.
      INSERT iv_link INTO TABLE gt_capped.
    ENDIF.
    DATA(lt_live) = zcl_cd_hck_ev_support=>live_cheques( ls_cheque-checks ).
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
      CLEAR ls_life.
      DATA(ls_lot) = VALUE ty_lot( lt_lots[ doc1r = <ls_payment>-doc1r ] OPTIONAL ).
      " A statement line of several cheques of one account: the lifecycle cannot be told
      READ TABLE ls_cheque-ambiguous ASSIGNING FIELD-SYMBOL(<ls_ambiguous>) WITH TABLE KEY doc1r = <ls_payment>-doc1r.
      IF sy-subrc = 0.
        ls_life-blocked  = abap_true.
        ls_life-evidence = VALUE #( doc1r    = <ls_payment>-doc1r
                                    anomaly  = zif_cd_hck_runtime_types=>gc_code-cheque_ambiguous
                                    severity = zif_cd_ops_types=>gc_severity-error
                                    detail   = <ls_ambiguous>-detail ).
      ELSEIF iv_cheque = abap_false.
        CLEAR lt_doc_lines.
        LOOP AT ls_lines-lines USING KEY by_doc ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE doc1r = <ls_payment>-doc1r.
          INSERT <ls_line> INTO TABLE lt_doc_lines.
        ENDLOOP.
        steps_of( EXPORTING is_payment  = <ls_payment>
                            it_lines    = lt_doc_lines
                  IMPORTING et_steps    = DATA(lt_steps)
                            et_unmapped = DATA(lt_unmapped) ).
        ls_life = evaluate( is_payment  = <ls_payment>
                            it_steps    = lt_steps
                            it_unmapped = lt_unmapped
                            is_lot      = ls_lot
                            is_register = VALUE #( ) ).
      ELSE.
        " One lifecycle per cheque (number within house bank account); the deciding cheque (newest
        " not voided) gives the payment's outcome, the returns lot belongs to it
        DATA(ls_live) = VALUE zif_cd_ops_trace_types=>ty_check( lt_live[ doc1r = <ls_payment>-doc1r ] OPTIONAL ).
        CLEAR: lt_others, lt_other_anoms.
        DATA(ls_live_life) = VALUE ty_life( ).
        LOOP AT lt_checks ASSIGNING FIELD-SYMBOL(<ls_check>) WHERE doc1r = <ls_payment>-doc1r.
          CLEAR lt_doc_lines.
          LOOP AT ls_lines-lines USING KEY by_doc ASSIGNING <ls_line> WHERE doc1r = <ls_payment>-doc1r.
            IF <ls_line>-ztnum = <ls_check>-ztnum AND <ls_line>-line-hbkid = <ls_check>-hbkid
               AND <ls_line>-line-hktid = <ls_check>-hktid.
              INSERT <ls_line> INTO TABLE lt_doc_lines.
            ENDIF.
          ENDLOOP.
          DATA(lv_is_live) = xsdbool( <ls_check>-ztnum = ls_live-ztnum AND <ls_check>-hbkid = ls_live-hbkid
                                      AND <ls_check>-hktid = ls_live-hktid ).
          steps_of( EXPORTING is_payment  = <ls_payment>
                              it_lines    = lt_doc_lines
                    IMPORTING et_steps    = lt_steps
                              et_unmapped = lt_unmapped ).
          DATA(ls_cheque_life) = evaluate(
            is_payment  = <ls_payment>
            it_steps    = lt_steps
            it_unmapped = lt_unmapped
            is_lot      = COND #( WHEN lv_is_live = abap_true THEN ls_lot )
            is_register = VALUE #( exists = abap_true
                                   state  = COND #( WHEN <ls_check>-state IS INITIAL THEN zif_cd_hck_runtime_types=>gc_state_blank
                                                    ELSE to_upper( CONV string( <ls_check>-state ) ) )
                                   ztnum  = condense( CONV string( <ls_check>-ztnum ) ) ) ).
          IF lv_is_live = abap_true.
            ls_live_life = ls_cheque_life.
            CONTINUE.
          ENDIF.
          " Another cheque of the same payment document keeps its own outcome (defensive: a stop and
          " reissue creates a new payment document with its own lifecycle, user 2026-11-08)
          IF ls_cheque_life-evidence-doc1r IS INITIAL.
            CONTINUE.
          ENDIF.
          INSERT |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_other_cheque
                                           iv_v1    = <ls_check>-ztnum
                                           iv_v2    = <ls_check>-state ) } { ls_cheque_life-evidence-detail }|
            INTO TABLE lt_others.
          IF ls_cheque_life-evidence-anomaly IS NOT INITIAL.
            INSERT VALUE #( code     = ls_cheque_life-evidence-anomaly
                            severity = ls_cheque_life-evidence-severity
                            detail   = ls_cheque_life-evidence-detail ) INTO TABLE lt_other_anoms.
          ENDIF.
          INSERT LINES OF ls_cheque_life-evidence-more INTO TABLE lt_other_anoms.
        ENDLOOP.
        ls_life = combine( is_live = ls_live_life it_others = lt_others it_other_anoms = lt_other_anoms ).
        IF ls_life-evidence IS NOT INITIAL.
          ls_life-evidence-doc1r = <ls_payment>-doc1r.
        ENDIF.
      ENDIF.
      INSERT VALUE #( link = iv_link doc1r = <ls_payment>-doc1r life = ls_life ) INTO TABLE gt_memo.
    ENDLOOP.
  ENDMETHOD.


  METHOD steps_of.
    CLEAR: et_steps, et_unmapped.
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      DATA(ls_code) = zcl_cd_ebs_src_feb=>line_code( iv_vorgc = <ls_line>-line-vorgc
                                                     iv_vgext = <ls_line>-line-vgext ).
      READ TABLE gt_roles ASSIGNING FIELD-SYMBOL(<ls_role>)
           WITH TABLE KEY flow         = is_payment-flow
                          method_class = is_payment-class
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
                                        iv_v4    = |{ is_payment-flow }{ is_payment-class }| )
            INTO TABLE et_unmapped.
        ENDIF.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( budat   = <ls_line>-line-budat
                      kukey   = <ls_line>-line-kukey
                      esnum   = <ls_line>-line-esnum
                      role    = <ls_role>-role
                      code    = ls_code-btc_code
                      amount  = abs( <ls_line>-line-kwbtr )
                      compare = <ls_role>-compare_amount ) INTO TABLE et_steps.
    ENDLOOP.
    " The lifecycle in statement order: statement date, statement, line
    SORT et_steps BY budat kukey esnum.
  ENDMETHOD.


  METHOD evaluate.
    DATA lt_roles TYPE string_table.
    DATA lt_codes TYPE string_table.
    DATA lt_anomalies TYPE zif_cd_hck_runtime_types=>tt_anomaly.
    " An unmapped monetary line: the lifecycle is INDETERMINATE (never CLEARED / RETURNED) and the
    " role table needs the row
    IF it_unmapped IS NOT INITIAL.
      rs_life-blocked  = abap_true.
      DATA(lv_indeterminate) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_indeterminate
                                                      iv_v1    = zif_cd_hck_runtime_types=>gc_outcome-indeterminate ).
      rs_life-evidence = VALUE #( doc1r    = is_payment-doc1r
                                  hits     = lines( it_steps )
                                  anomaly  = zif_cd_hck_runtime_types=>gc_code-btc_role_missing
                                  severity = zif_cd_ops_types=>gc_severity-error
                                  detail   = |{ lv_indeterminate } | &&
                                             concat_lines_of( table = it_unmapped sep = zif_cd_hck_runtime_types=>gc_role_sep ) ).
      RETURN.
    ENDIF.
    IF it_steps IS INITIAL.
      " No line with a role: no evidence - unless a returns lot exists without its return line
      IF is_lot-items > 0.
        rs_life-evidence = VALUE #( doc1r    = is_payment-doc1r
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
    rs_life-evidence-doc1r = is_payment-doc1r.
    rs_life-evidence-hits  = lines( it_steps ).
    " Newest line (steps ordered by statement date / statement / line): when the bank evidence arrived
    rs_life-evidence-ev_date = it_steps[ lines( it_steps ) ]-budat.
    DATA(lv_detail) = zcl_cd_ops_util=>text(
                        iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_sequence
                        iv_tail  = |{ lv_sequence } ({ concat_lines_of( table = lt_codes
                                                                        sep   = zif_cd_hck_runtime_types=>gc_role_sep ) })| ).
    IF is_register-exists = abap_true.
      lv_detail = |{ lv_detail } | &&
                  |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_cheque
                                            iv_v1    = is_register-ztnum
                                            iv_v2    = is_register-state ) }|.
    ENDIF.
    DATA(ls_match) = match( is_payment = is_payment iv_sequence = lv_sequence is_register = is_register ).
    IF ls_match-needs_register = abap_true.
      " The matching row needs the register state, but the payment has no register row for the link
      rs_life-blocked           = abap_true.
      rs_life-evidence-anomaly  = zif_cd_hck_runtime_types=>gc_code-register_missing.
      rs_life-evidence-severity = zif_cd_ops_types=>gc_severity-error.
      rs_life-evidence-detail   = |{ lv_detail } | &&
                                  |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_register_missing
                                                            iv_v1    = ls_match-row-seq ) }|.
      RETURN.
    ENDIF.
    IF ls_match-found = abap_false.
      rs_life-evidence-anomaly  = zif_cd_hck_runtime_types=>gc_code-unexpected_seq.
      rs_life-evidence-severity = zif_cd_ops_types=>gc_severity-error.
      rs_life-evidence-detail   = |{ lv_detail } { zcl_cd_ops_util=>text( zif_cd_hck_runtime_types=>gc_msg-ev_no_pattern ) }|.
      RETURN.
    ENDIF.
    DATA(ls_outcome) = ls_match-row.
    lv_detail = |{ lv_detail } | &&
                |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_outcome
                                          iv_v1    = ls_outcome-outcome
                                          iv_v2    = ls_outcome-seq ) }|.
    rs_life-outcome = ls_outcome-outcome.
    DATA(lv_severity) = COND zif_cd_ops_types=>ty_severity( WHEN ls_outcome-severity IS INITIAL
                                                            THEN zif_cd_ops_types=>gc_severity-error
                                                            ELSE ls_outcome-severity ).
    rs_life-evidence-severity = lv_severity.

    " Every anomaly is reported, the outcome's own finding first (clarification, manual clearing)
    IF ls_outcome-finding IS NOT INITIAL.
      INSERT VALUE #( code = ls_outcome-finding severity = lv_severity detail = ls_outcome-description )
        INTO TABLE lt_anomalies.
    ENDIF.
    DATA(lv_mismatch) = lot_mismatch( is_outcome = ls_outcome it_steps = it_steps is_lot = is_lot ).
    IF lv_mismatch IS NOT INITIAL.
      INSERT VALUE #( code = zif_cd_hck_runtime_types=>gc_code-return_inconsist severity = lv_severity detail = lv_mismatch )
        INTO TABLE lt_anomalies.
    ENDIF.
    IF is_register-exists = abap_true.
      lv_mismatch = register_mismatch( it_steps = it_steps iv_amount = abs( is_payment-amount ) ).
      IF lv_mismatch IS NOT INITIAL.
        rs_life-blocked = abap_true.
        INSERT VALUE #( code     = zif_cd_hck_runtime_types=>gc_code-cheque_amount
                        severity = zif_cd_ops_types=>gc_severity-error
                        detail   = lv_mismatch ) INTO TABLE lt_anomalies.
      ENDIF.
    ENDIF.
    " A pending outcome (e.g. redeposit) may stay MAX_AGE_DAYS after its last line
    DATA(lv_age) = gv_today - it_steps[ lines( it_steps ) ]-budat.
    IF ls_outcome-max_age_days > 0 AND lv_age > ls_outcome-max_age_days.
      rs_life-blocked = abap_true.
      INSERT VALUE #( code     = zif_cd_hck_runtime_types=>gc_code-pending_overdue
                      severity = lv_severity
                      detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_pending_age
                                                        iv_v1    = lv_age
                                                        iv_v2    = ls_outcome-max_age_days ) ) INTO TABLE lt_anomalies.
    ENDIF.

    rs_life-evidence-detail = lv_detail.
    LOOP AT lt_anomalies ASSIGNING FIELD-SYMBOL(<ls_anomaly>).
      IF sy-tabix = 1.
        rs_life-evidence-anomaly  = <ls_anomaly>-code.
        rs_life-evidence-severity = <ls_anomaly>-severity.
        rs_life-evidence-detail   = |{ lv_detail } { <ls_anomaly>-detail }|.
      ELSE.
        INSERT VALUE #( code     = <ls_anomaly>-code
                        severity = <ls_anomaly>-severity
                        detail   = |{ lv_detail } { <ls_anomaly>-detail }| ) INTO TABLE rs_life-evidence-more.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD combine.
    rs_life = is_live.
    IF it_others IS INITIAL AND it_other_anoms IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_others) = concat_lines_of( table = it_others sep = ` ` ).
    rs_life-evidence-detail = COND #( WHEN rs_life-evidence-detail IS INITIAL THEN lv_others
                                      ELSE |{ rs_life-evidence-detail } { lv_others }| ).
    LOOP AT it_other_anoms ASSIGNING FIELD-SYMBOL(<ls_anomaly>).
      " The deciding cheque's anomaly stays primary; the others' follow
      IF rs_life-evidence-anomaly IS INITIAL.
        rs_life-evidence-anomaly  = <ls_anomaly>-code.
        rs_life-evidence-severity = <ls_anomaly>-severity.
      ELSE.
        INSERT <ls_anomaly> INTO TABLE rs_life-evidence-more.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD match.
    LOOP AT gt_outcomes ASSIGNING FIELD-SYMBOL(<ls_outcome>)
         WHERE flow = is_payment-flow AND method_class = is_payment-class.
      IF zcl_cd_ops_util=>pcre_match( iv_value = iv_sequence iv_pattern = <ls_outcome>-row-seq_pattern ) = abap_false.
        CONTINUE.
      ENDIF.
      IF <ls_outcome>-states IS NOT INITIAL.
        " The register state applies only to a register row; without one the row cannot decide
        IF is_register-exists = abap_false.
          rs_match-needs_register = abap_true.
          rs_match-row            = <ls_outcome>-row.
          RETURN.
        ENDIF.
        IF NOT line_exists( <ls_outcome>-states[ table_line = is_register-state ] ).
          CONTINUE.
        ENDIF.
      ENDIF.
      rs_match-found = abap_true.
      rs_match-row   = <ls_outcome>-row.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_informational.
    READ TABLE gt_info ASSIGNING FIELD-SYMBOL(<ls_info>) WITH TABLE KEY scheme = iv_scheme.
    IF sy-subrc <> 0.
      INSERT VALUE #( scheme = iv_scheme
                      codes  = zcl_cd_hck_ev_support=>tokens( zcl_cd_ops_factory=>get_params( )->get_param(
                                 iv_name = CONV #( |{ zif_cd_hck_runtime_types=>gc_param_prefix-btc_info }{ iv_scheme }| ) ) ) )
        INTO TABLE gt_info ASSIGNING <ls_info>.
    ENDIF.
    rv_yes = xsdbool( line_exists( <ls_info>-codes[ table_line = to_upper( condense( CONV string( iv_code ) ) ) ] ) ).
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
    " From the last line back: a correction after the compared line supersedes its amount (the
    " cheque is cleared manually in FPCHR), else the last compared line must carry the payment amount
    DATA(lv_index) = lines( it_steps ).
    WHILE lv_index > 0.
      DATA(ls_step) = it_steps[ lv_index ].
      CASE ls_step-compare.
        WHEN zif_cd_hck_runtime_types=>gc_compare-correction.
          RETURN.
        WHEN zif_cd_hck_runtime_types=>gc_compare-register.
          IF ls_step-amount <> iv_amount.
            rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_cheque_amount
                                             iv_v1    = |{ ls_step-amount STYLE = SIMPLE }|
                                             iv_v2    = |{ iv_amount STYLE = SIMPLE }| ).
          ENDIF.
          RETURN.
      ENDCASE.
      lv_index = lv_index - 1.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
