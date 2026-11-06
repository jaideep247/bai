*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_config_drift.clas.abap
*& Purpose:
*& Configuration drift: SHA-256 of every table listed in ZCD_HCK_DRIFT
*& compared with the golden baseline in ZCD_HCK_BASELINE.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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

    LOOP AT lo_dao->get_drift_tables( ) INTO DATA(ls_table).
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
      READ TABLE lt_baselines INTO DATA(ls_baseline) WITH KEY tabname = ls_table-tabname.
      IF sy-subrc <> 0.
        INSERT VALUE #( object_key = ls_table-tabname
                        check_code = zif_cd_hck_types=>gc_code-no_baseline
                        severity   = zif_cd_ops_types=>gc_severity-warning
                        action     = zif_cd_ops_types=>gc_action-notify
                        message    = |Table { ls_table-tabname } has no configuration baseline yet| )
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
                      message    = |Table { ls_table-tabname } changed since baseline of | &&
                                   |{ ls_baseline-taken_at TIMESTAMP = ISO } by { ls_baseline-taken_by } | &&
                                   |(rows { ls_baseline-row_count } -> { ls_current-row_count })| ) INTO TABLE rs_result-findings.
    ENDLOOP.
    INSERT VALUE #( metric = gc_metric dim1 = zif_cd_hck_types=>gc_default_key value = lv_drifted )
      INTO TABLE rs_result-metrics.
  ENDMETHOD.

ENDCLASS.
