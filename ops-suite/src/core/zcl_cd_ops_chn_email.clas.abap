*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_email.clas.abap
*& Purpose:
*& Alert channel EMAIL: sends the HTML body through BCS to the comma/semicolon
*& separated addresses in the destination. Thin wrapper over SAP standard -
*& covered by the QA1 integration test, not by ABAP Unit.
*& Modification log:
*& 2026-11-05 | Initial version (replaces ZCL_CD_OPS_ALERT_MAIL).
*& 2026-11-06 | BCS send result checked (audit A45).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert channel e-mail (BCS)</p>
CLASS zcl_cd_ops_chn_email DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_channel.

ENDCLASS.



CLASS zcl_cd_ops_chn_email IMPLEMENTATION.

  METHOD zif_cd_ops_alert_channel~deliver.
    DATA(lt_recipients) = zcl_cd_ops_util=>split_list( is_message-destination ).
    IF lt_recipients IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e021(zcd_ops) WITH is_message-rule_id.
    ENDIF.
    TRY.
        DATA(lo_request) = cl_bcs=>create_persistent( ).
        DATA(lo_document) = cl_document_bcs=>create_document(
          i_type    = 'HTM'
          i_text    = cl_document_bcs=>string_to_soli( is_message-html )
          i_subject = CONV so_obj_des( is_message-subject ) ).
        lo_request->set_document( lo_document ).
        LOOP AT lt_recipients ASSIGNING FIELD-SYMBOL(<lv_address>).
          lo_request->add_recipient(
            cl_cam_address_bcs=>create_internet_address( CONV ad_smtpadr( <lv_address> ) ) ).
        ENDLOOP.
        lo_request->set_send_immediately( abap_true ).
        " A45: the BCS send result decides - a refused request is not logged as sent
        IF lo_request->send( ) = abap_false.
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e026(zcd_ops) WITH is_message-rule_id.
        ENDIF.
        " BCS sends on commit; the alert is delivered independently of the run's LUW
        COMMIT WORK.
      CATCH cx_bcs INTO DATA(lx_bcs).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e020(zcd_ops) WITH is_message-rule_id
          EXPORTING
            previous = lx_bcs.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
