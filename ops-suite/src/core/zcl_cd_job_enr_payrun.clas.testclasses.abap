*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_enr_payrun.clas.testclasses.abap
*& Purpose:
*& Unit tests of the payment run enricher with a data access double: a
*& mass activity run of a payment run type is the payment run LAUFD /
*& LAUFI with its payments and, when the run has one company code, that
*& company code; open worklist exceptions of the run are a second object;
*& a run of another activity type and a blank activity list add nothing.
*& Does not prove live SAP runtime behavior (VERIFY-SE11 V68).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_job_dao.
    DATA mt_payments TYPE zif_cd_job_types=>tt_run_payments.
    DATA mt_exceptions TYPE zif_cd_job_types=>tt_run_exceptions.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_job_dao~run_payments.
    LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_runs[ laufd = <ls_row>-laufd laufi = <ls_row>-laufi ] ).
        INSERT <ls_row> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_cd_job_dao~run_exceptions.
    LOOP AT mt_exceptions ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_runs[ laufd = <ls_row>-laufd laufi = <ls_row>-laufi ] ).
        INSERT <ls_row> INTO TABLE rt_exceptions.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_enr_payrun DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_activity TYPE string VALUE `0030`,
      gc_laufd    TYPE d VALUE '20261111',
      gc_laufi    TYPE c LENGTH 6 VALUE 'PAY01',
      gc_bukrs    TYPE bukrs VALUE 'ZT01',
      gc_job      TYPE btcjob VALUE 'ZT_FPY1_JOB',
      gc_count    TYPE btcjobcnt VALUE '10000001'.

    DATA mo_seed TYPE REF TO zcl_cd_ops_param_seed.
    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS act
      IMPORTING
        iv_activity       TYPE string DEFAULT gc_activity
      RETURNING
        VALUE(rt_objects) TYPE zif_ca_ops_job_types=>tt_bus_object
      RAISING
        zcx_ca_ops_error.

    METHODS payment_run_with_company   FOR TESTING.
    METHODS worklist_exceptions_object FOR TESTING.
    METHODS other_activity_no_run      FOR TESTING.
    METHODS blank_activities_off       FOR TESTING.
ENDCLASS.


CLASS ltc_enr_payrun IMPLEMENTATION.

  METHOD setup.
    mo_seed = NEW #( ).
    mo_seed->set( iv_name = zif_cd_job_types=>gc_param-payrun_activities iv_value = gc_activity ).
    zcl_cd_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_dao = NEW #( ).
    INSERT VALUE #( laufd = gc_laufd laufi = gc_laufi bukrs = gc_bukrs payments = 120 ) INTO TABLE mo_dao->mt_payments.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD act.
    rt_objects = VALUE #( ( jobname = gc_job jobcount = gc_count object_type = zif_cd_job_types=>gc_object_type-mass_run
                            object_key = |{ iv_activity }/{ gc_laufd }/{ gc_laufi }|
                            quality = zif_ca_ops_job_types=>gc_quality-probable ) ).
    NEW zcl_cd_job_enr_payrun( mo_dao )->zif_ca_ops_job_enricher~enrich(
      EXPORTING it_jobs    = VALUE #( ( jobname = gc_job jobcount = gc_count ) )
                it_steps   = VALUE #( )
      CHANGING  ct_objects = rt_objects ).
  ENDMETHOD.


  " Rule: the payment run of a payment-run mass activity, its payments and its one company code
  METHOD payment_run_with_company.
    TRY.
        DATA(lt_objects) = act( ).
        DATA(ls_run) = lt_objects[ object_type = zif_cd_job_types=>gc_object_type-payment_run ].
        cl_abap_unit_assert=>assert_equals( act = ls_run-object_key exp = |{ gc_laufd }/{ gc_laufi }| msg = 'LAUFD / LAUFI' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-item_count exp = 120 msg = 'Payments of the run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-bukrs exp = gc_bukrs msg = 'One company code' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-quality exp = zif_ca_ops_job_types=>gc_quality-probable
                                            msg = 'Quality of the mass activity link' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: open worklist exceptions of the run are an object of their own
  METHOD worklist_exceptions_object.
    TRY.
        INSERT VALUE #( laufd = gc_laufd laufi = gc_laufi exceptions = 3 ) INTO TABLE mo_dao->mt_exceptions.
        DATA(lt_objects) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = lt_objects[ object_type = zif_cd_job_types=>gc_object_type-worklist ]-item_count
          exp = 3 msg = 'Open exceptions of the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a mass activity of another type is no payment run
  METHOD other_activity_no_run.
    TRY.
        DATA(lt_objects) = act( iv_activity = `0090` ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_objects ) exp = 1 msg = 'Only the mass activity run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: delivered off - no activity type, nothing added
  METHOD blank_activities_off.
    TRY.
        mo_seed->remove( zif_cd_job_types=>gc_param-payrun_activities ).
        cl_abap_unit_assert=>assert_equals( act = lines( act( ) ) exp = 1 msg = 'Nothing added' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
