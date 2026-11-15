*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_src_break.clas.abap
*& Purpose:
*& Source of the account flow reconciliation for a clearing account (role
*& CLEARING, SETTLEMENT): what the break analysis accounts for - the open
*& break groups in a named bucket (not OTHER: timing, return next month,
*& ...) of the latest snapshot of each break account of the company code
*& in the account's G/L range, at most FLOW_BREAK_MAX_AGE_DAYS before the
*& key date. Groups in OTHER stay in the Unexplained row (the break check
*& raises them). No snapshot, or a partial one: not evaluated (grey).
*& Signed as the journal. Reads only framework tables.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Account flow source - explained clearing-account breaks</p>
"! A snapshot covers the lines of its look-back window (BRK_LOOKBACK_DAYS): an older open group is not in it and
"! shows as unexplained - the honest answer (docs/ACCOUNT_FLOW.md section 5).
CLASS zcl_ca_ops_flow_src_break DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_source.

ENDCLASS.



CLASS zcl_ca_ops_flow_src_break IMPLEMENTATION.

  METHOD zif_ca_ops_flow_source~accounted_for.
    DATA lt_ids TYPE zif_ca_ops_flow_types=>tt_run_id.

    DATA(lo_dao) = zcl_ca_ops_factory=>get_flow_dao( ).
    DATA(lv_age) = zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                               iv_name    = zif_ca_ops_flow_types=>gc_param-break_age
                                               iv_default = zif_ca_ops_flow_types=>gc_default-break_age ).
    DATA(lv_from) = CONV d( iv_key_date - lv_age ).
    DATA(lv_to) = COND saknr( WHEN is_account-hkont_to IS INITIAL THEN is_account-hkont_from
                              ELSE is_account-hkont_to ).
    DATA(lt_snaps) = lo_dao->break_snapshots( iv_bukrs      = is_account-bukrs
                                              iv_hkont_from = is_account-hkont_from
                                              iv_hkont_to   = lv_to
                                              iv_from       = lv_from
                                              iv_key_date   = iv_key_date ).
    IF lt_snaps IS INITIAL.
      INSERT VALUE #( currency = is_account-currency
                      status   = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                      reason   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-no_snapshot
                                                        iv_v1    = is_account-bukrs
                                                        iv_v2    = is_account-hkont_from
                                                        iv_v3    = lv_from
                                                        iv_v4    = iv_key_date ) ) INTO TABLE rt_rows.
      RETURN.
    ENDIF.
    LOOP AT lt_snaps ASSIGNING FIELD-SYMBOL(<ls_snap>).
      IF <ls_snap>-status = zif_ca_ops_brk_types=>gc_status-partial.
        " a partial snapshot holds the oldest groups only: what it explains is not the whole account
        INSERT VALUE #( currency = is_account-currency
                        status   = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                        reason   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-snap_partial
                                                          iv_v1    = <ls_snap>-acct_id
                                                          iv_v2    = <ls_snap>-hkont
                                                          iv_v3    = <ls_snap>-key_date ) ) INTO TABLE rt_rows.
        RETURN.
      ENDIF.
      INSERT <ls_snap>-snap_id INTO TABLE lt_ids.
    ENDLOOP.

    LOOP AT lo_dao->break_explained( lt_ids ) ASSIGNING FIELD-SYMBOL(<ls_sum>).
      IF is_account-currency IS NOT INITIAL AND <ls_sum>-currency <> is_account-currency.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( currency   = <ls_sum>-currency
                      amount     = <ls_sum>-amount
                      item_count = <ls_sum>-item_count
                      status     = zif_ca_ops_flow_types=>gc_item_status-evaluated ) INTO TABLE rt_rows.
    ENDLOOP.
    " evaluated: a row for the account's currency, or a blank-currency row = every other currency of the account
    " (nothing explained there) - so a currency without a row is evaluated as zero, never left grey by mistake
    IF is_account-currency IS INITIAL OR rt_rows IS INITIAL.
      INSERT VALUE #( currency = is_account-currency
                      status   = zif_ca_ops_flow_types=>gc_item_status-evaluated ) INTO TABLE rt_rows.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
