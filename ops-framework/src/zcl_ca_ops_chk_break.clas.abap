*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_break.clas.abap
*& Purpose:
*& Registered check of the clearing-account break analysis: per active
*& account of the area whose business process is in effect, the latest
*& snapshot (ZCA_OPS_BRKRUN). No snapshot, or one older than BRK_STALE_DAYS,
*& is a warning BREAK_NO_SNAPSHOT; a partial snapshot a warning
*& BREAK_PARTIAL; every unexplained group (bucket OTHER) at least
*& BRK_UNEXPLAINED_DAYS old is an exception BREAK_UNEXPLAINED with its
*& amount and currency (never summed across currencies), company code,
*& business date (oldest line) and the configuration version of the
*& snapshot that classified it. At most BRK_MAX_FINDINGS per account, the
*& rest summarised (294) - then the check is partial, so nothing unlisted is
*& auto-resolved. Reads only through ZIF_CA_OPS_BRK_DAO; writes nothing.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - unexplained clearing-account breaks</p>
"! Explainable, versioned: CFG_VERSION of a break finding = the snapshot's configuration version (bucket rules,
"! conditions, accounts, BRK_ parameters); its configuration lines are those versions and the check's parameters.
CLASS zcl_ca_ops_chk_break DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.
    INTERFACES zif_ca_ops_check_config.

  PRIVATE SECTION.
    "! Limits of the check
    TYPES:
      BEGIN OF ty_limits,
        unexplained TYPE i,
        stale_days  TYPE i,
        max_finds   TYPE i,
      END OF ty_limits.

    METHODS limits
      RETURNING
        VALUE(rs_limits) TYPE ty_limits.

    "! Active accounts of the area whose business process is in effect
    METHODS accounts
      IMPORTING
        iv_area            TYPE zif_ca_ops_types=>ty_area
        iv_today           TYPE d
      RETURNING
        VALUE(rt_accounts) TYPE zif_ca_ops_brk_types=>tt_account.

ENDCLASS.



