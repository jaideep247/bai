*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_eval_period.clas.testclasses.abap
*& Purpose:
*& Tests of the delivered period-close calendar: the rule on a list
*& (CLOSED_IN: area entry, company-code entry, * = every area, a scope of
*& several company codes closed only when each is) and the parameter
*& EVAL_PERIOD_CLOSED through the in-memory parameter store
*& (ZCL_CA_OPS_PARAM_SEED). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
CLASS ltc_period DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.

    METHODS area_entry_closes      FOR TESTING.
    METHODS bukrs_entry_one_only   FOR TESTING.
    METHODS any_area               FOR TESTING.
    METHODS nothing_configured     FOR TESTING.
    METHODS parameter_is_read      FOR TESTING.
ENDCLASS.


CLASS ltc_period IMPLEMENTATION.

  METHOD setup.
    mo_seed = NEW #( ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD area_entry_closes.
    DATA(lt_entries) = VALUE string_table( ( `ZT_OPS_A:202610` ) ).
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_eval_period=>closed_in( it_entries = lt_entries iv_area = 'ZT_OPS_A' iv_period = '202610' )
      msg = 'Area closed' ).
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_eval_period=>closed_in( it_entries = lt_entries iv_area = 'ZT_OPS_A' iv_period = '202610'
                                               iv_bukrs_list = 'ZT01,ZT02' )
      msg = 'An area entry closes every company code' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_eval_period=>closed_in( it_entries = lt_entries iv_area = 'ZT_OPS_A' iv_period = '202611' )
      msg = 'Other period open' ).
  ENDMETHOD.


  METHOD bukrs_entry_one_only.
    DATA(lt_entries) = VALUE string_table( ( `ZT_OPS_A:ZT01:202610` ) ).
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_eval_period=>closed_in( it_entries = lt_entries iv_area = 'ZT_OPS_A' iv_period = '202610'
                                               iv_bukrs_list = 'ZT01' )
      msg = 'Company code closed' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_eval_period=>closed_in( it_entries = lt_entries iv_area = 'ZT_OPS_A' iv_period = '202610'
                                               iv_bukrs_list = 'ZT01,ZT02' )
      msg = 'Closed only when every company code is' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_eval_period=>closed_in( it_entries = lt_entries iv_area = 'ZT_OPS_A' iv_period = '202610' )
      msg = 'A company-code entry does not close the area' ).
  ENDMETHOD.


  METHOD any_area.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_eval_period=>closed_in( it_entries = VALUE #( ( `*:202612` ) ) iv_area = 'ZT_OPS_B'
                                               iv_period = '202612' )
      msg = '* = every area' ).
  ENDMETHOD.


  METHOD nothing_configured.
    cl_abap_unit_assert=>assert_false(
      act = NEW zcl_ca_ops_eval_period( )->zif_ca_ops_eval_period~is_closed( iv_area = 'ZT_OPS_A' iv_period = '202610' )
      msg = 'Nothing configured, nothing closed' ).
  ENDMETHOD.


  METHOD parameter_is_read.
    mo_seed->set( iv_name = zif_ca_ops_eval_types=>gc_param-period_closed iv_value = 'ZT_OPS_A:202610,ZT_OPS_B:202609' ).
    cl_abap_unit_assert=>assert_true(
      act = NEW zcl_ca_ops_eval_period( )->zif_ca_ops_eval_period~is_closed( iv_area = 'ZT_OPS_B' iv_period = '202609' )
      msg = 'Closed by the parameter' ).
  ENDMETHOD.

ENDCLASS.
