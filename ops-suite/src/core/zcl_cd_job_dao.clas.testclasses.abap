*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the suite's SAP job monitor plug-in data access on
*& cl_osql_test_environment doubles of DPAYH and ZCD_PAY_OUTCOME: payments
*& of the asked runs per company code, rows without a payment document and runs not asked left
*& out (also a run date / run ID pair crossed between two asked runs);
*& current worklist rows with a finding per run. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
CLASS ltc_job_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_day_1 TYPE d VALUE '20261110',
      gc_day_2 TYPE d VALUE '20261111',
      gc_run_1 TYPE c LENGTH 6 VALUE 'PAY01',
      gc_run_2 TYPE c LENGTH 6 VALUE 'PAY02',
      gc_bukrs TYPE bukrs VALUE 'ZT01'.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_job_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS given_payment
      IMPORTING
        iv_laufd TYPE d
        iv_laufi TYPE clike
        iv_doc   TYPE clike OPTIONAL.

    METHODS payments_of_asked_runs  FOR TESTING.
    METHODS worklist_exceptions_run FOR TESTING.
ENDCLASS.


CLASS ltc_job_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'DPAYH' ) ( 'ZCD_PAY_OUTCOME' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_job_dao( ).
  ENDMETHOD.


  METHOD given_payment.
    DATA lt_rows TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_row TYPE dpayh.
    ls_row-laufd = iv_laufd.
    ls_row-laufi = iv_laufi.
    ls_row-pyord = |{ iv_laufi }{ iv_doc }|.
    ls_row-doc1r = iv_doc.
    ls_row-bukrs = gc_bukrs.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Rule: payments of the asked runs per company code; proposals and pairs not asked are left out
  METHOD payments_of_asked_runs.
    TRY.
        given_payment( iv_laufd = gc_day_1 iv_laufi = gc_run_1 iv_doc = '000000000001' ).
        given_payment( iv_laufd = gc_day_1 iv_laufi = gc_run_1 iv_doc = '000000000002' ).
        " a row without a payment document (proposal) is not a payment
        given_payment( iv_laufd = gc_day_1 iv_laufi = gc_run_1 ).
        given_payment( iv_laufd = gc_day_2 iv_laufi = gc_run_2 iv_doc = '000000000004' ).
        " crossed pair: day 1 with the ID of the second run was not asked
        given_payment( iv_laufd = gc_day_1 iv_laufi = gc_run_2 iv_doc = '000000000005' ).
        DATA(lt_payments) = mo_cut->run_payments( VALUE #( ( laufd = gc_day_1 laufi = gc_run_1 )
                                                           ( laufd = gc_day_2 laufi = gc_run_2 ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_payments ) exp = 2 msg = 'Two runs' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ laufd = gc_day_1 laufi = gc_run_1 ]-payments exp = 2
                                            msg = 'Row without payment document not counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: current worklist rows with a finding of the run
  METHOD worklist_exceptions_run.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA ls_row TYPE zcd_pay_outcome.
    TRY.
        " field by field (type resolution in the OSQL environment)
        ls_row-laufd    = gc_day_1.
        ls_row-laufi    = gc_run_1.
        ls_row-bukrs    = gc_bukrs.
        ls_row-augbl    = '000000000001'.
        ls_row-valid_to = zif_cd_ops_payout_types=>gc_valid_to_open.
        ls_row-finding  = 'PAYMENT_NOT_CLEARED'.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-augbl    = '000000000002'.
        CLEAR ls_row-finding.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-augbl    = '000000000003'.
        ls_row-valid_to = '20261110120000'.
        ls_row-finding  = 'PAYMENT_NOT_CLEARED'.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_exceptions) = mo_cut->run_exceptions( VALUE #( ( laufd = gc_day_1 laufi = gc_run_1 ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_exceptions[ 1 ]-exceptions exp = 1
                                            msg = 'One current exception row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
