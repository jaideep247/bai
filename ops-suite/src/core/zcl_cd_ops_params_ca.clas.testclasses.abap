*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_params_ca.clas.testclasses.abap
*& Purpose:
*& Unit tests of the parameter adapter over ZCA_PARAM with the REAL framework
*& logic: data built with ZCL_CA_PARAM_BUILDER, its in-memory DAO injected
*& with ZCL_CA_PARAM_INJECTOR (the adapter reads ZCL_CA_PARAM_FACTORY=>GET).
*& Area by prefix, definition default over caller default,
*& BOOL off, fallback when nothing resolves, condensing, lists as ranges,
*& errors listed once (no application log), snapshot refresh. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (parameters moved to ZCA_PARAM); the read semantics pinned before
*&            | in ZCL_CD_OPS_STORE's tests (blank = default, condensed, range from a list) moved here.
*& 2026-11-07 | No log channel double: parameter errors are listed only (SLG1 minimum).
*& 2026-11-08 | Table consolidation: MON_STALE_AFTER_MIN_<area> is read from area CD_OPS (prefix MON_).
*& 2026-11-08 | POSTAREA_* (customer posting areas) is read from area CD_OPS.
*&---------------------------------------------------------------------*
CLASS ltc_params_ca DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        int_set      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_TOP_N',
        int_default  TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_TIMEOUT_SEC',
        int_open     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAX_AGE_H_EBS',
        int_bad      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_LOOKBACK_RUNS',
        bool_off     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_FLAG_OFF',
        bool_on      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_FLAG_ON',
        bool_default TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_FLAG_DEFAULT',
        list         TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WATCH_PE_AREAS',
        select       TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_SELECT',
        text         TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAIL_ROUTE',
        unknown      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_NOT_DEFINED',
        value_25     TYPE zif_ca_param_types=>ty_value VALUE '25',
        value_300    TYPE zif_ca_param_types=>ty_value VALUE '300',
        value_bad    TYPE zif_ca_param_types=>ty_value VALUE 'many',
        list_value   TYPE zif_ca_param_types=>ty_value VALUE 'EBS;;FMON',
        text_value   TYPE zif_ca_param_types=>ty_value VALUE '  MORNING   REPORT ',
        caller       TYPE string VALUE `42`,
        msgno_name   TYPE symsgno VALUE '003',
        msgno_type   TYPE symsgno VALUE '006',
      END OF gc_test.

    DATA mo_dao TYPE REF TO zcl_ca_param_dao_mem.
    DATA mo_cut TYPE REF TO zif_cd_ops_params.

    METHODS setup.
    METHODS teardown.

    METHODS area_from_name_prefix FOR TESTING.
    METHODS maintained_value_wins FOR TESTING.
    METHODS definition_default_wins FOR TESTING.
    METHODS nothing_resolved_is_caller FOR TESTING.
    METHODS bool_blank_row_is_off FOR TESTING.
    METHODS bool_row_and_default_on FOR TESTING.
    METHODS value_is_condensed FOR TESTING.
    METHODS unknown_name_listed_once FOR TESTING.
    METHODS invalid_value_is_error FOR TESTING.
    METHODS range_from_list FOR TESTING.
    METHODS range_of_select_option FOR TESTING.
    METHODS refresh_new_snapshot FOR TESTING.
ENDCLASS.


