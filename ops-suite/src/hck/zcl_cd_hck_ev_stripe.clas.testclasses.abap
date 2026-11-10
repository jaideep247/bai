*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_stripe.clas.testclasses.abap
*& Purpose:
*& Unit tests of the Stripe payout evidence over the full chain payment
*& document -> DFKKOP payment intent ID -> payout log row: settings not
*& maintained (not configured, nothing read), payout row found, no payout
*& row, optional record-type / payout / ACK conditions, refund or partial
*& ACK = anomaly, one read per table, configured names passed to the DAO.
*& Runtime DAO is a double, the settings are the delivered ZCA_PARAM
*& definitions in memory (ZCL_CD_OPS_PARAM_SEED); does not prove live SAP
*& runtime behavior (field names VERIFY-SE11).
*& Modification log:
*& 2026-11-07 | Initial version (user correction: Stripe payment intent ID chain).
*& 2026-11-08 | Table consolidation: settings are the parameters HCK_STRIPE_* (was ZCD_HCK_EVSET); the
*&            | delivered definitions are blank = not configured (delivered_blank_not_configured).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    "! DFKKOP rows: REF = AUGBL, STATUS = payment intent ID
    DATA mt_items TYPE zif_cd_hck_runtime_types=>tt_ref_row.
    "! Payout log rows: REF = payment intent ID
    DATA mt_log TYPE zif_cd_hck_runtime_types=>tt_ref_row.
    DATA mt_sources TYPE STANDARD TABLE OF zif_cd_hck_runtime_types=>ty_ref_source WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_reference_rows.
    INSERT is_source INTO TABLE mt_sources.
    DATA(lt_rows) = COND #( WHEN is_source-tabname = zif_cd_ops_trace_types=>gc_table-dfkkop THEN mt_items ELSE mt_log ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_refs[ table_line = <ls_row>-ref ] ).
        INSERT <ls_row> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_stripe DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_paid    TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_waiting TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_refund  TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003'.
    DATA mo_dao TYPE REF TO ltd_runtime_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS setting
      IMPORTING
        iv_name  TYPE zif_ca_ops_types=>ty_param_name
        iv_value TYPE clike.
    METHODS configure
      IMPORTING
        iv_conditions TYPE abap_bool DEFAULT abap_false.
    METHODS collect
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_ca_ops_error.
    METHODS not_configured_reads_nothing FOR TESTING.
    METHODS payout_row_found             FOR TESTING.
    METHODS conditions_when_maintained   FOR TESTING.
    METHODS refund_is_anomaly            FOR TESTING.
    METHODS names_passed_one_read_each   FOR TESTING.
    METHODS delivered_blank_not_configured FOR TESTING.
ENDCLASS.


