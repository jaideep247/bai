*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_cfg_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the customizing repository: rule assignments join the rule
*& registry, registry defaults fill blank severity/action, inactive rows are
*& excluded. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltc_cfg_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ebs_cfg_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS insert_rule
      IMPORTING
        iv_group    TYPE char10
        iv_rule     TYPE char10
        iv_severity TYPE char1 OPTIONAL
        iv_active   TYPE abap_bool DEFAULT abap_true.

    METHODS registry_default_fills_blank FOR TESTING.
    METHODS assignment_severity_wins     FOR TESTING.
    METHODS inactive_assignment_excluded FOR TESTING.
ENDCLASS.


CLASS ltc_cfg_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_BTC_RULE' ) ( 'ZCD_EBS_RULE_DEF' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_def TYPE STANDARD TABLE OF zcd_ebs_rule_def WITH EMPTY KEY.
    DATA ls_def TYPE zcd_ebs_rule_def.
    go_env->clear_doubles( ).
    ls_def-rule_id          = 'R01'.
    ls_def-rule_level       = 'L'.
    ls_def-class_name       = 'ZCL_CD_EBS_R_R01_SIGN'.
    ls_def-default_severity = 'E'.
    ls_def-default_action   = 'EXCEPTION'.
    ls_def-active           = abap_true.
    INSERT ls_def INTO TABLE lt_def.
    go_env->insert_test_data( lt_def ).
    mo_cut = NEW zcl_cd_ebs_cfg_dao( ).
  ENDMETHOD.


  METHOD insert_rule.
    DATA lt_rule TYPE STANDARD TABLE OF zcd_btc_rule WITH EMPTY KEY.
    DATA ls_rule TYPE zcd_btc_rule.
    ls_rule-rule_group = iv_group.
    ls_rule-rule_id    = iv_rule.
    ls_rule-seq        = 10.
    ls_rule-severity   = iv_severity.
    ls_rule-active     = iv_active.
    INSERT ls_rule INTO TABLE lt_rule.
    go_env->insert_test_data( lt_rule ).
  ENDMETHOD.


  " A blank assignment severity/action takes the registry default
  METHOD registry_default_fills_blank.
    TRY.
        insert_rule( iv_group = '*' iv_rule = 'R01' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rules ) exp = 1 msg = 'One active assignment expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rules[ 1 ]-severity exp = 'E'
                                            msg = 'Blank severity must take the registry default' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rules[ 1 ]-class_name exp = 'ZCL_CD_EBS_R_R01_SIGN'
                                            msg = 'Class must come from the registry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A severity on the assignment overrides the registry default
  METHOD assignment_severity_wins.
    TRY.
        insert_rule( iv_group = '*' iv_rule = 'R01' iv_severity = 'B' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_equals( act = lt_rules[ 1 ]-severity exp = 'B'
                                            msg = 'Assignment severity must override the default' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Inactive assignments are not returned
  METHOD inactive_assignment_excluded.
    TRY.
        insert_rule( iv_group = '*' iv_rule = 'R01' iv_active = abap_false ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_rules( ) msg = 'Inactive assignment must be excluded' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
