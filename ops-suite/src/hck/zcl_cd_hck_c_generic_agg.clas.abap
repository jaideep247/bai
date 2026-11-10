*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_generic_agg.clas.abap
*& Purpose:
*& Generic aggregate check: COUNT/SUM with aging, grouping and up to three
*& conditions, defined only in ZCD_HCK_AGG (new checks by customizing).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Stops between aggregates when the time budget is used up (audit A18).
*& 2026-11-06 | Expected groups (ZCD_HCK_AGGGRP) measure zero when silent (audit A103).
*& 2026-11-08 | Table consolidation: expected groups from ZCD_HCK_AGG-EXPECTED_GROUPS, parsed once per
*&            | aggregate (was ZCD_HCK_AGGGRP).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - generic aggregate check (ZCD_HCK_AGG)</p>
"! One metric per ZCD_HCK_AGG row and group value (METRIC = AGG_ID,
"! DIM1 = group value). Thresholds per company code come from
"! ZCD_HCK_THRESH and are evaluated by the engine. An invalid row gives an
"! AGG_CONFIG_INVALID error finding; the other rows are still measured.
"! Example (acceptance test 1): return debits aging > 10 days by company code.
CLASS zcl_cd_hck_c_generic_agg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

ENDCLASS.



CLASS zcl_cd_hck_c_generic_agg IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lt_defs) = lo_dao->get_agg_defs( is_def-check_id ).
    IF lt_defs IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e310(zcd_ops) WITH is_def-check_id.
    ENDIF.
    LOOP AT lt_defs INTO DATA(ls_agg).
      " A18: stop between aggregates once the check's time budget is used up
      IF zcl_cd_hck_budget=>exhausted( is_context ) = abap_true.
        INSERT zcl_cd_hck_budget=>stop_finding( iv_check_id = is_def-check_id
                                                iv_done     = sy-tabix - 1
                                                iv_total    = lines( lt_defs )
                                                is_context  = is_context ) INTO TABLE rs_result-findings.
        EXIT.
      ENDIF.
      TRY.
          " A103: expected groups (ZCD_HCK_AGG-EXPECTED_GROUPS, parsed once) without rows measure 0
          INSERT LINES OF zcl_cd_hck_agg_query=>measure(
            is_def      = ls_agg
            iv_ref_date = is_context-report_date
            io_dao      = lo_dao
            it_expected = zcl_cd_hck_agg_query=>expected_groups( ls_agg-expected_groups ) )
            INTO TABLE rs_result-metrics.
        CATCH zcx_ca_ops_error INTO DATA(lx_config).
          INSERT VALUE #( object_key = |{ is_def-check_id }/{ ls_agg-agg_id }|
                          check_code = zif_cd_hck_types=>gc_code-agg_invalid
                          severity   = zif_ca_ops_types=>gc_severity-error
                          action     = zif_ca_ops_types=>gc_action-notify
                          reference  = ls_agg-tabname
                          message    = lx_config->get_text( ) ) INTO TABLE rs_result-findings.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
