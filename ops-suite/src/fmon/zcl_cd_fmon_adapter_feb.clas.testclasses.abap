*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_adapter_feb.clas.testclasses.abap
*& Purpose:
*& Application tests of the FEB source adapter with LTD_* FMON DAO, factory
*& calendar, EBS statement evidence (ZCL_CD_EBS_INJECTOR) and clock: the stage
*& per evidence state (fully / partially processed, received, loaded, evidence
*& only), the statement date of a Monday (prior working day), weekend business
*& dates, correlation with an instance registered by another source, banks
*& without payment engine accounts and interfaces out of the source's scope.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (BAI processing deadline: received / imported / processed evidence).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
    DATA mt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA mt_files TYPE zif_cd_fmon_types=>tt_file.
ENDCLASS.


CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~get_ifaces.
    rt_ifaces = mt_ifaces.
  ENDMETHOD.

  METHOD zif_cd_fmon_dao~get_calendars.
    CLEAR rt_cals.
  ENDMETHOD.

  METHOD zif_cd_fmon_dao~get_eval_files.
    rt_files = VALUE #( FOR ls_file IN mt_files
                        WHERE ( business_date BETWEEN iv_date_from AND iv_date_to ) ( ls_file ) ).
  ENDMETHOD.
ENDCLASS.


"! Saturday and Sunday are not working days (2026-11-07 / 08)
CLASS ltd_calendar DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_calendar PARTIALLY IMPLEMENTED.
ENDCLASS.


CLASS ltd_calendar IMPLEMENTATION.
  METHOD zif_cd_fmon_calendar~is_working_day.
    rv_working = xsdbool( iv_date <> '20261107' AND iv_date <> '20261108' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_evidence DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_stmt_evidence.
    DATA mt_evidence TYPE zif_cd_ebs_stmt_evidence=>tt_evidence.
    DATA ms_request TYPE zif_cd_ebs_stmt_evidence=>ty_request.
ENDCLASS.


CLASS ltd_evidence IMPLEMENTATION.
  METHOD zif_cd_ebs_stmt_evidence~read.
    ms_request  = is_request.
    rt_evidence = mt_evidence.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock PARTIALLY IMPLEMENTED.
ENDCLASS.


CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261109081500'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_adapter_feb DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        iface      TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'BAI_JPMC_IN',
        other      TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_RET_PNC_IN',
        bank       TYPE zif_cd_fmon_types=>ty_bank_key VALUE 'JPMC',
        src_id     TYPE zif_cd_fmon_types=>ty_src_id VALUE 'FEB',
        monday     TYPE d VALUE '20261109',
        friday     TYPE d VALUE '20261106',
        saturday   TYPE d VALUE '20261107',
        prism_ref  TYPE zif_cd_fmon_types=>ty_file_ref VALUE 'BAI_JPMC_20261109.TXT',
        own_ref    TYPE zif_cd_fmon_types=>ty_file_ref VALUE 'FEB/JPMC/20261106',
        now        TYPE timestampl VALUE '20261109081500',
        max_rows   TYPE i VALUE 100,
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        expected      TYPE i,
        imported      TYPE i,
        lines         TYPE i,
        open_lines    TYPE i,
        posting_off   TYPE abap_bool,
        "! Another source registered the Monday instance (PRISM delivery)
        prism_file    TYPE abap_bool,
        "! Window starts on the Saturday (weekend business dates)
        from_saturday TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_evidence TYPE REF TO ltd_evidence.
    DATA ms_request TYPE zif_cd_fmon_types=>ty_read_request.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS read_records
      RETURNING
        VALUE(rt_records) TYPE zif_cd_fmon_types=>tt_src_record
      RAISING
        zcx_ca_ops_error.
    METHODS expected_record
      IMPORTING
        is_flags        TYPE ty_flags
        iv_stage        TYPE zif_cd_fmon_types=>ty_stage
        iv_status       TYPE zif_cd_fmon_types=>ty_status_value
        iv_count        TYPE i
        iv_unprocessed  TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_exp)   TYPE zif_cd_fmon_types=>ty_src_record.

    METHODS all_posted_is_fully          FOR TESTING.
    METHODS open_entries_are_partial     FOR TESTING.
    METHODS some_accounts_is_received    FOR TESTING.
    METHODS nothing_imported_is_evidence FOR TESTING.
    METHODS posting_off_is_loaded        FOR TESTING.
    METHODS monday_reads_friday          FOR TESTING.
    METHODS prism_instance_is_used       FOR TESTING.
    METHODS bank_without_accounts_skip   FOR TESTING.
ENDCLASS.


