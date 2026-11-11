*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_onboard.clas.testclasses.abap
*& Purpose:
*& Tests of the onboarding (completeness) check through ZIF_CA_OPS_CHECK~RUN:
*& a fully integrated process raises nothing; each missing piece is its own
*& finding - no check (error), a check without control, no alert rule of the
*& area, no owner or an unknown user, own tables without an active purge
*& target, no role or an inactive area. Doubles of the check registry, the
*& purge registry and the authorisation service (user check) are injected
*& through ZCL_CA_OPS_INJECTOR. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*& 2026-11-11 | Process catalogue (local double of ZIF_CA_OPS_CATALOG, clock double): a process whose
*&            | catalogue process is off is not checked; CAT_NO_CHECK, CHECK_PROC_INACTIVE, CAT_REF_UNKNOWN
*&            | (error) and CAT_DEP_INACTIVE.
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check_dao PARTIALLY IMPLEMENTED.
    DATA mt_processes TYPE zif_ca_ops_chk_types=>tt_process.
    DATA mt_checks TYPE zif_ca_ops_chk_types=>tt_check.
    DATA mt_covered TYPE zif_ca_ops_chk_types=>tt_covered.
    DATA mt_alert_areas TYPE zif_ca_ops_chk_types=>tt_area.
    DATA mv_area_active TYPE abap_bool VALUE abap_true.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_check_dao~get_processes.
    rt_processes = mt_processes.
  ENDMETHOD.
  METHOD zif_ca_ops_check_dao~get_all_checks.
    rt_checks = mt_checks.
  ENDMETHOD.
  METHOD zif_ca_ops_check_dao~get_covered_checks.
    rt_covered = mt_covered.
  ENDMETHOD.
  METHOD zif_ca_ops_check_dao~get_alert_areas.
    rt_areas = mt_alert_areas.
  ENDMETHOD.
  METHOD zif_ca_ops_check_dao~is_area_active.
    rv_active = mv_area_active.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_purge_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_dao PARTIALLY IMPLEMENTED.
    DATA mt_targets TYPE zif_ca_ops_purge_dao=>tt_registry.
ENDCLASS.

CLASS ltd_purge_dao IMPLEMENTATION.
  METHOD zif_ca_ops_purge_dao~get_targets.
    rt_targets = mt_targets.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_catalog DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog PARTIALLY IMPLEMENTED.
    DATA mt_states TYPE zif_ca_ops_cat_types=>tt_state.
    DATA mt_onboarded TYPE zif_ca_ops_cat_types=>tt_onboarded.
    DATA mt_dependencies TYPE zif_ca_ops_cat_types=>tt_dependency.
ENDCLASS.

