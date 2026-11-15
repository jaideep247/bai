*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_eval.clas.abap
*& Purpose:
*& Evaluation of the account flows of an area at a key date (report
*& ZCA_OPS_FLOW_RUN): authorisation ZCA_OPS execute (16) for the area; per
*& active flow whose business process is in effect (process catalogue)
*& the configuration is read and validated (ZCL_CA_OPS_FLOW_CONFIG -
*& problems make the evaluation partial, they change no figure), the
*& configuration version is computed, and for every active account the
*& plug-in of its EVAL_CLASS (ZIF_CA_OPS_FLOW_SOURCE) says what existing
*& checks account for in its closing position. An account without a class
*& or whose class fails is recorded as not evaluated with the reason
*& (grey on the dashboard, never zero); an OUTSIDE account has no control
*& point and no row. The evaluation is saved and committed per flow; the
*& flow's evaluations older than FLOW_RETENTION_DAYS are removed. Test
*& mode writes nothing. Read-only towards business data.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - account flow evaluation</p>
"! The movement, the opening and closing positions and the stage rows are not computed here: they are CDS over the
"! released journal view and the FI-CA documents (docs/ACCOUNT_FLOW.md section 4); the evaluation only stores what
"! the checks hold open, so the dashboard compares nothing of its own.
CLASS zcl_ca_ops_flow_eval DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Evaluate the flows of an area at a key date
    "! @parameter iv_flow_id   | One flow (blank = every active flow of the area)
    "! @parameter iv_key_date  | Key date (the "to" date of the dashboard the evaluation answers)
    "! @parameter iv_test_mode | X = nothing is written
    "! @parameter rt_results   | One result per flow (evaluation, items, problems, skipped, removed evaluations)
    "! @raising zcx_ca_ops_error | 041 not authorised, 010 the evaluation could not be saved
    METHODS evaluate
      IMPORTING
        iv_area           TYPE zif_ca_ops_types=>ty_area
        iv_flow_id        TYPE zif_ca_ops_flow_types=>ty_flow_id OPTIONAL
        iv_key_date       TYPE d
        iv_test_mode      TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_results) TYPE zif_ca_ops_flow_types=>tt_result
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    METHODS evaluate_flow
      IMPORTING
        is_config        TYPE zif_ca_ops_flow_types=>ty_config
        iv_key_date      TYPE d
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_flow_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    "! What the account's source accounts for (status N rows with the reason when it cannot say)
    METHODS evaluate_account
      IMPORTING
        is_config      TYPE zif_ca_ops_flow_types=>ty_config
        is_account     TYPE zif_ca_ops_flow_types=>ty_account
        iv_key_date    TYPE d
      RETURNING
        VALUE(rt_rows) TYPE zif_ca_ops_flow_types=>tt_source_row.

    "! Version of the flow's effective configuration (ZCL_CA_OPS_CFG_VERSION)
    METHODS version
      IMPORTING
        is_config         TYPE zif_ca_ops_flow_types=>ty_config
      RETURNING
        VALUE(rv_version) TYPE zif_ca_ops_types=>ty_cfg_version.

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

ENDCLASS.