CLASS ltc_params_ca IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW zcl_ca_param_builder( )->area( zif_cd_ops_types=>gc_param_area-hck
      )->param( iv_name       = gc_test-int_set
                iv_value_type = zif_ca_param_types=>gc_value_type-int
                iv_default    = '20' )->row( gc_test-value_25
      )->param( iv_name       = gc_test-int_default
                iv_value_type = zif_ca_param_types=>gc_value_type-int
                iv_default    = gc_test-value_300
      )->param( iv_name       = gc_test-int_open
                iv_value_type = zif_ca_param_types=>gc_value_type-int
      )->param( iv_name       = gc_test-int_bad
                iv_value_type = zif_ca_param_types=>gc_value_type-int
                iv_default    = '8' )->row( gc_test-value_bad
      )->param( iv_name       = gc_test-bool_off
                iv_value_type = zif_ca_param_types=>gc_value_type-bool
                iv_default    = zif_ca_param_types=>gc_true )->row( space
      )->param( iv_name       = gc_test-bool_on
                iv_value_type = zif_ca_param_types=>gc_value_type-bool )->row( zif_ca_param_types=>gc_true
      )->param( iv_name       = gc_test-bool_default
                iv_value_type = zif_ca_param_types=>gc_value_type-bool
                iv_default    = zif_ca_param_types=>gc_true
      )->param( iv_name       = gc_test-list
                iv_value_type = zif_ca_param_types=>gc_value_type-list )->row( gc_test-list_value
      )->param( iv_name       = gc_test-select
                iv_kind       = zif_ca_param_types=>gc_kind-select )->row( iv_low    = 'A'
                                                                          iv_high   = 'C'
                                                                          iv_option = zif_ca_param_types=>gc_option-bt
      )->param( iv_name       = gc_test-text )->row( gc_test-text_value
      )->dao( ).
    zcl_ca_param_injector=>inject_dao( mo_dao ).
    mo_cut = NEW zcl_cd_ops_params_ca( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_param_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_cut, mo_dao.
  ENDMETHOD.


  " Rule: the area comes from the name prefix; no fitting prefix reads area CD_OPS
  METHOD area_from_name_prefix.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_ops_types=>gc_param-alert_default )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'ALERT_ is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_ops_types=>gc_param-sla_days_default )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'SLA_ is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_ops_types=>gc_param-purge_package )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'PURGE_ is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_ops_trace_types=>gc_param-max_rows )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'TRACE_ is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_ebs_types=>gc_param-gl_ledger )
                                        exp = zif_cd_ops_types=>gc_param_area-ebs msg = 'EBS_ is CD_EBS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_fmon_types=>gc_param-max_rows )
                                        exp = zif_cd_ops_types=>gc_param_area-fmon msg = 'FMON_ is CD_FMON' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_hck_types=>gc_param-top_n )
                                        exp = zif_cd_ops_types=>gc_param_area-hck msg = 'HCK_ is CD_HCK' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( 'RETENTION_DAYS_RUN' )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'RETENTION_ is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_params_ca=>area_of( |{ zif_cd_ops_types=>gc_param_prefix-stale_after_min }{
                                              zif_cd_ops_types=>gc_pe_area-file_monitor }| )
      exp = zif_cd_ops_types=>gc_param_area-ops
      msg = 'MON_ (monitor freshness, was ZCD_OPS_MONCFG) is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( zif_cd_ops_postarea_types=>gc_param-btc_map )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'POSTAREA_ is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_params_ca=>area_of( 'OTHER_NAME' )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'No prefix: CD_OPS' ).
  ENDMETHOD.


  " Rule: a maintained value is returned, not the caller's default
  METHOD maintained_value_wins.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = gc_test-int_set iv_default = gc_test-caller )
                                        exp = CONV string( gc_test-value_25 )
                                        msg = 'The maintained value must be read' ).
  ENDMETHOD.


  " Rule: single source of defaults - the definition default wins over the caller's default
  METHOD definition_default_wins.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name    = gc_test-int_default
                                                                 iv_default = gc_test-caller )
                                        exp = CONV string( gc_test-value_300 )
                                        msg = 'The definition default must win' ).
  ENDMETHOD.


  " Rule: no value row and no definition default - the caller's default (fallback chains)
  METHOD nothing_resolved_is_caller.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = gc_test-int_open iv_default = gc_test-caller )
                                        exp = gc_test-caller
                                        msg = 'Nothing resolved: the caller default' ).
    cl_abap_unit_assert=>assert_initial( act = mo_cut->get_errors( ) msg = 'Nothing resolved is no error' ).
  ENDMETHOD.


  " Rule: a BOOL value row with blank value is off - also against a caller default X
  METHOD bool_blank_row_is_off.
    cl_abap_unit_assert=>assert_initial(
      act = mo_cut->get_param( iv_name = gc_test-bool_off iv_default = CONV #( abap_true ) )
      msg = 'A blank BOOL row is an explicit off' ).
  ENDMETHOD.


  " Rule: BOOL row X is on; no row is the definition default
  METHOD bool_row_and_default_on.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( gc_test-bool_on )
                                        exp = CONV string( abap_true ) msg = 'Row X is on' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( gc_test-bool_default )
                                        exp = CONV string( abap_true ) msg = 'No row: the definition default X' ).
  ENDMETHOD.


  " Rule: a maintained value is read condensed (leading blanks removed, inner blanks collapsed)
  METHOD value_is_condensed.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( gc_test-text )
                                        exp = condense( CONV string( gc_test-text_value ) )
                                        msg = 'The value must be condensed' ).
  ENDMETHOD.


  " Rule: an unknown name is never silent - listed once, the caller's default keeps the run going
  METHOD unknown_name_listed_once.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = gc_test-unknown iv_default = gc_test-caller )
                                        exp = gc_test-caller msg = 'Unknown name: the caller default' ).
    mo_cut->get_param( iv_name = gc_test-unknown iv_default = gc_test-caller ).
    DATA(lt_errors) = mo_cut->get_errors( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_errors ) exp = 1 msg = 'One error per name' ).
    cl_abap_unit_assert=>assert_equals( act = lt_errors[ 1 ]-msgno exp = gc_test-msgno_name
                                        msg = 'Name not defined (ZCA_PARAM 003)' ).
    cl_abap_unit_assert=>assert_not_initial( act = lt_errors[ 1 ]-text msg = 'The framework message is kept' ).
  ENDMETHOD.


  " Rule: a value invalid for its definition is an error, not the definition default
  METHOD invalid_value_is_error.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( iv_name = gc_test-int_bad iv_default = gc_test-caller )
                                        exp = gc_test-caller msg = 'Invalid value: the caller default' ).
    DATA(lt_errors) = mo_cut->get_errors( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_errors ) exp = 1 msg = 'One error' ).
    cl_abap_unit_assert=>assert_equals( act = lt_errors[ 1 ]-msgno exp = gc_test-msgno_type
                                        msg = 'Not a valid INT (ZCA_PARAM 006)' ).
  ENDMETHOD.



  " Rule: a LIST is one I / EQ row per element, blank elements dropped
  METHOD range_from_list.
    DATA lt_exp TYPE zif_cd_ops_types=>tt_param_range.
    INSERT VALUE #( sign = zif_cd_ops_types=>gc_range-sign_include option = zif_cd_ops_types=>gc_range-option_equal
                    low = zif_cd_ops_types=>gc_pe_area-ebs ) INTO TABLE lt_exp.
    INSERT VALUE #( sign = zif_cd_ops_types=>gc_range-sign_include option = zif_cd_ops_types=>gc_range-option_equal
                    low = zif_cd_ops_types=>gc_pe_area-file_monitor ) INTO TABLE lt_exp.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_range( gc_test-list ) exp = lt_exp
                                        msg = 'One I / EQ row per element' ).
  ENDMETHOD.


  " Rule: a kind S parameter is its rows
  METHOD range_of_select_option.
    DATA(lt_range) = mo_cut->get_range( gc_test-select ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_range ) exp = 1 msg = 'One row' ).
    cl_abap_unit_assert=>assert_equals( act = lt_range[ 1 ]-option exp = zif_ca_param_types=>gc_option-bt
                                        msg = 'The row as maintained' ).
  ENDMETHOD.


  " Rule (A64): refresh_params starts a new snapshot - changed values and a new error list
  METHOD refresh_new_snapshot.
    DATA ls_value TYPE zif_ca_param_types=>ty_value_row.
    mo_cut->get_param( gc_test-unknown ).
    ls_value-area = zif_cd_ops_types=>gc_param_area-hck.
    ls_value-name = gc_test-int_set.
    ls_value-numb = 1.
    ls_value-sign = zif_ca_param_types=>gc_sign-include.
    ls_value-opti = zif_ca_param_types=>gc_option-eq.
    ls_value-low  = gc_test-value_300.
    mo_dao->add_value( ls_value ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( gc_test-int_set ) exp = CONV string( gc_test-value_25 )
                                        msg = 'Within a snapshot the value is stable' ).
    mo_cut->refresh_params( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_param( gc_test-int_set ) exp = CONV string( gc_test-value_300 )
                                        msg = 'The next snapshot sees the change' ).
    cl_abap_unit_assert=>assert_initial( act = mo_cut->get_errors( ) msg = 'A new snapshot has a new error list' ).
  ENDMETHOD.

ENDCLASS.
