*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_store.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the shared store: test-mode runs write nothing, findings of
*& severity B/E/W become open exceptions with an SLA due date, parameters fall
*& back to defaults. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Exception carry-forward: inherit, supersede, auto-resolve, waived kept.
*& 2026-11-06 | pending_waiver_is_carried (exceptions app).
*& 2026-11-06 | stale_running_run_is_found (audit A06).
*& 2026-11-06 | Parameter snapshot per run (audit A64).
*& 2026-11-06 | Performance fix 5: carry-forward by (type, key) pairs and binary search - other type untouched,
*&            | newest earlier row inherited.
*& 2026-11-06 | ltc_store_runs: finish, last run, runs since, findings read (coverage gap closure).
*& 2026-11-07 | Parameter semantics pinned (blank = default, condensed, get_range) - the same cases
*&            | as the shared fake ZCL_CD_OPS_PARAMS_MEM.
*&---------------------------------------------------------------------*
CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261105080000.0000000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261105'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '080000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_store DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_store.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    CONSTANTS:
      BEGIN OF gc_cf,
        key        TYPE zif_cd_ops_types=>ty_object_key VALUE 'S0001/1',
        other_key  TYPE zif_cd_ops_types=>ty_object_key VALUE 'S0009/1',
        check_code TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNMAPPED_BTC',
        group      TYPE zif_cd_ops_types=>ty_group VALUE 'HCK_A01',
        owner      TYPE syuname VALUE 'OPS_OWNER',
        due        TYPE d VALUE '20261110',
        first_seen TYPE timestampl VALUE '20261101060000.0000000',
        waiver_end TYPE d VALUE '20261231',
        prior_run  TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000AA',
      END OF gc_cf.

    METHODS finding
      IMPORTING
        iv_severity       TYPE zif_cd_ops_types=>ty_severity
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.
    "! An exception of an earlier run in the store (test data)
    METHODS prior_exception
      IMPORTING
        iv_object_key  TYPE zif_cd_ops_types=>ty_object_key
        iv_disposition TYPE zif_cd_ops_types=>ty_disposition
        iv_group       TYPE zif_cd_ops_types=>ty_group OPTIONAL
        iv_waiver_req  TYPE abap_bool DEFAULT abap_false.
    METHODS save_again
      RETURNING
        VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run
      RAISING
        zcx_cd_ops_error.
    METHODS read_row
      IMPORTING
        iv_run_id     TYPE zif_cd_ops_types=>ty_run_id
        iv_finding_no TYPE i
      RETURNING
        VALUE(rs_row) TYPE zcd_ops_finding.

    METHODS test_mode_writes_nothing     FOR TESTING.
    METHODS error_becomes_open_exception FOR TESTING.
    METHODS info_is_not_an_exception     FOR TESTING.
    METHODS sla_param_sets_due_date      FOR TESTING.
    METHODS missing_param_gives_default  FOR TESTING.
    METHODS repeat_keeps_owner_and_due   FOR TESTING.
    METHODS repeat_supersedes_old_row    FOR TESTING.
    METHODS first_occurrence_counts_one  FOR TESTING.
    METHODS waived_is_not_reopened       FOR TESTING.
    METHODS absent_exception_resolved    FOR TESTING.
    METHODS out_of_scope_stays_open      FOR TESTING.
    METHODS group_scope_resolves         FOR TESTING.
    METHODS pending_waiver_is_carried    FOR TESTING.
    METHODS stale_running_run_is_found   FOR TESTING.
    METHODS next_run_sees_changed_param  FOR TESTING.
    METHODS param_stable_within_run      FOR TESTING.
    METHODS blank_param_gives_default    FOR TESTING.
    METHODS param_value_is_condensed     FOR TESTING.
    METHODS param_range_from_list        FOR TESTING.
    METHODS carry_other_type_untouched   FOR TESTING.
    METHODS carry_newest_prior_inherited FOR TESTING.
    "! Fix 5: an earlier exception row with explicit type, owner and creation time (test data)
    METHODS prior_row
      IMPORTING
        iv_finding_no  TYPE i
        iv_object_type TYPE zcd_ops_finding-object_type
        iv_owner       TYPE syuname
        iv_created_at  TYPE timestampl.
    "! Replace the maintained parameters (test data)
    METHODS set_param
      IMPORTING
        iv_name  TYPE zif_cd_ops_types=>ty_param_name
        iv_value TYPE string.

    "! A run header in the store (test data)
    METHODS store_run
      IMPORTING
        iv_run_id     TYPE zif_cd_ops_types=>ty_run_id
        iv_status     TYPE zif_cd_ops_types=>ty_run_status
        iv_started_at TYPE timestampl.