CLASS ltc_ev_stripe IMPLEMENTATION.

  METHOD setup.
    DATA ls_row TYPE zif_cd_hck_runtime_types=>ty_ref_row.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    " Delivered parameter definitions in memory (HCK_STRIPE_* blank until maintained)
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    " Open items cleared by the payment documents with their payment intent IDs
    ls_row-ref = gc_paid.
    ls_row-status = 'pi_001'.
    INSERT ls_row INTO TABLE mo_dao->mt_items.
    ls_row-ref = gc_waiting.
    ls_row-status = 'pi_002'.
    INSERT ls_row INTO TABLE mo_dao->mt_items.
    ls_row-ref = gc_refund.
    ls_row-status = 'pi_003'.
    INSERT ls_row INTO TABLE mo_dao->mt_items.
    " Payout log: pi_001 charged, paid out, full ACK; pi_002 charge without payout; pi_003 refund
    CLEAR ls_row.
    ls_row-ref = 'pi_001'.
    ls_row-rtype = 'CHARGE'.
    ls_row-grp = 'po_1107'.
    ls_row-status = 'FULL'.
    INSERT ls_row INTO TABLE mo_dao->mt_log.
    ls_row-ref = 'pi_002'.
    CLEAR ls_row-grp.
    INSERT ls_row INTO TABLE mo_dao->mt_log.
    ls_row-ref = 'pi_003'.
    ls_row-rtype = 'REFUND'.
    ls_row-grp = 'po_1107'.
    INSERT ls_row INTO TABLE mo_dao->mt_log.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_params.
  ENDMETHOD.


  METHOD setting.
    mo_params->set( iv_name = iv_name iv_value = iv_value ).
  ENDMETHOD.


  METHOD configure.
    " Names as maintained after the SE11 check (placeholders in the seed)
    setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_table iv_value = 'ZCD_STRP_POUT_LOG' ).
    setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_intent_field iv_value = 'PAYMENT_INTENT' ).
    setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_dfkkop_field iv_value = 'ZZ_PAYMENT_INTENT' ).
    IF iv_conditions = abap_true.
      setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_type_field iv_value = 'RECORD_TYPE' ).
      setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_payout_field iv_value = 'PAYOUT_ID' ).
      setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_ack_field iv_value = 'ACK_STATUS' ).
      setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_charge iv_value = 'CHARGE' ).
      setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_refund iv_value = 'REFUND' ).
      setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_ack_full iv_value = 'FULL' ).
      setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_ack_partial iv_value = 'PARTIAL' ).
    ENDIF.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    INSERT VALUE #( doc1r = gc_paid ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_waiting ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_refund ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = '000000300004' ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_stripe( )->zif_cd_hck_evidence~collect(
                  it_payments = lt_payments
                  is_rule     = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_STRIPE' )
                  iv_max_rows = 100 ).
  ENDMETHOD.


  " Rule: while table or intent fields are not maintained the kind is not configured and reads nothing
  METHOD not_configured_reads_nothing.
    TRY.
        setting( iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_table iv_value = 'ZCD_STRP_POUT_LOG' ).
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-unconfigured msg = 'Not configured' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_sources msg = 'Nothing read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payout log row of the payment intent ID of the cleared open item holds (no conditions)
  METHOD payout_row_found.
    TRY.
        configure( ).
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_paid ]-found msg = 'Payout row' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_waiting ]-found msg = 'Any row without conditions' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = '000000300004' ] ) )
                                           msg = 'No intent: no evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: maintained conditions apply - charge, in a payout, full ACK; a charge without payout does not hold
  METHOD conditions_when_maintained.
    TRY.
        configure( abap_true ).
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_paid ]-found msg = 'Charge paid out, full ACK' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_waiting ]-found msg = 'Charge without payout' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a refund (or partial ACK) record is an anomaly CLEARING_INCONSISTENT
  METHOD refund_is_anomaly.
    TRY.
        configure( abap_true ).
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-evidence[ doc1r = gc_refund ]-anomaly
                                            exp = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                            msg = 'Refund' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-evidence[ doc1r = gc_paid ]-anomaly msg = 'Paid: no anomaly' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one read of DFKKOP (AUGBL -> intent field) and one of the payout log (intent field), names
  " from the settings
  METHOD names_passed_one_read_each.
    TRY.
        configure( ).
        collect( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_sources ) exp = 2 msg = 'Two reads' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_sources[ 1 ]-status_field exp = 'ZZ_PAYMENT_INTENT'
                                            msg = 'DFKKOP intent field' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_sources[ 1 ]-ref_field exp = zif_cd_hck_runtime_types=>gc_dfkkop_augbl
                                            msg = 'By AUGBL' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_sources[ 2 ]-ref_field exp = 'PAYMENT_INTENT'
                                            msg = 'Payout log intent field' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (table consolidation 2026-11-08): the parameters replacing ZCD_HCK_EVSET are delivered blank
  " (landscape-specific); with the delivered definitions only, the kind is not configured and reads
  " nothing - the morning report says so instead of judging card payments on half the chain
  METHOD delivered_blank_not_configured.
    DATA lt_names TYPE STANDARD TABLE OF zif_ca_ops_types=>ty_param_name WITH EMPTY KEY.
    TRY.
        lt_names = VALUE #( ( zif_cd_hck_runtime_types=>gc_param-stripe_table )
                            ( zif_cd_hck_runtime_types=>gc_param-stripe_intent_field )
                            ( zif_cd_hck_runtime_types=>gc_param-stripe_dfkkop_field ) ).
        DATA(lt_definitions) = zcl_cd_ops_param_seed=>definitions( ).
        LOOP AT lt_names INTO DATA(lv_name).
          cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_definitions[ name = lv_name ] ) )
                                            msg = |{ lv_name } is a delivered definition| ).
          cl_abap_unit_assert=>assert_initial( act = VALUE #( lt_definitions[ name = lv_name ]-default_value OPTIONAL )
                                               msg = |{ lv_name } is delivered blank| ).
        ENDLOOP.
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-unconfigured msg = 'Delivered definitions: not configured' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_sources msg = 'Nothing read' ).
        cl_abap_unit_assert=>assert_initial( act = mo_params->params( )->get_errors( )
                                             msg = 'Blank parameters are no framework error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
