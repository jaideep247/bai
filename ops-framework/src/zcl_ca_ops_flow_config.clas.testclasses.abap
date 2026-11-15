*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_config.clas.testclasses.abap
*& Purpose:
*& Tests of the cross-row rules of an account flow (pure): a valid flow
*& has no problem; a rule naming an unknown stage, a criterion of the
*& other line source or no criterion at all is reported; OTHER may be
*& named by a rule; a flow without an active stage, two accounts of one
*& role, company code and currency, and a stage naming a role no account
*& holds are reported; OUTSIDE accounts are never counted twice. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
CLASS ltc_flow_config DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS valid_config
      RETURNING
        VALUE(rs_config) TYPE zif_ca_ops_flow_types=>ty_config.
    METHODS has
      IMPORTING
        it_problems   TYPE zif_ca_ops_flow_types=>tt_problem
        iv_msgno      TYPE zif_ca_ops_types=>ty_msgno
      RETURNING
        VALUE(rv_has) TYPE abap_bool.

    METHODS valid_flow_no_problem      FOR TESTING.
    METHODS rule_unknown_stage         FOR TESTING.
    METHODS rule_other_allowed         FOR TESTING.
    METHODS rule_criterion_of_source   FOR TESTING.
    METHODS rule_without_criterion     FOR TESTING.
    METHODS no_active_stage            FOR TESTING.
    METHODS role_twice_per_currency    FOR TESTING.
    METHODS outside_never_twice        FOR TESTING.
    METHODS stage_role_not_held        FOR TESTING.
    METHODS tile_unknown_stage         FOR TESTING.
ENDCLASS.


