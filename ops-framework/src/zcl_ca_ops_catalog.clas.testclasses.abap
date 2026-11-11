*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_catalog.clas.testclasses.abap
*& Purpose:
*& Tests of the process catalogue through ZIF_CA_OPS_CATALOG with a data
*& access double (constructor injection): the effective state - delivered
*& default, the latest activation row on or before the day (effective-from
*& dates), a package switched off, an unknown process; the definition with
*& steps, tables, dependencies and monitoring business processes; the
*& business processes of an area not in effect (row inactive or catalogue
*& process off); the rule check (prefix 247, unknown package 248,
*& dependency 249, cycle 250, activation of an unknown process 252 or
*& without reason / approver 253). No database; does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
CLASS ltd_cat_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cat_dao.
    DATA mt_packages TYPE zif_ca_ops_cat_types=>tt_package.
    DATA mt_processes TYPE zif_ca_ops_cat_types=>tt_process.
    DATA mt_steps TYPE zif_ca_ops_cat_types=>tt_step.
    DATA mt_tables TYPE zif_ca_ops_cat_types=>tt_table.
    DATA mt_dependencies TYPE zif_ca_ops_cat_types=>tt_dependency.
    DATA mt_activations TYPE zif_ca_ops_cat_types=>tt_activation.
    DATA mt_onboarded TYPE zif_ca_ops_cat_types=>tt_onboarded.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_cat_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cat_dao~get_packages.
    mv_reads += 1.
    rt_packages = mt_packages.
  ENDMETHOD.
  METHOD zif_ca_ops_cat_dao~get_processes.
    rt_processes = mt_processes.
  ENDMETHOD.
  METHOD zif_ca_ops_cat_dao~get_steps.
    rt_steps = mt_steps.
  ENDMETHOD.
  METHOD zif_ca_ops_cat_dao~get_tables.
    rt_tables = mt_tables.
  ENDMETHOD.
  METHOD zif_ca_ops_cat_dao~get_dependencies.
    rt_dependencies = mt_dependencies.
  ENDMETHOD.
  METHOD zif_ca_ops_cat_dao~get_activations.
    rt_activations = mt_activations.
  ENDMETHOD.
  METHOD zif_ca_ops_cat_dao~get_onboarded.
    rt_onboarded = mt_onboarded.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_catalog DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        pkg_std   TYPE zif_ca_ops_cat_types=>ty_pkg_id VALUE 'FICA',
        pkg_cust  TYPE zif_ca_ops_cat_types=>ty_pkg_id VALUE 'XX',
        payrun    TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'FICA_PAYRUN',
        dunning   TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'FICA_DUNNING',
        ledger    TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'FICA_GL_TRANSFER',
        own       TYPE zif_ca_ops_cat_types=>ty_process_id VALUE 'XX_REQ_LIFE',
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        mon_pay   TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_PAYRUN',
        mon_dun   TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_DUNNING',
        mon_own   TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_OWN',
        mon_off   TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_ROW_OFF',
        approver  TYPE syuname VALUE 'ZT_APPROVER',
        go_live   TYPE d VALUE '20261101',
        switch    TYPE d VALUE '20261201',
        before    TYPE d VALUE '20261031',
        between   TYPE d VALUE '20261115',
        after     TYPE d VALUE '20261215',
        step_no   TYPE zif_ca_ops_cat_types=>ty_step_no VALUE '010',
        program   TYPE zif_ca_ops_cat_types=>ty_obj_name VALUE 'FPY1',
        table     TYPE zif_ca_ops_chk_types=>ty_tabname VALUE 'DPAYH',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_cat_dao.
    DATA mo_cut TYPE REF TO zif_ca_ops_catalog.

    METHODS setup.
    "! Product package FICA (payment run, dunning, G/L transfer), customer package XX (own process)
    METHODS given_catalogue.

    METHODS default_decides_without_row FOR TESTING.
    METHODS latest_row_on_the_day       FOR TESTING.
    METHODS package_off_wins            FOR TESTING.
    METHODS unknown_process_inactive    FOR TESTING.
    METHODS definition_complete         FOR TESTING.
    METHODS inactive_onboarded_of_area  FOR TESTING.
    METHODS active_processes_listed     FOR TESTING.
    METHODS catalogue_read_once         FOR TESTING.
    METHODS clean_catalogue_valid       FOR TESTING.
    METHODS rule_breaks_reported        FOR TESTING.
ENDCLASS.