CLASS zcl_ca_ops_chk_break IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_brk_dao( ).
    DATA(ls_limits) = limits( ).
    DATA(lv_stale_before) = CONV d( is_context-today - ls_limits-stale_days ).
    LOOP AT accounts( iv_area = is_check-area iv_today = is_context-today ) ASSIGNING FIELD-SYMBOL(<ls_account>).
      rs_result-item_count += 1.
      DATA(ls_snapshot) = lo_dao->latest_snapshot( iv_area = <ls_account>-area iv_acct_id = <ls_account>-acct_id ).
      IF ls_snapshot IS INITIAL OR ls_snapshot-key_date < lv_stale_before.
        INSERT VALUE #( object_type  = zif_ca_ops_brk_types=>gc_object_type-account
                        object_key   = <ls_account>-acct_id
                        rule_id      = zif_ca_ops_brk_types=>gc_rule_id
                        check_code   = zif_ca_ops_brk_types=>gc_code-no_snapshot
                        severity     = zif_ca_ops_types=>gc_severity-warning
                        company_code = <ls_account>-bukrs
                        message      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_brk_types=>gc_msg-no_snapshot
                                                              iv_v1    = <ls_account>-acct_id
                                                              iv_v2    = <ls_account>-area
                                                              iv_v3    = ls_snapshot-key_date ) )
               INTO TABLE rs_result-findings.
        CONTINUE.
      ENDIF.
      IF ls_snapshot-status = zif_ca_ops_brk_types=>gc_status-partial.
        " the unlisted groups are unknown, not resolved
        rs_result-partial = abap_true.
        INSERT VALUE #( object_type   = zif_ca_ops_brk_types=>gc_object_type-account
                        object_key    = <ls_account>-acct_id
                        rule_id       = zif_ca_ops_brk_types=>gc_rule_id
                        check_code    = zif_ca_ops_brk_types=>gc_code-partial
                        severity      = zif_ca_ops_types=>gc_severity-warning
                        company_code  = <ls_account>-bukrs
                        business_date = ls_snapshot-key_date
                        cfg_version   = ls_snapshot-cfg_version
                        message       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_brk_types=>gc_msg-partial
                                                               iv_v1    = <ls_account>-acct_id
                                                               iv_v2    = ls_snapshot-key_date
                                                               iv_v3    = ls_snapshot-message ) )
               INTO TABLE rs_result-findings.
      ENDIF.
      LOOP AT lo_dao->open_breaks( iv_snap_id = ls_snapshot-snap_id
                                   iv_min_age = ls_limits-unexplained
                                   iv_max     = ls_limits-max_finds ) ASSIGNING FIELD-SYMBOL(<ls_break>).
        INSERT VALUE #( object_type   = zif_ca_ops_brk_types=>gc_object_type-group
                        object_key    = |{ <ls_account>-acct_id }{ zif_ca_ops_brk_types=>gc_key_separator }|
                                     && |{ <ls_break>-assignment }{ zif_ca_ops_brk_types=>gc_key_separator }|
                                     && |{ <ls_break>-currency }|
                        rule_id       = zif_ca_ops_brk_types=>gc_rule_id
                        check_code    = zif_ca_ops_brk_types=>gc_code-unexplained
                        severity      = zif_ca_ops_types=>gc_severity-error
                        amount        = <ls_break>-amount
                        currency      = <ls_break>-currency
                        reference     = <ls_break>-assignment
                        company_code  = <ls_account>-bukrs
                        business_date = <ls_break>-first_date
                        item_count    = <ls_break>-line_count
                        cfg_version   = ls_snapshot-cfg_version
                        cfg_rule      = zif_ca_ops_brk_types=>gc_bucket_other
                        message       = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_brk_types=>gc_msg-unexplained
                                                               iv_v1    = <ls_account>-acct_id
                                                               iv_v2    = <ls_break>-assignment
                                                               iv_v3    = <ls_break>-currency
                                                               iv_v4    = <ls_break>-age_days ) )
               INTO TABLE rs_result-findings.
      ENDLOOP.
      DATA(lv_total) = lo_dao->count_open_breaks( iv_snap_id = ls_snapshot-snap_id iv_min_age = ls_limits-unexplained ).
      IF lv_total > ls_limits-max_finds.
        rs_result-partial = abap_true.
        INSERT VALUE #( object_type  = zif_ca_ops_brk_types=>gc_object_type-account
                        object_key   = <ls_account>-acct_id
                        rule_id      = zif_ca_ops_brk_types=>gc_rule_id
                        check_code   = zif_ca_ops_brk_types=>gc_code-unexplained
                        severity     = zif_ca_ops_types=>gc_severity-warning
                        company_code = <ls_account>-bukrs
                        cfg_version  = ls_snapshot-cfg_version
                        message      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_brk_types=>gc_msg-more_findings
                                                              iv_v1    = <ls_account>-acct_id
                                                              iv_v2    = lv_total - ls_limits-max_finds ) )
               INTO TABLE rs_result-findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_check_config~config_lines.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_brk_dao( ).
    INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_brk_types=>gc_param_marker is_row = limits( ) )
           INTO TABLE rt_lines.
    " the configuration that classified the breaks: the version of each account's latest snapshot
    LOOP AT lo_dao->get_accounts( is_check-area ) ASSIGNING FIELD-SYMBOL(<ls_account>).
      DATA(ls_snapshot) = lo_dao->latest_snapshot( iv_area = <ls_account>-area iv_acct_id = <ls_account>-acct_id ).
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_brk_types=>gc_object_type-account
                                           is_row  = |{ <ls_account>-acct_id }={ ls_snapshot-cfg_version }| )
             INTO TABLE rt_lines.
    ENDLOOP.
  ENDMETHOD.


  METHOD limits.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    rs_limits-unexplained = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                        iv_name    = zif_ca_ops_brk_types=>gc_param-unexplained
                                                        iv_default = zif_ca_ops_brk_types=>gc_default-unexplained ).
    rs_limits-stale_days = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                       iv_name    = zif_ca_ops_brk_types=>gc_param-stale_days
                                                       iv_default = zif_ca_ops_brk_types=>gc_default-stale_days ).
    rs_limits-max_finds = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                      iv_name    = zif_ca_ops_brk_types=>gc_param-max_finds
                                                      iv_default = zif_ca_ops_brk_types=>gc_default-max_finds ).
  ENDMETHOD.


  METHOD accounts.
    DATA(lt_off) = zcl_ca_ops_factory=>get_catalog( )->inactive_onboarded( iv_area = iv_area iv_date = iv_today ).
    LOOP AT zcl_ca_ops_factory=>get_brk_dao( )->get_accounts( iv_area ) ASSIGNING FIELD-SYMBOL(<ls_account>).
      " an account of a business process not in effect is not monitored (process catalogue)
      IF <ls_account>-process_id IS INITIAL OR NOT line_exists( lt_off[ table_line = <ls_account>-process_id ] ).
        INSERT <ls_account> INTO TABLE rt_accounts.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
