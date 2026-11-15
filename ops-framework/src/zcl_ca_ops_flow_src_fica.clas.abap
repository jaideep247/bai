*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_src_fica.clas.abap
*& Purpose:
*& Source of the account flow reconciliation for an FI-CA reconciliation
*& account (role RECEIVABLE, PAYABLE): what the subledger accounts for -
*& the open business partner items (DFKKOP: company code, G/L account in
*& the account's range, posted up to the key date, no clearing document)
*& summed per currency on the database, signed as the receivable (debit
*& +). The difference to the closing position is what the subledger does
*& not hold open - e.g. the G/L transfer gap, which the G/L transfer check
*& controls. Read-only; the split "not yet in a payment run / not yet
*& paid" is not evaluated (docs/ACCOUNT_FLOW.md section 5).
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Account flow source - open FI-CA items</p>
"! FI-CA tables have no released view on the target release: a direct table read, the clean-core exception the
"! repository already documents (VERIFY V146: the open-item semantics; an item cleared after the key date but
"! before the run counts as cleared - run the evaluation with key date today, FLOW_KEY_DATE_LAG 0).
CLASS zcl_ca_ops_flow_src_fica DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_source.

ENDCLASS.



CLASS zcl_ca_ops_flow_src_fica IMPLEMENTATION.

  METHOD zif_ca_ops_flow_source~accounted_for.
    DATA(lv_to) = COND saknr( WHEN is_account-hkont_to IS INITIAL THEN is_account-hkont_from
                              ELSE is_account-hkont_to ).
    DATA(lt_sums) = zcl_ca_ops_factory=>get_flow_dao( )->fica_open_items( iv_bukrs      = is_account-bukrs
                                                                          iv_hkont_from = is_account-hkont_from
                                                                          iv_hkont_to   = lv_to
                                                                          iv_currency   = is_account-currency
                                                                          iv_key_date   = iv_key_date ).
    rt_rows = VALUE #( FOR ls_sum IN lt_sums ( currency   = ls_sum-currency
                                               amount     = ls_sum-amount
                                               item_count = ls_sum-item_count
                                               status     = zif_ca_ops_flow_types=>gc_item_status-evaluated ) ).
    " a blank-currency row = every other currency of the account: no open item there
    IF is_account-currency IS INITIAL OR rt_rows IS INITIAL.
      INSERT VALUE #( currency = is_account-currency
                      status   = zif_ca_ops_flow_types=>gc_item_status-evaluated ) INTO TABLE rt_rows.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
