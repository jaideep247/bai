*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_recon3.clas.abap
*& Purpose:
*& Financial integrity: three-way reconciliation bank <-> G/L transit /
*& clearing account <-> payment engine per company code, clearing account,
*& currency and day (sets in ZCD_HCK_RCSET, bank code roles in
*& posting area ZBTR RECON), the Stripe descriptor group (charges + fees = BAI
*& deposit) and the one-to-one ACH clearing by assignment. Reads every leg
*& aggregated (ZIF_CD_HCK_RECON_DAO), judges with the pure rules of
*& ZCL_CD_HCK_RECON_EVAL and stores only results: the difference per group
*& and day plus bucket and status counts as metrics (ZCD_HCK_METRIC), the
*& breaks, timing and variances as findings with amount and detail. Writes
*& nothing itself (the engine persists), reads no business table directly.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*& 2026-11-08 | Table consolidation: bank code roles of the sets from ZCD_HCK_BTCROLE usage RECON (was
*&            | ZCD_HCK_RCBTC).
*& 2026-11-08 | Customer posting area: the roles of the sets are ZBTR entries (was ZCD_HCK_BTCROLE) - comments only.
*& 2026-11-10 | Deterministic evidence: every group-day with data records bank, G/L and payment engine legs,
*&            | the differences and the tolerance used with its source (RC_TOLERANCE_SET / _PARAM), balanced
*&            | days included; findings carry expected / actual / difference / tolerance / source (838).
*&            | TOLERANCE_SET = X makes the set tolerance count even at 0.00 (exact match).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - three-way reconciliation bank/G/L/subledger</p>
"! Window: report date - 1 back HCK_RECON_LOOKBACK_DAYS days. Tolerance per set (else
"! HCK_RECON_TOLERANCE). Timing (statement or transfer of a later day) and cut-off are listed as
"! information, a pending redeposit (468 without returns lot, HCK_RECON_REDEPOSIT_DAYS) too;
"! cheque, unmapped-code and other variances are warnings; what no bucket explains is a break.
"! No evidence at all: evidence NONE, the engine shows the check grey - never green.
CLASS zcl_cd_hck_c_recon3 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_set_work,
        set       TYPE zif_cd_hck_recon_types=>ty_set,
        group     TYPE zif_cd_hck_recon_types=>ty_group,
        accounts  TYPE zif_cd_hck_recon_types=>tt_account,
        gl_key    TYPE zif_cd_hck_recon_types=>ty_gl_key,
        tolerance TYPE zif_cd_hck_recon_types=>ty_amount,
        "! SET or PARAMETER (deterministic verification: the tolerance used and where it came from)
        tol_source TYPE string,
      END OF ty_set_work.
    TYPES tt_set_work TYPE STANDARD TABLE OF ty_set_work WITH EMPTY KEY.

    "! Group days per status / bucket of one set (RC_DAYS, RC_BUCKET)
    TYPES:
      BEGIN OF ty_count,
        name  TYPE zif_cd_hck_recon_types=>ty_status,
        count TYPE i,
      END OF ty_count.
    TYPES tt_count TYPE SORTED TABLE OF ty_count WITH UNIQUE KEY name.

    "! Batch reads of the THREEWAY / ACH sets (one statement per leg for all sets)
    TYPES:
      BEGIN OF ty_legs,
        bank_days   TYPE zif_cd_hck_recon_types=>tt_bank_day,
        bank_last   TYPE zif_cd_hck_recon_types=>tt_bank_last,
        bank_no_lot TYPE zif_cd_hck_recon_types=>tt_bank_day,
        gl_days     TYPE zif_cd_hck_recon_types=>tt_gl_day,
        fica_days   TYPE zif_cd_hck_recon_types=>tt_fica_day,
        pay_days    TYPE zif_cd_hck_recon_types=>tt_pay_day,
      END OF ty_legs.

    DATA mo_dao TYPE REF TO zif_cd_hck_recon_dao.
    DATA mo_eval TYPE REF TO zcl_cd_hck_recon_eval.
    "! Input template: window, parameters, sign conventions (set and legs added per set)
    DATA ms_base TYPE zif_cd_hck_recon_types=>ty_eval_input.
    DATA mv_check_id TYPE zif_cd_hck_types=>ty_check_id.
    DATA mv_ledger TYPE zif_cd_hck_recon_types=>ty_ledger.
    DATA mv_lookback TYPE i.
    DATA mv_max_rows TYPE i.
    DATA mt_roles TYPE zif_cd_hck_recon_types=>tt_btc_role.
    DATA ms_result TYPE zif_cd_hck_types=>ty_check_result.
    DATA mv_sets_with_data TYPE i.
    DATA mv_incomplete TYPE abap_bool.
    DATA mv_days TYPE i.
    DATA mv_breaks TYPE i.
    DATA mv_timing TYPE i.
    DATA mv_variance TYPE i.

    METHODS read_parameters
      IMPORTING
        is_context TYPE zif_cd_hck_types=>ty_context.

    "! Sets with their payment engine accounts (ZCD_EBS_ACCT); a set that cannot be evaluated
    "! (no active account, duplicate group, Stripe without deposit code) is RECON_CONFIG
    METHODS prepare_sets
      IMPORTING
        it_sets        TYPE zif_cd_hck_recon_types=>tt_set
      RETURNING
        VALUE(rt_work) TYPE tt_set_work.

    METHODS read_legs
      IMPORTING
        it_work        TYPE tt_set_work
      RETURNING
        VALUE(rs_legs) TYPE ty_legs.

    METHODS check_threeway
      IMPORTING
        is_work TYPE ty_set_work
        is_legs TYPE ty_legs.

    METHODS check_stripe
      IMPORTING
        is_work TYPE ty_set_work.

    METHODS check_ach
      IMPORTING
        is_work TYPE ty_set_work.

    METHODS day_findings
      IMPORTING
        is_work TYPE ty_set_work
        is_day  TYPE zif_cd_hck_recon_types=>ty_group_day.

    METHODS count_up
      IMPORTING
        iv_name   TYPE clike
      CHANGING
        ct_counts TYPE tt_count.

    METHODS set_input
      IMPORTING
        is_work         TYPE ty_set_work
      RETURNING
        VALUE(rs_input) TYPE zif_cd_hck_recon_types=>ty_eval_input.

    METHODS codes_of_role
      IMPORTING
        iv_set_id       TYPE zif_cd_hck_recon_types=>ty_set_id
        iv_role         TYPE zif_cd_hck_recon_types=>ty_role
      RETURNING
        VALUE(rt_codes) TYPE zif_cd_hck_recon_types=>tt_btc.

    METHODS group_key
      IMPORTING
        is_set          TYPE zif_cd_hck_recon_types=>ty_set
      RETURNING
        VALUE(rv_group) TYPE zif_cd_hck_recon_types=>ty_group.

    METHODS add_metric
      IMPORTING
        iv_metric TYPE zif_cd_hck_types=>ty_metric_name
        iv_dim1   TYPE clike
        iv_dim2   TYPE clike
        iv_value  TYPE zif_cd_hck_types=>ty_value
        iv_kind   TYPE zif_cd_hck_types=>ty_metric_kind DEFAULT zif_cd_hck_types=>gc_metric_kind-volume.

    METHODS add_finding
      IMPORTING
        is_work     TYPE ty_set_work
        iv_key      TYPE clike
        iv_code     TYPE zif_ca_ops_types=>ty_check_code
        iv_severity TYPE zif_ca_ops_types=>ty_severity
        iv_amount   TYPE zif_cd_hck_recon_types=>ty_amount OPTIONAL
        iv_message  TYPE string
        iv_details  TYPE string OPTIONAL.

    METHODS day_text
      IMPORTING
        iv_day         TYPE d
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS bucket_list
      IMPORTING
        it_buckets     TYPE zif_cd_hck_recon_types=>tt_bucket
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_hck_c_recon3 IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    CLEAR: ms_result, mv_sets_with_data, mv_incomplete, mv_days, mv_breaks, mv_timing, mv_variance.
    mv_check_id = COND #( WHEN is_def-check_id IS INITIAL THEN zif_cd_hck_recon_types=>gc_check_id
                          ELSE is_def-check_id ).
    read_parameters( is_context ).
    mo_dao  = zcl_cd_hck_factory=>get_recon_dao( ).
    mo_eval = NEW #( ).
    mt_roles = mo_dao->get_btc_roles( ).

    DATA(lt_work) = prepare_sets( mo_dao->get_sets( ) ).
    DATA(ls_legs) = read_legs( lt_work ).
    LOOP AT lt_work ASSIGNING FIELD-SYMBOL(<ls_work>).
      CASE <ls_work>-set-kind.
        WHEN zif_cd_hck_recon_types=>gc_kind-stripe.
          check_stripe( <ls_work> ).
        WHEN zif_cd_hck_recon_types=>gc_kind-ach_zuonr.
          check_threeway( is_work = <ls_work> is_legs = ls_legs ).
          check_ach( <ls_work> ).
        WHEN OTHERS.
          check_threeway( is_work = <ls_work> is_legs = ls_legs ).
      ENDCASE.
    ENDLOOP.

    add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-breaks
                iv_dim1   = zif_cd_hck_types=>gc_default_key
                iv_dim2   = space
                iv_value  = mv_breaks
                iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
    " Nothing to reconcile is not evidence of health: the engine shows the check grey
    ms_result-evidence = COND #( WHEN mv_sets_with_data = 0 THEN zif_cd_hck_types=>gc_evidence-none
                                 WHEN mv_incomplete = abap_true OR mv_sets_with_data < lines( lt_work )
                                 THEN zif_cd_hck_types=>gc_evidence-partial ).
    ms_result-summary = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-summary
                                               iv_v1    = mv_days
                                               iv_v2    = mv_breaks
                                               iv_v3    = mv_timing
                                               iv_v4    = mv_variance ).
    rs_result = ms_result.
  ENDMETHOD.


  METHOD read_parameters.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    mv_lookback = nmax( val1 = 1
                        val2 = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                           iv_name    = zif_cd_hck_recon_types=>gc_param-lookback_days
                                                           iv_default = zif_cd_hck_recon_types=>gc_param_default-lookback_days ) ).
    mv_max_rows = zcl_cd_hck_param=>row_cap( iv_name    = zif_cd_hck_recon_types=>gc_param-max_rows
                                             iv_default = zif_cd_hck_recon_types=>gc_param_default-max_rows
                                             iv_ceiling = zif_cd_hck_recon_types=>gc_max_rows ).
    CLEAR ms_base.
    ms_base-report_date    = is_context-report_date.
    ms_base-to             = is_context-report_date - 1.
    ms_base-from           = ms_base-to - mv_lookback + 1.
    DATA(lv_timing) = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                  iv_name    = zif_cd_hck_recon_types=>gc_param-timing_days
                                                  iv_default = zif_cd_hck_recon_types=>gc_param_default-timing_days ).
    DATA(lv_redeposit) = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                     iv_name    = zif_cd_hck_recon_types=>gc_param-redeposit_days
                                                     iv_default = zif_cd_hck_recon_types=>gc_param_default-redeposit_days ).
    ms_base-timing_days    = nmax( val1 = 0 val2 = lv_timing ).
    ms_base-redeposit_days = nmax( val1 = 0 val2 = lv_redeposit ).
    ms_base-tolerance = abs( zcl_ca_ops_util=>to_decimal(
                               lo_params->get_param( iv_name    = zif_cd_hck_recon_types=>gc_param-tolerance
                                                     iv_default = zif_cd_hck_recon_types=>gc_param_default-tolerance ) ) ).
    " Facts owned by other areas, read through their definitions (one source each)
    ms_base-credit_ind = lo_params->get_param( iv_name    = zif_cd_ebs_types=>gc_param-feb_credit_ind
                                               iv_default = zif_cd_ebs_types=>gc_param_default-feb_credit_ind ).
    ms_base-debit_ind  = lo_params->get_param( iv_name    = zif_cd_ebs_types=>gc_param-feb_debit_ind
                                               iv_default = zif_cd_ebs_types=>gc_param_default-feb_debit_ind ).
    ms_base-fica_awtyp = lo_params->get_param( iv_name    = zif_cd_ops_trace_types=>gc_param-gl_awtyp
                                               iv_default = zif_cd_ops_trace_types=>gc_default-gl_awtyp ).
    mv_ledger          = lo_params->get_param( iv_name    = zif_cd_ebs_types=>gc_param-gl_ledger
                                               iv_default = zif_cd_ebs_types=>gc_param_default-gl_ledger ).
  ENDMETHOD.


  METHOD prepare_sets.
    DATA lt_groups TYPE SORTED TABLE OF zif_cd_hck_recon_types=>ty_group WITH UNIQUE KEY table_line.
    DATA(lt_accounts) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_accounts( ).

    LOOP AT it_sets ASSIGNING FIELD-SYMBOL(<ls_set>).
      DATA(ls_work) = VALUE ty_set_work( set = <ls_set> ).
      ls_work-set-hkont = |{ <ls_set>-hkont ALPHA = IN }|.
      ls_work-group     = group_key( ls_work-set ).
      ls_work-gl_key    = VALUE #( bukrs = ls_work-set-bukrs hkont = ls_work-set-hkont currency = ls_work-set-waers ).
      " A maintained set tolerance wins - with the flag also 0.00 (exact match); without the flag a
      " value above 0 counts as maintained (rows before 2026-11-10), else the parameter applies
      IF <ls_set>-tolerance_set = abap_true OR <ls_set>-tolerance > 0.
        ls_work-tolerance  = abs( <ls_set>-tolerance ).
        ls_work-tol_source = zif_cd_hck_recon_types=>gc_tolerance_source-set.
      ELSE.
        ls_work-tolerance  = ms_base-tolerance.
        ls_work-tol_source = zif_cd_hck_recon_types=>gc_tolerance_source-parameter.
      ENDIF.
      " The XBLNR account of the house bank account, as the EBS scope (ZCD_EBS_ACCT, active)
      LOOP AT lt_accounts ASSIGNING FIELD-SYMBOL(<ls_account>)
           WHERE active = abap_true AND bukrs = <ls_set>-bukrs AND hbkid = <ls_set>-hbkid AND hktid = <ls_set>-hktid.
        DATA(lv_account) = CONV zif_cd_hck_recon_types=>ty_account( to_upper( condense( <ls_account>-account_no ) ) ).
        IF lv_account IS NOT INITIAL AND NOT line_exists( ls_work-accounts[ table_line = lv_account ] ).
          INSERT lv_account INTO TABLE ls_work-accounts.
        ENDIF.
      ENDLOOP.

      DATA(lv_reason) = VALUE zif_cd_hck_recon_types=>ty_status( ).
      IF line_exists( lt_groups[ table_line = ls_work-group ] ).
        lv_reason = zif_cd_hck_recon_types=>gc_config_reason-duplicate.
      ELSEIF ls_work-accounts IS INITIAL
             AND ( <ls_set>-leg_bank = abap_true OR <ls_set>-kind = zif_cd_hck_recon_types=>gc_kind-stripe ).
        lv_reason = zif_cd_hck_recon_types=>gc_config_reason-no_account.
      ELSEIF <ls_set>-kind = zif_cd_hck_recon_types=>gc_kind-stripe
             AND codes_of_role( iv_set_id = <ls_set>-set_id
                                iv_role   = zif_cd_hck_recon_types=>gc_role-deposit ) IS INITIAL.
        lv_reason = zif_cd_hck_recon_types=>gc_config_reason-no_deposit.
      ENDIF.
      IF lv_reason IS NOT INITIAL.
        mv_incomplete = abap_true.
        add_finding( is_work     = ls_work
                     iv_key      = |{ ls_work-group }{ zif_cd_hck_recon_types=>gc_key_sep }{ <ls_set>-set_id }|
                     iv_code     = zif_cd_hck_recon_types=>gc_code-recon_config
                     iv_severity = zif_ca_ops_types=>gc_severity-warning
                     iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-set_not_used
                                                          iv_v1    = <ls_set>-set_id
                                                          iv_v2    = lv_reason ) ).
        CONTINUE.
      ENDIF.
      INSERT ls_work-group INTO TABLE lt_groups.
      INSERT ls_work INTO TABLE rt_work.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_legs.
    DATA lt_accounts TYPE zif_cd_hck_recon_types=>tt_account.
    DATA lt_redeposit TYPE zif_cd_hck_recon_types=>tt_btc.
    DATA lt_keys TYPE zif_cd_hck_recon_types=>tt_gl_key.
    DATA lt_fica_keys TYPE zif_cd_hck_recon_types=>tt_gl_key.
    DATA lt_banks TYPE zif_cd_hck_recon_types=>tt_bank_key.

    LOOP AT it_work ASSIGNING FIELD-SYMBOL(<ls_work>)
         WHERE set-kind <> zif_cd_hck_recon_types=>gc_kind-stripe.
      INSERT <ls_work>-gl_key INTO TABLE lt_keys.
      IF <ls_work>-set-leg_fica = abap_true.
        INSERT <ls_work>-gl_key INTO TABLE lt_fica_keys.
        IF <ls_work>-set-hbkid IS NOT INITIAL.
          INSERT VALUE #( bukrs    = <ls_work>-set-bukrs
                          hbkid    = <ls_work>-set-hbkid
                          hktid    = <ls_work>-set-hktid
                          currency = <ls_work>-set-waers ) INTO TABLE lt_banks.
        ENDIF.
      ENDIF.
      IF <ls_work>-set-leg_bank = abap_true.
        INSERT LINES OF <ls_work>-accounts INTO TABLE lt_accounts.
        INSERT LINES OF codes_of_role( iv_set_id = <ls_work>-set-set_id
                                       iv_role   = zif_cd_hck_recon_types=>gc_role-redeposit ) INTO TABLE lt_redeposit.
      ENDIF.
    ENDLOOP.
    SORT lt_accounts BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_accounts COMPARING table_line.
    SORT lt_redeposit BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_redeposit COMPARING table_line.

    rs_legs-bank_days   = mo_dao->get_bank_days( it_accounts = lt_accounts
                                                 iv_from     = ms_base-from
                                                 iv_to       = ms_base-to ).
    " Statements loaded up to: lines up to the report date (the last day's statement arrives then)
    rs_legs-bank_last   = mo_dao->get_bank_last_days( it_accounts = lt_accounts
                                                      iv_from     = ms_base-from
                                                      iv_to       = ms_base-report_date ).
    rs_legs-bank_no_lot = mo_dao->get_bank_days_no_lot( it_accounts = lt_accounts
                                                        it_btcs     = lt_redeposit
                                                        iv_from     = ms_base-from
                                                        iv_to       = ms_base-to ).
    rs_legs-gl_days     = mo_dao->get_gl_days( it_keys   = lt_keys
                                               iv_ledger = mv_ledger
                                               iv_from   = ms_base-from
                                               iv_to     = ms_base-to ).
    rs_legs-fica_days   = mo_dao->get_fica_days( it_keys = lt_fica_keys
                                                 iv_from = ms_base-from
                                                 iv_to   = ms_base-to ).
    rs_legs-pay_days    = mo_dao->get_payment_days( it_banks = lt_banks
                                                    iv_from  = ms_base-from
                                                    iv_to    = ms_base-to ).
  ENDMETHOD.


  METHOD check_threeway.
    DATA lt_status_count TYPE tt_count.
    DATA lt_bucket_count TYPE tt_count.
    DATA(ls_input) = set_input( is_work ).

    LOOP AT is_legs-bank_last ASSIGNING FIELD-SYMBOL(<ls_last>).
      IF line_exists( is_work-accounts[ table_line = <ls_last>-account ] ) AND <ls_last>-last_day > ls_input-last_bank_day.
        ls_input-last_bank_day = <ls_last>-last_day.
      ENDIF.
    ENDLOOP.
    IF is_work-set-leg_bank = abap_true.
      " Lines of the set's payment engine account(s) in the set currency (other currencies: other sets)
      LOOP AT is_legs-bank_days ASSIGNING FIELD-SYMBOL(<ls_bank>) WHERE currency = is_work-set-waers.
        IF line_exists( is_work-accounts[ table_line = <ls_bank>-account ] ).
          INSERT <ls_bank> INTO TABLE ls_input-bank_days.
        ENDIF.
      ENDLOOP.
      LOOP AT is_legs-bank_no_lot ASSIGNING FIELD-SYMBOL(<ls_lot>) WHERE currency = is_work-set-waers.
        IF line_exists( is_work-accounts[ table_line = <ls_lot>-account ] ).
          INSERT <ls_lot> INTO TABLE ls_input-bank_no_lot.
        ENDIF.
      ENDLOOP.
    ENDIF.
    ls_input-gl_days = VALUE #( FOR ls_gl IN is_legs-gl_days
                                WHERE ( bukrs = is_work-gl_key-bukrs AND hkont = is_work-gl_key-hkont
                                        AND currency = is_work-gl_key-currency ) ( ls_gl ) ).
    IF is_work-set-leg_fica = abap_true.
      ls_input-fica_days = VALUE #( FOR ls_fica IN is_legs-fica_days
                                    WHERE ( bukrs = is_work-gl_key-bukrs AND hkont = is_work-gl_key-hkont
                                            AND currency = is_work-gl_key-currency ) ( ls_fica ) ).
      ls_input-pay_days = VALUE #( FOR ls_pay IN is_legs-pay_days
                                   WHERE ( bukrs = is_work-set-bukrs AND hbkid = is_work-set-hbkid
                                           AND hktid = is_work-set-hktid AND currency = is_work-set-waers ) ( ls_pay ) ).
    ENDIF.

    DATA(ls_eval) = mo_eval->evaluate( ls_input ).

    DATA(lv_with_data) = abap_false.
    LOOP AT ls_eval-days ASSIGNING FIELD-SYMBOL(<ls_day>).
      count_up( EXPORTING iv_name = <ls_day>-status CHANGING ct_counts = lt_status_count ).
      LOOP AT <ls_day>-buckets INTO DATA(lv_bucket).
        count_up( EXPORTING iv_name = lv_bucket CHANGING ct_counts = lt_bucket_count ).
      ENDLOOP.
      IF <ls_day>-status = zif_cd_hck_recon_types=>gc_status-empty.
        CONTINUE.
      ENDIF.
      lv_with_data = abap_true.
      mv_days = mv_days + 1.
      day_findings( is_work = is_work is_day = <ls_day> ).
    ENDLOOP.

    LOOP AT lt_status_count ASSIGNING FIELD-SYMBOL(<ls_status>).
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-days
                  iv_dim1   = is_work-group
                  iv_dim2   = <ls_status>-name
                  iv_value  = <ls_status>-count ).
    ENDLOOP.
    LOOP AT lt_bucket_count ASSIGNING FIELD-SYMBOL(<ls_bucket>).
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-bucket
                  iv_dim1   = is_work-group
                  iv_dim2   = <ls_bucket>-name
                  iv_value  = <ls_bucket>-count ).
    ENDLOOP.

    " New or unmapped bank codes: one warning per set naming the codes (ZBTR entry RECON needed)
    IF ls_eval-unmapped IS NOT INITIAL.
      DATA(lv_codes) = concat_lines_of( table = VALUE string_table( FOR ls_code IN ls_eval-unmapped
                                                                     ( condense( CONV string( ls_code-btc ) ) ) )
                                        sep   = zif_cd_hck_recon_types=>gc_list_sep ).
      mv_variance = mv_variance + 1.
      add_finding( is_work     = is_work
                   iv_key      = |{ is_work-group }{ zif_cd_hck_recon_types=>gc_key_sep }{ zif_cd_hck_recon_types=>gc_leg-unmapped }|
                   iv_code     = zif_cd_hck_recon_types=>gc_code-recon_variance
                   iv_severity = zif_ca_ops_types=>gc_severity-warning
                   iv_amount   = REDUCE #( INIT lv_sum = VALUE zif_cd_hck_recon_types=>ty_amount( )
                                           FOR ls_unmapped IN ls_eval-unmapped NEXT lv_sum = lv_sum + ls_unmapped-amount )
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-unmapped_codes
                                                        iv_v1    = is_work-group
                                                        iv_v2    = lv_codes )
                   iv_details  = lv_codes ).
    ENDIF.

    IF lv_with_data = abap_true.
      mv_sets_with_data = mv_sets_with_data + 1.
    ELSE.
      add_finding( is_work     = is_work
                   iv_key      = is_work-group
                   iv_code     = zif_cd_hck_recon_types=>gc_code-recon_no_data
                   iv_severity = zif_ca_ops_types=>gc_severity-info
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-no_data
                                                        iv_v1    = is_work-group
                                                        iv_v2    = day_text( ms_base-from )
                                                        iv_v3    = day_text( ms_base-to ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD day_findings.
    DATA(lv_day) = day_text( is_day-day ).
    DATA(lv_bank_key) = |{ is_work-group }{ zif_cd_hck_recon_types=>gc_key_sep }{ lv_day }|
                     && |{ zif_cd_hck_recon_types=>gc_key_sep }{ zif_cd_hck_recon_types=>gc_leg-bank }|.
    DATA(lv_fica_key) = |{ is_work-group }{ zif_cd_hck_recon_types=>gc_key_sep }{ lv_day }|
                     && |{ zif_cd_hck_recon_types=>gc_key_sep }{ zif_cd_hck_recon_types=>gc_leg-fica }|.
    DATA(lv_buckets) = bucket_list( is_day-buckets ).
    " Deterministic verification: expected, actual, difference, tolerance used and its source of
    " every group-day with data - balanced days included (metrics), and in every finding's details
    DATA(lv_bank_evidence) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-evidence
                                                    iv_v1    = |{ is_day-bank }|
                                                    iv_v2    = |{ is_day-gl_fica }|
                                                    iv_v3    = |{ is_day-diff_bank_gl }|
                                                    iv_v4    = |{ is_work-tolerance }|
                                                    iv_tail  = is_work-tol_source ).
    DATA(lv_fica_evidence) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-evidence
                                                    iv_v1    = |{ is_day-gl_fica }|
                                                    iv_v2    = |{ is_day-fica }|
                                                    iv_v3    = |{ is_day-diff_gl_fica }|
                                                    iv_v4    = |{ is_work-tolerance }|
                                                    iv_tail  = is_work-tol_source ).
    add_metric( iv_metric = COND #( WHEN is_work-tol_source = zif_cd_hck_recon_types=>gc_tolerance_source-set
                                    THEN zif_cd_hck_recon_types=>gc_metric-tol_set
                                    ELSE zif_cd_hck_recon_types=>gc_metric-tol_param )
                iv_dim1   = is_work-group
                iv_dim2   = lv_day
                iv_value  = is_work-tolerance
                iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).

    IF is_day-status <> zif_cd_hck_recon_types=>gc_status-none.
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-bank
                  iv_dim1   = is_work-group
                  iv_dim2   = lv_day
                  iv_value  = is_day-bank
                  iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-gl
                  iv_dim1   = is_work-group
                  iv_dim2   = lv_day
                  iv_value  = is_day-gl_fica
                  iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-diff_bank_gl
                  iv_dim1   = is_work-group
                  iv_dim2   = lv_day
                  iv_value  = is_day-diff_bank_gl
                  iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
    ENDIF.
    IF is_day-sub_status <> zif_cd_hck_recon_types=>gc_status-none.
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-fica
                  iv_dim1   = is_work-group
                  iv_dim2   = lv_day
                  iv_value  = is_day-fica
                  iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-diff_gl_fica
                  iv_dim1   = is_work-group
                  iv_dim2   = lv_day
                  iv_value  = is_day-diff_gl_fica
                  iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
    ENDIF.

    CASE is_day-status.
      WHEN zif_cd_hck_recon_types=>gc_status-break.
        mv_breaks = mv_breaks + 1.
        add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-unexplained
                    iv_dim1   = is_work-group
                    iv_dim2   = lv_day
                    iv_value  = is_day-residual
                    iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
        add_finding( is_work     = is_work
                     iv_key      = lv_bank_key
                     iv_code     = zif_cd_hck_recon_types=>gc_code-recon_break
                     iv_severity = zif_ca_ops_types=>gc_severity-error
                     iv_amount   = is_day-residual
                     iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-recon_break
                                                          iv_v1    = is_work-group
                                                          iv_v2    = lv_day
                                                          iv_v3    = |{ is_day-diff_bank_gl }|
                                                          iv_v4    = |{ is_day-residual }| )
                     iv_details  = |{ lv_bank_evidence }{ cl_abap_char_utilities=>newline }|
                                && |{ is_day-bank } { is_day-gl_fica } { is_day-gl_other } { lv_buckets }| ).
      WHEN zif_cd_hck_recon_types=>gc_status-timing.
        mv_timing = mv_timing + 1.
        add_finding( is_work     = is_work
                     iv_key      = lv_bank_key
                     iv_code     = zif_cd_hck_recon_types=>gc_code-recon_timing
                     iv_severity = zif_ca_ops_types=>gc_severity-info
                     iv_amount   = is_day-diff_bank_gl
                     iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-recon_timing
                                                          iv_v1    = is_work-group
                                                          iv_v2    = lv_day
                                                          iv_v3    = |{ is_day-diff_bank_gl }|
                                                          iv_v4    = lv_buckets )
                     iv_details  = lv_bank_evidence ).
      WHEN zif_cd_hck_recon_types=>gc_status-variance.
        mv_variance = mv_variance + 1.
        add_finding( is_work     = is_work
                     iv_key      = lv_bank_key
                     iv_code     = zif_cd_hck_recon_types=>gc_code-recon_variance
                     iv_severity = zif_ca_ops_types=>gc_severity-warning
                     iv_amount   = is_day-diff_bank_gl
                     iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-recon_variance
                                                          iv_v1    = is_work-group
                                                          iv_v2    = lv_day
                                                          iv_v3    = |{ is_day-diff_bank_gl }|
                                                          iv_v4    = lv_buckets )
                     iv_details  = lv_bank_evidence ).
    ENDCASE.

    CASE is_day-sub_status.
      WHEN zif_cd_hck_recon_types=>gc_status-break.
        mv_breaks = mv_breaks + 1.
        add_finding( is_work     = is_work
                     iv_key      = lv_fica_key
                     iv_code     = zif_cd_hck_recon_types=>gc_code-subledger_break
                     iv_severity = zif_ca_ops_types=>gc_severity-error
                     iv_amount   = is_day-diff_gl_fica
                     iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-subledger_break
                                                          iv_v1    = is_work-group
                                                          iv_v2    = lv_day
                                                          iv_v3    = |{ is_day-gl_fica }|
                                                          iv_v4    = |{ is_day-fica }| )
                     iv_details  = |{ lv_fica_evidence }{ cl_abap_char_utilities=>newline }{ is_day-payments }| ).
      WHEN zif_cd_hck_recon_types=>gc_status-timing.
        mv_timing = mv_timing + 1.
        add_finding( is_work     = is_work
                     iv_key      = lv_fica_key
                     iv_code     = zif_cd_hck_recon_types=>gc_code-recon_timing
                     iv_severity = zif_ca_ops_types=>gc_severity-info
                     iv_amount   = is_day-diff_gl_fica
                     iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-recon_timing
                                                          iv_v1    = is_work-group
                                                          iv_v2    = lv_day
                                                          iv_v3    = |{ is_day-diff_gl_fica }|
                                                          iv_v4    = zif_cd_hck_recon_types=>gc_bucket-timing )
                     iv_details  = lv_fica_evidence ).
    ENDCASE.
  ENDMETHOD.


  METHOD check_stripe.
    DATA lt_docs TYPE zif_cd_hck_recon_types=>tt_doc_key.
    DATA lt_descriptors TYPE zif_cd_hck_recon_types=>tt_zuonr.
    DATA(ls_input) = set_input( is_work ).

    DATA(lt_deposits) = mo_dao->get_deposits( it_accounts = is_work-accounts
                                              it_btcs     = codes_of_role( iv_set_id = is_work-set-set_id
                                                                           iv_role   = zif_cd_hck_recon_types=>gc_role-deposit )
                                              iv_from     = ms_base-from
                                              iv_to       = ms_base-to ).
    LOOP AT lt_deposits ASSIGNING FIELD-SYMBOL(<ls_deposit>) WHERE belnr IS NOT INITIAL.
      DATA(ls_doc) = VALUE zif_cd_hck_recon_types=>ty_doc_key( bukrs = <ls_deposit>-bukrs
                                                               belnr = <ls_deposit>-belnr
                                                               gjahr = <ls_deposit>-gjahr ).
      IF NOT line_exists( lt_docs[ bukrs = ls_doc-bukrs belnr = ls_doc-belnr gjahr = ls_doc-gjahr ] ).
        INSERT ls_doc INTO TABLE lt_docs.
      ENDIF.
    ENDLOOP.
    DATA(lt_doc_assign) = mo_dao->get_doc_assignments( it_docs   = lt_docs
                                                       iv_hkont  = is_work-set-hkont
                                                       iv_ledger = mv_ledger ).
    LOOP AT lt_doc_assign ASSIGNING FIELD-SYMBOL(<ls_assign>) WHERE zuonr IS NOT INITIAL.
      IF NOT line_exists( lt_descriptors[ table_line = <ls_assign>-zuonr ] ).
        INSERT <ls_assign>-zuonr INTO TABLE lt_descriptors.
      ENDIF.
    ENDLOOP.
    " Charges of a group are posted before its payout: read the descriptor back one window more
    DATA(lt_sums) = mo_dao->get_assignment_sums( is_key    = is_work-gl_key
                                                 it_zuonr  = lt_descriptors
                                                 iv_ledger = mv_ledger
                                                 iv_from   = CONV d( ms_base-from - mv_lookback )
                                                 iv_to     = ms_base-report_date ).

    DATA(lt_groups) = mo_eval->evaluate_stripe( is_input      = ls_input
                                                it_deposits   = lt_deposits
                                                it_doc_assign = lt_doc_assign
                                                it_group_sums = lt_sums ).
    IF lt_groups IS INITIAL.
      add_finding( is_work     = is_work
                   iv_key      = is_work-group
                   iv_code     = zif_cd_hck_recon_types=>gc_code-recon_no_data
                   iv_severity = zif_ca_ops_types=>gc_severity-info
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-no_data
                                                        iv_v1    = is_work-group
                                                        iv_v2    = day_text( ms_base-from )
                                                        iv_v3    = day_text( ms_base-to ) ) ).
      RETURN.
    ENDIF.
    mv_sets_with_data = mv_sets_with_data + 1.

    LOOP AT lt_groups ASSIGNING FIELD-SYMBOL(<ls_group>).
      mv_days = mv_days + 1.
      " The group: its descriptor; a deposit without one: its document, else its day
      DATA(lv_name) = COND string( WHEN <ls_group>-zuonr IS NOT INITIAL THEN condense( CONV string( <ls_group>-zuonr ) )
                                   WHEN <ls_group>-belnr IS NOT INITIAL THEN condense( CONV string( <ls_group>-belnr ) )
                                   ELSE day_text( <ls_group>-day ) ).
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-stripe_diff
                  iv_dim1   = is_work-group
                  iv_dim2   = lv_name
                  iv_value  = <ls_group>-difference
                  iv_kind   = zif_cd_hck_types=>gc_metric_kind-level ).
      DATA(lv_key) = |{ is_work-group }{ zif_cd_hck_recon_types=>gc_key_sep }{ lv_name }|
                  && |{ zif_cd_hck_recon_types=>gc_key_sep }{ zif_cd_hck_recon_types=>gc_leg-stripe }|.
      CASE <ls_group>-status.
        WHEN zif_cd_hck_recon_types=>gc_status-break.
          mv_breaks = mv_breaks + 1.
          add_finding( is_work     = is_work
                       iv_key      = lv_key
                       iv_code     = zif_cd_hck_recon_types=>gc_code-stripe_break
                       iv_severity = zif_ca_ops_types=>gc_severity-error
                       iv_amount   = <ls_group>-difference
                       iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-stripe_break
                                                            iv_v1    = lv_name
                                                            iv_v2    = |{ <ls_group>-charges }|
                                                            iv_v3    = |{ <ls_group>-fees }|
                                                            iv_v4    = |{ <ls_group>-deposit }| )
                       iv_details  = |{ day_text( <ls_group>-day ) } { <ls_group>-difference }| ).
        WHEN zif_cd_hck_recon_types=>gc_status-timing.
          mv_timing = mv_timing + 1.
          add_finding( is_work     = is_work
                       iv_key      = lv_key
                       iv_code     = zif_cd_hck_recon_types=>gc_code-recon_timing
                       iv_severity = zif_ca_ops_types=>gc_severity-info
                       iv_amount   = <ls_group>-difference
                       iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-recon_timing
                                                            iv_v1    = is_work-group
                                                            iv_v2    = day_text( <ls_group>-day )
                                                            iv_v3    = |{ <ls_group>-difference }|
                                                            iv_v4    = zif_cd_hck_recon_types=>gc_bucket-timing ) ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_ach.
    DATA(ls_input) = set_input( is_work ).
    " Read back the timing and redeposit days, so a pair that started before the window is complete
    DATA(lt_open) = mo_dao->get_open_assignments( is_key      = is_work-gl_key
                                                  iv_ledger   = mv_ledger
                                                  iv_from     = CONV d( ms_base-from - ms_base-timing_days
                                                                        - ms_base-redeposit_days )
                                                  iv_to       = ms_base-report_date
                                                  iv_max_rows = mv_max_rows ).
    IF lines( lt_open ) >= mv_max_rows.
      mv_incomplete = abap_true.
      ms_result-completion = zif_cd_hck_types=>gc_completion-partial.
      add_finding( is_work     = is_work
                   iv_key      = |{ is_work-group }{ zif_cd_hck_recon_types=>gc_key_sep }{ zif_cd_hck_recon_types=>gc_leg-ach }|
                   iv_code     = zif_cd_hck_runtime_types=>gc_code-read_capped
                   iv_severity = zif_ca_ops_types=>gc_severity-warning
                   iv_message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-read_capped
                                                        iv_v1    = zif_cd_hck_recon_types=>gc_param-max_rows
                                                        iv_v2    = mv_max_rows
                                                        iv_v3    = is_work-group ) ).
    ENDIF.

    LOOP AT mo_eval->evaluate_ach( is_input = ls_input it_open = lt_open ) ASSIGNING FIELD-SYMBOL(<ls_day>).
      DATA(lv_day) = day_text( <ls_day>-day ).
      add_metric( iv_metric = zif_cd_hck_recon_types=>gc_metric-ach_open
                  iv_dim1   = is_work-group
                  iv_dim2   = |{ lv_day }{ zif_cd_hck_recon_types=>gc_key_sep }{ <ls_day>-status }|
                  iv_value  = <ls_day>-group_count ).
      DATA(lv_message) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_recon_types=>gc_msg-ach_unmatched
                                                iv_v1    = is_work-group
                                                iv_v2    = <ls_day>-group_count
                                                iv_v3    = lv_day
                                                iv_v4    = |{ <ls_day>-amount }| ).
      DATA(lv_key) = |{ is_work-group }{ zif_cd_hck_recon_types=>gc_key_sep }{ lv_day }|
                  && |{ zif_cd_hck_recon_types=>gc_key_sep }{ zif_cd_hck_recon_types=>gc_leg-ach }|.
      IF <ls_day>-status = zif_cd_hck_recon_types=>gc_status-break.
        mv_breaks = mv_breaks + 1.
        add_finding( is_work     = is_work
                     iv_key      = lv_key
                     iv_code     = zif_cd_hck_recon_types=>gc_code-recon_break
                     iv_severity = zif_ca_ops_types=>gc_severity-error
                     iv_amount   = <ls_day>-amount
                     iv_message  = lv_message
                     iv_details  = condense( CONV string( <ls_day>-first_zuonr ) ) ).
      ELSE.
        mv_timing = mv_timing + 1.
        add_finding( is_work     = is_work
                     iv_key      = lv_key
                     iv_code     = zif_cd_hck_recon_types=>gc_code-recon_timing
                     iv_severity = zif_ca_ops_types=>gc_severity-info
                     iv_amount   = <ls_day>-amount
                     iv_message  = lv_message ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD count_up.
    READ TABLE ct_counts ASSIGNING FIELD-SYMBOL(<ls_count>) WITH TABLE KEY name = iv_name.
    IF sy-subrc = 0.
      <ls_count>-count = <ls_count>-count + 1.
    ELSE.
      INSERT VALUE #( name = iv_name count = 1 ) INTO TABLE ct_counts.
    ENDIF.
  ENDMETHOD.


  METHOD set_input.
    rs_input = ms_base.
    rs_input-set       = is_work-set.
    rs_input-tolerance = is_work-tolerance.
    rs_input-roles     = mt_roles.
  ENDMETHOD.


  METHOD codes_of_role.
    LOOP AT mt_roles ASSIGNING FIELD-SYMBOL(<ls_role>) USING KEY by_set WHERE set_id = iv_set_id.
      IF <ls_role>-role = iv_role.
        INSERT <ls_role>-btc INTO TABLE rt_codes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD group_key.
    rv_group = |{ is_set-bukrs WIDTH = zif_cd_hck_recon_types=>gc_group_width-bukrs }|
            && |{ zif_cd_hck_recon_types=>gc_key_sep }|
            && |{ is_set-hkont WIDTH = zif_cd_hck_recon_types=>gc_group_width-hkont }|
            && |{ zif_cd_hck_recon_types=>gc_key_sep }|
            && |{ is_set-waers WIDTH = zif_cd_hck_recon_types=>gc_group_width-waers }|.
  ENDMETHOD.


  METHOD add_metric.
    INSERT VALUE #( metric = iv_metric
                    dim1   = iv_dim1
                    dim2   = iv_dim2
                    value  = iv_value
                    kind   = iv_kind ) INTO TABLE ms_result-metrics.
  ENDMETHOD.


  METHOD add_finding.
    INSERT VALUE #( object_key = |{ mv_check_id }{ zif_cd_hck_recon_types=>gc_key_sep }{ iv_key }|
                    check_code = iv_code
                    severity   = iv_severity
                    action     = COND #( WHEN iv_severity <> zif_ca_ops_types=>gc_severity-info
                                         THEN zif_ca_ops_types=>gc_action-exception )
                    amount     = iv_amount
                    currency   = is_work-set-waers
                    reference  = is_work-set-set_id
                    message    = iv_message
                    details    = iv_details ) INTO TABLE ms_result-findings.
  ENDMETHOD.


  METHOD day_text.
    rv_text = |{ iv_day DATE = ISO }|.
  ENDMETHOD.


  METHOD bucket_list.
    rv_text = concat_lines_of( table = VALUE string_table( FOR lv_bucket IN it_buckets
                                                           ( condense( CONV string( lv_bucket ) ) ) )
                               sep   = zif_cd_hck_recon_types=>gc_list_sep ).
  ENDMETHOD.

ENDCLASS.
