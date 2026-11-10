*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_check_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the check registry SQL on cl_osql_test_environment doubles:
*& active checks of an area and schedule group in sequence, active processes,
*& active aggregate rows of a check, the approved-table list by key, checks
*& covered by an active control (GROUP2 rows only), areas of active alert
*& rules, and one aggregate on the database (COUNT per company code of the
*& open findings of a doubled ZCA_OPS_FINDING; S_TABU_NAM through an
*& authorisation double; an unapproved table refused 086). Does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
CLASS ltd_table_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_table_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~may_read_table.
    rv_allowed = abap_true.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_check_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area     TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        other    TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_B',
        group    TYPE zif_ca_ops_chk_types=>ty_sched_group VALUE 'DAILY',
        first    TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_FIRST',
        second   TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_SECOND',
        inactive TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_INACTIVE',
        process  TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_PROCESS',
        control  TYPE zif_ca_ops_ctl_types=>ty_control_id VALUE 'ZT_CONTROL',
        agg_id   TYPE zif_ca_ops_chk_types=>ty_agg_id VALUE 'R1',
        table    TYPE zif_ca_ops_chk_types=>ty_tabname VALUE 'ZCA_OPS_FINDING',
        company  TYPE bukrs VALUE '1000',
        other_cc TYPE bukrs VALUE '2000',
        today    TYPE d VALUE '20261110',
        run_id   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000B1',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_check_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS given_check
      IMPORTING
        iv_area     TYPE zif_ca_ops_types=>ty_area
        iv_check_id TYPE zif_ca_ops_chk_types=>ty_check_id
        iv_seq      TYPE i
        iv_active   TYPE abap_bool DEFAULT abap_true.
    METHODS given_finding
      IMPORTING
        iv_no          TYPE i
        iv_bukrs       TYPE bukrs
        iv_disposition TYPE zif_ca_ops_types=>ty_disposition.

    METHODS checks_of_area_and_group  FOR TESTING.
    METHODS active_processes_only     FOR TESTING.
    METHODS aggregates_of_the_check   FOR TESTING.
    METHODS approved_table_by_key     FOR TESTING.
    METHODS covered_by_active_control FOR TESTING.
    METHODS alert_areas_distinct      FOR TESTING.
    METHODS count_per_company_code    FOR TESTING.
    METHODS unapproved_table_refused  FOR TESTING.
ENDCLASS.


