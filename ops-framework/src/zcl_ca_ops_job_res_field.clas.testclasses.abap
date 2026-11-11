*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_field.clas.testclasses.abap
*& Purpose:
*& Tests of the resolver FIELD: blank JOB_PARENT_FIELDS = resolver off
*& (nothing read); a name that is not a field of TBTCO raises 127 before any
*& read; two fields of TBTCO are handed to the data access and the links are
*& confirmed (quality C); not two names raises 121. Data access double; the
*& runtime DDIC of TBTCO is read by RTTI (fields JOBNAME / JOBCOUNT exist).
*& Does not prove live SAP runtime behavior (VERIFY-SE11 V62).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mv_calls TYPE i.
    DATA mv_name_field TYPE zif_ca_ops_job_types=>ty_fieldname.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~parents_by_fields.
    mv_calls += 1.
    mv_name_field = iv_name_field.
    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      INSERT VALUE #( parent_name = 'ZT_PARENT' parent_count = '10000000'
                      child_name = <ls_key>-jobname child_count = <ls_key>-jobcount ) INTO TABLE rt_links.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_field DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.
    METHODS setup.
    METHODS teardown.
    METHODS parents
      RETURNING
        VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link
      RAISING
        zcx_ca_ops_error.
    METHODS blank_parameter_is_off  FOR TESTING.
    METHODS unknown_field_refused   FOR TESTING.
    METHODS known_fields_confirmed  FOR TESTING.
    METHODS one_name_is_not_usable  FOR TESTING.
ENDCLASS.


CLASS ltc_field IMPLEMENTATION.

  METHOD setup.
    mo_seed = NEW #( ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_dao = NEW #( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD parents.
    rt_links = NEW zcl_ca_ops_job_res_field( )->zif_ca_ops_job_resolver~parents(
                 it_jobs = VALUE #( ( jobname = 'ZT_CHILD' jobcount = '10000001' ) )
                 is_config = VALUE #( ) io_dao = mo_dao io_log = VALUE #( ) ).
  ENDMETHOD.


  " Rule: no fields configured = the resolver reads nothing
  METHOD blank_parameter_is_off.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = parents( ) msg = 'No link' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_calls exp = 0 msg = 'Nothing read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a guessed field that TBTCO does not have never reaches SQL (127)
  METHOD unknown_field_refused.
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-parent_fields iv_value = 'ZZ_NO_FIELD,JOBCOUNT' ).
    TRY.
        parents( ).
        cl_abap_unit_assert=>fail( msg = 'Expected 127' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '127'
                                            msg = 'Not a field of TBTCO' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_calls exp = 0 msg = 'Nothing read' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: two fields of the runtime DDIC are used and the links are confirmed
  METHOD known_fields_confirmed.
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-parent_fields iv_value = 'jobname,jobcount' ).
    TRY.
        DATA(lt_links) = parents( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_name_field exp = 'JOBNAME' msg = 'Upper-case field name' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-quality exp = zif_ca_ops_job_types=>gc_quality-confirmed
                                            msg = 'Confirmed by key' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-resolver exp = zif_ca_ops_job_types=>gc_resolver-field
                                            msg = 'Resolver FIELD' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the parameter names exactly two fields (121 otherwise)
  METHOD one_name_is_not_usable.
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-parent_fields iv_value = 'JOBNAME' ).
    TRY.
        parents( ).
        cl_abap_unit_assert=>fail( msg = 'Expected 121' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '121'
                                            msg = 'Two names required' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
