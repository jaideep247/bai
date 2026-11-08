*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_runtime_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the runtime reads: NRIV internal intervals of the current /
*& next year (external and past years left out), DPAYH payments in the
*& run-date window with the collection indicator of their method (proposal
*& runs, other methods, blank DOC1R left out) and qRFC entries grouped
*& per queue / state / day with the oldest time; field and whitelist
*& validation before any SQL. ltc_inflight_reads: G/L lines by XREF2 (company
*& code, fiscal years, accounts, cap), active rows of the in-flight
*& configuration, a configured table read by reference (whitelist, DDIC).
*& DDIC descriptions and the whitelist come from an HCK DAO double; does
*& not prove live SAP runtime behavior (VERIFY-DDIC field names).
*& Modification log:
*& 2026-11-07 | Initial version (checks E_NUMRANGE, E_QUEUES, A_INFLIGHT).
*& 2026-11-07 | BSAS assignment test replaced; ltc_inflight_reads (user rules 1-5).
*& 2026-11-07 | payments_by_document_all_runs: payment runs by payment document (canonical outcome).
*& 2026-11-08 | Table consolidation: the HCK whitelist is ZCD_OPS_TABWL (HCK / READ), comments only.
*&---------------------------------------------------------------------*
CLASS ltd_hck_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_fields TYPE zif_cd_hck_types=>tt_field.
    DATA mv_whitelisted TYPE abap_bool.
ENDCLASS.

CLASS ltd_hck_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_table_fields.
    rt_fields = mt_fields.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~is_table_whitelisted.
    rv_allowed = mv_whitelisted.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_runtime_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        object  TYPE zif_cd_hck_runtime_types=>ty_nr_object VALUE 'FKK_BELEG',
        other   TYPE zif_cd_hck_runtime_types=>ty_nr_object VALUE 'OTHER_OBJ',
        year    TYPE zif_cd_hck_runtime_types=>ty_year VALUE '2026',
        next    TYPE zif_cd_hck_runtime_types=>ty_year VALUE '2027',
        past    TYPE zif_cd_hck_runtime_types=>ty_year VALUE '2025',
        bukrs   TYPE c LENGTH 4 VALUE 'US01',
        land1   TYPE c LENGTH 3 VALUE 'US',
        wire    TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'E',
        debit   TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'D',
        other_m TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'K',
        doc1    TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
        doc2    TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
        from    TYPE d VALUE '20261101',
        to      TYPE d VALUE '20261111',
        queue   TYPE zif_cd_hck_runtime_types=>ty_queue_name VALUE 'ZCD_PAYM_0001',
        dest    TYPE zif_cd_hck_runtime_types=>ty_queue_name VALUE 'PRISM_OUT',
        day     TYPE d VALUE '20261110',
        early   TYPE t VALUE '081500',
        late    TYPE t VALUE '093000',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_hck_runtime_dao.
    DATA mo_hck_dao TYPE REF TO ltd_hck_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS insert_number_ranges.
    METHODS insert_payments.
    METHODS insert_queue_entries.
    METHODS set_field
      IMPORTING
        iv_name  TYPE clike
        iv_value TYPE simple
      CHANGING
        cs_row   TYPE any.
    METHODS qrfc_source
      RETURNING
        VALUE(rs_source) TYPE zif_cd_hck_runtime_types=>ty_queue_source.

    METHODS intervals_internal_this_year FOR TESTING.
    METHODS no_objects_read_nothing      FOR TESTING.
    METHODS payments_window_and_flow     FOR TESTING.
    METHODS payments_by_document_all_runs FOR TESTING.
    METHODS queue_grouped_per_day        FOR TESTING.
    METHODS unknown_field_raises         FOR TESTING.
    METHODS configured_needs_whitelist   FOR TESTING.
    METHODS date_field_must_be_dats      FOR TESTING.
ENDCLASS.


