*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_exc_contract.clas.testclasses.abap
*& Purpose:
*& Tests of the exception contract helpers: the evidence key is stable
*& for the same identity and differs by company code; key values of an
*& evidence row join FIELD=value pairs (blank values left out) and come
*& back as the same pairs (ZCL_CA_OPS_EVIDENCE=>PAIRS); MISSING names every
*& gap of an empty finding and none of a complete one, and a finding whose
*& payments all have unknown amounts needs no currency. Pure. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
CLASS ltc_exc_contract DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS evidence_key_stable   FOR TESTING.
    METHODS link_value_round_trip FOR TESTING.
    METHODS gaps_of_empty         FOR TESTING.
    METHODS complete_has_no_gap   FOR TESTING.
    METHODS unknown_needs_no_cur  FOR TESTING.
ENDCLASS.


CLASS ltc_exc_contract IMPLEMENTATION.

  METHOD evidence_key_stable.
    DATA(lv_one) = zcl_ca_ops_exc_contract=>evidence_key( iv_area = 'ZT' iv_check_id = 'C1' iv_object_key = 'F1' iv_bukrs = '1000' ).
    DATA(lv_two) = zcl_ca_ops_exc_contract=>evidence_key( iv_area = 'ZT' iv_check_id = 'C1' iv_object_key = 'F1' iv_bukrs = '1000' ).
    DATA(lv_other) = zcl_ca_ops_exc_contract=>evidence_key( iv_area = 'ZT' iv_check_id = 'C1' iv_object_key = 'F1' iv_bukrs = '2000' ).
    cl_abap_unit_assert=>assert_not_initial( act = lv_one msg = 'A key' ).
    cl_abap_unit_assert=>assert_equals( act = lv_two exp = lv_one msg = 'Stable' ).
    cl_abap_unit_assert=>assert_differs( act = lv_other exp = lv_one msg = 'Company code is part of the identity' ).
  ENDMETHOD.


  METHOD link_value_round_trip.
    DATA(lv_value) = zcl_ca_ops_exc_contract=>link_value( VALUE #( ( fieldname = 'LAUFD' value = '20261116' )
                                                                   ( fieldname = 'LAUFI' value = 'ZT1' )
                                                                   ( fieldname = 'DOC1R' value = '' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 'LAUFD=20261116;LAUFI=ZT1' msg = 'Blank left out' ).
    DATA(lt_pairs) = zcl_ca_ops_evidence=>pairs( lv_value ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_pairs ) exp = 2 msg = 'Two pairs' ).
    cl_abap_unit_assert=>assert_equals( act = lt_pairs[ 2 ]-value exp = 'ZT1' msg = 'Value back' ).
  ENDMETHOD.


  METHOD gaps_of_empty.
    DATA(lt_gaps) = zcl_ca_ops_exc_contract=>missing( VALUE #( amount = '10.00' ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_gaps ) exp = 6 msg = 'Every gap' ).
  ENDMETHOD.


  METHOD complete_has_no_gap.
    DATA(lt_gaps) = zcl_ca_ops_exc_contract=>missing( VALUE #( item_count = 2 amount = '10.00' currency = 'USD'
                                                               deadline_at = '20261117100000.0000000' stage = 'RECEIPT'
                                                               resp_source = zif_ca_ops_exc_contract=>gc_resp_source-none
                                                               evid_key = 'K' ) ).
    cl_abap_unit_assert=>assert_initial( act = lt_gaps msg = 'No gap - an owner source N says none is configured' ).
  ENDMETHOD.


  METHOD unknown_needs_no_cur.
    DATA(lt_gaps) = zcl_ca_ops_exc_contract=>missing( VALUE #( item_count = 3 unknown_count = 3
                                                               deadline_at = '20261117100000.0000000' stage = 'RECEIPT'
                                                               resp_source = zif_ca_ops_exc_contract=>gc_resp_source-process
                                                               evid_key = 'K' ) ).
    cl_abap_unit_assert=>assert_initial( act = lt_gaps msg = 'Amounts not known: no currency to name' ).
  ENDMETHOD.

ENDCLASS.