CLASS ltc_catalog IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_cut = NEW zcl_ca_ops_catalog( mo_dao ).
    given_catalogue( ).
  ENDMETHOD.


  METHOD given_catalogue.
    DATA ls_package TYPE zif_ca_ops_cat_types=>ty_package.
    DATA ls_process TYPE zif_ca_ops_cat_types=>ty_process.
    DATA ls_act TYPE zif_ca_ops_cat_types=>ty_activation.
    DATA ls_onb TYPE zif_ca_ops_cat_types=>ty_onboarded.
    DATA ls_dep TYPE zif_ca_ops_cat_types=>ty_dependency.
    DATA ls_step TYPE zif_ca_ops_cat_types=>ty_step.
    DATA ls_table TYPE zif_ca_ops_cat_types=>ty_table.

    ls_package-pkg_id    = gc-pkg_std.
    ls_package-pkg_kind  = zif_ca_ops_cat_types=>gc_pkg_kind-industry.
    ls_package-pkg_rank  = 20.
    ls_package-id_prefix = 'FICA_'.
    ls_package-active    = abap_true.
    INSERT ls_package INTO TABLE mo_dao->mt_packages.
    ls_package-pkg_id    = gc-pkg_cust.
    ls_package-pkg_kind  = zif_ca_ops_cat_types=>gc_pkg_kind-customer.
    ls_package-pkg_rank  = 100.
    ls_package-id_prefix = 'XX_'.
    INSERT ls_package INTO TABLE mo_dao->mt_packages.

    ls_process-pkg_id      = gc-pkg_std.
    ls_process-process_id  = gc-payrun.
    INSERT ls_process INTO TABLE mo_dao->mt_processes.
    ls_process-process_id  = gc-dunning.
    INSERT ls_process INTO TABLE mo_dao->mt_processes.
    ls_process-process_id  = gc-ledger.
    ls_process-dflt_active = abap_true.
    INSERT ls_process INTO TABLE mo_dao->mt_processes.
    ls_process-pkg_id      = gc-pkg_cust.
    ls_process-process_id  = gc-own.
    ls_process-dflt_active = abap_true.
    INSERT ls_process INTO TABLE mo_dao->mt_processes.

    " Payment run on from the go-live, off again from the switch date; dunning stays off (row)
    ls_act-process_id  = gc-payrun.
    ls_act-pkg_id      = gc-pkg_cust.
    ls_act-approved_by = gc-approver.
    ls_act-reason      = 'Payment run in use'.
    ls_act-valid_from  = gc-go_live.
    ls_act-active      = abap_true.
    INSERT ls_act INTO TABLE mo_dao->mt_activations.
    ls_act-valid_from  = gc-switch.
    ls_act-active      = abap_false.
    ls_act-reason      = 'Payment run replaced'.
    INSERT ls_act INTO TABLE mo_dao->mt_activations.
    ls_act-process_id  = gc-dunning.
    ls_act-valid_from  = gc-go_live.
    ls_act-reason      = 'No dunning at the customer'.
    INSERT ls_act INTO TABLE mo_dao->mt_activations.

    ls_dep-process_id = gc-payrun.
    ls_dep-pred_id    = gc-ledger.
    ls_dep-dep_kind   = zif_ca_ops_cat_types=>gc_dep_kind-soft.
    INSERT ls_dep INTO TABLE mo_dao->mt_dependencies.

    ls_step-process_id = gc-payrun.
    ls_step-step_no    = gc-step_no.
    ls_step-step_kind  = zif_ca_ops_cat_types=>gc_step_kind-transaction.
    ls_step-obj_name   = gc-program.
    INSERT ls_step INTO TABLE mo_dao->mt_steps.
    ls_table-process_id = gc-payrun.
    ls_table-tabname    = gc-table.
    INSERT ls_table INTO TABLE mo_dao->mt_tables.

    ls_onb-area        = gc-area.
    ls_onb-process_id  = gc-mon_pay.
    ls_onb-cat_process = gc-payrun.
    ls_onb-active      = abap_true.
    INSERT ls_onb INTO TABLE mo_dao->mt_onboarded.
    ls_onb-process_id  = gc-mon_dun.
    ls_onb-cat_process = gc-dunning.
    INSERT ls_onb INTO TABLE mo_dao->mt_onboarded.
    ls_onb-process_id  = gc-mon_own.
    ls_onb-cat_process = space.
    INSERT ls_onb INTO TABLE mo_dao->mt_onboarded.
    ls_onb-process_id  = gc-mon_off.
    ls_onb-active      = abap_false.
    INSERT ls_onb INTO TABLE mo_dao->mt_onboarded.
    " a reference to a process that is not in the catalogue: monitoring goes on (fail-open)
    ls_onb-process_id  = 'ZT_TYPO'.
    ls_onb-cat_process = 'FICA_NO_SUCH'.
    ls_onb-active      = abap_true.
    INSERT ls_onb INTO TABLE mo_dao->mt_onboarded.
  ENDMETHOD.


  " Rule: no activation row on or before the day - the delivered default decides
  METHOD default_decides_without_row.
    TRY.
        DATA(ls_payrun) = mo_cut->state( iv_process_id = gc-payrun iv_date = gc-before ).
        cl_abap_unit_assert=>assert_false( act = ls_payrun-active msg = 'Before the go-live: default (off)' ).
        cl_abap_unit_assert=>assert_equals( act = ls_payrun-source exp = zif_ca_ops_cat_types=>gc_source-default
                                            msg = 'Source default' ).
        DATA(ls_ledger) = mo_cut->state( iv_process_id = gc-ledger iv_date = gc-between ).
        cl_abap_unit_assert=>assert_true( act = ls_ledger-active msg = 'Default on, no row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the activation row with the latest VALID_FROM on or before the day decides (effective-from)
  METHOD latest_row_on_the_day.
    TRY.
        DATA(ls_on) = mo_cut->state( iv_process_id = gc-payrun iv_date = gc-between ).
        cl_abap_unit_assert=>assert_true( act = ls_on-active msg = 'Active from the go-live' ).
        cl_abap_unit_assert=>assert_equals( act = ls_on-valid_from exp = gc-go_live msg = 'The deciding row' ).
        cl_abap_unit_assert=>assert_equals( act = ls_on-approved_by exp = gc-approver msg = 'Its approver' ).
        DATA(ls_switch_day) = mo_cut->state( iv_process_id = gc-payrun iv_date = gc-switch ).
        cl_abap_unit_assert=>assert_false( act = ls_switch_day-active msg = 'Off on the switch date itself' ).
        DATA(ls_off) = mo_cut->state( iv_process_id = gc-payrun iv_date = gc-after ).
        cl_abap_unit_assert=>assert_false( act = ls_off-active msg = 'Off after the switch date' ).
        cl_abap_unit_assert=>assert_equals( act = ls_off-source exp = zif_ca_ops_cat_types=>gc_source-activation
                                            msg = 'Source activation row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a package switched off makes its processes inactive whatever their rows say
  METHOD package_off_wins.
    TRY.
        mo_dao->mt_packages[ pkg_id = gc-pkg_std ]-active = abap_false.
        DATA(ls_state) = mo_cut->state( iv_process_id = gc-payrun iv_date = gc-between ).
        cl_abap_unit_assert=>assert_false( act = ls_state-active msg = 'Package off' ).
        cl_abap_unit_assert=>assert_equals( act = ls_state-source exp = zif_ca_ops_cat_types=>gc_source-package
                                            msg = 'Source package' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD unknown_process_inactive.
    TRY.
        DATA(ls_state) = mo_cut->state( iv_process_id = 'FICA_NO_SUCH' iv_date = gc-between ).
        cl_abap_unit_assert=>assert_false( act = ls_state-active msg = 'Unknown process is inactive' ).
        cl_abap_unit_assert=>assert_equals( act = ls_state-source exp = zif_ca_ops_cat_types=>gc_source-unknown
                                            msg = 'Source unknown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the definition carries package, state, steps, tables, dependencies and its monitors (test tool view)
  METHOD definition_complete.
    TRY.
        DATA(ls_def) = mo_cut->definition( iv_process_id = gc-payrun iv_date = gc-between ).
        cl_abap_unit_assert=>assert_equals( act = ls_def-package-pkg_id exp = gc-pkg_std msg = 'Package' ).
        cl_abap_unit_assert=>assert_true( act = ls_def-state-active msg = 'State of the day' ).
        cl_abap_unit_assert=>assert_equals( act = ls_def-steps[ 1 ]-obj_name exp = gc-program msg = 'Step' ).
        cl_abap_unit_assert=>assert_equals( act = ls_def-tables[ 1 ]-tabname exp = gc-table msg = 'Table' ).
        cl_abap_unit_assert=>assert_equals( act = ls_def-dependencies[ 1 ]-pred_id exp = gc-ledger msg = 'Dependency' ).
        cl_abap_unit_assert=>assert_equals( act = ls_def-monitors[ 1 ]-process_id exp = gc-mon_pay msg = 'Monitor' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_def-monitors ) exp = 1 msg = 'Only its own monitor' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->definition( iv_process_id = 'FICA_NO_SUCH'
                                                                       iv_date       = gc-between )
                                             msg = 'Unknown process: initial' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: not in effect = the row is inactive or its catalogue process is off; no catalogue process = the row;
  " an unknown catalogue process does not stop monitoring (fail-open)
  METHOD inactive_onboarded_of_area.
    TRY.
        DATA(lt_off) = mo_cut->inactive_onboarded( iv_area = gc-area iv_date = gc-between ).
        cl_abap_unit_assert=>assert_equals(
          act = lt_off
          exp = VALUE zif_ca_ops_cat_types=>tt_process_ids( ( gc-mon_dun ) ( gc-mon_off ) )
          msg = 'Dunning (catalogue off) and the inactive row; payment run, own process and unknown reference run' ).
        DATA(lt_later) = mo_cut->inactive_onboarded( iv_area = gc-area iv_date = gc-after ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_later[ table_line = gc-mon_pay ] ) )
                                          msg = 'Payment run monitoring off after the switch date' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->inactive_onboarded( iv_area = 'ZT_OTHER' iv_date = gc-between )
                                             msg = 'Another area has none' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD active_processes_listed.
    TRY.
        DATA(lt_active) = mo_cut->active_processes( gc-between ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_active ) exp = 3 msg = 'Payment run, G/L transfer, own' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_active[ process_id = gc-dunning ] ) )
                                           msg = 'Dunning switched off' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD catalogue_read_once.
    TRY.
        mo_cut->states( gc-between ).
        mo_cut->active_processes( gc-after ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_reads exp = 1 msg = 'One read of the catalogue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD clean_catalogue_valid.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->validate( ) msg = 'No rule broken' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: prefix, package, dependency, cycle and activation rules each reported with their message
  METHOD rule_breaks_reported.
    DATA ls_process TYPE zif_ca_ops_cat_types=>ty_process.
    DATA ls_dep TYPE zif_ca_ops_cat_types=>ty_dependency.
    DATA ls_act TYPE zif_ca_ops_cat_types=>ty_activation.
    DATA lt_msgnos TYPE string_table.
    TRY.
        ls_process-pkg_id     = gc-pkg_std.
        ls_process-process_id = 'XX_WRONG_PREFIX'.
        INSERT ls_process INTO TABLE mo_dao->mt_processes.
        ls_process-pkg_id     = 'NOPKG'.
        ls_process-process_id = 'NOPKG_PROCESS'.
        INSERT ls_process INTO TABLE mo_dao->mt_processes.
        " a product process may not depend on a customer process (higher package)
        ls_dep-process_id = gc-ledger.
        ls_dep-pred_id    = gc-own.
        INSERT ls_dep INTO TABLE mo_dao->mt_dependencies.
        " cycle: G/L transfer <- payment run <- G/L transfer
        ls_dep-process_id = gc-ledger.
        ls_dep-pred_id    = gc-payrun.
        INSERT ls_dep INTO TABLE mo_dao->mt_dependencies.
        ls_act-process_id = 'FICA_NO_SUCH'.
        ls_act-valid_from = gc-go_live.
        ls_act-reason     = 'Unknown'.
        ls_act-approved_by = gc-approver.
        INSERT ls_act INTO TABLE mo_dao->mt_activations.
        ls_act-process_id = gc-ledger.
        CLEAR ls_act-approved_by.
        INSERT ls_act INTO TABLE mo_dao->mt_activations.
        LOOP AT mo_cut->validate( ) ASSIGNING FIELD-SYMBOL(<ls_problem>).
          INSERT CONV string( <ls_problem>-msgno ) INTO TABLE lt_msgnos.
        ENDLOOP.
        SORT lt_msgnos.
        DELETE ADJACENT DUPLICATES FROM lt_msgnos.
        cl_abap_unit_assert=>assert_equals(
          act = lt_msgnos
          exp = VALUE string_table( ( `247` ) ( `248` ) ( `249` ) ( `250` ) ( `252` ) ( `253` ) )
          msg = 'Prefix, package, dependency, cycle, unknown and incomplete activation' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
