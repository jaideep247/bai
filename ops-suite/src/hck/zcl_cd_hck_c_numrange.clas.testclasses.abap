*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_numrange.clas.testclasses.abap
*& Purpose:
*& Unit tests of the number range check: usage per interval, amber and red
*& boundaries, NRLEVEL initial, non-numeric limits, object without interval,
*& missing objects / limits, row cap, current and next year. The runtime DAO
*& is a test double from the HCK injector, parameters the delivered
*& in-memory definitions; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (number range exhaustion, morning report).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_intervals TYPE zif_cd_hck_runtime_types=>tt_nr_interval.
    DATA mt_objects TYPE zif_cd_hck_runtime_types=>tt_nr_object.
    DATA mv_year_from TYPE zif_cd_hck_runtime_types=>ty_year.
    DATA mv_year_to TYPE zif_cd_hck_runtime_types=>ty_year.
    DATA mv_max_rows TYPE i.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_number_ranges.
    mt_objects   = it_objects.
    mv_year_from = iv_year_from.
    mv_year_to   = iv_year_to.
    mv_max_rows  = iv_max_rows.
    rt_intervals = mt_intervals.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_numrange DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check   TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_NUMRANGE',
      gc_object  TYPE zif_cd_hck_runtime_types=>ty_nr_object VALUE 'FKK_BELEG',
      gc_other   TYPE zif_cd_hck_runtime_types=>ty_nr_object VALUE 'FKK_PAYRUN',
      gc_objects TYPE zif_cd_hck_types=>ty_param VALUE 'fkk_beleg, FKK_PAYRUN',
      gc_from    TYPE zif_cd_hck_runtime_types=>ty_nr_number VALUE '00000000000000000001',
      gc_to      TYPE zif_cd_hck_runtime_types=>ty_nr_number VALUE '00000000000000000101',
      gc_amber   TYPE zif_cd_hck_types=>ty_value VALUE 85,
      gc_red     TYPE zif_cd_hck_types=>ty_value VALUE 95,
      gc_today   TYPE d VALUE '20261107',
      gc_year    TYPE zif_cd_hck_runtime_types=>ty_year VALUE '2026',
      gc_next    TYPE zif_cd_hck_runtime_types=>ty_year VALUE '2027',
      gc_cap     TYPE i VALUE 2.

    TYPES:
      BEGIN OF ty_flags,
        "! NRLEVEL of the one interval of FKK_BELEG (blank = initial)
        level      TYPE zif_cd_hck_runtime_types=>ty_nr_number,
        both       TYPE abap_bool,
        not_number TYPE abap_bool,
        no_limits  TYPE abap_bool,
        objects    TYPE zif_cd_hck_types=>ty_param,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_runtime_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.
    DATA mt_thresholds TYPE zif_cd_hck_types=>tt_threshold.

    METHODS setup.
    METHODS teardown.
    METHODS usage_measured_per_interval FOR TESTING.
    METHODS below_amber_has_no_finding  FOR TESTING.
    METHODS amber_boundary_warns        FOR TESTING.
    METHODS red_boundary_is_error       FOR TESTING.
    METHODS level_initial_is_zero       FOR TESTING.
    METHODS not_numeric_reported        FOR TESTING.
    METHODS object_without_interval     FOR TESTING.
    METHODS objects_missing_raises      FOR TESTING.
    METHODS limits_missing_warns        FOR TESTING.
    METHODS read_cap_reported           FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      IMPORTING
        iv_objects       TYPE zif_cd_hck_types=>ty_param DEFAULT gc_objects
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
    METHODS finding
      IMPORTING
        is_result         TYPE zif_cd_hck_types=>ty_check_result
        iv_code           TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.
ENDCLASS.


