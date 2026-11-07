*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_outcome.clas.abap
*& Purpose:
*& The canonical payment outcome evaluator (ZIF_CD_OPS_PAY_OUTCOME),
*& extracted unchanged from the morning report check A_INFLIGHT: method
*& classes and house-bank calendars (ZCD_HCK_PMCLASS / PMBANK), rules per
*& flow + class and purpose (ZCD_HCK_CLRRULE: VOIDED, RETURNED, RETRIEVED,
*& PENDING, CLEARED, IN_FLIGHT - the first purpose with evidence decides;
*& X mandatory indicator, C mandatory corroboration, N must not hold,
*& blank informational), evidence plug-ins (ZIF_CD_HCK_EVIDENCE, one
*& collect per kind and parameters for all payments), anomalies of an
*& evidence, fail closed on an unusable mandatory kind (UNDETERMINED),
*& reversed payment documents (DFKKKO-STBEL). Also the source attribution
*& of a FIN number (request log, SUCCESS row rule): two or more sources =
*& AMBIGUOUS. The verdict names the outcome, the deciding evidence kind and
*& reference and the finding. Read-only; reads through ZIF_CD_HCK_RUNTIME_DAO
*& and ZIF_CD_OPS_TRACE_DAO (factories), never SQL of its own.
*& Modification log:
*& 2026-11-07 | Initial version: collect / decide moved from ZCL_CD_HCK_C_INFLIGHT (behaviour
*&            | unchanged), purpose RETRIEVED (a retrieval is not a return), outcome per payment,
*&            | latest payment run per document, source attribution (AMBIGUOUS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - canonical evaluator</p>
"! One instance per run (configuration and listing state); create it through
"! ZCL_CD_OPS_FACTORY=>GET_PAY_OUTCOME.
CLASS zcl_cd_ops_pay_outcome DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome.

    "! Purposes in the order they decide: the first purpose with evidence decides (a voided
    "! cheque or a returned / retrieved payment is never judged as cleared)
    CLASS-METHODS purposes
      RETURNING
        VALUE(rt_purposes) TYPE string_table.

    "! Row cap of every evidence read: HCK_INFLIGHT_MAX_ROWS (the cap of A_INFLIGHT), so every
    "! consumer judges with the same limit
    CLASS-METHODS evidence_cap
      RETURNING
        VALUE(rv_cap) TYPE i.

  PRIVATE SECTION.
    "! One evidence kind with its parameters, collected once for every payment that needs it
    TYPES:
      BEGIN OF ty_group,
        evidence_class TYPE zif_cd_ops_types=>ty_class_name,
        param1         TYPE zif_cd_hck_runtime_types=>ty_rule_param,
        param2         TYPE zif_cd_hck_runtime_types=>ty_rule_param,
        param3         TYPE zif_cd_hck_runtime_types=>ty_rule_param,
        "! The kind could not be used (class, parameters, read): its purposes are not judged
        invalid        TYPE abap_bool,
        "! The kind's settings are not maintained: informational rows are skipped, mandatory rows
        "! leave their purpose undetermined
        unconfigured   TYPE abap_bool,
        evidence       TYPE zif_cd_hck_runtime_types=>tt_evidence,
      END OF ty_group.
    TYPES tt_group TYPE SORTED TABLE OF ty_group WITH UNIQUE KEY evidence_class param1 param2 param3.

    "! Payment + code already listed in this evaluation (an anomaly is listed once per payment)
    TYPES:
      BEGIN OF ty_listed_key,
        doc1r TYPE zif_cd_hck_runtime_types=>ty_docno,
        code  TYPE zif_cd_ops_types=>ty_check_code,
      END OF ty_listed_key.
    TYPES tt_listed_key TYPE HASHED TABLE OF ty_listed_key WITH UNIQUE KEY doc1r code.
    TYPES tt_key TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    DATA ms_config TYPE zif_cd_ops_payout_types=>ty_config.
    DATA mv_loaded TYPE abap_bool.
    DATA mv_context TYPE zif_cd_hck_types=>ty_check_id.
    DATA mv_cap TYPE i.
    DATA mt_groups TYPE tt_group.
    DATA mt_listed TYPE tt_listed_key.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.

    "! Each evidence kind of the rules collected once for the payments of its flow / classes
    METHODS collect_evidence
      IMPORTING
        it_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.

    "! Verdict of one payment from its rules (purposes in order) and evidence anomalies
    METHODS decide
      IMPORTING
        is_payment        TYPE zif_cd_hck_runtime_types=>ty_issued_payment
      RETURNING
        VALUE(rs_verdict) TYPE zif_cd_ops_payout_types=>ty_verdict.

    METHODS group_of
      IMPORTING
        is_rule         TYPE zif_cd_hck_runtime_types=>ty_clr_rule
      RETURNING
        VALUE(rs_group) TYPE ty_group.

    "! Read capped: listed once per read
    METHODS capped
      IMPORTING
        iv_table TYPE clike.

    METHODS config_finding
      IMPORTING
        iv_object   TYPE clike
        iv_severity TYPE zif_cd_ops_types=>ty_severity DEFAULT zif_cd_ops_types=>gc_severity-info
        iv_code     TYPE zif_cd_ops_types=>ty_check_code DEFAULT zif_cd_hck_runtime_types=>gc_code-inflight_config
        iv_message  TYPE string
      CHANGING
        ct_findings TYPE zif_cd_ops_types=>tt_finding.

    "! A rule row of the group is mandatory (REQUIRED X / C / N)
    METHODS mandatory_use
      IMPORTING
        is_group      TYPE ty_group
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! Every anomaly of the evidence of the payment's rules, once per payment and code
    METHODS list_anomalies
      IMPORTING
        is_payment TYPE zif_cd_hck_runtime_types=>ty_issued_payment
      CHANGING
        cs_verdict TYPE zif_cd_ops_payout_types=>ty_verdict.

    METHODS list
      IMPORTING
        is_payment TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        is_listing TYPE zif_cd_ops_payout_types=>ty_listing
      CHANGING
        cs_verdict TYPE zif_cd_ops_payout_types=>ty_verdict.

    "! REQUIRED X, C or N: the row must be evaluable; blank (or any other value) = informational
    CLASS-METHODS is_mandatory
      IMPORTING
        iv_required   TYPE zif_cd_hck_runtime_types=>ty_required
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! Label of a rule row in a finding: SEQ and description (or class)
    CLASS-METHODS label
      IMPORTING
        is_rule        TYPE zif_cd_hck_runtime_types=>ty_clr_rule
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS payment_line
      IMPORTING
        is_payment     TYPE zif_cd_hck_runtime_types=>ty_issued_payment
        iv_what        TYPE clike
        iv_tail        TYPE string
      RETURNING
        VALUE(rv_line) TYPE string.

    "! Canonical outcome of a consistent purpose (the purpose values are the outcome values)
    CLASS-METHODS outcome_of
      IMPORTING
        iv_purpose        TYPE zif_cd_hck_runtime_types=>ty_purpose
      RETURNING
        VALUE(rv_outcome) TYPE zif_cd_ops_payout_types=>ty_outcome.

ENDCLASS.



CLASS zcl_cd_ops_pay_outcome IMPLEMENTATION.

  METHOD purposes.
    rt_purposes = VALUE #( ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-voided ) )
                           ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-returned ) )
                           ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-retrieved ) )
                           ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-pending ) )
                           ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-cleared ) )
                           ( CONV #( zif_cd_hck_runtime_types=>gc_purpose-in_flight ) ) ).
  ENDMETHOD.


  METHOD evidence_cap.
    rv_cap = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows
                                        iv_default = zif_cd_hck_runtime_types=>gc_param_default-inflight_max_rows
                                        iv_ceiling = zif_cd_hck_runtime_types=>gc_max_inflight_rows ).
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome~load.
    CLEAR: ms_config, mt_groups, mt_listed, mt_findings.
    mv_context = iv_context.
    mv_cap = iv_max_rows.
    " The evidence kinds share their reads (cheques, statement lines, lifecycles) within this run only
    zcl_cd_hck_ev_support=>start_collection( ).
    DATA(lo_dao) = zcl_cd_hck_factory=>get_runtime_dao( ).
    DATA(lt_classes) = lo_dao->get_pm_classes( ).
    ms_config-banks = lo_dao->get_pm_banks( ).
    ms_config-rules = lo_dao->get_clearing_rules( ).
    LOOP AT lt_classes ASSIGNING FIELD-SYMBOL(<ls_class>).
      DATA(lv_key) = CONV zif_cd_hck_runtime_types=>ty_flow_class( |{ <ls_class>-flow }{ <ls_class>-method_class }| ).
      DATA(lt_tokens) = zcl_cd_hck_ev_support=>tokens( <ls_class>-pay_methods ).
      IF lt_tokens IS INITIAL.
        config_finding( EXPORTING iv_object   = lv_key
                                  iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-class_not_watched
                                                                       iv_v1    = lv_key )
                        CHANGING  ct_findings = ms_config-findings ).
        CONTINUE.
      ENDIF.
      " A class is watched only when it has rules that clear it (else nothing could ever clear it)
      IF NOT line_exists( ms_config-rules[ flow = <ls_class>-flow method_class = <ls_class>-method_class
                                           purpose = zif_cd_hck_runtime_types=>gc_purpose-cleared ] ).
        config_finding( EXPORTING iv_object   = lv_key
                                  iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-no_cleared_rule
                                                                       iv_v1    = lv_key )
                        CHANGING  ct_findings = ms_config-findings ).
        CONTINUE.
      ENDIF.
      LOOP AT lt_tokens ASSIGNING FIELD-SYMBOL(<lv_method>).
        DATA(lv_pymet) = CONV zif_cd_hck_runtime_types=>ty_pymet( <lv_method> ).
        DATA(ls_known) = VALUE #( ms_config-methods[ flow = <ls_class>-flow pymet = lv_pymet ] OPTIONAL ).
        IF ls_known IS NOT INITIAL AND ls_known-class <> <ls_class>-method_class.
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e385(zcd_ops) WITH lv_pymet ls_known-class <ls_class>-method_class.
        ENDIF.
        INSERT VALUE #( flow = <ls_class>-flow pymet = lv_pymet class = <ls_class>-method_class )
          INTO TABLE ms_config-methods.
      ENDLOOP.
      INSERT <ls_class> INTO TABLE ms_config-classes.
      INSERT lv_key INTO TABLE ms_config-watched.
    ENDLOOP.
    IF ms_config-methods IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e384(zcd_ops) WITH iv_context.
    ENDIF.
    mv_loaded = abap_true.
    rs_config = ms_config.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome~classify.
    " Flow from the method (TFK042Z-XEINZ), class from the configuration
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_read>).
      DATA(ls_payment) = <ls_read>.
      ls_payment-flow = COND #( WHEN <ls_read>-xeinz = abap_true THEN zif_cd_hck_runtime_types=>gc_flow-collection
                                ELSE zif_cd_hck_runtime_types=>gc_flow-disbursement ).
      ls_payment-class = VALUE #( ms_config-methods[ flow = ls_payment-flow pymet = <ls_read>-pymet ]-class OPTIONAL ).
      IF ls_payment-class IS NOT INITIAL.
        INSERT ls_payment INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome~evaluate.
    DATA lt_reversed TYPE tt_key.
    DATA lt_judged TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    CLEAR: mt_groups, mt_listed, mt_findings.

    " Reversed payments (DFKKKO-STBEL) are not judged
    DATA(lt_docno) = zcl_cd_hck_ev_support=>docnos( it_payments ).
    IF lt_docno IS NOT INITIAL.
      LOOP AT zcl_cd_ops_factory=>get_trace_dao( )->get_doc_headers( lt_docno ) ASSIGNING FIELD-SYMBOL(<ls_header>)
           WHERE stbel IS NOT INITIAL.
        INSERT CONV string( <ls_header>-opbel ) INTO TABLE lt_reversed.
      ENDLOOP.
    ENDIF.
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      IF NOT line_exists( lt_reversed[ table_line = CONV string( <ls_payment>-doc1r ) ] ).
        INSERT <ls_payment> INTO TABLE lt_judged.
      ENDIF.
    ENDLOOP.

    collect_evidence( lt_judged ).

    LOOP AT it_payments ASSIGNING <ls_payment>.
      IF line_exists( lt_reversed[ table_line = CONV string( <ls_payment>-doc1r ) ] ).
        INSERT VALUE #( doc1r   = <ls_payment>-doc1r
                        laufd   = <ls_payment>-laufd
                        laufi   = <ls_payment>-laufi
                        bukrs   = <ls_payment>-bukrs
                        flow    = <ls_payment>-flow
                        class   = <ls_payment>-class
                        outcome = zif_cd_ops_payout_types=>gc_outcome-reversed
                        status  = zif_cd_ops_payout_types=>gc_status-reversed ) INTO TABLE rs_evaluation-verdicts.
        CONTINUE.
      ENDIF.
      INSERT decide( <ls_payment> ) INTO TABLE rs_evaluation-verdicts.
    ENDLOOP.

    rs_evaluation-findings = mt_findings.
    LOOP AT mt_groups ASSIGNING FIELD-SYMBOL(<ls_group>)
         WHERE invalid = abap_true OR unconfigured = abap_true.
      IF <ls_group>-invalid = abap_true OR mandatory_use( <ls_group> ) = abap_true.
        rs_evaluation-evidence_partial = abap_true.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome~evaluate_documents.
    DATA lt_latest TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    IF it_docno IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_runs) = zcl_cd_hck_factory=>get_runtime_dao( )->get_issued_payments_by_doc(
                      it_docno    = it_docno
                      iv_max_rows = nmax( val1 = mv_cap val2 = lines( it_docno ) ) ).
    " The latest payment run of each document decides (run date, then run ID, descending)
    SORT lt_runs BY doc1r ASCENDING laufd DESCENDING laufi DESCENDING.
    DELETE ADJACENT DUPLICATES FROM lt_runs COMPARING doc1r.
    INSERT LINES OF lt_runs INTO TABLE lt_latest.
    rs_evaluation = zif_cd_ops_pay_outcome~evaluate( zif_cd_ops_pay_outcome~classify( lt_latest ) ).
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome~sources_of.
    DATA lt_keys TYPE zif_cd_ops_trace_types=>tt_key_value.
    IF it_fin IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(ls_source) = zcl_cd_ops_trace_engine=>parse_source(
                        iv_param = zif_cd_ops_trace_types=>gc_param-src_request
                        iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_request ) ).
    IF ls_source-table_name IS INITIAL OR ls_source-key_field IS INITIAL OR ls_source-key2_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e703(zcd_ops) WITH zif_cd_ops_trace_types=>gc_param-src_request.
    ENDIF.
    DATA(lv_success) = condense( CONV string( lo_params->get_param(
                                                iv_name    = zif_cd_ops_trace_types=>gc_param-success_value
                                                iv_default = zif_cd_ops_trace_types=>gc_default-success_value ) ) ).
    LOOP AT it_fin ASSIGNING FIELD-SYMBOL(<lv_fin>).
      INSERT CONV #( <lv_fin> ) INTO TABLE lt_keys.
    ENDLOOP.
    " A capped read could hide a second source: fail closed (the caller writes nothing)
    DATA(lv_cap) = lines( lt_keys ) * zif_cd_ops_payout_types=>gc_max_attempts.
    DATA(lt_rows) = zcl_cd_ops_factory=>get_trace_dao( )->read_configured_set( is_source   = ls_source
                                                                              it_keys     = lt_keys
                                                                              iv_max_rows = lv_cap ).
    IF lines( lt_rows ) >= lv_cap.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e379(zcd_ops) WITH ls_source-table_name lv_cap mv_context.
    ENDIF.
    " Rule: the sources with a SUCCESS row (never the highest COUNTER); without any SUCCESS row
    " every source of the FIN counts
    LOOP AT it_fin ASSIGNING <lv_fin>.
      DATA(lt_found) = VALUE zif_cd_ops_payout_types=>tt_fin_source( ).
      DATA(lt_any) = VALUE zif_cd_ops_payout_types=>tt_fin_source( ).
      LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
        IF to_upper( condense( CONV string( <ls_row>-key1 ) ) ) <> to_upper( condense( CONV string( <lv_fin> ) ) ).
          CONTINUE.
        ENDIF.
        DATA(ls_fin_source) = VALUE zif_cd_ops_payout_types=>ty_fin_source( fin    = <lv_fin>
                                                                             source = to_upper( condense( <ls_row>-key2 ) ) ).
        INSERT ls_fin_source INTO TABLE lt_any.
        IF condense( CONV string( <ls_row>-status ) ) = lv_success.
          INSERT ls_fin_source INTO TABLE lt_found.
        ENDIF.
      ENDLOOP.
      IF lt_found IS INITIAL.
        lt_found = lt_any.
      ENDIF.
      IF lt_found IS INITIAL.
        INSERT VALUE #( fin = <lv_fin> ) INTO TABLE lt_found.
      ENDIF.
      DATA(lv_sources) = lines( lt_found ).
      LOOP AT lt_found ASSIGNING FIELD-SYMBOL(<ls_found>).
        <ls_found>-sources = lv_sources.
        INSERT <ls_found> INTO TABLE rt_sources.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_outcome~for_source.
    rs_verdict = is_verdict.
    IF is_source-sources <= 1.
      RETURN.
    ENDIF.
    " Never attributed to one source: every source of the FIN shows AMBIGUOUS
    rs_verdict-outcome      = zif_cd_ops_payout_types=>gc_outcome-ambiguous.
    rs_verdict-finding      = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
    rs_verdict-severity     = zif_cd_ops_types=>gc_severity-warning.
    rs_verdict-evidence_ref = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-source_ambiguous
                                                     iv_v1    = is_source-fin
                                                     iv_v2    = is_source-sources
                                                     iv_v3    = is_source-source
                                                     iv_v4    = is_verdict-outcome ).
  ENDMETHOD.


  METHOD collect_evidence.
    DATA lt_need TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    " One group per evidence class + parameters across all flows / classes
    LOOP AT ms_config-rules ASSIGNING FIELD-SYMBOL(<ls_rule>).
      INSERT VALUE #( evidence_class = to_upper( condense( <ls_rule>-evidence_class ) )
                      param1         = <ls_rule>-param1
                      param2         = <ls_rule>-param2
                      param3         = <ls_rule>-param3 ) INTO TABLE mt_groups.
    ENDLOOP.
    LOOP AT mt_groups ASSIGNING FIELD-SYMBOL(<ls_group>).
      CLEAR lt_need.
      DATA(ls_rule) = VALUE zif_cd_hck_runtime_types=>ty_clr_rule( ).
      LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
        LOOP AT ms_config-rules ASSIGNING <ls_rule> WHERE flow = <ls_payment>-flow AND method_class = <ls_payment>-class.
          IF to_upper( condense( <ls_rule>-evidence_class ) ) = <ls_group>-evidence_class
             AND <ls_rule>-param1 = <ls_group>-param1 AND <ls_rule>-param2 = <ls_group>-param2
             AND <ls_rule>-param3 = <ls_group>-param3.
            INSERT <ls_payment> INTO TABLE lt_need.
            ls_rule = <ls_rule>.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
      IF lt_need IS INITIAL.
        CONTINUE.
      ENDIF.
      TRY.
          DATA(lo_evidence) = CAST zif_cd_hck_evidence(
                                zcl_cd_ops_factory=>get_plugin( iv_class_name = <ls_group>-evidence_class
                                                                iv_interface  = zif_cd_hck_runtime_types=>gc_evidence_intf ) ).
          DATA(ls_result) = lo_evidence->collect( it_payments = lt_need
                                                  is_rule     = ls_rule
                                                  iv_max_rows = mv_cap ).
          <ls_group>-evidence = ls_result-evidence.
          IF ls_result-capped = abap_true.
            capped( ls_result-source ).
          ENDIF.
          IF ls_result-unconfigured = abap_true.
            <ls_group>-unconfigured = abap_true.
            " Mandatory rows: the purpose cannot be determined (warning); informational rows: skipped
            IF mandatory_use( <ls_group> ) = abap_true.
              config_finding( EXPORTING iv_object   = |{ <ls_group>-evidence_class }/{ <ls_group>-param1 }|
                                        iv_severity = zif_cd_ops_types=>gc_severity-warning
                                        iv_message  = zcl_cd_ops_util=>text(
                                                        iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_mandatory
                                                        iv_v1    = <ls_group>-evidence_class
                                                        iv_v2    = <ls_group>-param1 )
                              CHANGING  ct_findings = mt_findings ).
            ELSE.
              config_finding( EXPORTING iv_object   = |{ <ls_group>-evidence_class }/{ <ls_group>-param1 }|
                                        iv_message  = zcl_cd_ops_util=>text(
                                                        iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_unconfig
                                                        iv_v1    = <ls_group>-evidence_class
                                                        iv_v2    = <ls_group>-param1 )
                              CHANGING  ct_findings = mt_findings ).
            ENDIF.
          ENDIF.
        CATCH cx_root INTO DATA(lx_error).
          " Fail closed: the purposes of these rows are not judged (a payment stays in flight)
          <ls_group>-invalid = abap_true.
          config_finding( EXPORTING iv_object   = |{ <ls_group>-evidence_class }/{ <ls_group>-param1 }|
                                    iv_severity = zif_cd_ops_types=>gc_severity-error
                                    iv_code     = zif_cd_hck_runtime_types=>gc_code-clrrule_invalid
                                    iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-rule_invalid
                                                                         iv_v1    = <ls_group>-evidence_class
                                                                         iv_v2    = <ls_group>-param1
                                                                         iv_tail  = lx_error->get_text( ) )
                          CHANGING  ct_findings = mt_findings ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD decide.
    DATA lt_held TYPE string_table.
    DATA lt_missing TYPE string_table.
    DATA lt_forbidden TYPE string_table.
    DATA lt_info TYPE string_table.
    DATA lt_unusable TYPE string_table.
    DATA ls_group TYPE ty_group.
    DATA ls_evidence TYPE zif_cd_hck_runtime_types=>ty_evidence.
    rs_verdict = VALUE #( doc1r   = is_payment-doc1r
                          laufd   = is_payment-laufd
                          laufi   = is_payment-laufi
                          bukrs   = is_payment-bukrs
                          flow    = is_payment-flow
                          class   = is_payment-class
                          status  = zif_cd_ops_payout_types=>gc_status-open
                          outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).

    " Anomalies of any evidence of the payment's rules are listed under their own code
    list_anomalies( EXPORTING is_payment = is_payment
                    CHANGING  cs_verdict = rs_verdict ).

    " Purposes in order: the first one with evidence decides
    LOOP AT purposes( ) ASSIGNING FIELD-SYMBOL(<lv_purpose>).
      CLEAR: lt_held, lt_missing, lt_forbidden, lt_info, lt_unusable.
      DATA(lv_indicated) = abap_false.
      DATA(lv_rows) = 0.
      DATA(lv_indicator_unusable) = abap_false.
      DATA(lv_first_kind) = VALUE zif_cd_ops_types=>ty_class_name( ).
      DATA(lv_first_ref) = ``.
      DATA(lv_unusable_kind) = VALUE zif_cd_ops_types=>ty_class_name( ).
      LOOP AT ms_config-rules ASSIGNING FIELD-SYMBOL(<ls_rule>)
           WHERE flow = is_payment-flow AND method_class = is_payment-class AND purpose = <lv_purpose>.
        ls_group = group_of( <ls_rule> ).
        IF ls_group-unconfigured = abap_true OR ls_group-invalid = abap_true.
          " Only an informational row may be skipped; a mandatory one cannot be evaluated
          IF is_mandatory( <ls_rule>-required ) = abap_false.
            CONTINUE.
          ENDIF.
          INSERT zcl_cd_ops_util=>text( iv_msgno = COND #( WHEN ls_group-invalid = abap_true
                                                           THEN zif_cd_hck_runtime_types=>gc_msg-unusable_invalid
                                                           ELSE zif_cd_hck_runtime_types=>gc_msg-unusable_unconfig )
                                        iv_v1    = label( <ls_rule> ) ) INTO TABLE lt_unusable.
          IF lv_unusable_kind IS INITIAL.
            lv_unusable_kind = ls_group-evidence_class.
          ENDIF.
          IF <ls_rule>-required = zif_cd_hck_runtime_types=>gc_required-must_hold.
            lv_indicator_unusable = abap_true.
          ENDIF.
          CONTINUE.
        ENDIF.
        lv_rows = lv_rows + 1.
        ls_evidence = VALUE #( ls_group-evidence[ doc1r = is_payment-doc1r ] OPTIONAL ).
        DATA(lv_text) = COND string( WHEN ls_evidence-detail IS INITIAL THEN label( <ls_rule> )
                                     ELSE |{ label( <ls_rule> ) }: { ls_evidence-detail }| ).
        CASE <ls_rule>-required.
          WHEN zif_cd_hck_runtime_types=>gc_required-must_hold.
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_held.
              lv_indicated = abap_true.
              IF lv_first_kind IS INITIAL.
                lv_first_kind = ls_group-evidence_class.
                lv_first_ref  = lv_text.
              ENDIF.
            ELSE.
              INSERT lv_text INTO TABLE lt_missing.
            ENDIF.
          WHEN zif_cd_hck_runtime_types=>gc_required-condition.
            " A condition must hold but never indicates the purpose on its own
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_held.
            ELSE.
              INSERT lv_text INTO TABLE lt_missing.
            ENDIF.
          WHEN zif_cd_hck_runtime_types=>gc_required-must_not_hold.
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_forbidden.
            ENDIF.
          WHEN OTHERS.
            IF ls_evidence-found = abap_true.
              INSERT lv_text INTO TABLE lt_info.
            ENDIF.
        ENDCASE.
      ENDLOOP.
      " Fail closed: an indicator that cannot be read, or an indicated purpose whose mandatory
      " corroboration / exclusion cannot be read, is undetermined - no positive conclusion, no later
      " purpose decides, the payment stays in flight (aged) and is listed
      IF lv_indicator_unusable = abap_true OR ( lv_indicated = abap_true AND lt_unusable IS NOT INITIAL ).
        list( EXPORTING is_payment = is_payment
                        is_listing = VALUE #( code     = zif_cd_hck_runtime_types=>gc_code-undetermined
                                              severity = zif_cd_ops_types=>gc_severity-warning
                                              line     = payment_line(
                                                           is_payment = is_payment
                                                           iv_what    = <lv_purpose>
                                                           iv_tail    = zcl_cd_ops_util=>text(
                                                                          iv_msgno = zif_cd_hck_runtime_types=>gc_msg-undetermined
                                                                          iv_tail  = concat_lines_of( table = lt_unusable
                                                                                                      sep   = ` | ` ) ) ) )
              CHANGING  cs_verdict = rs_verdict ).
        rs_verdict-purpose = <lv_purpose>.
        IF rs_verdict-status = zif_cd_ops_payout_types=>gc_status-open.
          rs_verdict-outcome       = zif_cd_ops_payout_types=>gc_outcome-undetermined.
          rs_verdict-evidence_kind = lv_unusable_kind.
          rs_verdict-evidence_ref  = concat_lines_of( table = lt_unusable sep = ` | ` ).
        ENDIF.
        RETURN.
      ENDIF.
      " No evidence = next purpose
      IF lv_rows = 0 OR lv_indicated = abap_false.
        CONTINUE.
      ENDIF.
      rs_verdict-purpose = <lv_purpose>.
      IF lt_missing IS INITIAL AND lt_forbidden IS INITIAL.
        IF rs_verdict-status = zif_cd_ops_payout_types=>gc_status-open.
          rs_verdict-evidence_kind = lv_first_kind.
          rs_verdict-evidence_ref  = lv_first_ref.
          " A consistent state in flight stays in flight (aged); other purposes exclude
          IF <lv_purpose> <> zif_cd_hck_runtime_types=>gc_purpose-in_flight.
            rs_verdict-status  = zif_cd_ops_payout_types=>gc_status-excluded.
            rs_verdict-outcome = outcome_of( <lv_purpose> ).
          ENDIF.
        ENDIF.
        RETURN.
      ENDIF.
      " Some but not all: the finding names what held, what is missing and what must not hold
      DATA(lv_tail) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_held
                                             iv_tail  = concat_lines_of( table = lt_held sep = ` | ` ) ).
      IF lt_missing IS NOT INITIAL.
        lv_tail = |{ lv_tail } { zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_missing
                                                        iv_tail  = concat_lines_of( table = lt_missing sep = ` | ` ) ) }|.
      ENDIF.
      IF lt_forbidden IS NOT INITIAL.
        lv_tail = |{ lv_tail } { zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_forbidden
                                                        iv_tail  = concat_lines_of( table = lt_forbidden sep = ` | ` ) ) }|.
      ENDIF.
      IF lt_info IS NOT INITIAL.
        lv_tail = |{ lv_tail } { zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_info
                                                        iv_tail  = concat_lines_of( table = lt_info sep = ` | ` ) ) }|.
      ENDIF.
      IF rs_verdict-evidence_kind IS INITIAL.
        rs_verdict-evidence_kind = lv_first_kind.
        rs_verdict-evidence_ref  = lv_first_ref.
      ENDIF.
      list( EXPORTING is_payment = is_payment
                      is_listing = VALUE #( code     = COND #( WHEN <lv_purpose> = zif_cd_hck_runtime_types=>gc_purpose-returned
                                                               THEN zif_cd_hck_runtime_types=>gc_code-return_inconsist
                                                               ELSE zif_cd_hck_runtime_types=>gc_code-clearing_inconsist )
                                            severity = zif_cd_ops_types=>gc_severity-error
                                            line     = payment_line( is_payment = is_payment
                                                                     iv_what    = <lv_purpose>
                                                                     iv_tail    = lv_tail ) )
            CHANGING  cs_verdict = rs_verdict ).
      rs_verdict-status  = zif_cd_ops_payout_types=>gc_status-inconsistent.
      rs_verdict-outcome = zif_cd_ops_payout_types=>gc_outcome-inconsistent.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD list_anomalies.
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT ms_config-rules ASSIGNING FIELD-SYMBOL(<ls_rule>)
         WHERE flow = is_payment-flow AND method_class = is_payment-class.
      DATA(ls_group) = group_of( <ls_rule> ).
      INSERT |{ ls_group-evidence_class }/{ ls_group-param1 }/{ ls_group-param2 }/{ ls_group-param3 }|
        INTO TABLE lt_seen.
      IF sy-subrc <> 0 OR ls_group-invalid = abap_true OR ls_group-unconfigured = abap_true.
        CONTINUE.
      ENDIF.
      DATA(ls_evidence) = VALUE #( ls_group-evidence[ doc1r = is_payment-doc1r ] OPTIONAL ).
      IF ls_evidence-anomaly IS INITIAL.
        CONTINUE.
      ENDIF.
      " Every anomaly of the evidence, the primary one first; one kind used by several purposes
      " reports each anomaly once per payment and code
      DATA(lt_anomalies) = VALUE zif_cd_hck_runtime_types=>tt_anomaly(
                             ( code = ls_evidence-anomaly severity = ls_evidence-severity detail = ls_evidence-detail ) ).
      INSERT LINES OF ls_evidence-more INTO TABLE lt_anomalies.
      LOOP AT lt_anomalies ASSIGNING FIELD-SYMBOL(<ls_anomaly>).
        IF line_exists( mt_listed[ doc1r = is_payment-doc1r code = <ls_anomaly>-code ] ).
          CONTINUE.
        ENDIF.
        list( EXPORTING is_payment = is_payment
                        is_listing = VALUE #( code     = <ls_anomaly>-code
                                              severity = <ls_anomaly>-severity
                                              line     = payment_line(
                                                           is_payment = is_payment
                                                           iv_what    = <ls_anomaly>-code
                                                           iv_tail    = zcl_cd_ops_util=>text(
                                                                          iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_anomaly
                                                                          iv_v1    = label( <ls_rule> )
                                                                          iv_tail  = <ls_anomaly>-detail ) ) )
              CHANGING  cs_verdict = cs_verdict ).
        IF cs_verdict-evidence_kind IS INITIAL.
          cs_verdict-evidence_kind = ls_group-evidence_class.
          cs_verdict-evidence_ref  = <ls_anomaly>-detail.
        ENDIF.
      ENDLOOP.
      cs_verdict-status  = zif_cd_ops_payout_types=>gc_status-inconsistent.
      cs_verdict-outcome = zif_cd_ops_payout_types=>gc_outcome-inconsistent.
    ENDLOOP.
  ENDMETHOD.


  METHOD list.
    INSERT is_listing INTO TABLE cs_verdict-listings.
    INSERT VALUE #( doc1r = is_payment-doc1r code = is_listing-code ) INTO TABLE mt_listed.
    " The primary finding of the payment: the first listing (anomalies come before the purpose)
    IF cs_verdict-finding IS INITIAL.
      cs_verdict-finding  = is_listing-code.
      cs_verdict-severity = is_listing-severity.
    ENDIF.
  ENDMETHOD.


  METHOD group_of.
    rs_group = VALUE #( mt_groups[ evidence_class = to_upper( condense( is_rule-evidence_class ) )
                                   param1         = is_rule-param1
                                   param2         = is_rule-param2
                                   param3         = is_rule-param3 ] OPTIONAL ).
  ENDMETHOD.


  METHOD capped.
    IF line_exists( mt_findings[ object_key = |{ mv_context }/{ iv_table }| ] ).
      RETURN.
    ENDIF.
    INSERT VALUE #( object_key = |{ mv_context }/{ iv_table }|
                    check_code = zif_cd_hck_runtime_types=>gc_code-read_capped
                    severity   = zif_cd_ops_types=>gc_severity-warning
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                        iv_v1    = iv_table
                                                        iv_v2    = mv_cap
                                                        iv_v3    = mv_context ) ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD config_finding.
    INSERT VALUE #( object_key = |{ mv_context }/{ iv_code }/{ iv_object }|
                    check_code = iv_code
                    severity   = iv_severity
                    action     = zif_cd_ops_types=>gc_action-notify
                    message    = iv_message ) INTO TABLE ct_findings.
  ENDMETHOD.


  METHOD mandatory_use.
    LOOP AT ms_config-rules ASSIGNING FIELD-SYMBOL(<ls_rule>)
         WHERE param1 = is_group-param1 AND param2 = is_group-param2 AND param3 = is_group-param3.
      IF to_upper( condense( <ls_rule>-evidence_class ) ) = is_group-evidence_class
         AND is_mandatory( <ls_rule>-required ) = abap_true.
        rv_yes = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD is_mandatory.
    rv_yes = xsdbool( iv_required = zif_cd_hck_runtime_types=>gc_required-must_hold
                      OR iv_required = zif_cd_hck_runtime_types=>gc_required-condition
                      OR iv_required = zif_cd_hck_runtime_types=>gc_required-must_not_hold ).
  ENDMETHOD.


  METHOD label.
    rv_text = |{ is_rule-seq } { COND string( WHEN is_rule-description IS NOT INITIAL THEN is_rule-description
                                              ELSE is_rule-evidence_class ) }|.
  ENDMETHOD.


  METHOD payment_line.
    rv_line = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-evidence_line
                                     iv_v1    = is_payment-doc1r
                                     iv_v2    = is_payment-pymet
                                     iv_v3    = |{ is_payment-laufd DATE = ISO }|
                                     iv_v4    = iv_what
                                     iv_tail  = iv_tail ).
  ENDMETHOD.


  METHOD outcome_of.
    rv_outcome = SWITCH #( iv_purpose
                           WHEN zif_cd_hck_runtime_types=>gc_purpose-voided    THEN zif_cd_ops_payout_types=>gc_outcome-voided
                           WHEN zif_cd_hck_runtime_types=>gc_purpose-returned  THEN zif_cd_ops_payout_types=>gc_outcome-returned
                           WHEN zif_cd_hck_runtime_types=>gc_purpose-retrieved THEN zif_cd_ops_payout_types=>gc_outcome-retrieved
                           WHEN zif_cd_hck_runtime_types=>gc_purpose-pending   THEN zif_cd_ops_payout_types=>gc_outcome-pending
                           WHEN zif_cd_hck_runtime_types=>gc_purpose-cleared   THEN zif_cd_ops_payout_types=>gc_outcome-cleared
                           ELSE zif_cd_ops_payout_types=>gc_outcome-in_flight ).
  ENDMETHOD.

ENDCLASS.