CLASS ltc_runtime_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'NRIV' ) ( 'DPAYH' ) ( 'T001' ) ( 'TFK042Z' ) ( 'TRFCQOUT' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    insert_number_ranges( ).
    insert_payments( ).
    insert_queue_entries( ).
    mo_hck_dao = NEW #( ).
    mo_hck_dao->mt_fields = VALUE #( ( fieldname = zif_cd_hck_runtime_types=>gc_trfcqout-name_field
                                       type_kind = cl_abap_typedescr=>typekind_char )
                                     ( fieldname = zif_cd_hck_runtime_types=>gc_trfcqout-dest_field
                                       type_kind = cl_abap_typedescr=>typekind_char )
                                     ( fieldname = zif_cd_hck_runtime_types=>gc_trfcqout-state_field
                                       type_kind = cl_abap_typedescr=>typekind_char )
                                     ( fieldname = zif_cd_hck_runtime_types=>gc_trfcqout-date_field
                                       type_kind = cl_abap_typedescr=>typekind_date )
                                     ( fieldname = zif_cd_hck_runtime_types=>gc_trfcqout-time_field
                                       type_kind = cl_abap_typedescr=>typekind_time ) ).
    zcl_cd_hck_injector=>inject_dao( mo_hck_dao ).
    mo_cut = NEW zcl_cd_hck_runtime_dao( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_cut, mo_hck_dao.
  ENDMETHOD.


  METHOD insert_number_ranges.
    DATA lt_nriv TYPE STANDARD TABLE OF nriv WITH EMPTY KEY.
    DATA ls_nriv TYPE nriv.
    ls_nriv-object     = gc_test-object.
    ls_nriv-nrrangenr  = '01'.
    ls_nriv-toyear     = gc_test-year.
    ls_nriv-fromnumber = '00000000000000000001'.
    ls_nriv-tonumber   = '00000000000000000100'.
    ls_nriv-nrlevel    = '00000000000000000050'.
    INSERT ls_nriv INTO TABLE lt_nriv.
    " Next year and not year-dependent: read
    ls_nriv-toyear = gc_test-next.
    INSERT ls_nriv INTO TABLE lt_nriv.
    ls_nriv-nrrangenr = '02'.
    ls_nriv-toyear    = zif_cd_hck_runtime_types=>gc_nr_no_year.
    INSERT ls_nriv INTO TABLE lt_nriv.
    " Past year, external interval, other object: not read
    ls_nriv-nrrangenr = '03'.
    ls_nriv-toyear    = gc_test-past.
    INSERT ls_nriv INTO TABLE lt_nriv.
    ls_nriv-nrrangenr = '04'.
    ls_nriv-toyear    = gc_test-year.
    ls_nriv-externind = abap_true.
    INSERT ls_nriv INTO TABLE lt_nriv.
    CLEAR ls_nriv-externind.
    ls_nriv-object = gc_test-other.
    INSERT ls_nriv INTO TABLE lt_nriv.
    go_env->insert_test_data( lt_nriv ).
  ENDMETHOD.


  METHOD insert_payments.
    DATA lt_dpayh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_dpayh TYPE dpayh.
    DATA lt_t001 TYPE STANDARD TABLE OF t001 WITH EMPTY KEY.
    DATA ls_t001 TYPE t001.
    DATA lt_tfk042z TYPE STANDARD TABLE OF tfk042z WITH EMPTY KEY.
    DATA ls_tfk042z TYPE tfk042z.
    " Disbursement wire in the window (read)
    ls_dpayh-laufd = '20261105'.
    ls_dpayh-laufi = 'R00001'.
    ls_dpayh-doc1r = gc_test-doc1.
    ls_dpayh-bukrs = gc_test-bukrs.
    ls_dpayh-pymet = gc_test-wire.
    ls_dpayh-hbkid = 'JPMC1'.
    ls_dpayh-valut = '20261106'.
    ls_dpayh-rwbtr = '-100.00'.
    ls_dpayh-waers = 'USD'.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    " Collection direct debit in the window (read, XEINZ = X)
    ls_dpayh-laufi = 'R00002'.
    ls_dpayh-doc1r = gc_test-doc2.
    ls_dpayh-pymet = gc_test-debit.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    " Proposal run, blank DOC1R, out of window, other method: not read
    ls_dpayh-laufi = 'R00003'.
    ls_dpayh-doc1r = '000000300003'.
    ls_dpayh-pymet = gc_test-wire.
    ls_dpayh-xvorl = abap_true.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    CLEAR ls_dpayh-xvorl.
    ls_dpayh-laufi = 'R00004'.
    CLEAR ls_dpayh-doc1r.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    ls_dpayh-laufi = 'R00005'.
    ls_dpayh-doc1r = '000000300005'.
    ls_dpayh-laufd = '20261020'.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    ls_dpayh-laufi = 'R00006'.
    ls_dpayh-doc1r = '000000300006'.
    ls_dpayh-laufd = '20261105'.
    ls_dpayh-pymet = gc_test-other_m.
    INSERT ls_dpayh INTO TABLE lt_dpayh.
    go_env->insert_test_data( lt_dpayh ).

    ls_t001-bukrs = gc_test-bukrs.
    ls_t001-land1 = gc_test-land1.
    INSERT ls_t001 INTO TABLE lt_t001.
    go_env->insert_test_data( lt_t001 ).
    ls_tfk042z-land1 = gc_test-land1.
    ls_tfk042z-zlsch = gc_test-wire.
    INSERT ls_tfk042z INTO TABLE lt_tfk042z.
    ls_tfk042z-zlsch = gc_test-debit.
    ls_tfk042z-xeinz = abap_true.
    INSERT ls_tfk042z INTO TABLE lt_tfk042z.
    ls_tfk042z-zlsch = gc_test-other_m.
    CLEAR ls_tfk042z-xeinz.
    INSERT ls_tfk042z INTO TABLE lt_tfk042z.
    go_env->insert_test_data( lt_tfk042z ).
  ENDMETHOD.


  METHOD insert_queue_entries.
    DATA lt_queue TYPE STANDARD TABLE OF trfcqout WITH EMPTY KEY.
    DATA ls_queue TYPE trfcqout.
    " VERIFY-DDIC: fields set by name (the delivered constants), so the test follows them
    DO 3 TIMES.
      CLEAR ls_queue.
      set_field( EXPORTING iv_name = zif_cd_hck_runtime_types=>gc_trfcqout-name_field iv_value = gc_test-queue
                 CHANGING  cs_row  = ls_queue ).
      set_field( EXPORTING iv_name = zif_cd_hck_runtime_types=>gc_trfcqout-dest_field iv_value = gc_test-dest
                 CHANGING  cs_row  = ls_queue ).
      set_field( EXPORTING iv_name = zif_cd_hck_runtime_types=>gc_trfcqout-state_field iv_value = 'SYSFAIL'
                 CHANGING  cs_row  = ls_queue ).
      set_field( EXPORTING iv_name = zif_cd_hck_runtime_types=>gc_trfcqout-date_field iv_value = gc_test-day
                 CHANGING  cs_row  = ls_queue ).
      set_field( EXPORTING iv_name  = zif_cd_hck_runtime_types=>gc_trfcqout-time_field
                           iv_value = COND t( WHEN sy-index = 2 THEN gc_test-early ELSE gc_test-late )
                 CHANGING  cs_row   = ls_queue ).
      set_field( EXPORTING iv_name = 'QCOUNT' iv_value = sy-index
                 CHANGING  cs_row  = ls_queue ).
      INSERT ls_queue INTO TABLE lt_queue.
    ENDDO.
    go_env->insert_test_data( lt_queue ).
  ENDMETHOD.


  METHOD set_field.
    ASSIGN COMPONENT iv_name OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_field>).
    IF sy-subrc <> 0.
      cl_abap_unit_assert=>fail( msg = |VERIFY-DDIC: TRFCQOUT has no field { iv_name }| ).
    ENDIF.
    <lv_field> = iv_value.
  ENDMETHOD.


  METHOD qrfc_source.
    rs_source-kind        = zif_cd_hck_runtime_types=>gc_queue_kind-outbound.
    rs_source-tabname     = zif_cd_hck_runtime_types=>gc_trfcqout-tabname.
    rs_source-name_field  = zif_cd_hck_runtime_types=>gc_trfcqout-name_field.
    rs_source-dest_field  = zif_cd_hck_runtime_types=>gc_trfcqout-dest_field.
    rs_source-state_field = zif_cd_hck_runtime_types=>gc_trfcqout-state_field.
    rs_source-date_field  = zif_cd_hck_runtime_types=>gc_trfcqout-date_field.
    rs_source-time_field  = zif_cd_hck_runtime_types=>gc_trfcqout-time_field.
  ENDMETHOD.


  " Rule: internal intervals of the object, current / next year or not year-dependent, in key order
  METHOD intervals_internal_this_year.
    TRY.
        DATA(lt_intervals) = mo_cut->get_number_ranges( it_objects   = VALUE #( ( gc_test-object ) )
                                                        iv_year_from = gc_test-year
                                                        iv_year_to   = gc_test-next
                                                        iv_max_rows  = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_intervals ) exp = 3 msg = 'Three intervals read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_intervals[ 1 ]-toyear exp = gc_test-year msg = 'Key order' ).
        cl_abap_unit_assert=>assert_equals( act = lt_intervals[ 3 ]-toyear exp = zif_cd_hck_runtime_types=>gc_nr_no_year
                                            msg = 'Not year-dependent interval read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_intervals[ 1 ]-nrlevel exp = '00000000000000000050'
                                            msg = 'Level read' ).
        lt_intervals = mo_cut->get_number_ranges( it_objects   = VALUE #( ( gc_test-object ) )
                                                  iv_year_from = gc_test-year
                                                  iv_year_to   = gc_test-next
                                                  iv_max_rows  = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_intervals ) exp = 1 msg = 'Row cap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no configured object reads nothing (an empty range would read every object)
  METHOD no_objects_read_nothing.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_number_ranges( it_objects   = VALUE #( )
                                           iv_year_from = gc_test-year
                                           iv_year_to   = gc_test-next
                                           iv_max_rows  = 100 )
          msg = 'Nothing read' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_issued_payments( it_methods  = VALUE #( )
                                             iv_from     = gc_test-from
                                             iv_to       = gc_test-to
                                             iv_max_rows = 100 )
          msg = 'No method: nothing read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: payments of the requested methods in the run-date window, proposal runs and blank
  " DOC1R excluded, with the collection indicator of the method (TFK042Z via T001)
  METHOD payments_window_and_flow.
    TRY.
        DATA(lt_payments) = mo_cut->get_issued_payments( it_methods  = VALUE #( ( gc_test-wire ) ( gc_test-debit ) )
                                                         iv_from     = gc_test-from
                                                         iv_to       = gc_test-to
                                                         iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_payments ) exp = 2 msg = 'Two payments read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ 1 ]-doc1r exp = gc_test-doc1 msg = 'Oldest run first' ).
        cl_abap_unit_assert=>assert_false( act = lt_payments[ 1 ]-xeinz msg = 'Wire: disbursement' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ 1 ]-valut exp = '20261106' msg = 'Value date read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ 1 ]-currency exp = 'USD' msg = 'Currency read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ 1 ]-hbkid exp = 'JPMC1' msg = 'House bank read' ).
        cl_abap_unit_assert=>assert_true( act = lt_payments[ 2 ]-xeinz msg = 'Direct debit: collection' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the payment runs of payment documents (same join), every run of the document, latest
  " first, proposal runs left out; no document = nothing read
  METHOD payments_by_document_all_runs.
    TRY.
        DATA(lt_payments) = mo_cut->get_issued_payments_by_doc( it_docno    = VALUE #( ( gc_test-doc1 ) ( '000000300003' ) )
                                                                iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_payments ) exp = 1 msg = 'Proposal run left out' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ 1 ]-doc1r exp = gc_test-doc1 msg = 'The document' ).
        cl_abap_unit_assert=>assert_false( act = lt_payments[ 1 ]-xeinz msg = 'Flow from TFK042Z' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_issued_payments_by_doc( it_docno = VALUE #( ) iv_max_rows = 100 )
          msg = 'No document: nothing read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: entries are grouped per queue, destination, state and day with the oldest time
  METHOD queue_grouped_per_day.
    TRY.
        DATA(lt_groups) = mo_cut->get_queue_groups( is_source = qrfc_source( ) iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_groups ) exp = 1 msg = 'One group' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-entries exp = 3 msg = 'Three entries' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-qtime exp = gc_test-early msg = 'Oldest time of the day' ).
        cl_abap_unit_assert=>assert_equals( act = lt_groups[ 1 ]-dest exp = gc_test-dest msg = 'Destination' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a field name unknown to the DDIC raises before any SQL (never an empty result)
  METHOD unknown_field_raises.
    DATA(ls_source) = qrfc_source( ).
    ls_source-state_field = 'NO_SUCH_FIELD'.
    TRY.
        mo_cut->get_queue_groups( is_source = ls_source iv_max_rows = 100 ).
        cl_abap_unit_assert=>fail( msg = 'Unknown field must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Validation error' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a configured table (bgRFC) must be on ZCD_OPS_TABWL (HCK / READ)
  METHOD configured_needs_whitelist.
    DATA(ls_source) = qrfc_source( ).
    ls_source-configured = abap_true.
    TRY.
        mo_cut->get_queue_groups( is_source = ls_source iv_max_rows = 100 ).
        cl_abap_unit_assert=>fail( msg = 'Table off the whitelist must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Whitelist error' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the day field must be DATS (ages are computed from it)
  METHOD date_field_must_be_dats.
    DATA(ls_source) = qrfc_source( ).
    ls_source-date_field = zif_cd_hck_runtime_types=>gc_trfcqout-state_field.
    TRY.
        mo_cut->get_queue_groups( is_source = ls_source iv_max_rows = 100 ).
        cl_abap_unit_assert=>fail( msg = 'Character day field must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Type error' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.



CLASS ltc_inflight_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        bukrs TYPE c LENGTH 4 VALUE 'US01',
        doc1  TYPE zif_cd_hck_runtime_types=>ty_xref2 VALUE '000000300001',
        doc2  TYPE zif_cd_hck_runtime_types=>ty_xref2 VALUE '000000300002',
        hkont TYPE zif_cd_hck_runtime_types=>ty_hkont VALUE '0001100100',
        other TYPE zif_cd_hck_runtime_types=>ty_hkont VALUE '0001100200',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_hck_runtime_dao.
    DATA mo_hck_dao TYPE REF TO ltd_hck_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS insert_gl_lines.
    METHODS insert_configuration.

    METHODS gl_lines_by_xref2_window   FOR TESTING.
    METHODS gl_lines_by_account_capped FOR TESTING.
    METHODS configuration_active_only  FOR TESTING.
    METHODS reference_rows_read        FOR TESTING.
    METHODS reference_needs_whitelist  FOR TESTING.
    METHODS reference_unknown_field    FOR TESTING.
ENDCLASS.


CLASS ltc_inflight_reads IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'BSEG' ) ( 'ZCD_HCK_PMCLASS' ) ( 'ZCD_HCK_PMBANK' ) ( 'ZCD_HCK_CLRRULE' )
                                   ( 'ZCD_HCK_BTCROLE' ) ( 'ZCD_HCK_SEQOUT' ) ( 'ZCD_HCK_EVSET' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    insert_gl_lines( ).
    insert_configuration( ).
    mo_hck_dao = NEW #( ).
    mo_hck_dao->mt_fields = VALUE #( ( fieldname = 'METHOD_CLASS' type_kind = cl_abap_typedescr=>typekind_char )
                                     ( fieldname = 'FLOW' type_kind = cl_abap_typedescr=>typekind_char )
                                     ( fieldname = 'PAY_METHODS' type_kind = cl_abap_typedescr=>typekind_char ) ).
    mo_hck_dao->mv_whitelisted = abap_true.
    zcl_cd_hck_injector=>inject_dao( mo_hck_dao ).
    mo_cut = NEW zcl_cd_hck_runtime_dao( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_cut, mo_hck_dao.
  ENDMETHOD.


  METHOD insert_gl_lines.
    DATA lt_bseg TYPE STANDARD TABLE OF bseg WITH EMPTY KEY.
    DATA ls_bseg TYPE bseg.
    " Collection clearing line of doc1, cleared (Stripe: ZUONR = descriptor)
    ls_bseg-bukrs = gc_test-bukrs.
    ls_bseg-belnr = '0100000001'.
    ls_bseg-gjahr = '2026'.
    ls_bseg-buzei = '001'.
    ls_bseg-hkont = gc_test-hkont.
    ls_bseg-xref2 = gc_test-doc1.
    ls_bseg-zuonr = 'STRIPE DESCRIPTOR 1'.
    ls_bseg-augbl = '0200000001'.
    INSERT ls_bseg INTO TABLE lt_bseg.
    " Line of doc2 on another account, open
    ls_bseg-belnr = '0100000002'.
    ls_bseg-hkont = gc_test-other.
    ls_bseg-xref2 = gc_test-doc2.
    ls_bseg-zuonr = gc_test-doc2.
    CLEAR ls_bseg-augbl.
    INSERT ls_bseg INTO TABLE lt_bseg.
    " doc2 in an old fiscal year (outside the window) and in another company code
    ls_bseg-belnr = '0100000003'.
    ls_bseg-gjahr = '2024'.
    INSERT ls_bseg INTO TABLE lt_bseg.
    ls_bseg-belnr = '0100000004'.
    ls_bseg-gjahr = '2026'.
    ls_bseg-bukrs = 'DE01'.
    INSERT ls_bseg INTO TABLE lt_bseg.
    go_env->insert_test_data( lt_bseg ).
  ENDMETHOD.


  METHOD insert_configuration.
    DATA lt_class TYPE STANDARD TABLE OF zcd_hck_pmclass WITH EMPTY KEY.
    DATA ls_class TYPE zcd_hck_pmclass.
    DATA lt_bank TYPE STANDARD TABLE OF zcd_hck_pmbank WITH EMPTY KEY.
    DATA ls_bank TYPE zcd_hck_pmbank.
    DATA lt_rule TYPE STANDARD TABLE OF zcd_hck_clrrule WITH EMPTY KEY.
    DATA ls_rule TYPE zcd_hck_clrrule.
    DATA lt_role TYPE STANDARD TABLE OF zcd_hck_btcrole WITH EMPTY KEY.
    DATA ls_role TYPE zcd_hck_btcrole.
    DATA lt_out TYPE STANDARD TABLE OF zcd_hck_seqout WITH EMPTY KEY.
    DATA ls_out TYPE zcd_hck_seqout.
    DATA lt_set TYPE STANDARD TABLE OF zcd_hck_evset WITH EMPTY KEY.
    DATA ls_set TYPE zcd_hck_evset.
    ls_class-flow = 'D'.
    ls_class-method_class = 'WIR'.
    ls_class-pay_methods = 'E'.
    ls_class-age_basis = zif_cd_hck_runtime_types=>gc_age_basis-value_date.
    ls_class-calendar = 'US'.
    ls_class-active = abap_true.
    INSERT ls_class INTO TABLE lt_class.
    ls_class-method_class = 'ACI'.
    ls_class-active = abap_false.
    INSERT ls_class INTO TABLE lt_class.
    go_env->insert_test_data( lt_class ).
    ls_bank-flow = 'D'.
    ls_bank-method_class = 'ACI'.
    ls_bank-hbkid = 'BARC1'.
    ls_bank-calendar = 'GB'.
    ls_bank-active = abap_true.
    INSERT ls_bank INTO TABLE lt_bank.
    go_env->insert_test_data( lt_bank ).
    ls_rule-flow = 'D'.
    ls_rule-method_class = 'WIR'.
    ls_rule-purpose = zif_cd_hck_runtime_types=>gc_purpose-cleared.
    ls_rule-seq = '010'.
    ls_rule-evidence_class = 'ZCL_CD_HCK_EV_STMT_DOC'.
    ls_rule-required = zif_cd_hck_runtime_types=>gc_required-must_hold.
    ls_rule-active = abap_true.
    INSERT ls_rule INTO TABLE lt_rule.
    ls_rule-seq = '020'.
    ls_rule-active = abap_false.
    INSERT ls_rule INTO TABLE lt_rule.
    go_env->insert_test_data( lt_rule ).
    ls_role-flow = 'C'.
    ls_role-method_class = 'CRD'.
    ls_role-scheme = 'BAI2'.
    ls_role-btc_code = '195'.
    ls_role-role = 'PAYOUT_RECEIVED'.
    ls_role-active = abap_true.
    INSERT ls_role INTO TABLE lt_role.
    go_env->insert_test_data( lt_role ).
    ls_out-flow = 'D'.
    ls_out-method_class = 'ACH'.
    ls_out-seq = '010'.
    ls_out-seq_pattern = 'ORIGINAL'.
    ls_out-outcome = 'CLEARED'.
    ls_out-expected_dfkkrp = '0'.
    ls_out-active = abap_true.
    INSERT ls_out INTO TABLE lt_out.
    go_env->insert_test_data( lt_out ).
    ls_set-set_id = 'STRIPE'.
    ls_set-name = zif_cd_hck_runtime_types=>gc_setting-table.
    ls_set-value = 'ZCD_STRP_POUT_LOG'.
    ls_set-active = abap_true.
    INSERT ls_set INTO TABLE lt_set.
    ls_set-name = zif_cd_hck_runtime_types=>gc_setting-intent_field.
    ls_set-active = abap_false.
    INSERT ls_set INTO TABLE lt_set.
    go_env->insert_test_data( lt_set ).
  ENDMETHOD.


  " Rule: G/L lines by company code + XREF2 within the fiscal-year window, with ZUONR and AUGBL
  METHOD gl_lines_by_xref2_window.
    TRY.
        DATA(lt_lines) = mo_cut->get_gl_lines_by_xref2(
                           it_keys       = VALUE #( ( bukrs = gc_test-bukrs xref2 = gc_test-doc1 )
                                                    ( bukrs = gc_test-bukrs xref2 = gc_test-doc2 ) )
                           iv_gjahr_from = '2026'
                           iv_gjahr_to   = '2027'
                           it_hkont      = VALUE #( )
                           iv_max_rows   = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2 msg = 'Window and company code bound' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-augbl exp = '0200000001' msg = 'Clearing read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-zuonr exp = 'STRIPE DESCRIPTOR 1' msg = 'Assignment read' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->get_gl_lines_by_xref2( it_keys       = VALUE #( )
                                               iv_gjahr_from = '2026'
                                               iv_gjahr_to   = '2027'
                                               it_hkont      = VALUE #( )
                                               iv_max_rows   = 100 )
          msg = 'No key: nothing read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: G/L accounts restrict the read; the row cap cuts the result
  METHOD gl_lines_by_account_capped.
    TRY.
        DATA(lt_lines) = mo_cut->get_gl_lines_by_xref2(
                           it_keys       = VALUE #( ( bukrs = gc_test-bukrs xref2 = gc_test-doc1 )
                                                    ( bukrs = gc_test-bukrs xref2 = gc_test-doc2 ) )
                           iv_gjahr_from = '2026'
                           iv_gjahr_to   = '2027'
                           it_hkont      = VALUE #( ( gc_test-hkont ) )
                           iv_max_rows   = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'Only the clearing account' ).
        DATA(lt_capped) = mo_cut->get_gl_lines_by_xref2(
                            it_keys       = VALUE #( ( bukrs = gc_test-bukrs xref2 = gc_test-doc1 )
                                                     ( bukrs = gc_test-bukrs xref2 = gc_test-doc2 ) )
                            iv_gjahr_from = '2026'
                            iv_gjahr_to   = '2027'
                            it_hkont      = VALUE #( )
                            iv_max_rows   = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_capped ) exp = 1 msg = 'Cap applied' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every configuration read returns the active rows only (production switches rows off)
  METHOD configuration_active_only.
    TRY.
        DATA(lt_classes) = mo_cut->get_pm_classes( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_classes ) exp = 1 msg = 'Active class only' ).
        cl_abap_unit_assert=>assert_equals( act = lt_classes[ 1 ]-calendar exp = 'US' msg = 'Calendar read' ).
        DATA(lt_banks) = mo_cut->get_pm_banks( ).
        DATA(lt_roles) = mo_cut->get_btc_roles( ).
        DATA(lt_outcomes) = mo_cut->get_seq_outcomes( ).
        cl_abap_unit_assert=>assert_equals( act = lt_banks[ 1 ]-calendar exp = 'GB' msg = 'Bank calendar' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_clearing_rules( ) ) exp = 1 msg = 'Active rule only' ).
        cl_abap_unit_assert=>assert_equals( act = lt_roles[ 1 ]-role exp = 'PAYOUT_RECEIVED'
                                            msg = 'Role per flow / class / scheme / code' ).
        cl_abap_unit_assert=>assert_equals( act = lt_outcomes[ 1 ]-outcome exp = 'CLEARED' msg = 'Outcome' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_evidence_settings( 'STRIPE' ) ) exp = 1
                                            msg = 'Active settings of the set only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a configured table is read by its reference field for the given values (here the method
  " class table as stand-in for the Stripe payout log), roles without a field are not selected
  METHOD reference_rows_read.
    TRY.
        DATA(lt_rows) = mo_cut->get_reference_rows(
                          is_source   = VALUE #( tabname = 'ZCD_HCK_PMCLASS' ref_field = 'METHOD_CLASS'
                                                 type_field = 'FLOW' status_field = 'PAY_METHODS' )
                          it_refs     = VALUE #( ( CONV #( 'WIR' ) ) ( CONV #( 'XYZ' ) ) )
                          iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row by reference' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-rtype exp = 'D' msg = 'Role field read' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-status exp = 'E' msg = 'Status field read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the configured table must be on ZCD_OPS_TABWL (HCK / READ)
  METHOD reference_needs_whitelist.
    mo_hck_dao->mv_whitelisted = abap_false.
    TRY.
        mo_cut->get_reference_rows( is_source   = VALUE #( tabname = 'ZCD_HCK_PMCLASS' ref_field = 'METHOD_CLASS' )
                                    it_refs     = VALUE #( ( CONV #( 'WIR' ) ) )
                                    iv_max_rows = 100 ).
        cl_abap_unit_assert=>fail( msg = 'Table off the whitelist must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Whitelist error' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a field name that is not in the DDIC raises before any SQL
  METHOD reference_unknown_field.
    TRY.
        mo_cut->get_reference_rows( is_source   = VALUE #( tabname = 'ZCD_HCK_PMCLASS' ref_field = 'NO_SUCH_FIELD' )
                                    it_refs     = VALUE #( ( CONV #( 'WIR' ) ) )
                                    iv_max_rows = 100 ).
        cl_abap_unit_assert=>fail( msg = 'Unknown field must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Validation error' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
