*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_ticket_log.clas.testclasses.abap
*& Purpose:
*& Tests of the delivered ticket sink: it logs only - status L, reference
*& LOGGED and the text a ticketing system would have received (389);
*& nothing is called, nothing is written. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
CLASS ltc_pf_ticket_log DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS logs_only FOR TESTING.
ENDCLASS.


CLASS ltc_pf_ticket_log IMPLEMENTATION.

  METHOD logs_only.
    DATA(ls_result) = NEW zcl_ca_ops_pf_ticket_log( )->zif_ca_ops_pf_ticket_sink~raise_ticket(
                        VALUE #( native_key = 'F1' milestone = zif_ca_ops_pf_types=>gc_milestone-accepted overdue = 60 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status exp = zif_ca_ops_pf_types=>gc_ticket-logged msg = 'Logged only' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-ref exp = zif_ca_ops_pf_types=>gc_ticket_logged msg = 'LOGGED' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_result-text msg = 'The text' ).
  ENDMETHOD.

ENDCLASS.
