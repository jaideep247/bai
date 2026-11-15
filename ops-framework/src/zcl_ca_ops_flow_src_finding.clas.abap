*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_src_finding.clas.abap
*& Purpose:
*& Source of the account flow reconciliation from the open exceptions of
*& existing checks (role CLARIFICATION, CASH, any role a check reports
*& item by item): the open or assigned findings of the checks that
*& control the stages clearing the account's role (stages whose
*& EXPECT_FROM is the role) for the company code, amounts summed per
*& currency. A finding's amount is unsigned: it takes the sign of the
*& account's closing position (sign rule B). No stage clears the role, or
*& no check controls it: not evaluated (grey). Reads only ZCA_OPS_FINDING.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Account flow source - open exceptions of the stage checks</p>
"! What a check reports only after n days (an aggregate with an age threshold) is not accounted for before it -
"! young items show as unexplained until the check raises them (docs/ACCOUNT_FLOW.md section 5).
CLASS zcl_ca_ops_flow_src_finding DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_source.

ENDCLASS.



CLASS zcl_ca_ops_flow_src_finding IMPLEMENTATION.

  METHOD zif_ca_ops_flow_source~accounted_for.
    DATA lt_checks TYPE zif_ca_ops_flow_types=>tt_check_ref.

    LOOP AT is_config-stages ASSIGNING FIELD-SYMBOL(<ls_stage>)
         WHERE active = abap_true AND expect_from = is_account-role.
      LOOP AT is_config-controls ASSIGNING FIELD-SYMBOL(<ls_control>)
           WHERE stage_id = <ls_stage>-stage_id AND active = abap_true.
        INSERT VALUE #( check_area = <ls_control>-check_area check_id = <ls_control>-check_id ) INTO TABLE lt_checks.
      ENDLOOP.
    ENDLOOP.
    IF lt_checks IS INITIAL.
      INSERT VALUE #( currency = is_account-currency
                      status   = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                      reason   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-no_check
                                                        iv_v1    = is_config-flow-flow_id
                                                        iv_v2    = is_account-role ) ) INTO TABLE rt_rows.
      RETURN.
    ENDIF.

    DATA(lt_sums) = zcl_ca_ops_factory=>get_flow_dao( )->open_findings( it_checks   = lt_checks
                                                                        iv_bukrs    = is_account-bukrs
                                                                        iv_currency = is_account-currency ).
    rt_rows = VALUE #( FOR ls_sum IN lt_sums ( currency   = ls_sum-currency
                                               amount     = abs( ls_sum-amount )
                                               item_count = ls_sum-item_count
                                               sign_rule  = zif_ca_ops_flow_types=>gc_sign_of_balance
                                               status     = zif_ca_ops_flow_types=>gc_item_status-evaluated ) ).
    IF is_account-currency IS INITIAL OR rt_rows IS INITIAL.
      INSERT VALUE #( currency  = is_account-currency
                      sign_rule = zif_ca_ops_flow_types=>gc_sign_of_balance
                      status    = zif_ca_ops_flow_types=>gc_item_status-evaluated ) INTO TABLE rt_rows.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