CLASS ltd_catalog IMPLEMENTATION.
  METHOD zif_ca_ops_catalog~state.
    rs_state = VALUE #( mt_states[ process_id = iv_process_id ]
                        DEFAULT VALUE #( process_id = iv_process_id source = zif_ca_ops_cat_types=>gc_source-unknown ) ).
  ENDMETHOD.
  METHOD zif_ca_ops_catalog~onboarded.
    rt_onboarded = mt_onboarded.
  ENDMETHOD.
  METHOD zif_ca_ops_catalog~active_processes.
    LOOP AT mt_states ASSIGNING FIELD-SYMBOL(<ls_state>) WHERE active = abap_true.
      INSERT VALUE #( process_id = <ls_state>-process_id ) INTO TABLE rt_processes.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_catalog~definition.
    rs_definition-dependencies = FILTER #( mt_dependencies WHERE process_id = iv_process_id ).
  ENDMETHOD.
  METHOD zif_ca_ops_catalog~validate.
    CLEAR rt_problems.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261111070000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261111'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '070000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_known_user TYPE syuname.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~user_exists.
    rv_exists = xsdbool( iv_user = mv_known_user AND iv_user IS NOT INITIAL ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_onboard DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area    TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        process TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_PROCESS',
        check   TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_CHECK',
        owner   TYPE syuname VALUE 'ZT_OWNER',
        role    TYPE zif_ca_ops_chk_types=>ty_role VALUE 'Z_ZT_OPS_OPERATOR',
        target  TYPE zif_ca_ops_chk_types=>ty_purge_target VALUE 'ZT_EVENT',
        cat     TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XX_PAYRUN',
        cat_pre TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XX_LEDGER',
      END OF gc.

    TYPES:
      BEGIN OF ty_flags,
        no_check      TYPE abap_bool,
        not_covered   TYPE abap_bool,
        no_alert_rule TYPE abap_bool,
        unknown_owner TYPE abap_bool,
        own_data      TYPE abap_bool,
        target_active TYPE abap_bool,
        no_role       TYPE abap_bool,
        area_inactive TYPE abap_bool,
        "! The process monitors catalogue process XX_PAYRUN; cat_off = it is switched off today
        in_catalogue  TYPE abap_bool,
        cat_off       TYPE abap_bool,
        cat_unknown   TYPE abap_bool,
        "! XX_PAYRUN depends (hard) on XX_LEDGER, which is not active
        pred_off      TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_purge TYPE REF TO ltd_purge_dao.
    DATA mo_auth TYPE REF TO ltd_auth.
    DATA mo_catalog TYPE REF TO ltd_catalog.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    "! Check codes of the findings of one run
    METHODS codes
      RETURNING
        VALUE(rt_codes) TYPE string_table
      RAISING
        zcx_ca_ops_error.

    METHODS complete_process_is_clean   FOR TESTING.
    METHODS no_check_is_error           FOR TESTING.
    METHODS uncovered_check_reported    FOR TESTING.
    METHODS missing_alert_rule_reported FOR TESTING.
    METHODS unknown_owner_reported      FOR TESTING.
    METHODS own_data_needs_purge        FOR TESTING.
    METHODS active_purge_target_passes  FOR TESTING.
    METHODS no_role_reported            FOR TESTING.
    METHODS inactive_area_reported      FOR TESTING.
    METHODS switched_off_not_expected   FOR TESTING.
    METHODS active_catalogue_monitored  FOR TESTING.
    METHODS unmonitored_catalogue_proc  FOR TESTING.
    METHODS unknown_catalogue_is_error  FOR TESTING.
    METHODS inactive_predecessor        FOR TESTING.
ENDCLASS.


CLASS ltc_onboard IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_purge = NEW #( ).
    mo_auth  = NEW #( ).
    mo_catalog = NEW #( ).
    zcl_ca_ops_injector=>inject_check_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_catalog( mo_catalog ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_ca_ops_injector=>inject_purge_dao( mo_purge ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_process TYPE zif_ca_ops_chk_types=>ty_process.
    ls_process-area         = gc-area.
    ls_process-process_id   = gc-process.
    ls_process-owner        = gc-owner.
    ls_process-auth_role    = COND #( WHEN is_flags-no_role = abap_false THEN gc-role ).
    ls_process-own_data     = is_flags-own_data.
    ls_process-purge_target = COND #( WHEN is_flags-target_active = abap_true THEN gc-target ).
    ls_process-active       = abap_true.
    ls_process-cat_process  = COND #( WHEN is_flags-in_catalogue = abap_true THEN gc-cat ).
    INSERT ls_process INTO TABLE mo_dao->mt_processes.
    INSERT VALUE #( area = gc-area process_id = gc-process cat_process = ls_process-cat_process
                    active = abap_true ) INTO TABLE mo_catalog->mt_onboarded.
    IF is_flags-in_catalogue = abap_true AND is_flags-cat_unknown = abap_false.
      INSERT VALUE #( process_id = gc-cat active = xsdbool( is_flags-cat_off = abap_false )
                      source = zif_ca_ops_cat_types=>gc_source-activation ) INTO TABLE mo_catalog->mt_states.
    ENDIF.
    IF is_flags-pred_off = abap_true.
      INSERT VALUE #( process_id = gc-cat_pre source = zif_ca_ops_cat_types=>gc_source-default )
             INTO TABLE mo_catalog->mt_states.
      INSERT VALUE #( process_id = gc-cat pred_id = gc-cat_pre dep_kind = zif_ca_ops_cat_types=>gc_dep_kind-hard )
             INTO TABLE mo_catalog->mt_dependencies.
    ENDIF.
    IF is_flags-no_check = abap_false.
      INSERT VALUE #( area = gc-area check_id = gc-check process_id = gc-process active = abap_true )
             INTO TABLE mo_dao->mt_checks.
    ENDIF.
    IF is_flags-not_covered = abap_false.
      INSERT VALUE #( area = gc-area check_id = gc-check ) INTO TABLE mo_dao->mt_covered.
    ENDIF.
    IF is_flags-no_alert_rule = abap_false.
      INSERT gc-area INTO TABLE mo_dao->mt_alert_areas.
    ENDIF.
    IF is_flags-target_active = abap_true.
      INSERT VALUE #( target = gc-target ) INTO TABLE mo_purge->mt_targets.
    ENDIF.
    mo_auth->mv_known_user = COND #( WHEN is_flags-unknown_owner = abap_false THEN gc-owner ).
    mo_dao->mv_area_active = xsdbool( is_flags-area_inactive = abap_false ).
  ENDMETHOD.


  METHOD codes.
    DATA(ls_result) = NEW zcl_ca_ops_chk_onboard( )->zif_ca_ops_check~run(
                        is_check   = VALUE #( area = zif_ca_ops_types=>gc_param_area )
                        is_context = VALUE #( area = zif_ca_ops_types=>gc_param_area ) ).
    LOOP AT ls_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      INSERT CONV string( <ls_finding>-check_code ) INTO TABLE rt_codes.
    ENDLOOP.
  ENDMETHOD.


  " Rule: a process with check, control, alert rule, owner, purge and role raises nothing
  METHOD complete_process_is_clean.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = codes( ) msg = 'No gap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a process without an active check is an error (nothing monitors it)
  METHOD no_check_is_error.
    TRY.
        configure_scenario( VALUE #( no_check = abap_true ) ).
        DATA(ls_result) = NEW zcl_ca_ops_chk_onboard( )->zif_ca_ops_check~run( is_check   = VALUE #( )
                                                                              is_context = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One gap' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_ca_ops_chk_types=>gc_code-proc_no_check msg = 'PROC_NO_CHECK' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-error msg = 'Error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key exp = 'ZT_OPS_A/ZT_PROCESS'
                                            msg = 'Object key area / process' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every check of the process is covered by an active control (GROUP2 = check ID)
  METHOD uncovered_check_reported.
    TRY.
        configure_scenario( VALUE #( not_covered = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = codes( )
                                            exp = VALUE string_table( ( `PROC_NO_CONTROL` ) )
                                            msg = 'Uncovered check' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the area of the process has an active alert rule
  METHOD missing_alert_rule_reported.
    TRY.
        configure_scenario( VALUE #( no_alert_rule = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = codes( )
                                            exp = VALUE string_table( ( `PROC_NO_ALERT_RULE` ) )
                                            msg = 'No alert rule' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the owner is a user of this client
  METHOD unknown_owner_reported.
    TRY.
        configure_scenario( VALUE #( unknown_owner = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = codes( )
                                            exp = VALUE string_table( ( `PROC_NO_OWNER` ) )
                                            msg = 'Unknown owner' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a process with own tables names an active purge target
  METHOD own_data_needs_purge.
    TRY.
        configure_scenario( VALUE #( own_data = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = codes( )
                                            exp = VALUE string_table( ( `PROC_NO_PURGE` ) )
                                            msg = 'Own tables without purge target' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an active purge target of the registry covers the own tables
  METHOD active_purge_target_passes.
    TRY.
        configure_scenario( VALUE #( own_data = abap_true target_active = abap_true ) ).
        cl_abap_unit_assert=>assert_initial( act = codes( ) msg = 'Purge covered' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a role granting ZCA_OPS for the area is named
  METHOD no_role_reported.
    TRY.
        configure_scenario( VALUE #( no_role = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = codes( )
                                            exp = VALUE string_table( ( `PROC_NO_AUTH` ) )
                                            msg = 'No role' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the area is an active parameter area (the authorisation field takes it)
  METHOD inactive_area_reported.
    TRY.
        configure_scenario( VALUE #( area_inactive = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = codes( )
                                            exp = VALUE string_table( ( `PROC_NO_AUTH` ) )
                                            msg = 'Inactive area' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  " Rule: a business process whose catalogue process is switched off is not expected - no gap of it; its
  " still active check is reported once (it does not run)
  METHOD switched_off_not_expected.
    TRY.
        configure_scenario( VALUE #( in_catalogue = abap_true cat_off = abap_true no_alert_rule = abap_true ) ).
        DATA(lt_codes) = codes( ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( lt_codes[ table_line = CONV string( zif_ca_ops_chk_types=>gc_code-proc_no_alert ) ] ) )
          msg = 'No onboarding gap of a process that is switched off' ).
        cl_abap_unit_assert=>assert_equals( act = lt_codes
                                            exp = VALUE string_table( ( CONV #( zif_ca_ops_cat_types=>gc_code-check_proc_off ) ) )
                                            msg = 'The active check of the switched-off process is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an active catalogue process monitored by a check in effect raises nothing
  METHOD active_catalogue_monitored.
    TRY.
        configure_scenario( VALUE #( in_catalogue = abap_true ) ).
        cl_abap_unit_assert=>assert_initial( act = codes( ) msg = 'Active, monitored, complete: no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an active catalogue process without a check in effect is reported (CAT_NO_CHECK)
  METHOD unmonitored_catalogue_proc.
    TRY.
        configure_scenario( VALUE #( in_catalogue = abap_true no_check = abap_true ) ).
        DATA(lt_codes) = codes( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_codes[ table_line = CONV string( zif_ca_ops_cat_types=>gc_code-cat_no_check ) ] ) )
          msg = 'Active process without a check in effect' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a business process naming a catalogue process that is not defined is an error
  METHOD unknown_catalogue_is_error.
    TRY.
        configure_scenario( VALUE #( in_catalogue = abap_true cat_unknown = abap_true ) ).
        DATA(ls_result) = NEW zcl_ca_ops_chk_onboard( )->zif_ca_ops_check~run( is_check   = VALUE #( )
                                                                              is_context = VALUE #( ) ).
        DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_cat_types=>gc_code-cat_ref_unknown ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Unknown catalogue reference is an error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = CONV zif_ca_ops_types=>ty_reference( gc-process )
                                            msg = 'The finding names the business process' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an active process whose hard predecessor is not active is reported (CAT_DEP_INACTIVE)
  METHOD inactive_predecessor.
    TRY.
        configure_scenario( VALUE #( in_catalogue = abap_true pred_off = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = codes( )
                                            exp = VALUE string_table( ( CONV #( zif_ca_ops_cat_types=>gc_code-cat_dep_inactive ) ) )
                                            msg = 'Inactive hard predecessor' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
