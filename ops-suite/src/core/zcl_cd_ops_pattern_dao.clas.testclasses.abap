*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pattern_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the pattern check and migration repository: active patterns
*& with their source, job-name lists of the technical job checks, distinct
*& values in the date window with the row cap, XBLNR of configured accounts
*& only, finding keys of HCK runs in the window, migration rows with key and
*& field length (pattern-list parameters of the listed check classes only),
*& write of converted patterns (key field PATTERN re-keyed, change stamp).
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: pattern check and migration).
*& 2026-11-10 | migration_rows_of_areas_only: tables of areas outside IT_PE_AREAS are not read (B7).
*&---------------------------------------------------------------------*
CLASS ltc_pattern_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        from      TYPE d VALUE '20261101',
        to        TYPE d VALUE '20261106',
        in_window TYPE d VALUE '20261105',
        before    TYPE d VALUE '20261020',
        run_in    TYPE timestampl VALUE '20261105070000.0000000',
        run_out   TYPE timestampl VALUE '20261020070000.0000000',
        file_a    TYPE c LENGTH 30 VALUE 'ACH_PNC_20261105_01',
        file_b    TYPE c LENGTH 30 VALUE 'POSPAY_BOA_20261105',
        file_old  TYPE c LENGTH 30 VALUE 'ACH_PNC_20261020_01',
        cp_flow   TYPE c LENGTH 30 VALUE 'ACH*',
        pcre_flow TYPE c LENGTH 30 VALUE 'ACH.*',
        iface     TYPE c LENGTH 20 VALUE 'ACH_PNC_OUT',
        descr     TYPE c LENGTH 60 VALUE 'ACH PNC outbound',
        cp_iface  TYPE c LENGTH 30 VALUE 'ACH_PNC_*',
        check_job TYPE c LENGTH 20 VALUE 'E_TECH_JOBS',
        check_vol TYPE c LENGTH 20 VALUE 'A_VOLUME',
        job_list  TYPE c LENGTH 40 VALUE 'ZCD_PAYM_.*, ZCD_POST_GL',
        bukrs     TYPE c LENGTH 4 VALUE 'US01',
        hbkid     TYPE c LENGTH 5 VALUE 'JPMC1',
        hktid     TYPE c LENGTH 5 VALUE 'OPER1',
        other_bk  TYPE c LENGTH 5 VALUE 'BOA01',
        xblnr_in  TYPE c LENGTH 16 VALUE 'JPMC8XX117441233',
        xblnr_out TYPE c LENGTH 16 VALUE 'BOA9999999999999',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_pattern_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS insert_config.

    METHODS active_patterns_with_source  FOR TESTING.
    METHODS job_lists_are_job_patterns   FOR TESTING.
    METHODS file_values_distinct_capped  FOR TESTING.
    METHODS xblnr_of_configured_accounts FOR TESTING.
    METHODS finding_keys_of_hck_runs     FOR TESTING.
    METHODS migration_rows_key_length    FOR TESTING.
    METHODS write_rekeys_and_updates     FOR TESTING.
    METHODS migration_rows_of_areas_only FOR TESTING.
    METHODS all_areas
      RETURNING
        VALUE(rt_areas) TYPE zif_cd_ops_pattern_types=>tt_pe_area.
ENDCLASS.


