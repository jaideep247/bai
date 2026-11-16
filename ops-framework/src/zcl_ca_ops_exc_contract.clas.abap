*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_exc_contract.clas.abap
*& Purpose:
*& Helpers of the exception contract (ZIF_CA_OPS_EXC_CONTRACT,
*& docs/EXCEPTION_CONTRACT.md): the evidence key of a finding (SHA-1 of
*& area, check, object key and company code - the identity of an
*& exception, stable over the carry-forward), the key values of an
*& evidence row ("FIELD=value;..."), and MISSING - the contract gaps of a
*& finding (count, currency, deadline, owner, stage, evidence), used by
*& the tests of every adopting module and by its check to say what it
*& could not fill. Pure: no database, no state.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - exception contract helpers</p>
CLASS zcl_ca_ops_exc_contract DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Evidence key of a finding: SHA-1 of area, check ID, object key and company code
    CLASS-METHODS evidence_key
      IMPORTING
        iv_area       TYPE zif_ca_ops_types=>ty_area
        iv_check_id   TYPE clike
        iv_object_key TYPE clike
        iv_bukrs      TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_exc_contract=>ty_evid_key.

    "! Key values of an evidence row: FIELD=value pairs joined by GC_VALUE_SEPARATOR (blank values left out)
    CLASS-METHODS link_value
      IMPORTING
        it_pairs        TYPE zif_ca_ops_link_types=>tt_pair
      RETURNING
        VALUE(rv_value) TYPE zif_ca_ops_exc_contract=>ty_link_value.

    "! Contract gaps of a finding (GC_GAP): COUNT no item and no unknown item, CURRENCY an amount or items without
    "! currency, DEADLINE none, OWNER no source of the responsible owner, STAGE none, EVIDENCE no evidence key
    CLASS-METHODS missing
      IMPORTING
        is_finding     TYPE zif_ca_ops_types=>ty_finding
      RETURNING
        VALUE(rt_gaps) TYPE zif_ca_ops_exc_contract=>tt_gap.

ENDCLASS.



CLASS zcl_ca_ops_exc_contract IMPLEMENTATION.

  METHOD evidence_key.
    rv_key = zcl_ca_ops_cfg_version=>of_lines( VALUE #( ( |{ iv_area }\|{ iv_check_id }\|{ iv_object_key }\|{ iv_bukrs }| ) ) ).
  ENDMETHOD.


  METHOD link_value.
    DATA lt_parts TYPE string_table.
    LOOP AT it_pairs ASSIGNING FIELD-SYMBOL(<ls_pair>) WHERE value IS NOT INITIAL.
      INSERT |{ <ls_pair>-fieldname }={ condense( CONV string( <ls_pair>-value ) ) }| INTO TABLE lt_parts.
    ENDLOOP.
    rv_value = concat_lines_of( table = lt_parts sep = zif_ca_ops_exc_contract=>gc_value_separator ).
  ENDMETHOD.


  METHOD missing.
    IF is_finding-item_count <= 0 AND is_finding-unknown_count <= 0.
      INSERT zif_ca_ops_exc_contract=>gc_gap-count INTO TABLE rt_gaps.
    ENDIF.
    IF is_finding-currency IS INITIAL
       AND ( is_finding-amount <> 0 OR is_finding-dup_amount <> 0 OR is_finding-item_count > 0 ).
      INSERT zif_ca_ops_exc_contract=>gc_gap-currency INTO TABLE rt_gaps.
    ENDIF.
    IF is_finding-deadline_at IS INITIAL.
      INSERT zif_ca_ops_exc_contract=>gc_gap-deadline INTO TABLE rt_gaps.
    ENDIF.
    IF is_finding-resp_source IS INITIAL.
      INSERT zif_ca_ops_exc_contract=>gc_gap-owner INTO TABLE rt_gaps.
    ENDIF.
    IF is_finding-stage IS INITIAL.
      INSERT zif_ca_ops_exc_contract=>gc_gap-stage INTO TABLE rt_gaps.
    ENDIF.
    IF is_finding-evid_key IS INITIAL.
      INSERT zif_ca_ops_exc_contract=>gc_gap-evidence INTO TABLE rt_gaps.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
