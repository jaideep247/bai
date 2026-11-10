*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chn_email.clas.abap
*& Purpose:
*& Alert channel EMAIL: sends the HTML body through BCS to the SAPoffice shared
*& distribution lists (SO23) named in the destination, comma/semicolon separated.
*& Recipients are maintained in SO23 only: whoever is on the list receives the
*& alert, no address is kept in the suite. A name that is not a shared list is
*& refused before anything is sent (027) and by the configuration app (419).
*& Thin wrapper over SAP standard: the list lookup, the BCS calls and the COMMIT
*& sit in test seams (DLI_READ, BCS_SEND, BCS_COMMIT); the real delivery is
*& covered by the QA1 integration test.
*& Modification log:
*& 2026-11-05 | Initial version (replaces a consumer's class).
*& 2026-11-06 | BCS send result checked (audit A45).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Test seams BCS_SEND / BCS_COMMIT; send result and BCS error in locals; document type constant (coverage gap closure).
*& 2026-11-07 | Recipients are SO23 shared distribution lists (user decision); CHECK_DESTINATION, test seam DLI_READ.
*& 2026-11-10 | COMMIT WORK AND WAIT; a failed commit raises 806, so the router logs FAILED, never SENT.
*& 2026-11-10 | Moved from ZCL_CD_OPS_CHN_EMAIL to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert channel e-mail (BCS)</p>
CLASS zcl_ca_ops_chn_email DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_channel.

  PRIVATE SECTION.
    "! BCS document type of the HTML body
    CONSTANTS gc_document_type TYPE so_obj_tp VALUE 'HTM'.

    "! SO23 list name as SAPoffice stores it (upper case); blank when the name
    "! does not fit SO_OBJ_NAM, so a long name never resolves to a truncated list
    CLASS-METHODS dli_name
      IMPORTING
        iv_name        TYPE string
      RETURNING
        VALUE(rv_name) TYPE so_obj_nam.

ENDCLASS.



CLASS zcl_ca_ops_chn_email IMPLEMENTATION.

  METHOD dli_name.
    DATA(lv_upper) = to_upper( iv_name ).
    rv_name = lv_upper.
    IF CONV string( rv_name ) <> lv_upper.
      CLEAR rv_name.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_alert_channel~check_destination.
    DATA lv_found TYPE abap_bool.
    DATA lt_invalid TYPE string_table.
    LOOP AT zcl_ca_ops_util=>split_list( iv_destination ) ASSIGNING FIELD-SYMBOL(<lv_name>).
      DATA(lv_dli) = dli_name( <lv_name> ).
      lv_found = abap_false.
      IF lv_dli IS NOT INITIAL.
        " Shared list only (I_PRIVATE blank): a personal list of the job user is not maintainable by support
        TEST-SEAM dli_read.
          TRY.
              cl_distributionlist_bcs=>getu_persistent( i_dliname = lv_dli
                                                        i_private = abap_false ).
              lv_found = abap_true.
            CATCH cx_address_bcs.
              lv_found = abap_false.
          ENDTRY.
        END-TEST-SEAM.
      ENDIF.
      IF lv_found = abap_false.
        INSERT <lv_name> INTO TABLE lt_invalid.
      ENDIF.
    ENDLOOP.
    rv_invalid = concat_lines_of( table = lt_invalid sep = `,` ).
  ENDMETHOD.


  METHOD zif_ca_ops_alert_channel~deliver.
    DATA lo_request TYPE REF TO cl_bcs.
    DATA lv_sent TYPE abap_bool.
    DATA lx_error TYPE REF TO cx_bcs.
    DATA lv_commit_subrc TYPE sysubrc.
    FIELD-SYMBOLS <lv_name> TYPE string.
    DATA(lt_recipients) = zcl_ca_ops_util=>split_list( is_message-destination ).
    IF lt_recipients IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e021(zca_ops) WITH is_message-rule_id.
    ENDIF.
    " Every name must be a shared SO23 list - nothing is sent to part of a route
    DATA(lv_invalid) = zif_ca_ops_alert_channel~check_destination( is_message-destination ).
    IF lv_invalid IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e027(zca_ops) WITH is_message-rule_id lv_invalid.
    ENDIF.
    TEST-SEAM bcs_send.
      TRY.
          lo_request = cl_bcs=>create_persistent( ).
          lo_request->set_document( cl_document_bcs=>create_document(
                                      i_type    = gc_document_type
                                      i_text    = cl_document_bcs=>string_to_soli( is_message-html )
                                      i_subject = CONV so_obj_des( is_message-subject ) ) ).
          " SAPconnect expands the list to its current members at send time
          LOOP AT lt_recipients ASSIGNING <lv_name>.
            lo_request->add_recipient(
              cl_distributionlist_bcs=>getu_persistent( i_dliname = dli_name( <lv_name> )
                                                        i_private = abap_false ) ).
          ENDLOOP.
          lo_request->set_send_immediately( abap_true ).
          lv_sent = lo_request->send( ).
        CATCH cx_bcs INTO lx_error.
          " raised below as a failed delivery
      ENDTRY.
    END-TEST-SEAM.
    IF lx_error IS BOUND.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e020(zca_ops) WITH is_message-rule_id
        EXPORTING
          previous = lx_error.
    ENDIF.
    " A45: the BCS send result decides - a refused request is not logged as sent
    IF lv_sent = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e026(zca_ops) WITH is_message-rule_id.
    ENDIF.
    " BCS sends on commit; the alert is delivered independently of the run's LUW. AND WAIT: the
    " send request is in the database before the router logs the alert as submitted
    TEST-SEAM bcs_commit.
      COMMIT WORK AND WAIT.
      lv_commit_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_commit_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e806(zca_ops) WITH is_message-rule_id lv_commit_subrc.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