CLASS ltc_flow_config IMPLEMENTATION.

  " The sample disbursement flow: payable (FI-CA), disbursement clearing, cash, returns clearing, an expense outside
  METHOD valid_config.
    rs_config-flow = VALUE #( area = 'ZT_OPS_A' flow_id = 'DISB' active = abap_true ).
    rs_config-accounts = VALUE #(
      ( flow_acct = 'PAYABLE' role = zif_ca_ops_flow_types=>gc_role-payable bukrs = 'ZT01' line_source = 'F'
        active = abap_true )
      ( flow_acct = 'EXPENSE' role = zif_ca_ops_flow_types=>gc_role-outside bukrs = 'ZT01' line_source = 'G'
        active = abap_true )
      ( flow_acct = 'CLEARING' role = zif_ca_ops_flow_types=>gc_role-clearing bukrs = 'ZT01' line_source = 'G'
        active = abap_true )
      ( flow_acct = 'CASH' role = zif_ca_ops_flow_types=>gc_role-cash bukrs = 'ZT01' line_source = 'G'
        active = abap_true )
      ( flow_acct = 'RETURNS' role = zif_ca_ops_flow_types=>gc_role-clarification bukrs = 'ZT01' line_source = 'G'
        active = abap_true ) ).
    rs_config-stages = VALUE #(
      ( stage_id = 'REQUEST' seq = 10 active = abap_true )
      ( stage_id = 'PAYRUN' seq = 20 active = abap_true )
      ( stage_id = 'RETURNS_LOT' seq = 50 expect_from = zif_ca_ops_flow_types=>gc_role-clarification
        expect_to = zif_ca_ops_flow_types=>gc_role-payable active = abap_true )
      ( stage_id = 'GL_TRANSFER' seq = 60 active = abap_true ) ).
    rs_config-tiles = VALUE #(
      ( tile = 'REQUESTED' stage_id = 'REQUEST' role = zif_ca_ops_flow_types=>gc_role-payable side = 'C'
        active = abap_true ) ).
    rs_config-rules = VALUE #(
      ( rule_seq = '0010' rule_id = 'FICA_REQUEST' stage_id = 'REQUEST' line_source = 'F' doc_type = 'ZR'
        active = abap_true )
      ( rule_seq = '0020' rule_id = 'FICA_PAYRUN' stage_id = 'PAYRUN' line_source = 'F' origin = 'ZP'
        active = abap_true )
      ( rule_seq = '0090' rule_id = 'S4_GL_TRANSFER' stage_id = 'GL_TRANSFER' line_source = 'G' ref_type = 'FKKSU'
        active = abap_true ) ).
  ENDMETHOD.


  METHOD has.
    rv_has = xsdbool( line_exists( it_problems[ msgno = iv_msgno ] ) ).
  ENDMETHOD.


  " Rule: the sample flow is consistent - no problem
  METHOD valid_flow_no_problem.
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_flow_config=>validate( valid_config( ) )
                                         msg = 'Valid flow' ).
  ENDMETHOD.


  " Rule: an active rule must name an active stage of its flow (324)
  METHOD rule_unknown_stage.
    DATA(ls_config) = valid_config( ).
    ls_config-rules[ 1 ]-stage_id = 'NO_SUCH_STAGE'.
    DATA(lt_problems) = zcl_ca_ops_flow_config=>validate( ls_config ).
    cl_abap_unit_assert=>assert_true( act = has( it_problems = lt_problems
                                                 iv_msgno    = zif_ca_ops_flow_types=>gc_msg-rule_stage )
                                      msg = 'Unknown stage reported' ).
  ENDMETHOD.


  " Rule: a rule may send lines to the row OTHER on purpose
  METHOD rule_other_allowed.
    DATA(ls_config) = valid_config( ).
    ls_config-rules[ 1 ]-stage_id = zif_ca_ops_flow_types=>gc_stage-other.
    cl_abap_unit_assert=>assert_false( act = has( it_problems = zcl_ca_ops_flow_config=>validate( ls_config )
                                                  iv_msgno    = zif_ca_ops_flow_types=>gc_msg-rule_stage )
                                       msg = 'OTHER is a valid target' ).
  ENDMETHOD.


  " Rule: a journal rule names no FI-CA criterion, an FI-CA rule no reference transaction (325)
  METHOD rule_criterion_of_source.
    DATA(ls_config) = valid_config( ).
    ls_config-rules[ 3 ]-origin = 'ZP'.
    ls_config-rules[ 1 ]-ref_type = 'FKKSU'.
    DATA(lt_problems) = zcl_ca_ops_flow_config=>validate( ls_config ).
    cl_abap_unit_assert=>assert_equals(
      act = REDUCE i( INIT n = 0 FOR ls_problem IN lt_problems
                      WHERE ( msgno = zif_ca_ops_flow_types=>gc_msg-rule_criterion ) NEXT n = n + 1 )
      exp = 2
      msg = 'One problem per wrong criterion' ).
  ENDMETHOD.


  " Rule: a rule without any criterion would hide the row OTHER (329)
  METHOD rule_without_criterion.
    DATA(ls_config) = valid_config( ).
    CLEAR ls_config-rules[ 1 ]-doc_type.
    cl_abap_unit_assert=>assert_true( act = has( it_problems = zcl_ca_ops_flow_config=>validate( ls_config )
                                                 iv_msgno    = zif_ca_ops_flow_types=>gc_msg-rule_open )
                                      msg = 'Catch-all rule reported' ).
  ENDMETHOD.


  " Rule: a flow needs at least one active stage (327)
  METHOD no_active_stage.
    DATA(ls_config) = valid_config( ).
    LOOP AT ls_config-stages ASSIGNING FIELD-SYMBOL(<ls_stage>).
      <ls_stage>-active = abap_false.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( act = has( it_problems = zcl_ca_ops_flow_config=>validate( ls_config )
                                                 iv_msgno    = zif_ca_ops_flow_types=>gc_msg-no_stage )
                                      msg = 'No stage reported' ).
  ENDMETHOD.


  " Rule: one account per company code and currency of a role that receives an expected counter-posting (326);
  " several accounts of another role (ACH, wire, cheque clearing) are fine
  METHOD role_twice_per_currency.
    DATA(ls_config) = valid_config( ).
    INSERT VALUE #( flow_acct = 'CLEARING2' role = zif_ca_ops_flow_types=>gc_role-clearing bukrs = 'ZT01'
                    active = abap_true ) INTO TABLE ls_config-accounts.
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_flow_config=>validate( ls_config )
                                         msg = 'Two clearing accounts are fine' ).
    INSERT VALUE #( flow_acct = 'PAYABLE2' role = zif_ca_ops_flow_types=>gc_role-payable bukrs = 'ZT01'
                    active = abap_true ) INTO TABLE ls_config-accounts.
    cl_abap_unit_assert=>assert_true( act = has( it_problems = zcl_ca_ops_flow_config=>validate( ls_config )
                                                 iv_msgno    = zif_ca_ops_flow_types=>gc_msg-role_twice )
                                      msg = 'Second payable (expected reopen) reported' ).
  ENDMETHOD.


  " Rule: accounts outside the control chain may be several (expense, revenue) - never counted
  METHOD outside_never_twice.
    DATA(ls_config) = valid_config( ).
    INSERT VALUE #( flow_acct = 'EXPENSE2' role = zif_ca_ops_flow_types=>gc_role-outside bukrs = 'ZT01'
                    active = abap_true ) INTO TABLE ls_config-accounts.
    cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_flow_config=>validate( ls_config )
                                         msg = 'Two outside accounts are fine' ).
  ENDMETHOD.


  " Rule: a role a stage (expected postings) or a tile row names must be held by an active account (328)
  METHOD stage_role_not_held.
    DATA(ls_config) = valid_config( ).
    DELETE ls_config-accounts WHERE role = zif_ca_ops_flow_types=>gc_role-clarification.
    DATA(lt_problems) = zcl_ca_ops_flow_config=>validate( ls_config ).
    cl_abap_unit_assert=>assert_true( act = has( it_problems = lt_problems
                                                 iv_msgno    = zif_ca_ops_flow_types=>gc_msg-role_missing )
                                      msg = 'Missing clarification account reported' ).
  ENDMETHOD.

  " Rule: a tile row names an active stage of the flow (324)
  METHOD tile_unknown_stage.
    DATA(ls_config) = valid_config( ).
    ls_config-tiles[ 1 ]-stage_id = 'NO_SUCH_STAGE'.
    cl_abap_unit_assert=>assert_true( act = has( it_problems = zcl_ca_ops_flow_config=>validate( ls_config )
                                                 iv_msgno    = zif_ca_ops_flow_types=>gc_msg-rule_stage )
                                      msg = 'Tile of an unknown stage reported' ).
  ENDMETHOD.

ENDCLASS.
