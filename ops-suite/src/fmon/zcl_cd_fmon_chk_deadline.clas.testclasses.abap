*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_chk_deadline.clas.testclasses.abap
*& Purpose:
*& Domain tests of the stage deadline check (pure, context built field by
*& field): the three conditions at the due time - not received, received but
*& not imported (none or some payment engine accounts), imported but not
*& posted - the all-good case, holiday / no expected file / before the due
*& time, the day-type fallback, one finding per interface and day and the
*& severity of the row. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (BAI processing deadline, user requirement 2026-11-07).
*&---------------------------------------------------------------------*
CLASS ltc_deadline DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        iface      TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'BAI_JPMC_IN',
        bank       TYPE zif_cd_fmon_types=>ty_bank_key VALUE 'JPMC',
        date       TYPE d VALUE '20261109',
        stmt_date  TYPE d VALUE '20261106',
        due        TYPE t VALUE '100000',
        early_due  TYPE t VALUE '090000',
        late_due   TYPE t VALUE '110000',
        time_zone  TYPE zif_cd_fmon_types=>ty_time_zone VALUE 'UTC',
        before_due TYPE timestampl VALUE '20261109095900',
        after_due  TYPE timestampl VALUE '20261109100100',
        check_id   TYPE zif_cd_fmon_types=>ty_check_id VALUE 'F_DEADLINE',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        "! Registry: stage / outcome of the day's file instance (blank = no file)
        stage        TYPE zif_cd_fmon_types=>ty_stage,
        "! Statement evidence (FEB adapter): read, accounts imported, entries open
        evidence     TYPE abap_bool,
        imported     TYPE i,
        open_lines   TYPE i,
        "! Calendar: day type and expected files of the day
        day_type     TYPE zif_cd_fmon_types=>ty_day_type,
        expected     TYPE i,
        "! Deadline rows: day type of the FULLY_PROCESSED row, an extra FILE_RECEIVED row
        row_day_type TYPE zif_cd_fmon_types=>ty_day_type,
        receipt_row  TYPE abap_bool,
        row_severity TYPE zif_cd_ops_types=>ty_severity,
        before_due   TYPE abap_bool,
      END OF ty_flags.

    DATA ms_ctx TYPE zif_cd_fmon_types=>ty_check_ctx.
    DATA ms_check TYPE zif_cd_fmon_types=>ty_chk.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS add_deadline
      IMPORTING
        iv_stage    TYPE zif_cd_fmon_types=>ty_stage
        iv_day_type TYPE zif_cd_fmon_types=>ty_day_type
        iv_due      TYPE t
        iv_severity TYPE zif_cd_ops_types=>ty_severity.
    METHODS run_check
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding
      RAISING
        zcx_cd_ops_error.
    METHODS assert_condition
      IMPORTING
        it_findings TYPE zif_cd_ops_types=>tt_finding
        iv_cond     TYPE zif_cd_ops_types=>ty_group.

    METHODS not_received_is_condition_1 FOR TESTING.
    METHODS no_import_is_condition_2     FOR TESTING.
    METHODS some_accounts_is_condition_2 FOR TESTING.
    METHODS not_posted_is_condition_3    FOR TESTING.
    METHODS processed_raises_nothing     FOR TESTING.
    METHODS holiday_raises_nothing       FOR TESTING.
    METHODS no_file_day_raises_nothing   FOR TESTING.
    METHODS before_due_raises_nothing    FOR TESTING.
    METHODS month_end_uses_normal_row    FOR TESTING.
    METHODS one_finding_per_day          FOR TESTING.
    METHODS message_names_counts         FOR TESTING.
    METHODS registry_only_names_step     FOR TESTING.
ENDCLASS.