CLASS ltc_adapter_feb IMPLEMENTATION.

  METHOD setup.
    mo_dao      = NEW #( ).
    mo_evidence = NEW #( ).
    zcl_cd_fmon_injector=>inject_dao( mo_dao ).
    zcl_cd_fmon_injector=>inject_calendar( NEW ltd_calendar( ) ).
    zcl_cd_ebs_injector=>inject_stmt_evidence( mo_evidence ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_evidence.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    DATA ls_evidence TYPE zif_cd_ebs_stmt_evidence=>ty_evidence.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.

    CLEAR ms_request.
    ms_request-src-src_id        = gc_test-src_id.
    ms_request-src-adapter_class = 'ZCL_CD_FMON_ADAPTER_FEB'.
    ms_request-date_from         = COND #( WHEN is_flags-from_saturday = abap_true THEN gc_test-saturday
                                           ELSE gc_test-monday ).
    ms_request-date_to           = gc_test-monday.
    ms_request-time_zone         = zif_ca_ops_types=>gc_time_zone_utc.
    ms_request-max_rows          = gc_test-max_rows.

    ls_iface-iface_id  = gc_test-iface.
    ls_iface-direction = zif_cd_fmon_types=>gc_direction-inbound.
    ls_iface-file_type = zif_cd_fmon_types=>gc_file_type-statement.
    ls_iface-bank_key  = gc_test-bank.
    ls_iface-active    = abap_true.
    INSERT ls_iface INTO TABLE mo_dao->mt_ifaces.
    " Not a statement interface: not reported by a source row without interface
    ls_iface-iface_id  = gc_test-other.
    ls_iface-file_type = zif_cd_fmon_types=>gc_file_type-returns.
    INSERT ls_iface INTO TABLE mo_dao->mt_ifaces.

    ls_evidence-bank_key          = gc_test-bank.
    ls_evidence-stmt_date         = gc_test-friday.
    ls_evidence-accounts_expected = is_flags-expected.
    ls_evidence-accounts_imported = is_flags-imported.
    ls_evidence-statements        = is_flags-imported.
    ls_evidence-lines_total       = is_flags-lines.
    ls_evidence-lines_open        = is_flags-open_lines.
    ls_evidence-posting_known     = xsdbool( is_flags-posting_off = abap_false ).
    INSERT ls_evidence INTO TABLE mo_evidence->mt_evidence.

    IF is_flags-prism_file = abap_true.
      ls_file-file_id       = '0000000000000000000000000000000B'.
      ls_file-iface_id      = gc_test-iface.
      ls_file-file_ref      = gc_test-prism_ref.
      ls_file-business_date = gc_test-monday.
      ls_file-stage         = zif_cd_fmon_types=>gc_stage-received.
      INSERT ls_file INTO TABLE mo_dao->mt_files.
    ENDIF.
  ENDMETHOD.


  METHOD read_records.
    rt_records = NEW zcl_cd_fmon_adapter_feb( )->zif_cd_fmon_adapter~read( ms_request ).
  ENDMETHOD.


  METHOD expected_record.
    rs_exp-src_id        = gc_test-src_id.
    rs_exp-iface_id      = gc_test-iface.
    rs_exp-file_ref      = COND #( WHEN is_flags-prism_file = abap_true THEN gc_test-prism_ref
                                   ELSE gc_test-own_ref ).
    rs_exp-business_date = gc_test-monday.
    rs_exp-event_at      = gc_test-now.
    rs_exp-count_known   = abap_true.
    rs_exp-stage         = iv_stage.
    rs_exp-raw_status    = iv_status.
    rs_exp-rec_count     = iv_count.
    rs_exp-unprocessed   = iv_unprocessed.
    rs_exp-evidence_only = xsdbool( iv_stage IS INITIAL ).
    rs_exp-evidence-iface_id          = gc_test-iface.
    rs_exp-evidence-business_date     = gc_test-monday.
    rs_exp-evidence-bank_key          = gc_test-bank.
    rs_exp-evidence-stmt_date         = gc_test-friday.
    rs_exp-evidence-accounts_expected = is_flags-expected.
    rs_exp-evidence-accounts_imported = is_flags-imported.
    rs_exp-evidence-lines_total       = is_flags-lines.
    rs_exp-evidence-lines_open        = is_flags-open_lines.
    rs_exp-evidence-posting_known     = xsdbool( is_flags-posting_off = abap_false ).
  ENDMETHOD.


  " Rule: every payment engine account imported, every in-scope entry posted - FULLY_PROCESSED
  METHOD all_posted_is_fully.
    TRY.
        DATA(ls_flags) = VALUE ty_flags( expected = 2 imported = 2 lines = 10 ).
        configure_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals(
          act = read_records( )
          exp = VALUE zif_cd_fmon_types=>tt_src_record( ( expected_record(
                  is_flags = ls_flags iv_stage = zif_cd_fmon_types=>gc_stage-fully
                  iv_status = zif_cd_fmon_types=>gc_feb_status-posted iv_count = 10 ) ) )
          msg = 'One fully processed record for the Monday statement file' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: entries not posted - PARTIALLY_PROCESSED with the open entries as unprocessed count
  METHOD open_entries_are_partial.
    TRY.
        DATA(ls_flags) = VALUE ty_flags( expected = 2 imported = 2 lines = 10 open_lines = 3 ).
        configure_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals(
          act = read_records( )
          exp = VALUE zif_cd_fmon_types=>tt_src_record( ( expected_record(
                  is_flags = ls_flags iv_stage = zif_cd_fmon_types=>gc_stage-partially
                  iv_status = zif_cd_fmon_types=>gc_feb_status-posting_open iv_count = 10 iv_unprocessed = 3 ) ) )
          msg = 'Partially processed, 3 entries unprocessed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: some accounts imported - the file arrived (FILE_RECEIVED), the import is not complete
  METHOD some_accounts_is_received.
    TRY.
        DATA(ls_flags) = VALUE ty_flags( expected = 2 imported = 1 lines = 4 ).
        configure_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals(
          act = read_records( )
          exp = VALUE zif_cd_fmon_types=>tt_src_record( ( expected_record(
                  is_flags = ls_flags iv_stage = zif_cd_fmon_types=>gc_stage-received
                  iv_status = zif_cd_fmon_types=>gc_feb_status-import_partial iv_count = 1 ) ) )
          msg = 'Received, one of two accounts imported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing imported - no stage, only the evidence for the deadline check
  METHOD nothing_imported_is_evidence.
    TRY.
        DATA(ls_flags) = VALUE ty_flags( expected = 2 ).
        configure_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals(
          act = read_records( )
          exp = VALUE zif_cd_fmon_types=>tt_src_record( ( expected_record(
                  is_flags = ls_flags iv_stage = space iv_status = space iv_count = 0 ) ) )
          msg = 'Evidence only: zero of two accounts' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: posting state not read (EBS_FEB_POSTED_FIELDS OFF) - imported, processing not proven
  METHOD posting_off_is_loaded.
    TRY.
        DATA(ls_flags) = VALUE ty_flags( expected = 2 imported = 2 lines = 10 posting_off = abap_true ).
        configure_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals(
          act = read_records( )
          exp = VALUE zif_cd_fmon_types=>tt_src_record( ( expected_record(
                  is_flags = ls_flags iv_stage = zif_cd_fmon_types=>gc_stage-loaded
                  iv_status = zif_cd_fmon_types=>gc_feb_status-imported iv_count = 10 ) ) )
          msg = 'FILE_LOADED only - never FULLY_PROCESSED without the posting state' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: Monday's statement file carries Friday's statement (prior working day, offset 1);
  " Saturday and Sunday are no business dates
  METHOD monday_reads_friday.
    TRY.
        configure_scenario( VALUE #( expected = 2 imported = 2 lines = 10 from_saturday = abap_true ) ).
        DATA(lt_records) = read_records( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_records ) exp = 1
                                            msg = 'Weekend days are no business dates' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_evidence->ms_request-stmt_dates
          exp = VALUE zif_cd_ebs_stmt_evidence=>tt_date( ( gc_test-friday ) )
          msg = 'Statement date of Monday is Friday' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_evidence->ms_request-bank_keys
          exp = VALUE zif_cd_ebs_stmt_evidence=>tt_bank_key( ( CONV #( gc_test-bank ) ) )
          msg = 'Only the statement interface bank is read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the one instance registered by another source for the day takes the statement
  METHOD prism_instance_is_used.
    TRY.
        DATA(ls_flags) = VALUE ty_flags( expected = 2 imported = 2 lines = 10 prism_file = abap_true ).
        configure_scenario( ls_flags ).
        DATA(lt_records) = read_records( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_records ) exp = 1 msg = 'One record' ).
        cl_abap_unit_assert=>assert_equals( act = lt_records[ 1 ]-file_ref exp = gc_test-prism_ref
                                            msg = 'Statement evidence goes to the PRISM file instance' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a bank without active payment engine accounts proves nothing - no record
  METHOD bank_without_accounts_skip.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = read_records( ) msg = 'No accounts: no record' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