CLASS ltc_check_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCA_OPS_CHECK' ) ( 'ZCA_OPS_PROC' ) ( 'ZCA_OPS_AGG' ) ( 'ZCA_OPS_TABWL' )
                                   ( 'ZCA_OPS_CTLCHK' ) ( 'ZCA_OPS_CONTROL' ) ( 'ZCA_OPS_ALRULE' )
                                   ( 'ZCA_OPS_FINDING' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    zcl_ca_ops_injector=>inject_auth( NEW ltd_table_auth( ) ).
    mo_cut = NEW zcl_ca_ops_check_dao( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD given_check.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_check WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_check.
    ls_row-area        = iv_area.
    ls_row-check_id    = iv_check_id.
    ls_row-process_id  = gc-process.
    ls_row-sched_group = gc-group.
    ls_row-seq         = iv_seq.
    ls_row-active      = iv_active.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD given_finding.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_finding.
    ls_row-run_id      = gc-run_id.
    ls_row-finding_no  = iv_no.
    ls_row-area        = gc-area.
    ls_row-bukrs       = iv_bukrs.
    ls_row-disposition = iv_disposition.
    ls_row-severity    = zif_ca_ops_types=>gc_severity-error.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Rule: active checks of the area and group only, in sequence
  METHOD checks_of_area_and_group.
    TRY.
        given_check( iv_area = gc-area iv_check_id = gc-second iv_seq = 20 ).
        given_check( iv_area = gc-area iv_check_id = gc-first iv_seq = 10 ).
        given_check( iv_area = gc-area iv_check_id = gc-inactive iv_seq = 5 iv_active = abap_false ).
        given_check( iv_area = gc-other iv_check_id = gc-first iv_seq = 1 ).
        DATA(lt_checks) = mo_cut->get_checks( iv_area = gc-area iv_sched_group = gc-group ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_checks ) exp = 2 msg = 'Two active checks of the area' ).
        cl_abap_unit_assert=>assert_equals( act = lt_checks[ 1 ]-check_id exp = gc-first msg = 'In sequence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: inactive processes are not onboarded (not checked)
  METHOD active_processes_only.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_proc WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_proc.
    TRY.
        ls_row-area       = gc-area.
        ls_row-process_id = gc-process.
        ls_row-active     = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-area   = gc-other.
        ls_row-active = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_processes) = mo_cut->get_processes( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_processes ) exp = 1 msg = 'One active process' ).
        cl_abap_unit_assert=>assert_equals( act = lt_processes[ 1 ]-area exp = gc-area msg = 'The active one' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the active rows of the asked check only
  METHOD aggregates_of_the_check.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_agg WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_agg.
    TRY.
        ls_row-area     = gc-area.
        ls_row-check_id = gc-first.
        ls_row-agg_id   = gc-agg_id.
        ls_row-tabname  = gc-table.
        ls_row-active   = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-check_id = gc-second.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-check_id = gc-first.
        ls_row-agg_id   = 'R2'.
        ls_row-active   = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_aggs) = mo_cut->get_aggregates( iv_area = gc-area iv_check_id = gc-first ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_aggs ) exp = 1 msg = 'One active row of the check' ).
        cl_abap_unit_assert=>assert_equals( act = lt_aggs[ 1 ]-tabname exp = gc-table msg = 'With its table' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: approved = an active row for the area and table (case of the name ignored)
  METHOD approved_table_by_key.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_tabwl WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_tabwl.
    TRY.
        ls_row-area       = gc-area.
        ls_row-table_name = gc-table.
        ls_row-active     = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->is_table_approved( iv_area = gc-area iv_tabname = 'zca_ops_finding' )
                                          msg = 'Approved for the area' ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->is_table_approved( iv_area = gc-other iv_tabname = gc-table )
                                           msg = 'Not approved for another area' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a check is covered by a GROUP2 row of an active control only
  METHOD covered_by_active_control.
    DATA lt_controls TYPE STANDARD TABLE OF zca_ops_control WITH EMPTY KEY.
    DATA ls_control TYPE zca_ops_control.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_ctlchk WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_ctlchk.
    TRY.
        ls_control-area       = gc-area.
        ls_control-control_id = gc-control.
        ls_control-active     = abap_true.
        INSERT ls_control INTO TABLE lt_controls.
        ls_control-control_id = 'ZT_INACTIVE'.
        ls_control-active     = abap_false.
        INSERT ls_control INTO TABLE lt_controls.
        go_env->insert_test_data( lt_controls ).
        ls_row-area        = gc-area.
        ls_row-control_id  = gc-control.
        ls_row-check_area  = gc-area.
        ls_row-match_field = zif_ca_ops_ctl_types=>gc_match_field-group2.
        ls_row-match_value = gc-first.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-match_field = zif_ca_ops_ctl_types=>gc_match_field-rule_id.
        ls_row-match_value = gc-second.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-control_id  = 'ZT_INACTIVE'.
        ls_row-match_field = zif_ca_ops_ctl_types=>gc_match_field-group2.
        ls_row-match_value = gc-inactive.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->get_covered_checks( )
          exp = VALUE zif_ca_ops_chk_types=>tt_covered( ( area = gc-area check_id = gc-first ) )
          msg = 'GROUP2 rows of active controls only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: areas of active alert rules, each once
  METHOD alert_areas_distinct.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_alrule WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_alrule.
    TRY.
        ls_row-rule_id = 'ZT_ONE'.
        ls_row-area    = gc-area.
        ls_row-active  = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = 'ZT_TWO'.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-rule_id = 'ZT_OFF'.
        ls_row-area    = gc-other.
        ls_row-active  = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_alert_areas( )
                                            exp = VALUE zif_ca_ops_chk_types=>tt_area( ( gc-area ) )
                                            msg = 'One area, active rules only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: COUNT on the database per company code, status condition applied (VERIFY: dynamic FROM on a double)
  METHOD count_per_company_code.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_tabwl WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_tabwl.
    DATA ls_agg TYPE zif_ca_ops_chk_types=>ty_agg.
    TRY.
        ls_row-area       = gc-area.
        ls_row-table_name = gc-table.
        ls_row-active     = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        given_finding( iv_no = 1 iv_bukrs = gc-company iv_disposition = zif_ca_ops_types=>gc_disposition-open ).
        given_finding( iv_no = 2 iv_bukrs = gc-company iv_disposition = zif_ca_ops_types=>gc_disposition-open ).
        given_finding( iv_no = 3 iv_bukrs = gc-other_cc iv_disposition = zif_ca_ops_types=>gc_disposition-open ).
        given_finding( iv_no = 4 iv_bukrs = gc-other_cc iv_disposition = zif_ca_ops_types=>gc_disposition-resolved ).
        ls_agg-area         = gc-area.
        ls_agg-check_id     = gc-first.
        ls_agg-agg_id       = gc-agg_id.
        ls_agg-tabname      = gc-table.
        ls_agg-agg_func     = zif_ca_ops_chk_types=>gc_agg_func-count.
        ls_agg-bukrs_field  = 'BUKRS'.
        ls_agg-status_field = 'DISPOSITION'.
        ls_agg-status_op    = zif_ca_ops_chk_types=>gc_operator-eq.
        ls_agg-status_value = zif_ca_ops_types=>gc_disposition-open.
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->aggregate( is_agg = ls_agg iv_bukrs_aware = abap_true iv_today = gc-today )
          exp = VALUE zif_ca_ops_chk_types=>tt_agg_row( ( company_code = gc-company row_count = 2 )
                                                        ( company_code = gc-other_cc row_count = 1 ) )
          msg = 'Open rows per company code' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a table not approved for the area is never read (086)
  METHOD unapproved_table_refused.
    DATA ls_agg TYPE zif_ca_ops_chk_types=>ty_agg.
    ls_agg-area     = gc-area.
    ls_agg-agg_id   = gc-agg_id.
    ls_agg-tabname  = gc-table.
    ls_agg-agg_func = zif_ca_ops_chk_types=>gc_agg_func-count.
    TRY.
        mo_cut->aggregate( is_agg = ls_agg iv_bukrs_aware = abap_false iv_today = gc-today ).
        cl_abap_unit_assert=>fail( msg = 'An unapproved table must be refused' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '086' msg = 'Message 086' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
