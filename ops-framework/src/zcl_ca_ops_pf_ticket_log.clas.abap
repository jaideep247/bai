*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_ticket_log.clas.abap
*& Purpose:
*& Delivered ticket sink of the payment file lifecycle
*& (ZIF_CA_OPS_PF_TICKET_SINK, role TICKET): log only. It raises no
*& ticket anywhere - no outbound HTTP, no incident in SAP, no application
*& log - and answers status L with the reference LOGGED and the text that
*& a site's ticketing would have received (message 389); the engine
*& keeps the reference on the file so a file is handed over once. A site
*& that wants real tickets plugs its own sink class.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file ticket sink (log only)</p>
CLASS zcl_ca_ops_pf_ticket_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_ticket_sink.

ENDCLASS.



CLASS zcl_ca_ops_pf_ticket_log IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting: nothing leaves the system
  ENDMETHOD.


  METHOD zif_ca_ops_pf_ticket_sink~raise_ticket.
    rs_result = VALUE #( status = zif_ca_ops_pf_types=>gc_ticket-logged
                         ref    = zif_ca_ops_pf_types=>gc_ticket_logged
                         text   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_pf_types=>gc_msg-ticket_logged
                                                         iv_v1    = is_ticket-native_key
                                                         iv_v2    = is_ticket-milestone ) ).
  ENDMETHOD.

ENDCLASS.
