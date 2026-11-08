*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_stripe.clas.abap
*& Purpose:
*& Evidence kind "Stripe payout" (card collections): the payment intent
*& IDs of the payment document are read from the open items it cleared
*& (DFKKOP-AUGBL = payment document, intent ID field configurable), then
*& the Stripe payout log (e.g. ZCD_STRP_POUT_LOG, intent ID field
*& configurable) by those IDs. Found = a payout log row of one of the
*& intent IDs; when maintained, the row must also be a charge (CHARGE
*& values), carry a payout (PAYOUT_FIELD) and a full ACK (ACK_FULL). A
*& refund (REFUND) or partial ACK (ACK_PARTIAL) row is an anomaly
*& CLEARING_INCONSISTENT. Settings are ZCA_PARAM parameters HCK_STRIPE_*
*& (area CD_HCK); while table or intent fields are not maintained the kind
*& reports "not configured" (information) and its rows are ignored. Tables on
*& ZCD_OPS_TABWL (HCK / READ) and fields in the DDIC are checked before each read. One
*& read per table for all payments, capped. Read-only.
*& Modification log:
*& 2026-11-07 | Initial version (user correction: link by Stripe payment intent ID, method B).
*& 2026-11-08 | Table consolidation: approved tables (HCK / READ) and drift tables (HCK / DRIFT) read from
*&            | ZCD_OPS_TABWL (was ZCD_HCK_TABWL, ZCD_HCK_DRIFT).
*& 2026-11-08 | Table consolidation: settings from the parameters HCK_STRIPE_* through ZCL_CD_OPS_FACTORY=>
*&            | GET_PARAMS (was ZCD_HCK_EVSET by set id PARAM1); PARAM1 of the rule is no longer read.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Evidence - Stripe payout log row of the payment intent</p>
"! One Stripe payout log per landscape: the settings are parameters of area CD_HCK, not a set
"! of rows (no set id dimension is needed - a second log would be a second evidence kind).
CLASS zcl_cd_hck_ev_stripe DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_evidence.

  PRIVATE SECTION.
    "! Payment intent ID -> payment document
    TYPES:
      BEGIN OF ty_intent,
        intent TYPE string,
        doc1r  TYPE zif_cd_hck_runtime_types=>ty_docno,
      END OF ty_intent.
    TYPES tt_intent TYPE SORTED TABLE OF ty_intent WITH NON-UNIQUE KEY intent.

    "! Value of a setting parameter (upper case; blank when not maintained)
    CLASS-METHODS setting
      IMPORTING
        io_params       TYPE REF TO zif_cd_ops_params
        iv_name         TYPE zif_cd_ops_types=>ty_param_name
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Blank list = condition not configured (holds); else the value must be listed
    CLASS-METHODS listed_or_open
      IMPORTING
        it_values     TYPE string_table
        iv_value      TYPE clike
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_hck_ev_stripe IMPLEMENTATION.

  METHOD zif_cd_hck_evidence~collect.
    DATA lt_docs TYPE zif_cd_hck_runtime_types=>tt_ref_value.
    DATA lt_ids TYPE zif_cd_hck_runtime_types=>tt_ref_value.
    DATA lt_intent TYPE tt_intent.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_runtime_dao( ).
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(lv_op_intent) = setting( io_params = lo_params
                                  iv_name   = zif_cd_hck_runtime_types=>gc_param-stripe_dfkkop_field ).
    DATA(ls_log) = VALUE zif_cd_hck_runtime_types=>ty_ref_source(
      tabname      = setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_table )
      ref_field    = setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_intent_field )
      type_field   = setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_type_field )
      group_field  = setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_payout_field )
      status_field = setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_ack_field ) ).
    " Until SE11 is checked and the parameters are maintained, the kind is not configured
    IF lv_op_intent IS INITIAL OR ls_log-tabname IS INITIAL OR ls_log-ref_field IS INITIAL.
      rs_result-unconfigured = abap_true.
      RETURN.
    ENDIF.
    DATA(lt_charge) = zcl_cd_hck_ev_support=>tokens(
                        setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_charge ) ).
    DATA(lt_ack_full) = zcl_cd_hck_ev_support=>tokens(
                          setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_ack_full ) ).
    DATA(lt_refund) = zcl_cd_hck_ev_support=>tokens(
                        setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_refund ) ).
    DATA(lt_partial) = zcl_cd_hck_ev_support=>tokens(
                         setting( io_params = lo_params iv_name = zif_cd_hck_runtime_types=>gc_param-stripe_ack_partial ) ).
    IF it_payments IS INITIAL.
      RETURN.
    ENDIF.
    rs_result-source = ls_log-tabname.

    " 1. Payment intent IDs of the open items each payment document cleared (one read)
    LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_payment>).
      INSERT CONV #( <ls_payment>-doc1r ) INTO TABLE lt_docs.
    ENDLOOP.
    DATA(lt_items) = lo_dao->get_reference_rows(
                       is_source   = VALUE #( tabname      = zif_cd_ops_trace_types=>gc_table-dfkkop
                                              ref_field    = zif_cd_hck_runtime_types=>gc_dfkkop_augbl
                                              status_field = lv_op_intent )
                       it_refs     = lt_docs
                       iv_max_rows = iv_max_rows ).
    rs_result-capped = xsdbool( lines( lt_items ) >= iv_max_rows ).
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE status IS NOT INITIAL.
      DATA(lv_id) = condense( CONV string( <ls_item>-status ) ).
      INSERT VALUE #( intent = lv_id doc1r = <ls_item>-ref ) INTO TABLE lt_intent.
      INSERT CONV #( lv_id ) INTO TABLE lt_ids.
    ENDLOOP.
    IF lt_ids IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Payout log rows of those intent IDs (one read)
    DATA(lt_rows) = lo_dao->get_reference_rows( is_source   = ls_log
                                                it_refs     = lt_ids
                                                iv_max_rows = iv_max_rows ).
    IF lines( lt_rows ) >= iv_max_rows.
      rs_result-capped = abap_true.
    ENDIF.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_type) = to_upper( condense( CONV string( <ls_row>-rtype ) ) ).
      DATA(lv_ack) = to_upper( condense( CONV string( <ls_row>-status ) ) ).
      DATA(lv_found) = xsdbool( listed_or_open( it_values = lt_charge iv_value = lv_type ) = abap_true
                                AND listed_or_open( it_values = lt_ack_full iv_value = lv_ack ) = abap_true
                                AND ( ls_log-group_field IS INITIAL OR <ls_row>-grp IS NOT INITIAL ) ).
      DATA(lv_conflict) = xsdbool( line_exists( lt_refund[ table_line = lv_type ] )
                                   OR line_exists( lt_partial[ table_line = lv_ack ] ) ).
      LOOP AT lt_intent ASSIGNING FIELD-SYMBOL(<ls_intent>) WHERE intent = condense( CONV string( <ls_row>-ref ) ).
        zcl_cd_hck_ev_support=>add_hit(
          EXPORTING iv_doc1r    = <ls_intent>-doc1r
                    iv_found    = lv_found
                    iv_detail   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_runtime_types=>gc_msg-ev_ref_row
                                                         iv_v1    = <ls_intent>-intent
                                                         iv_v2    = lv_type
                                                         iv_v3    = <ls_row>-grp
                                                         iv_v4    = lv_ack )
          CHANGING  ct_evidence = rs_result-evidence ).
        IF lv_conflict = abap_true.
          READ TABLE rs_result-evidence ASSIGNING FIELD-SYMBOL(<ls_evidence>) WITH TABLE KEY doc1r = <ls_intent>-doc1r.
        IF sy-subrc = 0.
            <ls_evidence>-anomaly  = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist.
            <ls_evidence>-severity = zif_cd_ops_types=>gc_severity-error.
        ENDIF.
      ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD setting.
    " Delivered blank (landscape-specific): blank = not maintained
    rv_value = to_upper( condense( io_params->get_param( iv_name ) ) ).
  ENDMETHOD.


  METHOD listed_or_open.
    rv_yes = xsdbool( it_values IS INITIAL
                      OR line_exists( it_values[ table_line = to_upper( condense( CONV string( iv_value ) ) ) ] ) ).
  ENDMETHOD.

ENDCLASS.
