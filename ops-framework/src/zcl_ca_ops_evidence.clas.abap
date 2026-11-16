*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_evidence.clas.abap
*& Purpose:
*& Evidence of findings (ZIF_CA_OPS_EVIDENCE, exception contract): the
*& only writer of ZCA_OPS_FNDEVI. SAVE replaces the rows of every evidence
*& key it is given (a finding raised again shows the evidence of its
*& latest run, never a mix), numbering rows without a sequence in the
*& order given; READ returns a finding's rows; WALKER_REQUEST turns an
*& evidence row into the start of the link registry walker (its link
*& object and the "FIELD=value;..." key values). No commit: the runner's
*& unit of work.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - evidence of findings (DB)</p>
CLASS zcl_ca_ops_evidence DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_evidence.

    "! The key values of an evidence row as pairs (FIELD=value separated by GC_VALUE_SEPARATOR)
    CLASS-METHODS pairs
      IMPORTING
        iv_link_value   TYPE zif_ca_ops_exc_contract=>ty_link_value
      RETURNING
        VALUE(rt_pairs) TYPE zif_ca_ops_link_types=>tt_pair.

ENDCLASS.



CLASS zcl_ca_ops_evidence IMPLEMENTATION.

  METHOD zif_ca_ops_evidence~save.
    DATA lt_db TYPE STANDARD TABLE OF zca_ops_fndevi WITH EMPTY KEY.
    DATA lt_keys TYPE RANGE OF zif_ca_ops_exc_contract=>ty_evid_key.
    DATA lv_seq TYPE i.
    DATA lv_last TYPE zif_ca_ops_exc_contract=>ty_evid_key.

    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    LOOP AT it_evidence ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE evid_key IS NOT INITIAL.
      IF NOT line_exists( lt_keys[ low = <ls_row>-evid_key ] ).
        INSERT VALUE #( sign = 'I' option = 'EQ' low = <ls_row>-evid_key ) INTO TABLE lt_keys.
      ENDIF.
      IF <ls_row>-evid_key <> lv_last.
        lv_last = <ls_row>-evid_key.
        lv_seq = 0.
      ENDIF.
      lv_seq += 1.
      INSERT VALUE #( area        = iv_area
                      evid_key    = <ls_row>-evid_key
                      seq         = COND #( WHEN <ls_row>-seq > 0 THEN <ls_row>-seq ELSE lv_seq )
                      kind        = <ls_row>-kind
                      ev_type     = <ls_row>-ev_type
                      label       = <ls_row>-label
                      native_key  = <ls_row>-native_key
                      link_object = <ls_row>-link_object
                      link_value  = <ls_row>-link_value
                      occurred_at = <ls_row>-occurred_at
                      observed_at = <ls_row>-observed_at
                      quality     = <ls_row>-quality
                      source_id   = <ls_row>-source_id
                      run_id      = iv_run_id
                      created_at  = lv_now ) INTO TABLE lt_db.
    ENDLOOP.
    IF lt_db IS INITIAL.
      RETURN.
    ENDIF.
    DELETE FROM zca_ops_fndevi WHERE area = @iv_area AND evid_key IN @lt_keys.
    " a key given twice in the input keeps its first row of a sequence
    SORT lt_db BY evid_key seq.
    DELETE ADJACENT DUPLICATES FROM lt_db COMPARING evid_key seq.
    INSERT zca_ops_fndevi FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_db ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_FNDEVI'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_evidence~read.
    SELECT evid_key, seq, kind, ev_type, label, native_key, link_object, link_value, occurred_at, observed_at,
           quality, source_id
      FROM zca_ops_fndevi
      WHERE area     = @iv_area
        AND evid_key = @iv_evid_key
      ORDER BY seq
      INTO CORRESPONDING FIELDS OF TABLE @rt_evidence.
  ENDMETHOD.


  METHOD zif_ca_ops_evidence~walker_request.
    rs_request = VALUE #( area      = iv_area
                          object_id = is_evidence-link_object
                          keys      = pairs( is_evidence-link_value ) ).
    IF rs_request-object_id IS INITIAL OR rs_request-keys IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e377(zca_ops) WITH is_evidence-evid_key is_evidence-seq.
    ENDIF.
  ENDMETHOD.


  METHOD pairs.
    SPLIT iv_link_value AT zif_ca_ops_exc_contract=>gc_value_separator INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      SPLIT <lv_part> AT '=' INTO DATA(lv_field) DATA(lv_value).
      lv_field = to_upper( condense( lv_field ) ).
      IF lv_field IS NOT INITIAL AND lv_value IS NOT INITIAL.
        INSERT VALUE #( fieldname = lv_field value = lv_value ) INTO TABLE rt_pairs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
