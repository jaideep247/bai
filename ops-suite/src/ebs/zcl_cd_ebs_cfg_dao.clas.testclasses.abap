*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_cfg_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the customizing repository: rule assignments join the rule
*& registry, registry defaults fill blank severity/action, inactive rows are
*& excluded. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A03: unusable assignments.
*& 2026-11-06 | Operating model: NEEDS_POSTING carried from the rule registry.
*& 2026-11-06 | ltc_cfg_reads: BTC map, accounts, flow patterns, reason map, lookups (coverage gap closure).
*& 2026-11-06 | Flow pattern seeds are PCRE.
*& 2026-11-07 | Read-only scope: blocks-posting flag (A27) removed.
*& 2026-11-08 | Customer posting areas: ltc_postarea_reads - BTC map from ZBTM and reasons from ZRSN with
*&            | the in-memory posting areas (ZCL_CD_OPS_POSTAREA_MEM); BTC map / reason map OSQL tests removed.
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
    METHODS insert_definition
      IMPORTING
        iv_rule   TYPE char10
        iv_active TYPE abap_bool.

    METHODS registry_default_fills_blank FOR TESTING.
    METHODS assignment_severity_wins     FOR TESTING.
    METHODS inactive_assignment_excluded FOR TESTING.
    METHODS missing_definition_unusable  FOR TESTING.
    METHODS inactive_definition_unusable FOR TESTING.
    METHODS none_row_is_not_unusable     FOR TESTING.
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
        insert_definition( iv_rule = 'R07' iv_active = abap_false ).
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


"! OSQL tests of the plain customizing reads (every table they read is doubled)
CLASS ltc_cfg_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        bukrs      TYPE bukrs VALUE 'US01',
        hbkid      TYPE c LENGTH 5 VALUE 'JPMC',
        hktid_1    TYPE c LENGTH 5 VALUE 'ACH01',
        hktid_2    TYPE c LENGTH 5 VALUE 'CHK01',
        pattern_1  TYPE c LENGTH 30 VALUE 'ACH.*',
        pattern_2  TYPE c LENGTH 30 VALUE '.*CHECK.*',
        flow_coll  TYPE c LENGTH 1 VALUE 'C',
        lookup_on  TYPE c LENGTH 10 VALUE 'PAYREQ',
        lookup_off TYPE c LENGTH 10 VALUE 'OLDLOG',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ebs_cfg_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS accounts_all_rows_sorted FOR TESTING.
    METHODS flow_patterns_active_by_prio FOR TESTING.
    METHODS lookups_only_active FOR TESTING.
ENDCLASS.


CLASS ltc_cfg_reads IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_EBS_ACCT' ) ( 'ZCD_EBS_FLOW_PAT' ) ( 'ZCD_EBS_LOOKUP' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ebs_cfg_dao( ).
  ENDMETHOD.


  " Rule: every account row (active or not) ordered by company code, bank, account ID
  METHOD accounts_all_rows_sorted.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ebs_acct WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ebs_acct.
    TRY.
        ls_row-bukrs  = gc_test-bukrs.
        ls_row-hbkid  = gc_test-hbkid.
        ls_row-hktid  = gc_test-hktid_2.
        ls_row-active = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-hktid  = gc_test-hktid_1.
        ls_row-active = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_accounts) = mo_cut->get_accounts( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_accounts ) exp = 2 msg = 'Both accounts' ).
        cl_abap_unit_assert=>assert_equals( act = lt_accounts[ 1 ]-hktid exp = gc_test-hktid_1
                                            msg = 'Ordered by account ID' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only active flow patterns, lowest priority number first
  METHOD flow_patterns_active_by_prio.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ebs_flow_pat WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ebs_flow_pat.
    TRY.
        ls_row-priority  = 20.
        ls_row-pattern   = gc_test-pattern_2.
        ls_row-flow_type = gc_test-flow_coll.
        ls_row-active    = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-priority  = 10.
        ls_row-pattern   = gc_test-pattern_1.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-priority  = 5.
        ls_row-active    = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_patterns) = mo_cut->get_flow_patterns( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_patterns ) exp = 2 msg = 'Inactive pattern excluded' ).
        cl_abap_unit_assert=>assert_equals( act = lt_patterns[ 1 ]-pattern exp = gc_test-pattern_1
                                            msg = 'Lowest priority number first' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (R21): only active lookups are configured
  METHOD lookups_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_ebs_lookup WITH EMPTY KEY.
    DATA ls_row TYPE zcd_ebs_lookup.
    TRY.
        ls_row-lookup_id = gc_test-lookup_on.
        ls_row-active    = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-lookup_id = gc_test-lookup_off.
        ls_row-active    = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_lookups) = mo_cut->get_lookups( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lookups ) exp = 1 msg = 'Only the active lookup' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lookups[ 1 ]-lookup_id exp = gc_test-lookup_on
                                            msg = 'Active lookup returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! The bank transaction codes (ZBTM) and return / NOC reasons (ZRSN) are entries of customer