ENDCLASS.


CLASS ltc_store IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_OPS_RUN' ) ( 'ZCD_OPS_FINDING' ) ( 'ZCD_OPS_PARAM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_cut = NEW zcl_cd_ops_store( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_cut.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_type = 'LINE'.
    rs_finding-object_key  = 'S0001/1'.
    rs_finding-rule_id     = 'R14'.
    rs_finding-check_code  = gc_cf-check_code.
    rs_finding-severity    = iv_severity.
    rs_finding-message     = 'test'.
  ENDMETHOD.


  " Test mode: neither run header nor findings reach the database
  METHOD test_mode_writes_nothing.
    TRY.
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_test_mode = abap_true ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT COUNT(*) FROM zcd_ops_finding INTO @DATA(lv_count).
        cl_abap_unit_assert=>assert_equals( act = lv_count exp = 0 msg = 'Test mode must not write findings' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-finding_count exp = 1 msg = 'Count must still advance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An E finding is stored as an open, owned exception
  METHOD error_becomes_open_exception.
    TRY.
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT SINGLE disposition, due_date FROM zcd_ops_finding WHERE run_id = @ls_run-run_id AND finding_no = 1
          INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 act = sy-subrc msg = 'The saved finding must be readable' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-disposition exp = zcl_cd_ops_store=>gc_disposition-open
                                            msg = 'E finding must be an open exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-due_date exp = '20261106'
                                            msg = 'Default SLA is one day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An I finding is information, not an exception to work
  METHOD info_is_not_an_exception.
    TRY.
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-info ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT SINGLE disposition, due_date FROM zcd_ops_finding WHERE run_id = @ls_run-run_id AND finding_no = 1
          INTO @DATA(ls_row).
        cl_abap_unit_assert=>assert_subrc( exp = 0 act = sy-subrc msg = 'The saved finding must be readable' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-disposition
                                            exp = zcl_cd_ops_store=>gc_disposition-information
                                            msg = 'I finding must be information' ).
        cl_abap_unit_assert=>assert_initial( act = ls_row-due_date msg = 'Information has no due date' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " SLA_DAYS_<payment engine area>_<severity> drives the due date
  METHOD sla_param_sets_due_date.
    DATA lt_param TYPE STANDARD TABLE OF zcd_ops_param WITH EMPTY KEY.
    DATA ls_param TYPE zcd_ops_param.
    TRY.
        ls_param-param_name  = 'SLA_DAYS_EBS_B'.
        ls_param-param_value = '0'.
        INSERT ls_param INTO TABLE lt_param.
        go_env->insert_test_data( lt_param ).
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-block ) ) )
                               CHANGING  cs_run      = ls_run ).
        SELECT SINGLE due_date FROM zcd_ops_finding WHERE run_id = @ls_run-run_id AND finding_no = 1
          INTO @DATA(lv_due).
        cl_abap_unit_assert=>assert_subrc( exp = 0 act = sy-subrc msg = 'The saved finding must be readable' ).
        cl_abap_unit_assert=>assert_equals( act = lv_due exp = '20261105' msg = 'Blocks are due the same day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A parameter that is not maintained returns the caller's default
  METHOD missing_param_gives_default.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = 'NOT_THERE' iv_default = `42` )
                                        exp = `42`
                                        msg = 'Missing parameter must return the default' ).
  ENDMETHOD.


  METHOD prior_exception.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ops_finding.
    ls_row-run_id        = gc_cf-prior_run.
    ls_row-finding_no    = lines( lt_rows ) + 1.
    ls_row-pe_area        = zif_cd_ops_types=>gc_pe_area-ebs.
    ls_row-object_type   = 'LINE'.
    ls_row-object_key    = iv_object_key.
    ls_row-group2        = iv_group.
    ls_row-rule_id       = 'R14'.
    ls_row-check_code    = gc_cf-check_code.
    ls_row-severity      = zif_cd_ops_types=>gc_severity-error.
    ls_row-disposition   = iv_disposition.
    ls_row-owner         = gc_cf-owner.
    ls_row-due_date      = gc_cf-due.
    ls_row-first_seen_at = gc_cf-first_seen.
    ls_row-created_at    = gc_cf-first_seen.
    ls_row-occurrences   = 1.
    IF iv_disposition = zif_cd_ops_types=>gc_disposition-waived.
      ls_row-waiver_until = gc_cf-waiver_end.
    ENDIF.
    IF iv_waiver_req = abap_true.
      ls_row-waiver_req_by = gc_cf-owner.
      ls_row-waiver_req_at = gc_cf-first_seen.
      ls_row-waiver_reason = 'Known bank issue'.
      ls_row-waiver_until  = gc_cf-waiver_end.
    ENDIF.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD prior_row.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ops_finding.
    ls_row-run_id        = gc_cf-prior_run.
    ls_row-finding_no    = iv_finding_no.
    ls_row-pe_area       = zif_cd_ops_types=>gc_pe_area-ebs.
    ls_row-object_type   = iv_object_type.
    ls_row-object_key    = gc_cf-key.
    ls_row-rule_id       = 'R14'.
    ls_row-check_code    = gc_cf-check_code.
    ls_row-severity      = zif_cd_ops_types=>gc_severity-error.
    ls_row-disposition   = zif_cd_ops_types=>gc_disposition-assigned.
    ls_row-owner         = iv_owner.
    ls_row-due_date      = gc_cf-due.
    ls_row-first_seen_at = iv_created_at.
    ls_row-created_at    = iv_created_at.
    ls_row-occurrences   = 1.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Fix 5 parity: an earlier exception of another object type with the same key is neither
  " inherited nor superseded (the read is by type and key)
  METHOD carry_other_type_untouched.
    TRY.
        prior_row( iv_finding_no = 1 iv_object_type = 'STMT' iv_owner = gc_cf-owner iv_created_at = gc_cf-first_seen ).
        DATA(ls_run) = save_again( ).
        DATA(ls_new) = read_row( iv_run_id = ls_run-run_id iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-occurrences exp = 1
                                            msg = 'A LINE exception must not inherit from a STMT row' ).
        cl_abap_unit_assert=>assert_initial( act = ls_new-owner msg = 'No owner from another object type' ).
        DATA(ls_old) = read_row( iv_run_id = gc_cf-prior_run iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_old-disposition exp = zif_cd_ops_types=>gc_disposition-assigned
                                            msg = 'The STMT row must not be superseded' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fix 5 parity: with two earlier rows of the same exception the newest is inherited and both
  " are superseded (binary search keeps the CREATED_AT descending order of the block)
  METHOD carry_newest_prior_inherited.
    CONSTANTS lc_old_owner TYPE syuname VALUE 'OLD_OWNER'.
    CONSTANTS lc_older TYPE timestampl VALUE '20261020060000.0000000'.
    TRY.
        prior_row( iv_finding_no = 1 iv_object_type = 'LINE' iv_owner = lc_old_owner iv_created_at = lc_older ).
        prior_row( iv_finding_no = 2 iv_object_type = 'LINE' iv_owner = gc_cf-owner iv_created_at = gc_cf-first_seen ).
        DATA(ls_run) = save_again( ).
        DATA(ls_new) = read_row( iv_run_id = ls_run-run_id iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-owner exp = gc_cf-owner
                                            msg = 'The newest earlier row must be inherited' ).
        cl_abap_unit_assert=>assert_equals(
          act = read_row( iv_run_id = gc_cf-prior_run iv_finding_no = 1 )-disposition
          exp = zif_cd_ops_types=>gc_disposition-superseded
          msg = 'The older row must be superseded too' ).
        cl_abap_unit_assert=>assert_equals(
          act = read_row( iv_run_id = gc_cf-prior_run iv_finding_no = 2 )-disposition
          exp = zif_cd_ops_types=>gc_disposition-superseded
          msg = 'The newest earlier row must be superseded' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD save_again.
    rs_run = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
    mo_cut->save_findings( EXPORTING it_findings = VALUE #( ( finding( zif_cd_ops_types=>gc_severity-error ) ) )
                           CHANGING  cs_run      = rs_run ).
  ENDMETHOD.


  METHOD read_row.
    SELECT SINGLE disposition, owner, due_date, first_seen_at, occurrences, superseded_by, waiver_until,
                  resolution, resolved_by
      FROM zcd_ops_finding
      WHERE run_id     = @iv_run_id
        AND finding_no = @iv_finding_no
      INTO CORRESPONDING FIELDS OF @rs_row.
    cl_abap_unit_assert=>assert_subrc( exp = 0 act = sy-subrc msg = 'The finding row must exist' ).
  ENDMETHOD.


  " Rule: an exception raised again keeps its owner, due date and first-seen time
  " and counts the occurrence - the queue is not reset by every re-run
  METHOD repeat_keeps_owner_and_due.
    TRY.
        prior_exception( iv_object_key = gc_cf-key iv_disposition = zif_cd_ops_types=>gc_disposition-assigned ).
        DATA(ls_run) = save_again( ).
        DATA(ls_new) = read_row( iv_run_id = ls_run-run_id iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-disposition exp = zif_cd_ops_types=>gc_disposition-assigned
                                            msg = 'Disposition must be carried forward' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-owner exp = gc_cf-owner msg = 'Owner must be carried forward' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-due_date exp = gc_cf-due msg = 'Due date must be kept' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-first_seen_at exp = gc_cf-first_seen
                                            msg = 'First-seen time must be kept' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-occurrences exp = 2 msg = 'Occurrences must be counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the old row is superseded by the new run, so each exception is listed once
  METHOD repeat_supersedes_old_row.
    TRY.
        prior_exception( iv_object_key = gc_cf-key iv_disposition = zif_cd_ops_types=>gc_disposition-open ).
        DATA(ls_run) = save_again( ).
        DATA(ls_old) = read_row( iv_run_id = gc_cf-prior_run iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_old-disposition exp = zif_cd_ops_types=>gc_disposition-superseded
                                            msg = 'The earlier row must be superseded' ).
        cl_abap_unit_assert=>assert_equals( act = ls_old-superseded_by exp = ls_run-run_id
                                            msg = 'The earlier row must name the run that replaced it' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a new exception starts its own history
  METHOD first_occurrence_counts_one.
    TRY.
        DATA(ls_run) = save_again( ).
        DATA(ls_new) = read_row( iv_run_id = ls_run-run_id iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-occurrences exp = 1 msg = 'First occurrence counts one' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-first_seen_at exp = '20261105080000.0000000'
                                            msg = 'First seen is now' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-disposition exp = zif_cd_ops_types=>gc_disposition-open
                                            msg = 'A new exception is open' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a valid waiver is not reopened by a re-run
  METHOD waived_is_not_reopened.
    TRY.
        prior_exception( iv_object_key = gc_cf-key iv_disposition = zif_cd_ops_types=>gc_disposition-waived ).
        DATA(ls_run) = save_again( ).
        DATA(ls_new) = read_row( iv_run_id = ls_run-run_id iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-disposition exp = zif_cd_ops_types=>gc_disposition-waived
                                            msg = 'A valid waiver must stay waived' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-waiver_until exp = gc_cf-waiver_end
                                            msg = 'The waiver end date must be carried forward' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an open exception whose object was evaluated again without the finding is resolved
  METHOD absent_exception_resolved.
    TRY.
        prior_exception( iv_object_key = gc_cf-key iv_disposition = zif_cd_ops_types=>gc_disposition-open ).
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        mo_cut->reconcile( is_run = ls_run it_object_keys = VALUE #( ( gc_cf-key ) ) ).
        DATA(ls_old) = read_row( iv_run_id = gc_cf-prior_run iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_old-disposition exp = zif_cd_ops_types=>gc_disposition-resolved
                                            msg = 'A passed object must resolve its exception' ).
        cl_abap_unit_assert=>assert_not_initial( act = ls_old-resolution msg = 'The resolution must name the re-run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_old-resolved_by exp = sy-uname msg = 'Resolved by the run user' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: objects the run did not look at keep their exceptions
  METHOD out_of_scope_stays_open.
    TRY.
        prior_exception( iv_object_key = gc_cf-other_key iv_disposition = zif_cd_ops_types=>gc_disposition-open ).
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        mo_cut->reconcile( is_run = ls_run it_object_keys = VALUE #( ( gc_cf-key ) ) ).
        DATA(ls_old) = read_row( iv_run_id = gc_cf-prior_run iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_old-disposition exp = zif_cd_ops_types=>gc_disposition-open
                                            msg = 'An object outside the scope must stay open' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a group scope (health check ID in GROUP2) resolves that check's absent exceptions
  METHOD group_scope_resolves.
    TRY.
        prior_exception( iv_object_key  = gc_cf-other_key
                         iv_disposition = zif_cd_ops_types=>gc_disposition-assigned
                         iv_group       = gc_cf-group ).
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        mo_cut->reconcile( is_run = ls_run it_groups = VALUE #( ( gc_cf-group ) ) ).
        DATA(ls_old) = read_row( iv_run_id = gc_cf-prior_run iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_old-disposition exp = zif_cd_ops_types=>gc_disposition-resolved
                                            msg = 'A check that passed must resolve its exceptions' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (exceptions app): a waiver request waiting for approval survives a re-run -
  " the new row carries requester, reason and requested end date
  METHOD pending_waiver_is_carried.
    TRY.
        prior_exception( iv_object_key  = gc_cf-key
                         iv_disposition = zif_cd_ops_types=>gc_disposition-assigned
                         iv_waiver_req  = abap_true ).
        DATA(ls_run) = save_again( ).
        DATA(ls_new) = read_row( iv_run_id = ls_run-run_id iv_finding_no = 1 ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-waiver_req_by exp = gc_cf-owner
                                            msg = 'The requester must be carried forward' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-waiver_reason exp = 'Known bank issue'
                                            msg = 'The waiver reason must be carried forward' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-waiver_until exp = gc_cf-waiver_end
                                            msg = 'The requested end date must be carried forward' ).
        cl_abap_unit_assert=>assert_equals( act = ls_new-disposition exp = zif_cd_ops_types=>gc_disposition-assigned
                                            msg = 'The request does not change the disposition' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD store_run.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ops_run.
    ls_row-run_id     = iv_run_id.
    ls_row-pe_area    = zif_cd_ops_types=>gc_pe_area-file_monitor.
    ls_row-status     = iv_status.
    ls_row-started_at = iv_started_at.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Audit A06: a run still in status R before the limit is found - finished runs,
  " recent runs and the caller's own run are not
  METHOD stale_running_run_is_found.
    CONSTANTS lc_hung TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000B1'.
    CONSTANTS lc_done TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000B2'.
    CONSTANTS lc_young TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000B3'.
    CONSTANTS lc_own TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000B4'.
    TRY.
        store_run( iv_run_id = lc_hung  iv_status = zif_cd_ops_types=>gc_run_status-running
                   iv_started_at = '20261105010000.0000000' ).
        store_run( iv_run_id = lc_done  iv_status = zif_cd_ops_types=>gc_run_status-success
                   iv_started_at = '20261105010000.0000000' ).
        store_run( iv_run_id = lc_young iv_status = zif_cd_ops_types=>gc_run_status-running
                   iv_started_at = '20261105065900.0000000' ).
        store_run( iv_run_id = lc_own   iv_status = zif_cd_ops_types=>gc_run_status-running
                   iv_started_at = '20261105010000.0000000' ).
        DATA(lt_stale) = mo_cut->get_stale_runs( iv_pe_area        = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                 iv_started_before = '20261105060000.0000000'
                                                 iv_exclude_run    = lc_own ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_stale ) exp = 1
                                            msg = 'Only the old run still in status R is stale' ).
        cl_abap_unit_assert=>assert_equals( act = lt_stale[ 1 ]-run_id exp = lc_hung
                                            msg = 'The stale run must be the hung one' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD set_param.
    DATA lt_param TYPE STANDARD TABLE OF zcd_ops_param WITH EMPTY KEY.
    go_env->clear_doubles( ).
    INSERT VALUE #( param_name = iv_name param_value = iv_value ) INTO TABLE lt_param.
    go_env->insert_test_data( lt_param ).
  ENDMETHOD.


  " The parameter semantics the shared fake ZCL_CD_OPS_PARAMS_MEM mirrors (its own tests
  " assert the same cases): a blank value is the default
  METHOD blank_param_gives_default.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_LOOKBACK'.
    TRY.
        set_param( iv_name = lc_name iv_value = `   ` ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = lc_name iv_default = `8` )
                                            exp = `8`
                                            msg = 'A blank parameter must return the default' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A maintained value is read condensed (leading blanks removed, inner blanks collapsed)
  METHOD param_value_is_condensed.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WATCH_PE_AREAS'.
    TRY.
        set_param( iv_name = lc_name iv_value = `  EBS,   FMON ` ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = lc_name iv_default = `X` )
                                            exp = `EBS, FMON`
                                            msg = 'The value must be condensed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " get_range: one I / EQ row per list entry, blank entries dropped
  METHOD param_range_from_list.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WATCH_PE_AREAS'.
    DATA lt_exp TYPE zif_cd_ops_types=>tt_param_range.
    TRY.
        set_param( iv_name = lc_name iv_value = `EBS;;FMON` ).
        INSERT VALUE #( sign = zif_cd_ops_types=>gc_range-sign_include option = zif_cd_ops_types=>gc_range-option_equal
                        low = zif_cd_ops_types=>gc_pe_area-ebs ) INTO TABLE lt_exp.
        INSERT VALUE #( sign = zif_cd_ops_types=>gc_range-sign_include option = zif_cd_ops_types=>gc_range-option_equal
                        low = zif_cd_ops_types=>gc_pe_area-file_monitor ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_range( lc_name )
                                            exp = lt_exp
                                            msg = 'One I / EQ row per entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A64: two runs in one internal session - the second run sees a parameter that
  " was changed between the runs (the cache is not session-wide)
  METHOD next_run_sees_changed_param.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_LOOKBACK'.
    TRY.
        set_param( iv_name = lc_name iv_value = `8` ).
        mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( lc_name ) exp = `8`
                                            msg = 'The first run reads the maintained value' ).
        set_param( iv_name = lc_name iv_value = `12` ).
        mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( lc_name ) exp = `12`
                                            msg = 'The next run must see the changed parameter' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A64: inside one run the parameters are a snapshot taken at start_run
  METHOD param_stable_within_run.
    CONSTANTS lc_name TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_LOOKBACK'.
    TRY.
        set_param( iv_name = lc_name iv_value = `8` ).
        mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_test_mode = abap_true ).
        set_param( iv_name = lc_name iv_value = `12` ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( lc_name ) exp = `8`
                                            msg = 'A running run keeps its start snapshot' ).
        mo_cut->refresh_params( ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( lc_name ) exp = `12`
                                            msg = 'refresh_params reads the table again' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! OSQL tests of the run header life cycle and the run / finding reads (ZCD_OPS_RUN,
"! ZCD_OPS_FINDING and ZCD_OPS_PARAM doubled; clock double through ZCL_CD_OPS_INJECTOR).
"! COMMIT / ROLLBACK are one statement each and covered by the engine LUW tests (store double).
CLASS ltc_store_runs DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        variant TYPE zif_cd_ops_types=>ty_variant VALUE 'DAILY',
        other   TYPE zif_cd_ops_types=>ty_variant VALUE 'WEEKLY',
        since   TYPE timestampl VALUE '20261105000000.0000000',
        later   TYPE timestampl VALUE '20261105120000.0000000',
        key     TYPE zif_cd_ops_types=>ty_object_key VALUE 'S0001/1',
        code    TYPE zif_cd_ops_types=>ty_check_code VALUE 'UNMAPPED_BTC',
        run_x   TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000EE',
        msgno   TYPE symsgno VALUE '011',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_store.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS finished_run_is_last_run FOR TESTING.
    METHODS running_run_is_not_last FOR TESTING.
    METHODS last_run_per_variant FOR TESTING.
    METHODS runs_since_exclude_test_mode FOR TESTING.
    METHODS findings_read_by_run FOR TESTING.
    METHODS finish_unknown_run_raises FOR TESTING.

    METHODS finished_run
      IMPORTING
        iv_variant    TYPE zif_cd_ops_types=>ty_variant
      RETURNING
        VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_store_runs IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_OPS_RUN' ) ( 'ZCD_OPS_FINDING' ) ( 'ZCD_OPS_PARAM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_cut = NEW zcl_cd_ops_store( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_cut.
  ENDMETHOD.


  METHOD finished_run.
    rs_run = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs
                                iv_variant = iv_variant ).
    rs_run-status = zif_cd_ops_types=>gc_run_status-success.
    rs_run-rag    = zif_cd_ops_types=>gc_rag-green.
    mo_cut->finish_run( rs_run ).
  ENDMETHOD.


  " Rule: a finished run is the last run of its payment engine area, with its status
  METHOD finished_run_is_last_run.
    TRY.
        DATA(ls_run) = finished_run( gc_test-variant ).
        DATA(ls_last) = mo_cut->get_last_run( zif_cd_ops_types=>gc_pe_area-ebs ).
        cl_abap_unit_assert=>assert_equals( act = ls_last-run_id exp = ls_run-run_id msg = 'The finished run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_last-status exp = zif_cd_ops_types=>gc_run_status-success
                                            msg = 'Status written by finish_run' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_last_run( zif_cd_ops_types=>gc_pe_area-health_check )
                                             msg = 'Other area has no run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a run still running is never reported as the last completed run
  METHOD running_run_is_not_last.
    TRY.
        mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_last_run( zif_cd_ops_types=>gc_pe_area-ebs )
                                             msg = 'Running run is not the last run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: with a variant only runs of that variant count
  METHOD last_run_per_variant.
    TRY.
        DATA(ls_run) = finished_run( gc_test-variant ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->get_last_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_variant = gc_test-variant )-run_id
          exp = ls_run-run_id
          msg = 'Run of the variant' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_last_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_variant = gc_test-other )
          msg = 'Other variant has no run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: runs since a time stamp, test-mode runs excluded (they are never written)
  METHOD runs_since_exclude_test_mode.
    TRY.
        finished_run( gc_test-variant ).
        mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( mo_cut->get_runs_since( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_since = gc_test-since ) )
          exp = 1
          msg = 'One real run since the time stamp' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_runs_since( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs iv_since = gc_test-later )
          msg = 'No run after the later time stamp' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the findings of a run are read back in their order
  METHOD findings_read_by_run.
    DATA lt_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    TRY.
        DATA(ls_run) = mo_cut->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-ebs ).
        ls_finding-object_key = gc_test-key.
        ls_finding-check_code = gc_test-code.
        ls_finding-severity   = zif_cd_ops_types=>gc_severity-info.
        INSERT ls_finding INTO TABLE lt_findings.
        mo_cut->save_findings( EXPORTING it_findings = lt_findings
                               CHANGING  cs_run      = ls_run ).
        DATA(lt_read) = mo_cut->get_findings( ls_run-run_id ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_read ) exp = 1 msg = 'The saved finding' ).
        cl_abap_unit_assert=>assert_equals( act = lt_read[ 1 ]-check_code exp = gc_test-code msg = 'Check code read' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_findings( gc_test-run_x ) msg = 'Unknown run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: finishing a run whose header is not stored raises 011 - never a silent loss
  METHOD finish_unknown_run_raises.
    DATA ls_run TYPE zif_cd_ops_types=>ty_run.
    ls_run-run_id  = gc_test-run_x.
    ls_run-pe_area = zif_cd_ops_types=>gc_pe_area-ebs.
    TRY.
        mo_cut->finish_run( ls_run ).
        cl_abap_unit_assert=>fail( msg = 'Unknown run must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = gc_test-msgno
                                            msg = 'Update error is message 011' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