CLASS ltc_numrange IMPLEMENTATION.

  METHOD setup.
    DATA ls_threshold TYPE zif_cd_hck_types=>ty_threshold.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    ls_threshold-check_id        = gc_check.
    ls_threshold-metric          = zcl_cd_hck_c_numrange=>gc_metric.
    ls_threshold-bukrs           = zif_cd_hck_types=>gc_default_key.
    ls_threshold-amber           = gc_amber.
    ls_threshold-red             = gc_red.
    ls_threshold-higher_is_worse = abap_true.
    ls_threshold-baseline_mode   = zif_cd_hck_types=>gc_baseline-none.
    INSERT ls_threshold INTO TABLE mt_thresholds.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_params, mt_thresholds.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_interval TYPE zif_cd_hck_runtime_types=>ty_nr_interval.
    ls_interval-object     = gc_object.
    ls_interval-nrrangenr  = '01'.
    ls_interval-toyear     = gc_year.
    ls_interval-fromnumber = gc_from.
    ls_interval-tonumber   = gc_to.
    ls_interval-nrlevel    = is_flags-level.
    IF is_flags-not_number = abap_true.
      ls_interval-tonumber = 'A0000000000000000101'.
    ENDIF.
    INSERT ls_interval INTO TABLE mo_dao->mt_intervals.
    IF is_flags-both = abap_true.
      ls_interval-object    = gc_other.
      ls_interval-toyear    = zif_cd_hck_runtime_types=>gc_nr_no_year.
      ls_interval-tonumber  = gc_to.
      ls_interval-nrlevel   = '00000000000000000011'.
      INSERT ls_interval INTO TABLE mo_dao->mt_intervals.
    ENDIF.
    IF is_flags-no_limits = abap_true.
      CLEAR mt_thresholds.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA ls_context TYPE zif_cd_hck_types=>ty_context.
    ls_def-check_id        = gc_check.
    ls_def-param1          = iv_objects.
    ls_context-report_date = gc_today.
    ls_context-now_date    = gc_today.
    rs_result = NEW zcl_cd_hck_c_numrange( )->zif_cd_hck_check~execute( is_def        = ls_def
                                                                        it_thresholds = mt_thresholds
                                                                        is_context    = ls_context ).
  ENDMETHOD.


  METHOD finding.
    rs_finding = VALUE #( is_result-findings[ check_code = iv_code ] OPTIONAL ).
  ENDMETHOD.


  " Rule: one level metric per object / subobject / interval / year; usage = (level - from) /
  " (to - from) x 100; the DAO is asked for the configured objects of this and next year
  METHOD usage_measured_per_interval.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    DATA lt_objects TYPE zif_cd_hck_runtime_types=>tt_nr_object.
    TRY.
        configure_scenario( VALUE #( level = '00000000000000000051' both = abap_true ) ).
        INSERT VALUE #( metric = zcl_cd_hck_c_numrange=>gc_metric dim1 = |{ gc_object }//01/{ gc_year }|
                        value  = 50 kind = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = zcl_cd_hck_c_numrange=>gc_metric dim1 = |{ gc_other }//01/0000|
                        value  = 10 kind = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE lt_exp.
        INSERT gc_object INTO TABLE lt_objects.
        INSERT gc_other INTO TABLE lt_objects.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp msg = 'Usage per interval' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Below amber: no finding' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_objects exp = lt_objects
                                            msg = 'Configured objects, condensed and upper case' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_year_from exp = gc_year msg = 'Current year' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_year_to exp = gc_next msg = 'Next year' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: just below the amber limit (84 %) is measured, not reported
  METHOD below_amber_has_no_finding.
    TRY.
        configure_scenario( VALUE #( level = '00000000000000000085' ) ).
        DATA(ls_result) = act( iv_objects = CONV #( gc_object ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 84 msg = '84 % used' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = '84 %: no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: usage equal to amber (85 %) is a warning naming object, interval, usage and numbers left
  METHOD amber_boundary_warns.
    TRY.
        configure_scenario( VALUE #( level = '00000000000000000086' ) ).
        DATA(ls_result) = act( iv_objects = CONV #( gc_object ) ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-nr_usage_high ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = '85 % = amber: warning' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_finding-message
          exp = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-nr_usage
                                       iv_v1    = gc_object
                                       iv_v2    = |/01/{ gc_year }|
                                       iv_v3    = `85`
                                       iv_v4    = `15` )
          msg = 'Object, interval, usage and numbers left' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: usage equal to red (95 %) is an error (HCK_RED alert); level beyond TONUMBER = 100 %
  METHOD red_boundary_is_error.
    TRY.
        configure_scenario( VALUE #( level = '00000000000000000096' ) ).
        DATA(ls_result) = act( iv_objects = CONV #( gc_object ) ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-nr_usage_high )-severity
          exp = zif_cd_ops_types=>gc_severity-error
          msg = '95 % = red: error' ).
        CLEAR mo_dao->mt_intervals.
        configure_scenario( VALUE #( level = '00000000000000000999' ) ).
        ls_result = act( iv_objects = CONV #( gc_object ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 100
                                            msg = 'Level beyond the interval: 100 %' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: NRLEVEL initial = nothing issued yet: 0 %, measured (never skipped)
  METHOD level_initial_is_zero.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = act( iv_objects = CONV #( gc_object ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-metrics ) exp = 1 msg = 'Interval measured' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0 msg = '0 % used' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a limit that is not a number is reported, never converted to a wrong usage
  METHOD not_numeric_reported.
    TRY.
        configure_scenario( VALUE #( level = '00000000000000000051' not_number = abap_true ) ).
        DATA(ls_result) = act( iv_objects = CONV #( gc_object ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-metrics msg = 'No usage measured' ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-nr_not_numeric )-severity
          exp = zif_cd_ops_types=>gc_severity-warning
          msg = 'Not numeric: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a configured object without an internal interval is a warning - nothing evaluated is never green
  METHOD object_without_interval.
    TRY.
        DATA(ls_result) = act( iv_objects = CONV #( gc_other ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-metrics msg = 'No data: no metric' ).
        DATA(ls_finding) = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-nr_no_interval ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'No interval: warning' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = CONV zif_cd_ops_types=>ty_reference( gc_other )
                                            msg = 'Object named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM1 blank is a configuration error of the check (PLUGIN_ERROR), never an empty green
  METHOD objects_missing_raises.
    TRY.
        act( iv_objects = space ).
        cl_abap_unit_assert=>fail( msg = 'Missing objects must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without ZCD_HCK_THRESH limits the usage is measured but not judged - a warning says so
  METHOD limits_missing_warns.
    TRY.
        configure_scenario( VALUE #( level = '00000000000000000099' no_limits = abap_true ) ).
        DATA(ls_result) = act( iv_objects = CONV #( gc_object ) ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-limits_missing )-severity
          exp = zif_cd_ops_types=>gc_severity-warning
          msg = 'Limits missing: warning' ).
        cl_abap_unit_assert=>assert_initial(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-nr_usage_high )
          msg = 'No usage verdict without limits' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a read that reaches HCK_MAX_TECH_ROWS is reported as possibly incomplete
  METHOD read_cap_reported.
    TRY.
        mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-max_tech_rows iv_value = |{ gc_cap }| ).
        configure_scenario( VALUE #( level = '00000000000000000051' both = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_max_rows exp = gc_cap msg = 'Cap passed to the read' ).
        cl_abap_unit_assert=>assert_equals(
          act = finding( is_result = ls_result iv_code = zif_cd_hck_runtime_types=>gc_code-read_capped )-severity
          exp = zif_cd_ops_types=>gc_severity-warning
          msg = 'Cap reached: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
