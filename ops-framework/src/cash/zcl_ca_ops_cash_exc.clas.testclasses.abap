*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_exc.clas.testclasses.abap
*& Purpose:
*& Tests of the cash exception builder: the one mapping into the finding
*& keeps amount and currency, company code, oldest item as business date,
*& stage as rule, the rule parameter as configuration rule and the source
*& key; the details carry count / amount, oldest and age, next cutoff,
*& owner and every evidence key; the context (alert e-mail) carries no
*& amount; a not-evaluated exception is a notification; object key and
*& age. Pure logic, no database.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltc_cash_exc DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS exception
      RETURNING
        VALUE(rs_exc) TYPE zif_ca_ops_cash_types=>ty_exception.

    METHODS stored_fields_mapped      FOR TESTING.
    METHODS details_carry_content     FOR TESTING.
    METHODS context_without_amount    FOR TESTING.
    METHODS not_evaluated_is_notify   FOR TESTING.
    METHODS unknown_cutoff_and_owner  FOR TESTING.
    METHODS object_key_and_age        FOR TESTING.
ENDCLASS.


CLASS ltc_cash_exc IMPLEMENTATION.

  METHOD exception.
    rs_exc = VALUE #( check_code   = zif_ca_ops_cash_types=>gc_code-lot_not_posted
                      severity     = zif_ca_ops_types=>gc_severity-error
                      stage        = zif_ca_ops_cash_types=>gc_stage-posting
                      evaluation   = zif_ca_ops_cash_types=>gc_evaluation-observed
                      object_type  = zif_ca_ops_cash_types=>gc_object_type-lot
                      object_key   = 'LOT1/ZT01/EUR'
                      source       = zif_ca_ops_cash_types=>gc_source-lots
                      company_code = 'ZT01'
                      currency     = 'EUR'
                      item_count   = 3
                      amount       = '1234.50'
                      oldest       = '20261110'
                      age_days     = 6
                      cutoff       = VALUE #( known = abap_true date = '20261116' time = '100000' time_zone = 'UTC' )
                      owner        = VALUE #( control_id = 'ZT_CTL' owner = 'ZT_OWNER' backup = 'ZT_BACKUP'
                                              team = 'ZT_TEAM' )
                      rule_param   = zif_ca_ops_cash_types=>gc_param-lot_done_status
                      evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-lot value = 'LOT1' ) )
                      msgno        = zif_ca_ops_cash_types=>gc_msg-lot_not_posted
                      msgv1        = 'LOT1'
                      msgv2        = '6'
                      msgv3        = '3'
                      msgv4        = '1,234.50 EUR' ).
  ENDMETHOD.


  " Rule: the stored columns carry the exception's own values (one currency per finding, oldest = business date)
  METHOD stored_fields_mapped.
    DATA(ls_finding) = zcl_ca_ops_cash_exc=>to_finding( exception( ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '1234.50' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = 'ZT01' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261110' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = zif_ca_ops_cash_types=>gc_stage-posting ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-cfg_rule exp = zif_ca_ops_cash_types=>gc_param-lot_done_status ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'LOT1/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-item_count exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-action exp = zif_ca_ops_types=>gc_action-exception ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = zif_ca_ops_cash_types=>gc_source-lots ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-message CS 'LOT1' ) ).
  ENDMETHOD.


  " Rule: count, amount, oldest and age, cutoff, owner and every evidence key are in the details
  METHOD details_carry_content.
    DATA(lv_details) = zcl_ca_ops_cash_exc=>to_finding( exception( ) )-details.

    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS '1,234.50' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS '2026-11-10' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS '2026-11-16' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS 'ZT_TEAM' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS 'KEYZ1' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS zif_ca_ops_cash_types=>gc_evaluation-observed ) ).
  ENDMETHOD.


  " Rule: the alert e-mail context never carries an amount (rules without SHOW_AMOUNTS)
  METHOD context_without_amount.
    DATA(lv_context) = zcl_ca_ops_cash_exc=>to_finding( exception( ) )-context.

    cl_abap_unit_assert=>assert_false( xsdbool( lv_context CS '1,234.50' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_context CS 'KEYZ1' ) ).
  ENDMETHOD.


  " Rule: a rule that was not evaluated is a notification, never an owned business exception
  METHOD not_evaluated_is_notify.
    DATA(ls_exc) = exception( ).
    ls_exc-evaluation = zif_ca_ops_cash_types=>gc_evaluation-not_evaluated.
    ls_exc-severity   = zif_ca_ops_types=>gc_severity-warning.

    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cash_exc=>to_finding( ls_exc )-action
                                        exp = zif_ca_ops_types=>gc_action-notify ).
  ENDMETHOD.


  " Rule: an unknown cutoff and a missing owner are said, not left blank
  METHOD unknown_cutoff_and_owner.
    DATA(ls_exc) = exception( ).
    CLEAR: ls_exc-cutoff, ls_exc-owner.

    DATA(lv_details) = zcl_ca_ops_cash_exc=>to_finding( ls_exc )-details.

    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS zif_ca_ops_cash_types=>gc_param-calendar ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_details CS zif_ca_ops_cash_types=>gc_code-lot_not_posted ) ).
  ENDMETHOD.


  " Rule: source key parts, company code and currency joined by /; age from the oldest item, never negative
  METHOD object_key_and_age.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cash_exc=>object_key( iv_id       = '20261112'
                                                                               iv_sub      = 'PAY01'
                                                                               iv_company  = 'ZT01'
                                                                               iv_currency = 'EUR' )
                                        exp = '20261112/PAY01/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cash_exc=>object_key( 'LOT1' ) exp = 'LOT1' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cash_exc=>age_days( iv_oldest = '20261110'
                                                                             iv_today  = '20261116' )
                                        exp = 6 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_cash_exc=>age_days( iv_oldest = '20261120'
                                                                             iv_today  = '20261116' )
                                        exp = 0 ).
  ENDMETHOD.

ENDCLASS.