CLASS zcl_ca_ops_flow_eval IMPLEMENTATION.

  METHOD evaluate.
    zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                            iv_area     = iv_area ).
    DATA(lo_dao) = zcl_ca_ops_factory=>get_flow_dao( ).
    DATA(lt_off) = zcl_ca_ops_factory=>get_catalog( )->inactive_onboarded(
                     iv_area = iv_area
                     iv_date = zcl_ca_ops_factory=>get_clock( )->today( ) ).
    DATA(lv_retention) = int_param( iv_name    = zif_ca_ops_flow_types=>gc_param-retention
                                    iv_default = zif_ca_ops_flow_types=>gc_default-retention ).

    LOOP AT lo_dao->get_flows( iv_area = iv_area iv_flow_id = iv_flow_id ) ASSIGNING FIELD-SYMBOL(<ls_flow>).
      IF <ls_flow>-process_id IS NOT INITIAL AND line_exists( lt_off[ table_line = <ls_flow>-process_id ] ).
        " the flow's business process is not in effect (process catalogue): not evaluated, nothing written
        INSERT VALUE #( eval     = VALUE #( area = iv_area flow_id = <ls_flow>-flow_id key_date = iv_key_date )
                        skipped  = abap_true
                        problems = VALUE #( ( msgno = zif_ca_ops_flow_types=>gc_msg-process_off
                                              v1    = <ls_flow>-flow_id
                                              v2    = iv_area
                                              v3    = <ls_flow>-process_id ) ) ) INTO TABLE rt_results.
        CONTINUE.
      ENDIF.
      DATA(ls_result) = evaluate_flow( is_config   = lo_dao->get_config( <ls_flow> )
                                       iv_key_date = iv_key_date ).
      IF iv_test_mode = abap_false.
        lo_dao->save_evaluation( is_eval = ls_result-eval it_items = ls_result-items ).
        IF lv_retention > 0.
          ls_result-purged = lo_dao->delete_evaluations( iv_area    = iv_area
                                                         iv_flow_id = <ls_flow>-flow_id
                                                         iv_before  = CONV d( iv_key_date - lv_retention ) ).
        ENDIF.
        " one flow, one unit of work: a later flow's failure never undoes this evaluation
        lo_dao->commit( ).
      ENDIF.
      INSERT ls_result INTO TABLE rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD evaluate_flow.
    DATA lv_eval_id TYPE zif_ca_ops_types=>ty_run_id.
    DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).

    TRY.
        lv_eval_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e001(zca_ops)
          EXPORTING
            previous = lx_uuid.
    ENDTRY.
    rs_result-problems = zcl_ca_ops_flow_config=>validate( is_config ).
    rs_result-eval = VALUE #( eval_id     = lv_eval_id
                              area        = is_config-flow-area
                              flow_id     = is_config-flow-flow_id
                              key_date    = iv_key_date
                              status      = COND #( WHEN rs_result-problems IS INITIAL
                                                    THEN zif_ca_ops_flow_types=>gc_status-complete
                                                    ELSE zif_ca_ops_flow_types=>gc_status-partial )
                              cfg_version = version( is_config )
                              started_at  = lo_clock->now( )
                              created_by  = sy-uname ).

    LOOP AT is_config-accounts ASSIGNING FIELD-SYMBOL(<ls_account>)
         WHERE active = abap_true AND role <> zif_ca_ops_flow_types=>gc_role-outside.
      rs_result-eval-acct_count += 1.
      DATA(lt_rows) = evaluate_account( is_config = is_config is_account = <ls_account> iv_key_date = iv_key_date ).
      IF line_exists( lt_rows[ status = zif_ca_ops_flow_types=>gc_item_status-not_evaluated ] ).
        rs_result-eval-not_evaluated += 1.
        rs_result-eval-status = zif_ca_ops_flow_types=>gc_status-partial.
      ENDIF.
      LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
        INSERT VALUE #( item_no      = lines( rs_result-items ) + 1
                        flow_acct    = <ls_account>-flow_acct
                        role         = <ls_account>-role
                        bukrs        = <ls_account>-bukrs
                        currency     = <ls_row>-currency
                        category     = <ls_account>-eval_category
                        amount       = <ls_row>-amount
                        item_count   = <ls_row>-item_count
                        sign_rule    = <ls_row>-sign_rule
                        status       = <ls_row>-status
                        source_class = <ls_account>-eval_class
                        reason       = <ls_row>-reason ) INTO TABLE rs_result-items.
      ENDLOOP.
    ENDLOOP.

    rs_result-eval-ended_at = lo_clock->now( ).
    rs_result-eval-message = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-summary
                                                    iv_v1    = is_config-flow-flow_id
                                                    iv_v2    = is_config-flow-area
                                                    iv_v3    = iv_key_date
                                                    iv_v4    = |{ rs_result-eval-acct_count
                                                               - rs_result-eval-not_evaluated } / {
                                                               rs_result-eval-acct_count }| ).
  ENDMETHOD.


  METHOD evaluate_account.
    DATA lo_source TYPE REF TO zif_ca_ops_flow_source.

    IF is_account-eval_class IS INITIAL.
      rt_rows = VALUE #( ( currency = is_account-currency
                           status   = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                           reason   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-no_source
                                                             iv_v1    = is_account-flow_acct ) ) ).
      RETURN.
    ENDIF.
    TRY.
        lo_source ?= zcl_ca_ops_factory=>get_plugin( iv_class_name = is_account-eval_class
                                                     iv_interface  = zif_ca_ops_flow_types=>gc_source_interface ).
      CATCH zcx_ca_ops_error INTO DATA(lx_plugin).
        rt_rows = VALUE #( ( currency = is_account-currency
                             status   = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                             reason   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-source_invalid
                                                               iv_v1    = is_account-eval_class
                                                               iv_v2    = lx_plugin->get_text( ) ) ) ).
        RETURN.
    ENDTRY.
    TRY.
        rt_rows = lo_source->accounted_for( is_config   = is_config
                                            is_account  = is_account
                                            iv_key_date = iv_key_date ).
      CATCH zcx_ca_ops_error INTO DATA(lx_source).
        rt_rows = VALUE #( ( currency = is_account-currency
                             status   = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                             reason   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-source_failed
                                                               iv_v1    = is_account-eval_class
                                                               iv_v2    = lx_source->get_text( ) ) ) ).
    ENDTRY.
    IF rt_rows IS INITIAL.
      " a source that answers nothing has not evaluated the account: grey, never zero
      rt_rows = VALUE #( ( currency = is_account-currency
                           status   = zif_ca_ops_flow_types=>gc_item_status-not_evaluated
                           reason   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_flow_types=>gc_msg-no_answer
                                                             iv_v1    = is_account-eval_class
                                                             iv_v2    = is_account-flow_acct ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD version.
    DATA lt_lines TYPE string_table.
    DATA(ls_flow) = is_config-flow.
    CLEAR ls_flow-description.
    INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_flow_types=>gc_version_kind-flow is_row = ls_flow )
           INTO TABLE lt_lines.
    LOOP AT is_config-accounts INTO DATA(ls_account).
      CLEAR ls_account-description.
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_flow_types=>gc_version_kind-account is_row = ls_account )
             INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT is_config-stages INTO DATA(ls_stage).
      CLEAR ls_stage-description.
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_flow_types=>gc_version_kind-stage is_row = ls_stage )
             INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT is_config-tiles INTO DATA(ls_tile).
      CLEAR ls_tile-description.
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_flow_types=>gc_version_kind-tile is_row = ls_tile )
             INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT is_config-controls INTO DATA(ls_control).
      CLEAR ls_control-description.
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_flow_types=>gc_version_kind-control is_row = ls_control )
             INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT is_config-rules INTO DATA(ls_rule).
      CLEAR ls_rule-description.
      INSERT zcl_ca_ops_cfg_version=>line( iv_kind = zif_ca_ops_flow_types=>gc_version_kind-rule is_row = ls_rule )
             INTO TABLE lt_lines.
    ENDLOOP.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    INSERT zcl_ca_ops_cfg_version=>line(
             iv_kind = zif_ca_ops_flow_types=>gc_version_kind-param
             is_row  = |{ zif_ca_ops_flow_types=>gc_param-ledger }={ lo_params->get_param(
                          iv_name    = zif_ca_ops_flow_types=>gc_param-ledger
                          iv_default = CONV #( zif_ca_ops_flow_types=>gc_default-ledger ) ) }| ) INTO TABLE lt_lines.
    INSERT zcl_ca_ops_cfg_version=>line(
             iv_kind = zif_ca_ops_flow_types=>gc_version_kind-param
             is_row  = |{ zif_ca_ops_flow_types=>gc_param-break_age }={
                          int_param( iv_name    = zif_ca_ops_flow_types=>gc_param-break_age
                                     iv_default = zif_ca_ops_flow_types=>gc_default-break_age ) }| ) INTO TABLE lt_lines.
    rv_version = zcl_ca_ops_cfg_version=>of_lines( lt_lines ).
  ENDMETHOD.


  METHOD int_param.
    rv_value = zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                           iv_name    = iv_name
                                           iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
