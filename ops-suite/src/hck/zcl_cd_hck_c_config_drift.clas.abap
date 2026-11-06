*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_config_drift.clas.abap
*& Purpose:
*& Configuration drift: SHA-256 of every table listed in ZCD_HCK_DRIFT
*& compared with the golden baseline in ZCD_HCK_BASELINE.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Baseline of another hash version reported as outdated, not as drift (audit A57).
*& 2026-11-06 | Stops between tables when the time budget is used up (audit A18).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - configuration drift vs golden baseline</p>
"! A changed table = CONFIG_DRIFT (E), a table without baseline =
"! CONFIG_NO_BASELINE (W). Metric DRIFTED_TABLES. The baseline is taken by
"! the morning report action "take config baseline" after an approved
"! transport (ZCL_CD_HCK_ENGINE=>TAKE_BASELINE).
CLASS zcl_cd_hck_c_config_drift DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'DRIFTED_TABLES'.

ENDCLASS.



CLASS zcl_cd_hck_c_config_drift IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lv_drifted TYPE i.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lt_baselines) = lo_dao->get_baselines( ).

    DATA(lt_tables) = lo_dao->get_drift_tables( ).
    LOOP AT lt_tables INTO DATA(ls_table).
      " A18: hashing is per table - stop between tables once the time budget is used up
      IF zcl_cd_hck_budget=>exhausted( is_context ) = abap_true.
        INSERT zcl_cd_hck_budget=>stop_finding( iv_check_id = is_def-check_id
                                                iv_done     = sy-tabix - 1
                                                iv_total    = lines( lt_tables )
                                                is_context  = is_context ) INTO TABLE rs_result-findings.
        EXIT.
      ENDIF.
      TRY.
          DATA(ls_current) = lo_dao->compute_table_hash( ls_table-tabname ).
        CATCH zcx_cd_ops_error INTO DATA(lx_hash).
          INSERT VALUE #( object_key = ls_table-tabname
                          check_code = zif_cd_hck_types=>gc_code-config_drift
                          severity   = zif_cd_ops_types=>gc_severity-error
                          action     = zif_cd_ops_types=>gc_action-notify
                          message    = lx_hash->get_text( ) ) INTO TABLE rs_result-findings.
          CONTINUE.
      ENDTRY.
      READ TABLE lt_baselines INTO DATA(ls_baseline) WITH KEY by_table COMPONENTS tabname = ls_table-tabname.
      IF sy-subrc <> 0.
        INSERT VALUE #( object_key = ls_table-tabname
                        check_code = zif_cd_hck_types=>gc_code-no_baseline
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-table_has_no_configuration
                                                            iv_v1    = ls_table-tabname ) )
          INTO TABLE rs_result-findings.
        CONTINUE.
      ENDIF.
      " A57: a baseline of another hash version cannot be compared - retake it, no false drift
      IF ls_baseline-hash_version <> ls_current-hash_version.
        INSERT VALUE #( object_key = ls_table-tabname
                        check_code = zif_cd_hck_types=>gc_code-baseline_outdated
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-baseline_outdated
                                                            iv_v1    = ls_table-tabname
                                                            iv_v2    = ls_baseline-hash_version
                                                            iv_v3    = ls_current-hash_version ) )
          INTO TABLE rs_result-findings.
        CONTINUE.
      ENDIF.
      IF ls_baseline-hash = ls_current-hash.
        CONTINUE.
      ENDIF.
      lv_drifted = lv_drifted + 1.
      INSERT VALUE #( object_key = ls_table-tabname
                      check_code = zif_cd_hck_types=>gc_code-config_drift
                      severity   = zif_cd_ops_types=>gc_severity-error
                      action     = zif_cd_ops_types=>gc_action-exception
                      reference  = ls_baseline-taken_by
                      message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-config_drift
                                                          iv_v1    = ls_table-tabname
                                                          iv_v2    = |{ ls_baseline-taken_at TIMESTAMP = ISO }|
                                                          iv_v3    = ls_baseline-taken_by
                                                          iv_v4    = |{ ls_baseline-row_count } -> { ls_current-row_count }| )
                      ) INTO TABLE rs_result-findings.
    ENDLOOP.
    INSERT VALUE #( metric = gc_metric dim1 = zif_cd_hck_types=>gc_default_key value = lv_drifted )
      INTO TABLE rs_result-metrics.
  ENDMETHOD.

ENDCLASS.