CLASS ltc_pattern_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_EBS_FLOW_PAT' ) ( 'ZCD_FMON_IFACE' ) ( 'ZCD_JOB_STEP' )
                                   ( 'ZCD_OPS_ALRULE' ) ( 'ZCD_HCK_DEF' ) ( 'ZCD_HCK_SUPPRESS' )
                                   ( 'ZCD_FMON_FILE' ) ( 'TBTCO' ) ( 'ZCD_OPS_FINDING' ) ( 'ZCD_OPS_RUN' )
                                   ( 'FEBEP' ) ( 'FEBKO' ) ( 'ZCD_EBS_ACCT' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    insert_config( ).
    mo_cut = NEW zcl_cd_ops_pattern_dao( ).
  ENDMETHOD.


  METHOD insert_config.
    DATA lt_flow TYPE STANDARD TABLE OF zcd_ebs_flow_pat WITH EMPTY KEY.
    DATA ls_flow TYPE zcd_ebs_flow_pat.
    DATA lt_iface TYPE STANDARD TABLE OF zcd_fmon_iface WITH EMPTY KEY.
    DATA ls_iface TYPE zcd_fmon_iface.
    DATA lt_def TYPE STANDARD TABLE OF zcd_hck_def WITH EMPTY KEY.
    DATA ls_def TYPE zcd_hck_def.

    ls_flow-priority  = 10.
    ls_flow-pattern   = gc_test-cp_flow.
    ls_flow-flow_type = 'D'.
    ls_flow-active    = abap_true.
    INSERT ls_flow INTO TABLE lt_flow.
    ls_flow-priority  = 20.
    ls_flow-pattern   = 'OLD*'.
    ls_flow-active    = abap_false.
    INSERT ls_flow INTO TABLE lt_flow.
    go_env->insert_test_data( lt_flow ).

    ls_iface-iface_id     = gc_test-iface.
    ls_iface-name_pattern = gc_test-cp_iface.
    ls_iface-description  = gc_test-descr.
    ls_iface-min_bytes    = 100.
    ls_iface-active       = abap_true.
    INSERT ls_iface INTO TABLE lt_iface.
    go_env->insert_test_data( lt_iface ).

    ls_def-check_id   = gc_test-check_job.
    ls_def-class_name = zif_cd_ops_pattern_types=>gc_list_class-tech_jobs.
    ls_def-active     = abap_true.
    ls_def-param1     = gc_test-job_list.
    INSERT ls_def INTO TABLE lt_def.
    " A check whose PARAM1 is a number, not a pattern list: never in scope
    ls_def-check_id   = gc_test-check_vol.
    ls_def-class_name = 'ZCL_CD_HCK_C_VOLUME'.
    ls_def-param1     = '1'.
    INSERT ls_def INTO TABLE lt_def.
    go_env->insert_test_data( lt_def ).
  ENDMETHOD.


  " Only active patterns are checked; the source names table and key
  METHOD active_patterns_with_source.
    TRY.
        DATA(lt_patterns) = mo_cut->get_patterns( zif_cd_ops_pattern_types=>gc_area-ebs_flow ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_patterns ) exp = 1 msg = 'Only the active pattern' ).
        cl_abap_unit_assert=>assert_equals( act = lt_patterns[ 1 ]-pattern exp = CONV string( gc_test-cp_flow )
                                            msg = 'Pattern as maintained' ).
        cl_abap_unit_assert=>assert_equals( act = lt_patterns[ 1 ]-source exp = `ZCD_EBS_FLOW_PAT 10`
                                            msg = 'Source names table and priority' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The job-name list of a technical job check counts as one pattern per list item
  METHOD job_lists_are_job_patterns.
    TRY.
        DATA(lt_patterns) = mo_cut->get_patterns( zif_cd_ops_pattern_types=>gc_area-hck_job ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_patterns ) exp = 2 msg = 'Two list items' ).
        cl_abap_unit_assert=>assert_equals( act = lt_patterns[ 2 ]-pattern exp = `ZCD_POST_GL`
                                            msg = 'Second item of PARAM1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Distinct file names of the window, ascending, at most the row cap
  METHOD file_values_distinct_capped.
    DATA lt_files TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.
    DATA ls_file TYPE zcd_fmon_file.
    TRY.
        ls_file-file_id       = '000000000000000000000000000000A1'.
        ls_file-file_name     = gc_test-file_a.
        ls_file-business_date = gc_test-in_window.
        INSERT ls_file INTO TABLE lt_files.
        ls_file-file_id       = '000000000000000000000000000000A2'.
        INSERT ls_file INTO TABLE lt_files.
        ls_file-file_id       = '000000000000000000000000000000B1'.
        ls_file-file_name     = gc_test-file_b.
        INSERT ls_file INTO TABLE lt_files.
        ls_file-file_id       = '000000000000000000000000000000C1'.
        ls_file-file_name     = gc_test-file_old.
        ls_file-business_date = gc_test-before.
        INSERT ls_file INTO TABLE lt_files.
        go_env->insert_test_data( lt_files ).
        DATA(lt_values) = mo_cut->get_values( iv_area     = zif_cd_ops_pattern_types=>gc_area-fmon_file
                                              iv_from     = gc_test-from
                                              iv_to       = gc_test-to
                                              iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_values ) exp = 2
                                            msg = 'Two distinct names in the window' ).
        lt_values = mo_cut->get_values( iv_area     = zif_cd_ops_pattern_types=>gc_area-fmon_file
                                        iv_from     = gc_test-from
                                        iv_to       = gc_test-to
                                        iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lt_values[ 1 ] exp = CONV string( gc_test-file_a )
                                            msg = 'Row cap keeps the first name in order' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_values ) exp = 1 msg = 'Row cap applied' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " EBS: XBLNR of statements of active configured accounts only
  METHOD xblnr_of_configured_accounts.
    DATA lt_acct TYPE STANDARD TABLE OF zcd_ebs_acct WITH EMPTY KEY.
    DATA ls_acct TYPE zcd_ebs_acct.
    DATA lt_febko TYPE STANDARD TABLE OF febko WITH EMPTY KEY.
    DATA ls_febko TYPE febko.
    DATA lt_febep TYPE STANDARD TABLE OF febep WITH EMPTY KEY.
    DATA ls_febep TYPE febep.
    TRY.
        ls_acct-bukrs  = gc_test-bukrs.
        ls_acct-hbkid  = gc_test-hbkid.
        ls_acct-hktid  = gc_test-hktid.
        ls_acct-active = abap_true.
        INSERT ls_acct INTO TABLE lt_acct.
        go_env->insert_test_data( lt_acct ).
        ls_febko-kukey = '00000101'.
        ls_febko-bukrs = gc_test-bukrs.
        ls_febko-hbkid = gc_test-hbkid.
        ls_febko-hktid = gc_test-hktid.
        ls_febko-azdat = gc_test-in_window.
        INSERT ls_febko INTO TABLE lt_febko.
        ls_febko-kukey = '00000102'.
        ls_febko-hbkid = gc_test-other_bk.
        INSERT ls_febko INTO TABLE lt_febko.
        go_env->insert_test_data( lt_febko ).
        ls_febep-kukey = '00000101'.
        ls_febep-esnum = '00001'.
        ls_febep-xblnr = gc_test-xblnr_in.
        INSERT ls_febep INTO TABLE lt_febep.
        ls_febep-kukey = '00000102'.
        ls_febep-xblnr = gc_test-xblnr_out.
        INSERT ls_febep INTO TABLE lt_febep.
        go_env->insert_test_data( lt_febep ).
        DATA(lt_values) = mo_cut->get_values( iv_area     = zif_cd_ops_pattern_types=>gc_area-ebs_flow
                                              iv_from     = gc_test-from
                                              iv_to       = gc_test-to
                                              iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_values ) exp = 1 msg = 'Configured account only' ).
        cl_abap_unit_assert=>assert_equals( act = lt_values[ 1 ] exp = CONV string( gc_test-xblnr_in )
                                            msg = 'XBLNR of the configured account' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Suppression keys: object keys of HCK findings of runs started in the window
  METHOD finding_keys_of_hck_runs.
    DATA lt_runs TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
    DATA ls_run TYPE zcd_ops_run.
    DATA lt_findings TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_finding TYPE zcd_ops_finding.
    TRY.
        ls_run-run_id     = '000000000000000000000000000000E1'.
        ls_run-started_at = gc_test-run_in.
        INSERT ls_run INTO TABLE lt_runs.
        ls_run-run_id     = '000000000000000000000000000000E2'.
        ls_run-started_at = gc_test-run_out.
        INSERT ls_run INTO TABLE lt_runs.
        go_env->insert_test_data( lt_runs ).
        ls_finding-run_id     = '000000000000000000000000000000E1'.
        ls_finding-finding_no = 1.
        ls_finding-pe_area    = zif_cd_ops_types=>gc_pe_area-health_check.
        ls_finding-object_key = 'HCK_C04/AGE_DAYS/US01'.
        INSERT ls_finding INTO TABLE lt_findings.
        ls_finding-finding_no = 2.
        ls_finding-pe_area    = zif_cd_ops_types=>gc_pe_area-ebs.
        ls_finding-object_key = 'S0001/1'.
        INSERT ls_finding INTO TABLE lt_findings.
        ls_finding-run_id     = '000000000000000000000000000000E2'.
        ls_finding-finding_no = 1.
        ls_finding-pe_area    = zif_cd_ops_types=>gc_pe_area-health_check.
        ls_finding-object_key = 'HCK_A01/OLD'.
        INSERT ls_finding INTO TABLE lt_findings.
        go_env->insert_test_data( lt_findings ).
        DATA(lt_values) = mo_cut->get_values( iv_area     = zif_cd_ops_pattern_types=>gc_area-hck_suppr
                                              iv_from     = gc_test-from
                                              iv_to       = gc_test-to
                                              iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lt_values exp = VALUE zif_cd_ops_pattern_types=>tt_value(
                                                                         ( `HCK_C04/AGE_DAYS/US01` ) )
                                            msg = 'HCK finding of the run in the window only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Migration rows: every non-blank pattern with its key and field length; a numeric PARAM1
  " of a check outside the pattern-list classes is never touched
  METHOD migration_rows_key_length.
    TRY.
        DATA(lt_rows) = mo_cut->get_migration_rows( all_areas( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 4
                                            msg = 'Two flow patterns, one interface, one job list' ).
        DATA(ls_flow) = lt_rows[ table = zif_cd_ops_pattern_types=>gc_table-flow_pattern key1 = `10` ].
        cl_abap_unit_assert=>assert_equals( act = ls_flow-key2 exp = CONV string( gc_test-cp_flow )
                                            msg = 'The pattern is part of the key' ).
        cl_abap_unit_assert=>assert_equals( act = ls_flow-max_length exp = 30 msg = 'Field length of PATTERN' ).
        DATA(ls_list) = lt_rows[ table = zif_cd_ops_pattern_types=>gc_table-hck_def ].
        cl_abap_unit_assert=>assert_equals( act = ls_list-key1 exp = CONV string( gc_test-check_job )
                                            msg = 'Only the technical job check' ).
        cl_abap_unit_assert=>assert_true( act = ls_list-is_list msg = 'PARAM1 is a pattern list' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD all_areas.
    rt_areas = VALUE #( ( zif_cd_ops_types=>gc_pe_area-core ) ( zif_cd_ops_types=>gc_pe_area-ebs )
                        ( zif_cd_ops_types=>gc_pe_area-file_monitor ) ( zif_cd_ops_types=>gc_pe_area-health_check ) ).
  ENDMETHOD.


  " B7: only the areas the caller may display are read - here EBS only (two flow patterns)
  METHOD migration_rows_of_areas_only.
    TRY.
        DATA(lt_rows) = mo_cut->get_migration_rows( VALUE #( ( zif_cd_ops_types=>gc_pe_area-ebs ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2
                                            msg = 'Only the two flow patterns of EBS' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( lt_rows[ table = zif_cd_ops_pattern_types=>gc_table-fmon_iface ] ) )
          msg = 'No FMON row without FMON display authorisation' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Write: the flow pattern (key field) is re-keyed, the interface pattern updated with stamp
  METHOD write_rekeys_and_updates.
    TRY.
        DATA(lt_plan) = zcl_cd_ops_pattern_check=>plan_migration( mo_cut->get_migration_rows( all_areas( ) ) ).
        DATA(lt_written) = mo_cut->write_migration( lt_plan ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_written ) exp = 2
                                            msg = 'Flow patterns and interfaces written' ).
        SELECT priority, pattern FROM zcd_ebs_flow_pat WHERE priority = 10
          ORDER BY priority, pattern INTO TABLE @DATA(lt_flow).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_flow ) exp = 1 msg = 'Old key deleted' ).
        cl_abap_unit_assert=>assert_equals( act = lt_flow[ 1 ]-pattern exp = gc_test-pcre_flow
                                            msg = 'PCRE pattern written' ).
        SELECT SINGLE name_pattern, last_changed_by, description, min_bytes FROM zcd_fmon_iface
          WHERE iface_id = @gc_test-iface
          INTO @DATA(ls_iface).
        cl_abap_unit_assert=>assert_subrc( act = sy-subrc exp = 0 msg = 'Interface row kept' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-description exp = gc_test-descr
                                            msg = 'Fields other than the pattern are kept' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-min_bytes exp = 100
                                            msg = 'Numeric fields are kept' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-name_pattern exp = 'ACH_PNC_.*'
                                            msg = 'Interface pattern converted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_iface-last_changed_by exp = sy-uname
                                            msg = 'Change stamp set' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
