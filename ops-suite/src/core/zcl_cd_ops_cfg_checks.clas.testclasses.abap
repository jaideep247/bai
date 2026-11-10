*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_checks.clas.testclasses.abap
*& Purpose:
*& Domain tests of the payment engine field checks of the configuration
*& apps: threshold order; configuration check of the customer posting
*& areas. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (written before the class, RAP config apps).
*& 2026-11-07 | ltc_destination: CHANNEL_CLASS / INVALID_DESTINATION (SO23 lists).
*& 2026-11-08 | ltc_posting_areas: configuration check of the customer posting areas (in-memory posting
*&            | areas ZCL_CD_OPS_POSTAREA_MEM, EBS rule groups from a configuration double) - every validation.
*& 2026-11-10 | Tests of the generic checks moved with them to the framework ZCA_OPS (ZCL_CA_OPS_CFG_CHECKS).
*&---------------------------------------------------------------------*
CLASS ltc_checks DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS amber_below_red_when_higher   FOR TESTING.
    METHODS amber_above_red_when_lower    FOR TESTING.
ENDCLASS.


CLASS ltc_checks IMPLEMENTATION.

  " Rule: higher is worse -> amber below red; lower is worse -> amber above red
  METHOD amber_below_red_when_higher.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>thresholds_ordered( iv_amber           = 5
                                                                                            iv_red             = 10
                                                                                            iv_higher_is_worse = abap_true )
                                          msg = 'Amber 5 / red 10 is ordered when higher is worse' ).
        cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_cfg_checks=>thresholds_ordered( iv_amber           = 10
                                                                                             iv_red             = 5
                                                                                             iv_higher_is_worse = abap_true )
                                           msg = 'Amber 10 / red 5 is reversed when higher is worse' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD amber_above_red_when_lower.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_cfg_checks=>thresholds_ordered( iv_amber           = 10
                                                                                            iv_red             = 5
                                                                                            iv_higher_is_worse = abap_false )
                                          msg = 'Amber 10 / red 5 is ordered when lower is worse' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


ENDCLASS.


"! EBS rule assignments: only the rule groups are read by the posting area check
CLASS ltd_ebs_cfg DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao PARTIALLY IMPLEMENTED.
    DATA mt_rules TYPE zif_cd_ebs_types=>tt_rule_cfg.
ENDCLASS.

CLASS ltd_ebs_cfg IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_rules.
    rt_rules = mt_rules.
  ENDMETHOD.
ENDCLASS.


"! Configuration check of the customer posting areas ZRSN / ZPMC / ZBTM / ZBTR: a valid set of
"! entries (in memory, ZCL_CD_OPS_POSTAREA_MEM) plus one invalid entry per scenario
CLASS ltc_posting_areas DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_area,
        rsn TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZRSN',
        pmc TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZPMC',
        btm TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTM',
        btr TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTR',
      END OF gc_area.
    CONSTANTS gc_group TYPE zif_cd_ebs_types=>ty_rule_group VALUE 'W01'.

    TYPES:
      BEGIN OF ty_flags,
        no_reasons      TYPE abap_bool,
        generic_keys    TYPE abap_bool,
        too_long        TYPE abap_bool,
        blank_bank      TYPE abap_bool,
        noc_flag        TYPE abap_bool,
        two_classes     TYPE abap_bool,
        bank_calendar   TYPE abap_bool,
        no_class_entry  TYPE abap_bool,
        class_differs   TYPE abap_bool,
        unknown_class   TYPE abap_bool,
        roles_per_usage TYPE abap_bool,
        scope_form      TYPE abap_bool,
        recon_scheme    TYPE abap_bool,
        rule_group      TYPE abap_bool,
        iso_parts       TYPE abap_bool,
      END OF ty_flags.

    DATA mo_mem TYPE REF TO zcl_cd_ops_postarea_mem.

    METHODS setup.
    METHODS teardown.

    METHODS valid_entries_no_finding     FOR TESTING.
    METHODS empty_area_is_warning        FOR TESTING.
    METHODS generic_key_where_not_read   FOR TESTING.
    METHODS value_longer_than_reader     FOR TESTING.
    METHODS blank_key_needs_value_or_any FOR TESTING.
    METHODS noc_flag_x_or_blank          FOR TESTING.
    METHODS one_class_per_pay_method     FOR TESTING.
    METHODS house_bank_needs_calendar    FOR TESTING.
    METHODS house_bank_needs_class_entry FOR TESTING.
    METHODS one_calendar_per_class       FOR TESTING.
    METHODS lifecycle_class_must_exist   FOR TESTING.
    METHODS role_values_per_usage        FOR TESTING.
    METHODS lifecycle_scope_form         FOR TESTING.
    METHODS recon_scheme_bai2_no_compare FOR TESTING.
    METHODS rule_group_needs_active_rule FOR TESTING.
    METHODS iso_code_needs_its_parts     FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS check
      RETURNING
        VALUE(rt_messages) TYPE zif_cd_ops_postarea_types=>tt_check_message.
    "! The message of an entry (area, key text, message number) is in the result
    METHODS assert_message
      IMPORTING
        it_messages TYPE zif_cd_ops_postarea_types=>tt_check_message
        iv_area     TYPE zif_cd_ops_postarea_types=>ty_area
        iv_entry    TYPE string
        iv_number   TYPE zif_ca_ops_cfg_types=>ty_msg_number
        iv_msg      TYPE string.
