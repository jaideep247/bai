*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_email.clas.abap
*& Purpose:
*& Alert channel EMAIL: sends the HTML body through BCS to the comma/semicolon
*& separated addresses in the destination. Thin wrapper over SAP standard: the
*& BCS calls and the COMMIT sit in test seams (BCS_SEND, BCS_COMMIT), so the own
*& test include proves the recipient guard and the error mapping; the real
*& delivery is covered by the QA1 integration test.
*& Modification log:
*& 2026-11-05 | Initial version (replaces ZCL_CD_OPS_ALERT_MAIL).
*& 2026-11-06 | BCS send result checked (audit A45).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Test seams BCS_SEND / BCS_COMMIT; send result and BCS error in locals; document type constant (coverage gap closure).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert channel e-mail (BCS)</p>
CLASS zcl_cd_ops_chn_email DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_channel.

  PRIVATE SECTION.
    "! BCS document type of the HTML body
    CONSTANTS gc_document_type TYPE so_obj_tp VALUE 'HTM'.

ENDCLASS.



CLASS zcl_cd_ops_chn_email IMPLEMENTATION.

  METHOD zif_cd_ops_alert_channel~deliver.
    DATA lo_request TYPE REF TO cl_bcs.
    DATA lv_sent TYPE abap_bool.
    DATA lx_error TYPE REF TO cx_bcs.
    FIELD-SYMBOLS <lv_address> TYPE string.
    DATA(lt_recipients) = zcl_cd_ops_util=>split_list( is_message-destination ).
    IF lt_recipients IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e021(zcd_ops) WITH is_message-rule_id.
    ENDIF.
    TEST-SEAM bcs_send.
      TRY.
          lo_request = cl_bcs=>create_persistent( ).
          lo_request->set_document( cl_document_bcs=>create_document(
                                      i_type    = gc_document_type
                                      i_text    = cl_document_bcs=>string_to_soli( is_message-html )
                                      i_subject = CONV so_obj_des( is_message-subject ) ) ).
          LOOP AT lt_recipients ASSIGNING <lv_address>.
            lo_request->add_recipient(
              cl_cam_address_bcs=>create_internet_address( CONV ad_smtpadr( <lv_address> ) ) ).
          ENDLOOP.
          lo_request->set_send_immediately( abap_true ).
          lv_sent = lo_request->send( ).
        CATCH cx_bcs INTO lx_error.
          " raised below as a failed delivery
      ENDTRY.
    END-TEST-SEAM.
    IF lx_error IS BOUND.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e020(zcd_ops) WITH is_message-rule_id
        EXPORTING
          previous = lx_error.
    ENDIF.
    " A45: the BCS send result decides - a refused request is not logged as sent
    IF lv_sent = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e026(zcd_ops) WITH is_message-rule_id.
    ENDIF.
    " BCS sends on commit; the alert is delivered independently of the run's LUW
    TEST-SEAM bcs_commit.
      COMMIT WORK.
    END-TEST-SEAM.
  ENDMETHOD.

ENDCLASS.
