*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_runtime_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the runtime reads: NRIV internal intervals of the current /
*& next year (external and past years left out), DPAYH payments in the
*& run-date window with the collection indicator of their method (proposal
*& runs, other methods, blank DOC1R left out), cleared assignments (BSAS)
*& and qRFC entries grouped per queue / state / day with the oldest time;
*& field and whitelist validation before any SQL. DDIC descriptions and
*& the whitelist come from an HCK DAO double; does not prove live SAP
*& runtime behavior (VERIFY-DDIC field names, BSAS as compatibility view).
*& Modification log:
*& 2026-11-07 | Initial version (checks E_NUMRANGE, E_QUEUES, A_INFLIGHT).
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
    METHODS cleared_assignment_found     FOR TESTING.
    METHODS queue_grouped_per_day        FOR TESTING.
    METHODS unknown_field_raises         FOR TESTING.
    METHODS configured_needs_whitelist   FOR TESTING.
    METHODS date_field_must_be_dats      FOR TESTING.
ENDCLASS.


CLASS ltc_runtime_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'NRIV' ) ( 'DPAYH' ) ( 'T001' ) ( 'TFK042Z' ) ( 'BSAS' ) ( 'TRFCQOUT' ) ) ).
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
    DATA lt_bsas TYPE STANDARD TABLE OF bsas WITH EMPTY KEY.
    DATA ls_bsas TYPE bsas.
    " Disbursement wire in the window (read)
    ls_dpayh-laufd = '20261105'.
    ls_dpayh-laufi = 'R00001'.
    ls_dpayh-doc1r = gc_test-doc1.
    ls_dpayh-bukrs = gc_test-bukrs.
    ls_dpayh-pymet = gc_test-wire.
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

    ls_bsas-bukrs = gc_test-bukrs.
    ls_bsas-zuonr = gc_test-doc2.
    ls_bsas-belnr = '0100000001'.
    ls_bsas-gjahr = '2026'.
    ls_bsas-buzei = '001'.
    INSERT ls_bsas INTO TABLE lt_bsas.
    go_env->insert_test_data( lt_bsas ).
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
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_cleared_assignments( VALUE #( ) )
                                             msg = 'No key: nothing read' ).
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
        cl_abap_unit_assert=>assert_true( act = lt_payments[ 2 ]-xeinz msg = 'Direct debit: collection' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an assignment with a cleared G/L line is returned, others are not
  METHOD cleared_assignment_found.
    TRY.
        DATA(lt_cleared) = mo_cut->get_cleared_assignments(
          VALUE #( ( bukrs = gc_test-bukrs zuonr = gc_test-doc2 ) ( bukrs = gc_test-bukrs zuonr = gc_test-doc1 ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_cleared
                                            exp = VALUE zif_cd_hck_runtime_types=>tt_assignment(
                                                    ( bukrs = gc_test-bukrs zuonr = gc_test-doc2 ) )
                                            msg = 'Only the cleared assignment' ).
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


  " Rule: a configured table (bgRFC) must be on ZCD_HCK_TABWL
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
