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
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs iv_test_mode = abap_true ).
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
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
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
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
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


  " SLA_DAYS_<module>_<severity> drives the due date
  METHOD sla_param_sets_due_date.
    DATA lt_param TYPE STANDARD TABLE OF zcd_ops_param WITH EMPTY KEY.
    DATA ls_param TYPE zcd_ops_param.
    TRY.
        ls_param-param_name  = 'SLA_DAYS_EBS_B'.
        ls_param-param_value = '0'.
        INSERT ls_param INTO TABLE lt_param.
        go_env->insert_test_data( lt_param ).
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
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
    ls_row-module        = zif_cd_ops_types=>gc_module-ebs.
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


  METHOD save_again.
    rs_run = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
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
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
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
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
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
        DATA(ls_run) = mo_cut->start_run( iv_module = zif_cd_ops_types=>gc_module-ebs ).
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

ENDCLASS.
