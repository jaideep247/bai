*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_ticket_log.clas.testclasses.abap
*& Purpose:
*& Tests of the delivered ticket sink: it logs only - status L, reference
*& LOGGED and the text a ticketing system would have received (389);
*& nothing is called, nothing is written. Does not prove live SAP
*& runtime behavior.
*& Build Q: the ticket of a file carries the file's own company code and
*& nothing of its payments (ZCL_CA_OPS_PF_INGEST=>TICKET_OF).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*& 2026-11-16 | Company code of the ticket (build Q).
*&---------------------------------------------------------------------*
CLASS ltc_pf_ticket_log DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS logs_only FOR TESTING.
    METHODS ticket_has_file_company FOR TESTING.
ENDCLASS.


CLASS ltc_pf_ticket_log IMPLEMENTATION.

  METHOD logs_only.
    DATA(ls_result) = NEW zcl_ca_ops_pf_ticket_log( )->zif_ca_ops_pf_ticket_sink~raise_ticket(
                        VALUE #( native_key = 'F1' milestone = zif_ca_ops_pf_types=>gc_milestone-accepted overdue = 60 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status exp = zif_ca_ops_pf_types=>gc_ticket-logged msg = 'Logged only' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-ref exp = zif_ca_ops_pf_types=>gc_ticket_logged msg = 'LOGGED' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_result-text msg = 'The text' ).
  ENDMETHOD.


  " Rule (build Q): a ticket link carries only the company code of the file it is about
  METHOD ticket_has_file_company.
    CONSTANTS lc_company TYPE bukrs VALUE 'ZT01'.
    DATA(ls_ticket) = zcl_ca_ops_pf_ingest=>ticket_of(
                        iv_area      = 'ZT_OPS_A'
                        iv_file_type = 'ACH'
                        is_file      = VALUE #( native_key = 'F1' bukrs = lc_company overdue_min = 30
                                                next_ms = zif_ca_ops_pf_types=>gc_milestone-accepted ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_ticket-company_code exp = lc_company msg = 'The file company code' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ticket-overdue exp = 30 msg = 'Minutes overdue' ).
    cl_abap_unit_assert=>assert_equals( act = ls_ticket-milestone exp = zif_ca_ops_pf_types=>gc_milestone-accepted
                                        msg = 'The milestone it waits for' ).
  ENDMETHOD.

ENDCLASS.
