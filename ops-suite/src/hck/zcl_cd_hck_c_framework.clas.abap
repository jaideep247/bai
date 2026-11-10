*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_framework.clas.abap
*& Purpose:
*& Adapter of the framework's check contract to the health check (process
*& onboarding, 2026-11-10): a ZCD_HCK_DEF row with this class runs any
*& check of the operations framework (ZIF_CA_OPS_CHECK, PARAM1 = its class,
*& e.g. the onboarding check ZCL_CA_OPS_CHK_ONBOARD or the no-code aggregate
*& check ZCL_CA_OPS_CHK_AGG) inside the morning report: the engine gives it
*& its time budget, thresholds of its metrics (none), suppressions, scoring,
*& persistence (GROUP2 = HCK check ID) and the report e-mail. PARAM2 = area
*& of the framework registry rows the check reads (aggregate rows; blank =
*& CD_HCK). A partial framework result is a PARTIAL check. Reads nothing
*& itself; does not change the framework check.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding: the suite adopts the framework check contract).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - framework check adapter (ZIF_CA_OPS_CHECK)</p>
"! Example (config/hck_seed.md): D_PROC_ONBOARD, PARAM1 = ZCL_CA_OPS_CHK_ONBOARD - every registered
"! business process integrated end to end, reported every morning.
CLASS zcl_cd_hck_c_framework DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

ENDCLASS.



CLASS zcl_cd_hck_c_framework IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    " the factory checks the framework interface by RTTI before the class is created (message 032)
    DATA(lo_check) = CAST zif_ca_ops_check( zcl_ca_ops_factory=>get_plugin(
                       iv_class_name = CONV #( is_def-param1 )
                       iv_interface  = zif_ca_ops_chk_types=>gc_check_intf ) ).
    DATA(lv_area) = COND zif_ca_ops_types=>ty_area( WHEN is_def-param2 IS INITIAL
                                                    THEN zif_cd_ops_types=>gc_pe_area-health_check
                                                    ELSE CONV #( is_def-param2 ) ).
    DATA(ls_result) = lo_check->run(
      is_check   = VALUE #( area        = lv_area
                            check_id    = is_def-check_id
                            description = is_def-description
                            class_name  = CONV #( is_def-param1 )
                            active      = abap_true )
      is_context = VALUE #( area      = lv_area
                            run_id    = is_context-run_id
                            test_mode = is_context-test_mode
                            today     = is_context-report_date
                            now       = zcl_ca_ops_factory=>get_clock( )->now( ) ) ).
    rs_result-findings = ls_result-findings.
    IF ls_result-partial = abap_true.
      rs_result-completion = zif_cd_hck_types=>gc_completion-partial.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