"! posting areas: read through the posting area reader with in-memory posting areas
CLASS ltc_postarea_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        btm        TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTM',
        rsn        TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZRSN',
        bank       TYPE zif_cd_ebs_types=>ty_bank_key VALUE 'JPMC',
        bai_code   TYPE zif_cd_ebs_types=>ty_btc_code VALUE '495',
        family     TYPE zif_cd_ebs_types=>ty_btc_code VALUE 'PMNT-ICDT',
        iso_code   TYPE zif_cd_ebs_types=>ty_btc_code VALUE 'PMNT-ICDT-ARET',
        category   TYPE zif_cd_ebs_types=>ty_category VALUE 'W01',
        reason_ret TYPE c LENGTH 4 VALUE 'R01',
        reason_noc TYPE c LENGTH 4 VALUE 'C01',
        reason_new TYPE c LENGTH 4 VALUE 'R99',
        fica_ret   TYPE c LENGTH 3 VALUE 'R1',
        fica_any   TYPE c LENGTH 3 VALUE 'ZZ',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        btc_entries    TYPE abap_bool,
        reason_entries TYPE abap_bool,
        reason_generic TYPE abap_bool,
      END OF ty_flags.

    DATA mo_mem TYPE REF TO zcl_cd_ops_postarea_mem.

    METHODS setup.
    METHODS teardown.

    METHODS btc_map_from_posting_area FOR TESTING.
    METHODS btc_map_empty_no_entries  FOR TESTING.
    METHODS reason_map_with_noc_flag  FOR TESTING.
    METHODS reason_exact_beats_generic FOR TESTING.
    METHODS reason_without_entry      FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS cut
      RETURNING
        VALUE(ro_cut) TYPE REF TO zif_cd_ebs_cfg_dao.
ENDCLASS.


