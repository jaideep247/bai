*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_coverage.clas.abap
*& Purpose:
*& Registered check of the monitor coverage (module CORE; registry row
*& CA_OPS / COVERAGE, group MORNING; docs/EVALUATION_AND_COVERAGE.md
*& section 5): every registered check of every area with its coverage
*& state today - the registry and the business process activation (the
*& catalogue API), the licence decision for the modules it needs read
*& through the existing licence service (ZIF_CA_OPS_LICENSE: no other
*& verification), its latest evaluation record and its schedule window
*& (CHECK_STALE_MIN_<area>, else CHECK_STALE_MIN_DEFAULT; the area
*& dashboard's freshness). A monitor gap is an owned exception, so the
*& existing alert rules route it: not run in its window (568) and refused
*& by the licence (570) = E, impaired - not evaluated, stale or partial
*& (569) - and running under a licence warning (571) = W. A check switched
*& off by configuration is no finding (shown by ZR_CA_OpsCoverage). This
*& check itself is left out. Reads only.
*& Modification log:
*& 2026-11-16 | Initial version (build O: monitor coverage state).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - monitor coverage check</p>
CLASS zcl_ca_ops_chk_coverage DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! The coverage rows of the registry today (the rule of ZCL_CA_OPS_COVERAGE on the live inputs)
    METHODS coverage
      IMPORTING
        is_check       TYPE zif_ca_ops_chk_types=>ty_check
        is_context     TYPE zif_ca_ops_chk_types=>ty_context
      RETURNING
        VALUE(rt_rows) TYPE zif_ca_ops_eval_types=>tt_cov_row.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_window,
        area       TYPE zif_ca_ops_types=>ty_area,
        window_min TYPE i,
      END OF ty_window.
    TYPES tt_window TYPE HASHED TABLE OF ty_window WITH UNIQUE KEY area.

    DATA mt_windows TYPE tt_window.

    "! Schedule window of an area in minutes (the freshness of the area dashboard)
    METHODS window_of
      IMPORTING
        iv_area           TYPE zif_ca_ops_types=>ty_area
      RETURNING
        VALUE(rv_minutes) TYPE i.

    "! The finding of a gap (initial for RAN and DISABLED)
    METHODS finding
      IMPORTING
        is_row            TYPE zif_ca_ops_eval_types=>ty_cov_row
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_ca_ops_chk_coverage IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA(lt_rows) = coverage( is_check = is_check is_context = is_context ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      rs_result-item_count += 1.
      DATA(ls_finding) = finding( <ls_row> ).
      IF ls_finding IS NOT INITIAL.
        INSERT ls_finding INTO TABLE rs_result-findings.
      ENDIF.
    ENDLOOP.
    rs_result-eval-expected = lines( lt_rows ).
    rs_result-eval-observed = REDUCE i( INIT n = 0
                                        FOR ls_row IN lt_rows
                                        WHERE ( state = zif_ca_ops_eval_types=>gc_cov-ran
                                             OR state = zif_ca_ops_eval_types=>gc_cov-warned )
                                        NEXT n = n + 1 ).
  ENDMETHOD.


  METHOD coverage.
    DATA lt_off TYPE zif_ca_ops_cat_types=>tt_process_ids.
    DATA lv_area TYPE zif_ca_ops_types=>ty_area.
    DATA(lo_license) = zcl_ca_ops_factory=>get_license( ).
    DATA(lo_catalog) = zcl_ca_ops_factory=>get_catalog( ).
    DATA(lt_latest) = zcl_ca_ops_factory=>get_eval_dao( )->latest( ).
    DATA(lt_registry) = zcl_ca_ops_factory=>get_check_dao( )->get_registry( ).
    SORT lt_registry BY area check_id.
    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_reg>).
      IF <ls_reg>-area = is_check-area AND <ls_reg>-check_id = is_check-check_id.
        " the coverage check does not judge itself
        CONTINUE.
      ENDIF.
      IF <ls_reg>-area <> lv_area.
        lv_area = <ls_reg>-area.
        lt_off = lo_catalog->inactive_onboarded( iv_area = lv_area iv_date = is_context-today ).
      ENDIF.
      DATA(ls_input) = VALUE zif_ca_ops_eval_types=>ty_cov_input(
        active      = xsdbool( <ls_reg>-active = abap_true
                               AND NOT ( <ls_reg>-process_id IS NOT INITIAL
                                         AND line_exists( lt_off[ table_line = <ls_reg>-process_id ] ) ) )
        lic_allowed = abap_true
        now         = is_context-now
        window_min  = window_of( <ls_reg>-area ) ).
      DATA(ls_row) = VALUE zif_ca_ops_eval_types=>ty_cov_row( area       = <ls_reg>-area
                                                              check_id   = <ls_reg>-check_id
                                                              process_id = <ls_reg>-process_id ).
      " the licence through the existing licence service: refused only under X, warned under W
      LOOP AT lo_license->modules_of_check( <ls_reg> ) ASSIGNING FIELD-SYMBOL(<lv_module>).
        DATA(ls_decision) = lo_license->decide( <lv_module> ).
        ls_row-module = <lv_module>.
        IF ls_decision-allowed = abap_false.
          ls_input-lic_allowed = abap_false.
          EXIT.
        ENDIF.
        IF ls_decision-lic_state = zif_ca_ops_lic_types=>gc_lic_state-valid
           AND ( ls_decision-state = zif_ca_ops_lic_types=>gc_state-unlicensed
              OR ls_decision-state = zif_ca_ops_lic_types=>gc_state-expired ).
          ls_input-lic_warned = abap_true.
        ENDIF.
      ENDLOOP.
      DATA(ls_last) = VALUE zif_ca_ops_eval_types=>ty_eval( lt_latest[ area = <ls_reg>-area check_id = <ls_reg>-check_id ] OPTIONAL ).
      IF ls_last IS NOT INITIAL.
        ls_input-has_eval     = abap_true.
        ls_input-evaluated_at = ls_last-evaluated_at.
        ls_input-eval_state   = ls_last-eval_state.
        ls_input-reason_code  = ls_last-reason_code.
        ls_row-eval_state     = ls_last-eval_state.
        ls_row-evaluated_at   = ls_last-evaluated_at.
      ENDIF.
      ls_row-state = zcl_ca_ops_coverage=>state( ls_input ).
      INSERT ls_row INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD window_of.
    ASSIGN mt_windows[ area = iv_area ] TO FIELD-SYMBOL(<ls_window>).
    IF sy-subrc = 0.
      rv_minutes = <ls_window>-window_min.
      RETURN.
    ENDIF.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_default) = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                   iv_name    = zif_ca_ops_chk_types=>gc_param-stale_default
                                                   iv_default = zif_ca_ops_chk_types=>gc_param_default-stale_default ).
    rv_minutes = zcl_ca_ops_util=>param_int(
                   io_params  = lo_params
                   iv_name    = CONV #( |{ zif_ca_ops_chk_types=>gc_param_prefix-stale_min }{ iv_area }| )
                   iv_default = lv_default ).
    INSERT VALUE #( area = iv_area window_min = rv_minutes ) INTO TABLE mt_windows.
  ENDMETHOD.


  METHOD finding.
    DATA(lv_key) = CONV zif_ca_ops_types=>ty_object_key( |{ is_row-area }/{ is_row-check_id }| ).
    rs_finding = VALUE #( object_type = zif_ca_ops_eval_types=>gc_object_type-check
                          object_key  = lv_key
                          rule_id     = zif_ca_ops_eval_types=>gc_rule_id-coverage
                          reference   = is_row-module ).
    CASE is_row-state.
      WHEN zif_ca_ops_eval_types=>gc_cov-not_run.
        rs_finding-check_code = zif_ca_ops_eval_types=>gc_code-not_run.
        rs_finding-severity   = zif_ca_ops_types=>gc_severity-error.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-cov_not_run
                                                       iv_v1    = is_row-check_id
                                                       iv_v2    = is_row-area
                                                       iv_v3    = COND string( WHEN is_row-evaluated_at IS INITIAL THEN `-`
                                                                               ELSE |{ is_row-evaluated_at TIMESTAMP = ISO }| ) ).
      WHEN zif_ca_ops_eval_types=>gc_cov-refused.
        rs_finding-check_code = zif_ca_ops_eval_types=>gc_code-refused.
        rs_finding-severity   = zif_ca_ops_types=>gc_severity-error.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-cov_refused
                                                       iv_v1    = is_row-check_id
                                                       iv_v2    = is_row-area
                                                       iv_v3    = is_row-module ).
      WHEN zif_ca_ops_eval_types=>gc_cov-impaired.
        rs_finding-check_code = zif_ca_ops_eval_types=>gc_code-impaired.
        rs_finding-severity   = zif_ca_ops_types=>gc_severity-warning.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-cov_impaired
                                                       iv_v1    = is_row-check_id
                                                       iv_v2    = is_row-area
                                                       iv_v3    = is_row-eval_state ).
      WHEN zif_ca_ops_eval_types=>gc_cov-warned.
        rs_finding-check_code = zif_ca_ops_eval_types=>gc_code-warned.
        rs_finding-severity   = zif_ca_ops_types=>gc_severity-warning.
        rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-cov_warned
                                                       iv_v1    = is_row-check_id
                                                       iv_v2    = is_row-area
                                                       iv_v3    = is_row-module ).
      WHEN OTHERS.
        " RAN, DISABLED: shown by the coverage view, no exception
        CLEAR rs_finding.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