ENDCLASS.


CLASS ltc_posting_areas IMPLEMENTATION.

  METHOD setup.
    DATA(lo_ebs) = NEW ltd_ebs_cfg( ).
    INSERT VALUE #( rule_group = gc_group active = abap_true ) INTO TABLE lo_ebs->mt_rules.
    zcl_cd_ebs_injector=>inject_cfg_dao( lo_ebs ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
    mo_mem = NEW #( ).
    zcl_cd_ops_postarea_injector=>inject_dao( mo_mem ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_postarea_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR mo_mem.
  ENDMETHOD.


  METHOD configure_scenario.
    " Valid set (seed rows of config/postarea_*.csv and config/hck_seed.md 8a / 8e / 10b)
    IF is_flags-no_reasons = abap_false.
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `R01` iv_results = `R1/` ).
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `C01` iv_results = `/X` ).
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `*` iv_results = `RZ/` ).
    ENDIF.
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/E/*` iv_results = `WIR/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/A/*` iv_results = `ACH/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/G/*` iv_results = `ACH/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/X/*` iv_results = `ACI/VALUE_DATE/` ).
    mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/X/BARC1` iv_results = `ACI//GB` ).
    mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/495///*/*` iv_results = `W01//D/WIRE//AUTO_POST/` ).
    mo_mem->add( iv_area = gc_area-btm iv_keys = `ISO/PMNT/ICDT/*/JPMC/D` iv_results = `W02/W01/D/WIRE//AUTO_POST/` ).
    mo_mem->add( iv_area = gc_area-btm iv_keys = `PRTRY/NOC///*/*` iv_results = `N01//*/ACH//BLOCK/` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DWIR/BAI2/495` iv_results = `ORIGINAL/` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACH/BAI2/168` iv_results = `RETURNED/X` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACI/ISO/PMNT/ICDT/ARET` iv_results = `RETURNED/X` ).
    mo_mem->add( iv_area = gc_area-btr iv_keys = `RECON/DISB_WIRE/BAI2/495` iv_results = `LEG` ).
    " One invalid entry per scenario
    IF is_flags-generic_keys = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `*/196///*/*` iv_results = `W01//D/WIRE//AUTO_POST/` ).
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `*/E/*` iv_results = `WIR/VALUE_DATE/` ).
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DWIR/BAI2/*` iv_results = `ORIGINAL/` ).
    ENDIF.
    IF is_flags-too_long = abap_true.
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `R02` iv_results = `ABCD/` ).
    ENDIF.
    IF is_flags-blank_bank = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/466///` iv_results = `W01//D/ACH//AUTO_POST/` ).
    ENDIF.
    IF is_flags-noc_flag = abap_true.
      mo_mem->add( iv_area = gc_area-rsn iv_keys = `C02` iv_results = `/Y` ).
    ENDIF.
    IF is_flags-two_classes = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/E/BARC1` iv_results = `ACI//GB` ).
    ENDIF.
    IF is_flags-bank_calendar = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/X/COMM1` iv_results = `ACI/VALUE_DATE/` ).
    ENDIF.
    IF is_flags-no_class_entry = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/Q/BARC1` iv_results = `ACI//GB` ).
    ENDIF.
    IF is_flags-class_differs = abap_true.
      mo_mem->add( iv_area = gc_area-pmc iv_keys = `D/H/*` iv_results = `ACH/ISSUE_DATE/` ).
    ENDIF.
    IF is_flags-unknown_class = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DCHQ/BAI2/581` iv_results = `CASHED/R` ).
    ENDIF.
    IF is_flags-roles_per_usage = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACH/BAI2/466` iv_results = `LEG/` ).
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/DACH/BAI2/166` iv_results = `/` ).
      mo_mem->add( iv_area = gc_area-btr iv_keys = `RECON/DISB_ACH/BAI2/466` iv_results = `ORIGINAL` ).
    ENDIF.
    IF is_flags-scope_form = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `LIFECYCLE/XACH/BAI2/466` iv_results = `ORIGINAL/` ).
    ENDIF.
    IF is_flags-recon_scheme = abap_true.
      mo_mem->add( iv_area = gc_area-btr iv_keys = `RECON/DISB_ACH/PRTRY/X1` iv_results = `LEG/X` ).
    ENDIF.
    IF is_flags-rule_group = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/475///*/*` iv_results = `K01/G99/D/CHECK//AUTO_POST/` ).
    ENDIF.
    IF is_flags-iso_parts = abap_true.
      mo_mem->add( iv_area = gc_area-btm iv_keys = `ISO/PMNT///*/C` iv_results = `W01//C/WIRE//AUTO_POST/` ).
      mo_mem->add( iv_area = gc_area-btm iv_keys = `BAI2/142/RCDT//*/*` iv_results = `W01//C/ACH//AUTO_POST/` ).
    ENDIF.
  ENDMETHOD.


  METHOD check.
    rt_messages = zcl_cd_ops_cfg_checks=>check_posting_areas( ).
  ENDMETHOD.


  METHOD assert_message.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( it_messages[ area = iv_area entry = iv_entry number = iv_number ] ) )
      msg = iv_msg ).
  ENDMETHOD.


  " Rule: the delivered set (incl. ZRSN '*', ZPMC house-bank calendar, ZBTM bank and family rows)
  " gives no finding
  METHOD valid_entries_no_finding.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = check( ) msg = 'A valid configuration has no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: a posting area without entries maps nothing - one warning, no entry key
  METHOD empty_area_is_warning.
    TRY.
        configure_scenario( VALUE #( no_reasons = abap_true ) ).
        DATA(lt_messages) = check( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 1 msg = 'One message' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-number exp = zif_cd_ops_cfg_types=>gc_msg-area_empty
                                            msg = 'Message 432' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-warning
                                            msg = 'A warning' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-area exp = gc_area-rsn msg = 'Of ZRSN' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: '*' only where the reader applies it (ZBTM scheme, ZPMC flow, ZBTR code: refused)
  METHOD generic_key_where_not_read.
    TRY.
        configure_scenario( VALUE #( generic_keys = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `*/196///*/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-generic_key iv_msg = 'Scheme * refused' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-pmc iv_entry = `*/E/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-generic_key iv_msg = 'Flow * refused' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `LIFECYCLE/DWIR/BAI2/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-generic_key iv_msg = 'Code * refused' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 3 msg = 'Nothing else (ZRSN * is fine)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a value longer than its reader takes is a finding, never truncated
  METHOD value_longer_than_reader.
    TRY.
        configure_scenario( VALUE #( too_long = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-rsn iv_entry = `R02`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_too_long iv_msg = 'FICA_REASON has 3 characters' ).
        cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-v2 exp = zif_cd_ops_postarea_types=>gc_field-fica_reason
                                            msg = 'Names the field' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: bank key and flow of ZBTM are a value or '*' (blank no longer means 'every bank')
  METHOD blank_key_needs_value_or_any.
    TRY.
        configure_scenario( VALUE #( blank_bank = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-key_blank iv_msg = 'Blank bank key / flow' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 2 msg = 'Bank key and flow' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the NOC flag of ZRSN is X or blank
  METHOD noc_flag_x_or_blank.
    TRY.
        configure_scenario( VALUE #( noc_flag = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-rsn iv_entry = `C02`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_invalid iv_msg = 'NOC flag Y refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment method maps to exactly one class - a house bank may not name another class
  METHOD one_class_per_pay_method.
    TRY.
        configure_scenario( VALUE #( two_classes = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-pmc iv_entry = `D/E/BARC1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-method_two_classes iv_msg = 'E in WIR and ACI' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a house-bank entry overrides the calendar only - calendar present, no ageing basis
  METHOD house_bank_needs_calendar.
    TRY.
        configure_scenario( VALUE #( bank_calendar = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-pmc iv_entry = `D/X/COMM1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-required iv_msg = 'Calendar required' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-pmc iv_entry = `D/X/COMM1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-must_be_blank iv_msg = 'No ageing basis' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a house-bank entry needs the class entry ('*') of its payment method
  METHOD house_bank_needs_class_entry.
    TRY.
        configure_scenario( VALUE #( no_class_entry = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-pmc iv_entry = `D/Q/BARC1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-class_entry_none iv_msg = 'No D/Q/* entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the payment methods of one class share ageing basis and calendar
  METHOD one_calendar_per_class.
    TRY.
        configure_scenario( VALUE #( class_differs = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-pmc iv_entry = `D/H/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-entries_differ iv_msg = 'ACH ageing basis differs' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the method class of a LIFECYCLE scope exists in ZPMC for the flow
  METHOD lifecycle_class_must_exist.
    TRY.
        configure_scenario( VALUE #( unknown_class = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-btr iv_entry = `LIFECYCLE/DCHQ/BAI2/581`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-class_unknown iv_msg = 'CHQ is no class of D' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: LIFECYCLE needs a role and never a reconciliation role; RECON only the seven roles
  METHOD role_values_per_usage.
    TRY.
        configure_scenario( VALUE #( roles_per_usage = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `LIFECYCLE/DACH/BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_reserved iv_msg = 'LEG is a RECON role' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `LIFECYCLE/DACH/BAI2/166`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-required iv_msg = 'Lifecycle role required' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `RECON/DISB_ACH/BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_invalid iv_msg = 'ORIGINAL is no RECON role' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a LIFECYCLE scope is flow D / C + method class
  METHOD lifecycle_scope_form.
    TRY.
        configure_scenario( VALUE #( scope_form = abap_true ) ).
        assert_message( it_messages = check( ) iv_area = gc_area-btr iv_entry = `LIFECYCLE/XACH/BAI2/466`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-form_invalid iv_msg = 'XACH has no flow' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: RECON entries are BAI2 type codes and compare no amount
  METHOD recon_scheme_bai2_no_compare.
    TRY.
        configure_scenario( VALUE #( recon_scheme = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `RECON/DISB_ACH/PRTRY/X1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-value_invalid iv_msg = 'RECON scheme BAI2 only' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btr iv_entry = `RECON/DISB_ACH/PRTRY/X1`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-must_be_blank iv_msg = 'RECON compares nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a ZBTM entry that is not BLOCK needs a rule group (blank = category) in ZCD_BTC_RULE
  METHOD rule_group_needs_active_rule.
    TRY.
        configure_scenario( VALUE #( rule_group = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `BAI2/475///*/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-rule_group_empty iv_msg = 'G99 has no rule' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 1
                                            msg = 'W02 uses group W01; BLOCK (NOC) needs none' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an ISO code needs family and sub-family; other schemes leave both blank
  METHOD iso_code_needs_its_parts.
    TRY.
        configure_scenario( VALUE #( iso_parts = abap_true ) ).
        DATA(lt_messages) = check( ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `ISO/PMNT///*/C`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-required iv_msg = 'ISO family required' ).
        assert_message( it_messages = lt_messages iv_area = gc_area-btm iv_entry = `BAI2/142/RCDT//*/*`
                        iv_number = zif_cd_ops_cfg_types=>gc_msg-must_be_blank iv_msg = 'BAI2 has no family' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