CLASS ltc_postarea_reads IMPLEMENTATION.

  METHOD setup.
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
    mo_mem = NEW #( ).
    zcl_cd_ops_postarea_injector=>inject_dao( mo_mem ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_postarea_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_mem.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-btc_entries = abap_true.
      " SCHEME / CODE (ISO domain) / FAMILY / SUB-FAMILY / BANK / FLOW ->
      " CATEGORY / RULE_GROUP / EXP_CDI / PAY_METHOD / POSTING_RULE / ACTION / DISPOSITION
      mo_mem->add( iv_area = gc_test-btm iv_keys = |BAI2/{ gc_test-bai_code }///*/*|
                   iv_results = |{ gc_test-category }//D/WIRE//AUTO_POST/| ).
      mo_mem->add( iv_area = gc_test-btm iv_keys = |ISO/PMNT/ICDT/*/{ gc_test-bank }/D|
                   iv_results = |W02/W01/D/WIRE//AUTO_POST/| ).
      mo_mem->add( iv_area = gc_test-btm iv_keys = |ISO/PMNT/ICDT/ARET/*/C|
                   iv_results = |D02//C/ACH//EXCEPTION/NOT_POSTED| ).
    ENDIF.
    IF is_flags-reason_entries = abap_true.
      mo_mem->add( iv_area = gc_test-rsn iv_keys = |{ gc_test-reason_ret }| iv_results = |{ gc_test-fica_ret }/| ).
      mo_mem->add( iv_area = gc_test-rsn iv_keys = |{ gc_test-reason_noc }| iv_results = |/X| ).
    ENDIF.
    IF is_flags-reason_generic = abap_true.
      mo_mem->add( iv_area = gc_test-rsn iv_keys = CONV #( zif_cd_ops_postarea_types=>gc_generic )
                   iv_results = |{ gc_test-fica_any }/| ).
    ENDIF.
  ENDMETHOD.


  METHOD cut.
    ro_cut = NEW zcl_cd_ebs_cfg_dao( ).
  ENDMETHOD.


  " Rule: every ZBTM entry is a map row - bank '*' = blank bank (every bank), ISO code from its
  " three parts, sub-family '*' = the family row; an entry that exists is active
  METHOD btc_map_from_posting_area.
    TRY.
        configure_scenario( VALUE #( btc_entries = abap_true ) ).
        DATA(lt_map) = cut( )->get_btc_map( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_map ) exp = 3 msg = 'One row per entry' ).
        DATA(ls_bai) = VALUE #( lt_map[ btc_code = gc_test-bai_code ] OPTIONAL ).
        cl_abap_unit_assert=>assert_initial( act = ls_bai-bank_key msg = 'Bank * = default row of every bank' ).
        cl_abap_unit_assert=>assert_equals( act = ls_bai-flow_type exp = zif_cd_ebs_types=>gc_flow-any
                                            msg = 'Flow * = any flow' ).
        cl_abap_unit_assert=>assert_equals( act = ls_bai-category exp = gc_test-category msg = 'Category' ).
        cl_abap_unit_assert=>assert_equals( act = ls_bai-action exp = zif_cd_ops_types=>gc_action-auto_post
                                            msg = 'Action' ).
        cl_abap_unit_assert=>assert_true( act = ls_bai-active msg = 'An entry that exists applies' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_map[ btc_code = gc_test-family ]-bank_key OPTIONAL )
                                            exp = gc_test-bank msg = 'ISO family row of one bank' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_map[ btc_code = gc_test-iso_code ]-disposition OPTIONAL )
                                            exp = zif_cd_ebs_types=>gc_disposition-not_posted
                                            msg = 'ISO code from domain, family and sub-family' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: no entry - empty map (every line unmapped, R14), no exception
  METHOD btc_map_empty_no_entries.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = cut( )->get_btc_map( ) msg = 'Empty map' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the reason map carries the payment engine reason and the NOC flag per bank reason
  METHOD reason_map_with_noc_flag.
    TRY.
        configure_scenario( VALUE #( reason_entries = abap_true ) ).
        DATA(lt_reasons) = cut( )->get_reason_map( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_reasons ) exp = 2 msg = 'Both reasons' ).
        cl_abap_unit_assert=>assert_true( act = lt_reasons[ reason = gc_test-reason_noc ]-is_noc
                                          msg = 'C01 is a NOC' ).
        cl_abap_unit_assert=>assert_false( act = lt_reasons[ reason = gc_test-reason_ret ]-is_noc
                                           msg = 'R01 is a return' ).
        cl_abap_unit_assert=>assert_equals( act = lt_reasons[ reason = gc_test-reason_ret ]-fica_reason
                                            exp = gc_test-fica_ret msg = 'Payment engine reason of R01' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (FQC0): the exact reason beats a '*' entry; '*' maps every other reason
  METHOD reason_exact_beats_generic.
    TRY.
        configure_scenario( VALUE #( reason_entries = abap_true reason_generic = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = cut( )->get_reason( gc_test-reason_ret )-fica_reason
                                            exp = gc_test-fica_ret msg = 'R01 has its own entry' ).
        DATA(ls_other) = cut( )->get_reason( gc_test-reason_new ).
        cl_abap_unit_assert=>assert_equals( act = ls_other-fica_reason exp = gc_test-fica_any
                                            msg = 'Another reason takes the * entry' ).
        cl_abap_unit_assert=>assert_equals( act = ls_other-reason exp = zif_cd_ops_postarea_types=>gc_generic
                                            msg = 'The entry that applied is named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: no exact and no '*' entry - initial (R05: REASON_UNMAPPED)
  METHOD reason_without_entry.
    TRY.
        configure_scenario( VALUE #( reason_entries = abap_true ) ).
        cl_abap_unit_assert=>assert_initial( act = cut( )->get_reason( gc_test-reason_new )
                                             msg = 'Unmapped reason' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
