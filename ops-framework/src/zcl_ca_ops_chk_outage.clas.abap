*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_outage.clas.abap
*& Purpose:
*& Generic risk check of the process catalogue: accounting around a planned
*& downtime. For every approved planned downtime window of the check's area
*& (ZIF_CA_OPS_DOWNTIME) that ended within the last CAT_OUTAGE_DAYS days,
*& every active aggregate row of the check (ZCA_OPS_AGG, table approved for
*& the area) is measured in the window instead of its age limits: a row with
*& a TIME_FIELD counts the rows posted inside the window (date and time, e.g.
*& postings entered while the system was meant to be down), a row without
*& one counts the rows of the window's days plus CAT_OUTAGE_MARGIN_DAYS
*& (e.g. reconciliation keys of the outage days not transferred to the G/L).
*& A count at or above the row's RED / AMBER limit is a finding per window,
*& rule and company code. The check is always partial: a posting inside a
*& window never goes away, so an operator closes the exception after the
*& accounting was confirmed (never auto-resolved). Reads only through
*& ZIF_CA_OPS_CHECK_DAO and the downtime API.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue: generic risk checks).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - accounting around planned downtime</p>
"! Example rows (FI-CA, VERIFY-SE11, delivered inactive): documents entered in the window (DFKKKO, entry date
"! and time); reconciliation keys of the window's days still open (docs/PROCESS_CATALOGUE.md section 6).
CLASS zcl_ca_ops_chk_outage DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    CONSTANTS gc_seconds_per_day TYPE i VALUE 86400.

    "! Findings of one row in one window (the row's limits; per company code)
    METHODS window_findings
      IMPORTING
        is_agg             TYPE zif_ca_ops_chk_types=>ty_agg
        is_window          TYPE zif_ca_ops_resp_types=>ty_window
        it_rows            TYPE zif_ca_ops_chk_types=>tt_agg_row
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

ENDCLASS.



CLASS zcl_ca_ops_chk_outage IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA lv_from TYPE timestampl.

    " the check never resolves what it raised: an operator confirms the accounting of a window
    rs_result-partial = abap_true.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_check_dao( ).
    DATA(lt_aggs) = lo_dao->get_aggregates( iv_area     = is_check-area
                                            iv_check_id = is_check-check_id ).
    IF lt_aggs IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e092(zca_ops) WITH is_check-check_id is_check-area.
    ENDIF.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_days) = CONV i( lo_params->get_param(
                              iv_name    = zif_ca_ops_cat_types=>gc_param-outage_days
                              iv_default = CONV #( zif_ca_ops_cat_types=>gc_param_default-outage_days ) ) ).
    DATA(lv_margin) = CONV i( lo_params->get_param(
                                iv_name    = zif_ca_ops_cat_types=>gc_param-outage_margin
                                iv_default = CONV #( zif_ca_ops_cat_types=>gc_param_default-outage_margin ) ) ).
    lv_from = cl_abap_tstmp=>add( tstmp = is_context-now
                                  secs  = - lv_days * gc_seconds_per_day ).
    DATA(lt_windows) = zcl_ca_ops_factory=>get_downtime( )->windows( iv_area          = is_check-area
                                                                     iv_from          = lv_from
                                                                     iv_to            = is_context-now
                                                                     iv_approved_only = abap_true ).
    LOOP AT lt_windows ASSIGNING FIELD-SYMBOL(<ls_window>) WHERE to_utc <= is_context-now.
      LOOP AT lt_aggs ASSIGNING FIELD-SYMBOL(<ls_agg>).
        " without a time field the window's days plus the margin (what happened around the outage)
        DATA(ls_range) = VALUE zif_ca_ops_chk_types=>ty_window( from_date = <ls_window>-from_date
                                                                from_time = <ls_window>-from_time
                                                                to_date   = <ls_window>-to_date
                                                                to_time   = <ls_window>-to_time ).
        IF <ls_agg>-time_field IS INITIAL.
          ls_range-to_date = ls_range-to_date + lv_margin.
        ENDIF.
        TRY.
            DATA(lt_rows) = lo_dao->aggregate( is_agg         = <ls_agg>
                                               iv_bukrs_aware = is_check-bukrs_aware
                                               iv_today       = is_context-today
                                               is_window      = ls_range ).
            INSERT LINES OF window_findings( is_agg    = <ls_agg>
                                             is_window = <ls_window>
                                             it_rows   = lt_rows ) INTO TABLE rs_result-findings.
            rs_result-item_count += lines( lt_rows ).
          CATCH zcx_ca_ops_error INTO DATA(lx_error).
            INSERT VALUE #( object_type = zif_ca_ops_chk_types=>gc_object_type-aggregate
                            object_key  = |{ <ls_agg>-check_id }/{ <ls_agg>-agg_id }|
                            rule_id     = <ls_agg>-agg_id
                            check_code  = zif_ca_ops_chk_types=>gc_code-agg_invalid
                            severity    = zif_ca_ops_types=>gc_severity-error
                            action      = zif_ca_ops_types=>gc_action-notify
                            reference   = <ls_agg>-tabname
                            message     = lx_error->get_text( )
                            details     = zcl_ca_ops_util=>exception_trace( lx_error )
                            error_class = zcl_ca_ops_util=>error_class( lx_error ) ) INTO TABLE rs_result-findings.
        ENDTRY.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD window_findings.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_severity) = COND zif_ca_ops_types=>ty_severity(
                            WHEN is_agg-red > 0 AND <ls_row>-row_count >= is_agg-red THEN zif_ca_ops_types=>gc_severity-error
                            WHEN is_agg-amber > 0 AND <ls_row>-row_count >= is_agg-amber
                            THEN zif_ca_ops_types=>gc_severity-warning ).
      IF lv_severity IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( object_type  = zif_ca_ops_cat_types=>gc_object_type-window
                      object_key   = |{ is_window-from_date }{ is_window-from_time }/{ is_agg-agg_id }|
                      rule_id      = is_agg-agg_id
                      check_code   = COND #( WHEN is_agg-check_code IS NOT INITIAL THEN is_agg-check_code
                                             ELSE zif_ca_ops_cat_types=>gc_code-outage_rows )
                      severity     = lv_severity
                      action       = zif_ca_ops_types=>gc_action-exception
                      reference    = is_agg-tabname
                      company_code = <ls_row>-company_code
                      business_date = is_window-from_date
                      item_count   = <ls_row>-row_count
                      message      = zcl_ca_ops_util=>text(
                                       iv_msgno = zif_ca_ops_cat_types=>gc_msg-outage_rows
                                       iv_v1    = |{ is_window-from_date DATE = ISO } { is_window-from_time TIME = ISO }|
                                       iv_v2    = |{ is_window-to_date DATE = ISO } { is_window-to_time TIME = ISO }|
                                       iv_v3    = <ls_row>-row_count
                                       iv_v4    = is_agg-agg_id ) ) INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