CLASS ltc_deadline IMPLEMENTATION.

  METHOD configure_scenario.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    DATA ls_expect TYPE zif_cd_fmon_types=>ty_expect.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    DATA ls_evidence TYPE zif_cd_fmon_types=>ty_stmt_evidence.

    CLEAR ms_ctx.
    ms_ctx-business_date = gc_test-date.
    ms_ctx-time_zone     = gc_test-time_zone.
    ms_ctx-now           = COND #( WHEN is_flags-before_due = abap_true THEN gc_test-before_due
                                   ELSE gc_test-after_due ).
    ms_check-check_id = gc_test-check_id.
    ms_check-severity = zif_cd_ops_types=>gc_severity-warning.

    ls_iface-iface_id  = gc_test-iface.
    ls_iface-direction = zif_cd_fmon_types=>gc_direction-inbound.
    ls_iface-file_type = zif_cd_fmon_types=>gc_file_type-statement.
    ls_iface-bank_key  = gc_test-bank.
    ls_iface-active    = abap_true.
    INSERT ls_iface INTO TABLE ms_ctx-ifaces.

    ls_expect-iface_id       = gc_test-iface.
    ls_expect-day_type       = COND #( WHEN is_flags-day_type IS NOT INITIAL THEN is_flags-day_type
                                       ELSE zif_cd_fmon_types=>gc_day_type-normal ).
    ls_expect-expected_count = COND #( WHEN is_flags-day_type IS NOT INITIAL THEN is_flags-expected ELSE 1 ).
    INSERT ls_expect INTO TABLE ms_ctx-expects.

    add_deadline( iv_stage    = zif_cd_fmon_types=>gc_stage-fully
                  iv_day_type = COND #( WHEN is_flags-row_day_type IS NOT INITIAL THEN is_flags-row_day_type
                                        ELSE CONV #( zif_cd_fmon_types=>gc_wildcard ) )
                  iv_due      = gc_test-due
                  iv_severity = COND #( WHEN is_flags-row_severity IS NOT INITIAL THEN is_flags-row_severity
                                        ELSE zif_cd_ops_types=>gc_severity-error ) ).
    IF is_flags-receipt_row = abap_true.
      add_deadline( iv_stage    = zif_cd_fmon_types=>gc_stage-received
                    iv_day_type = CONV #( zif_cd_fmon_types=>gc_wildcard )
                    iv_due      = gc_test-early_due
                    iv_severity = zif_cd_ops_types=>gc_severity-block ).
    ENDIF.

    IF is_flags-stage IS NOT INITIAL.
      ls_file-file_id       = '0000000000000000000000000000000A'.
      ls_file-iface_id      = gc_test-iface.
      ls_file-file_ref      = 'FEB/JPMC/20261106'.
      ls_file-direction     = zif_cd_fmon_types=>gc_direction-inbound.
      ls_file-business_date = gc_test-date.
      ls_file-stage         = is_flags-stage.
      ls_file-outcome       = COND #( WHEN zcl_cd_fmon_status=>is_terminal( is_flags-stage ) = abap_true
                                      THEN is_flags-stage ).
      ls_file-unprocessed_count = is_flags-open_lines.
      INSERT ls_file INTO TABLE ms_ctx-files.
    ENDIF.

    IF is_flags-evidence = abap_true.
      ls_evidence-iface_id          = gc_test-iface.
      ls_evidence-business_date     = gc_test-date.
      ls_evidence-bank_key          = gc_test-bank.
      ls_evidence-stmt_date         = gc_test-stmt_date.
      ls_evidence-accounts_expected = 2.
      ls_evidence-accounts_imported = is_flags-imported.
      ls_evidence-lines_total       = 10.
      ls_evidence-lines_open        = is_flags-open_lines.
      ls_evidence-posting_known     = abap_true.
      INSERT ls_evidence INTO TABLE ms_ctx-statements.
    ENDIF.
  ENDMETHOD.


  METHOD add_deadline.
    DATA ls_deadline TYPE zif_cd_fmon_types=>ty_deadline.
    ls_deadline-iface_id = gc_test-iface.
    ls_deadline-stage    = iv_stage.
    ls_deadline-day_type = iv_day_type.
    ls_deadline-due_time = iv_due.
    ls_deadline-severity = iv_severity.
    ls_deadline-active   = abap_true.
    INSERT ls_deadline INTO TABLE ms_ctx-deadlines.
  ENDMETHOD.


  METHOD run_check.
    rt_findings = NEW zcl_cd_fmon_chk_deadline( )->zif_cd_fmon_check~execute( is_ctx   = ms_ctx
                                                                              is_check = ms_check ).
  ENDMETHOD.


  METHOD assert_condition.
    cl_abap_unit_assert=>assert_equals( act = lines( it_findings ) exp = 1
                                        msg = 'One finding for the interface and day' ).
    DATA(ls_finding) = it_findings[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code
                                        exp = zif_cd_fmon_types=>gc_check_code-deadline_missed
                                        msg = 'Check code STAGE_DEADLINE_MISSED' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-group2 exp = iv_cond
                                        msg = 'The earliest missing step is named' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key
                                        exp = zcl_cd_fmon_util=>iface_day_key( iv_iface_id = gc_test-iface
                                                                              iv_date     = gc_test-date )
                                        msg = 'Object key interface/business date' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-group1 exp = gc_test-iface
                                        msg = 'Interface in group1 (alert routing)' ).
  ENDMETHOD.


  " Condition 1: at the due time no file was received and no statement imported
  METHOD not_received_is_condition_1.
    TRY.
        configure_scenario( VALUE #( evidence = abap_true ) ).
        DATA(lt_findings) = run_check( ).
        assert_condition( it_findings = lt_findings iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_received ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Severity from the deadline row, not the check row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Condition 2: the file arrived (PRISM / load log), no payment engine account was imported
  METHOD no_import_is_condition_2.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-received evidence = abap_true ) ).
        assert_condition( it_findings = run_check( ) iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_imported ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Condition 2 (partial): some payment engine accounts imported, others not
  METHOD some_accounts_is_condition_2.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-received evidence = abap_true
                                     imported = 1 ) ).
        assert_condition( it_findings = run_check( ) iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_imported ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Condition 3: every account imported, an in-scope entry is not posted
  METHOD not_posted_is_condition_3.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-partially evidence = abap_true
                                     imported = 2 open_lines = 3 ) ).
        assert_condition( it_findings = run_check( ) iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_posted ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " All good: fully processed before the due time - no finding
  METHOD processed_raises_nothing.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-fully evidence = abap_true
                                     imported = 2 ) ).
        cl_abap_unit_assert=>assert_initial( act = run_check( ) msg = 'Processed in time: no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Non-business day: a holiday never fires, whatever is missing
  METHOD holiday_raises_nothing.
    TRY.
        configure_scenario( VALUE #( day_type = zif_cd_fmon_types=>gc_day_type-holiday expected = 1
                                     evidence = abap_true ) ).
        cl_abap_unit_assert=>assert_initial( act = run_check( ) msg = 'Holiday: no deadline' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A business day on which the calendar expects no file does not fire either
  METHOD no_file_day_raises_nothing.
    TRY.
        configure_scenario( VALUE #( day_type = zif_cd_fmon_types=>gc_day_type-normal expected = 0 ) ).
        cl_abap_unit_assert=>assert_initial( act = run_check( ) msg = 'No file expected: no deadline' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: one minute before the due time nothing is due yet
  METHOD before_due_raises_nothing.
    TRY.
        configure_scenario( VALUE #( before_due = abap_true ) ).
        cl_abap_unit_assert=>assert_initial( act = run_check( ) msg = 'Before the due time: no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A month-end day without its own row uses the NORMAL row (same fallback as the calendar)
  METHOD month_end_uses_normal_row.
    TRY.
        configure_scenario( VALUE #( day_type     = zif_cd_fmon_types=>gc_day_type-month_end expected = 1
                                     row_day_type = zif_cd_fmon_types=>gc_day_type-normal ) ).
        assert_condition( it_findings = run_check( ) iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_received ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two missed stages of one interface and day are one finding, with the worst severity
  METHOD one_finding_per_day.
    TRY.
        configure_scenario( VALUE #( receipt_row = abap_true ) ).
        DATA(lt_findings) = run_check( ).
        assert_condition( it_findings = lt_findings iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_received ).
        cl_abap_unit_assert=>assert_equals( act = lt_findings[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-block
                                            msg = 'Worst severity of the missed rows' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The message names the step, the due time, the bank, the statement date and the counts
  METHOD message_names_counts.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-partially evidence = abap_true
                                     imported = 2 open_lines = 3 ) ).
        DATA(lv_tail) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_accounts
                                               iv_v1    = 2
                                               iv_v2    = 2 ).
        lv_tail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_lines_open
                                         iv_v1    = 3
                                         iv_v2    = 10
                                         iv_tail  = lv_tail ).
        lv_tail = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_statement
                                         iv_v1    = gc_test-bank
                                         iv_v2    = |{ gc_test-stmt_date DATE = ISO }|
                                         iv_tail  = lv_tail ).
        DATA(lv_exp) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_types=>gc_msg-deadline_not_posted
                                              iv_v1    = gc_test-iface
                                              iv_v2    = |{ gc_test-date DATE = ISO }|
                                              iv_v3    = |{ gc_test-due TIME = ISO }|
                                              iv_v4    = zif_cd_fmon_types=>gc_stage-fully
                                              iv_tail  = lv_tail ).
        DATA(lt_findings) = run_check( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals( act = CONV string( lt_findings[ 1 ]-message )
                                            exp = lv_exp
                                            msg = 'Message 274 with bank, statement date, lines and accounts' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Without statement evidence the registry stage names the step (another source, FEB off)
  METHOD registry_only_names_step.
    TRY.
        configure_scenario( VALUE #( stage = zif_cd_fmon_types=>gc_stage-loaded ) ).
        assert_condition( it_findings = run_check( ) iv_cond = zif_cd_fmon_types=>gc_deadline_cond-not_posted ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
