*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_cfg_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the customizing repository: rule assignments join the rule
*& registry, registry defaults fill blank severity/action, inactive rows are
*& excluded. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A03 / A27: unusable assignments and blocks-posting resolution.
*& 2026-11-06 | Operating model: NEEDS_POSTING carried from the rule registry.
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
        iv_active   TYPE abap_bool DEFAULT abap_true
        iv_blocks   TYPE char1 OPTIONAL.
    METHODS insert_definition
      IMPORTING
        iv_rule   TYPE char10
        iv_active TYPE abap_bool
        iv_blocks TYPE abap_bool.

    METHODS registry_default_fills_blank FOR TESTING.
    METHODS assignment_severity_wins     FOR TESTING.
    METHODS inactive_assignment_excluded FOR TESTING.
    METHODS missing_definition_unusable  FOR TESTING.
    METHODS inactive_definition_unusable FOR TESTING.
    METHODS none_row_is_not_unusable     FOR TESTING.
    METHODS blocks_default_from_registry FOR TESTING.
    METHODS blocks_override_wins         FOR TESTING.
    METHODS needs_posting_from_registry  FOR TESTING.
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
    ls_rule-blocks_posting = iv_blocks.
    INSERT ls_rule INTO TABLE lt_rule.
    go_env->insert_test_data( lt_rule ).
  ENDMETHOD.


  METHOD insert_definition.
    DATA lt_def TYPE STANDARD TABLE OF zcd_ebs_rule_def WITH EMPTY KEY.
    DATA ls_def TYPE zcd_ebs_rule_def.
    ls_def-rule_id          = iv_rule.
    ls_def-rule_level       = 'L'.
    ls_def-class_name       = 'ZCL_CD_EBS_R_R07_PAYMENT'.
    ls_def-default_severity = 'E'.
    ls_def-default_action   = 'EXCEPTION'.
    ls_def-active           = iv_active.
    ls_def-blocks_posting   = iv_blocks.
    INSERT ls_def INTO TABLE lt_def.
    go_env->insert_test_data( lt_def ).
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


  " A03: an active assignment without a rule definition is returned as UNUSABLE, never dropped
  METHOD missing_definition_unusable.
    TRY.
        insert_rule( iv_group = 'G1' iv_rule = 'R98' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rules ) exp = 1
                                            msg = 'The assignment without definition must be returned' ).
        cl_abap_unit_assert=>assert_true( act = lt_rules[ 1 ]-unusable
                                          msg = 'An assignment without definition is unusable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A03: an assignment whose definition is inactive is returned as UNUSABLE
  METHOD inactive_definition_unusable.
    TRY.
        insert_definition( iv_rule = 'R07' iv_active = abap_false iv_blocks = abap_true ).
        insert_rule( iv_group = 'G1' iv_rule = 'R07' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_true( act = VALUE #( lt_rules[ rule_id = 'R07' ]-unusable OPTIONAL )
                                          msg = 'An assignment of an inactive rule is unusable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A03: a NONE row (group intentionally without own rules) is not a configuration gap
  METHOD none_row_is_not_unusable.
    TRY.
        insert_rule( iv_group = 'T02' iv_rule = 'NONE' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rules ) exp = 1 msg = 'The NONE row must be returned' ).
        cl_abap_unit_assert=>assert_false( act = lt_rules[ 1 ]-unusable msg = 'A NONE row is not unusable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A27: without an override the registry decides whether the rule blocks posting
  METHOD blocks_default_from_registry.
    TRY.
        insert_definition( iv_rule = 'R07' iv_active = abap_true iv_blocks = abap_true ).
        insert_rule( iv_group = 'G1' iv_rule = 'R07' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_true( act = VALUE #( lt_rules[ rule_id = 'R07' ]-blocks_posting OPTIONAL )
                                          msg = 'The registry default must make R07 blocking' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A27: Y / N on the assignment overrides the registry default
  METHOD blocks_override_wins.
    TRY.
        insert_definition( iv_rule = 'R07' iv_active = abap_true iv_blocks = abap_true ).
        insert_rule( iv_group = 'G1' iv_rule = 'R07' iv_blocks = 'N' ).
        insert_rule( iv_group = 'G2' iv_rule = 'R01' iv_blocks = 'Y' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_false( act = VALUE #( lt_rules[ rule_group = 'G1' ]-blocks_posting OPTIONAL )
                                           msg = 'N must make a blocking rule advisory for this group' ).
        cl_abap_unit_assert=>assert_true( act = VALUE #( lt_rules[ rule_group = 'G2' ]-blocks_posting OPTIONAL )
                                          msg = 'Y must make an advisory rule blocking for this group' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Operating model 2026-11-06: the registry flag NEEDS_POSTING reaches every assignment of
  " the rule (the engine skips such a rule for an entry expected to post but not posted)
  METHOD needs_posting_from_registry.
    DATA lt_def TYPE STANDARD TABLE OF zcd_ebs_rule_def WITH EMPTY KEY.
    DATA ls_def TYPE zcd_ebs_rule_def.
    TRY.
        ls_def-rule_id          = 'R19'.
        ls_def-rule_level       = 'L'.
        ls_def-class_name       = 'ZCL_CD_EBS_R_R19_FI_DOCUMENT'.
        ls_def-default_severity = 'E'.
        ls_def-default_action   = 'EXCEPTION'.
        ls_def-active           = abap_true.
        ls_def-needs_posting    = abap_true.
        INSERT ls_def INTO TABLE lt_def.
        go_env->insert_test_data( lt_def ).
        insert_rule( iv_group = 'G1' iv_rule = 'R19' ).
        insert_rule( iv_group = 'G1' iv_rule = 'R01' ).
        DATA(lt_rules) = mo_cut->get_rules( ).
        cl_abap_unit_assert=>assert_true( act = VALUE #( lt_rules[ rule_id = 'R19' ]-needs_posting OPTIONAL )
                                          msg = 'R19 must carry the registry flag NEEDS_POSTING' ).
        cl_abap_unit_assert=>assert_false( act = VALUE #( lt_rules[ rule_id = 'R01' ]-needs_posting OPTIONAL )
                                           msg = 'R01 has no NEEDS_POSTING flag in the registry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
