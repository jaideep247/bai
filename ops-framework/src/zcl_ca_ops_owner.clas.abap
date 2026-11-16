*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_owner.clas.abap
*& Purpose:
*& Responsible owner of a finding (ZIF_CA_OPS_OWNER): the active controls
*& that cover the area of the findings (ZCA_OPS_CTLCHK, ZCA_OPS_CONTROL)
*& and the business processes (ZCA_OPS_PROC) are read once per instance
*& and area; the control covering the check code wins over the one
*& covering the check ID (GROUP2) and the rule; of several controls the
*& lowest control ID. Without a control the process owner, without that
*& none (source N). Read only.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - responsible owner (configuration)</p>
CLASS zcl_ca_ops_owner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_owner.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cover,
        match_field TYPE c LENGTH 10,
        match_value TYPE c LENGTH 35,
        control_id  TYPE c LENGTH 20,
        owner       TYPE syuname,
        team        TYPE zif_ca_ops_exc_contract=>ty_team,
      END OF ty_cover.
    TYPES tt_cover TYPE SORTED TABLE OF ty_cover WITH NON-UNIQUE KEY match_field match_value control_id.
    TYPES:
      BEGIN OF ty_proc,
        process_id TYPE zif_ca_ops_chk_types=>ty_process_id,
        owner      TYPE syuname,
      END OF ty_proc.
    TYPES tt_proc TYPE SORTED TABLE OF ty_proc WITH UNIQUE KEY process_id.

    DATA mv_area TYPE zif_ca_ops_types=>ty_area.
    DATA mt_cover TYPE tt_cover.
    DATA mt_proc TYPE tt_proc.

    METHODS load
      IMPORTING
        iv_area TYPE zif_ca_ops_types=>ty_area.

    METHODS by_control
      IMPORTING
        iv_field        TYPE csequence
        iv_value        TYPE csequence
      RETURNING
        VALUE(rs_cover) TYPE ty_cover.

ENDCLASS.



CLASS zcl_ca_ops_owner IMPLEMENTATION.

  METHOD zif_ca_ops_owner~resolve.
    IF iv_area <> mv_area OR mv_area IS INITIAL.
      load( iv_area ).
    ENDIF.
    DATA(ls_cover) = by_control( iv_field = 'CHECK_CODE' iv_value = iv_check_code ).
    IF ls_cover IS INITIAL.
      ls_cover = by_control( iv_field = 'GROUP2' iv_value = iv_check_id ).
    ENDIF.
    IF ls_cover IS INITIAL AND iv_rule_id IS NOT INITIAL.
      ls_cover = by_control( iv_field = 'RULE_ID' iv_value = iv_rule_id ).
    ENDIF.
    IF ls_cover IS NOT INITIAL.
      rs_owner = VALUE #( user   = ls_cover-owner
                          team   = ls_cover-team
                          source = zif_ca_ops_exc_contract=>gc_resp_source-control
                          ref    = ls_cover-control_id ).
      RETURN.
    ENDIF.
    READ TABLE mt_proc WITH TABLE KEY process_id = iv_process_id ASSIGNING FIELD-SYMBOL(<ls_proc>).
    IF sy-subrc = 0 AND iv_process_id IS NOT INITIAL AND <ls_proc>-owner IS NOT INITIAL.
      rs_owner = VALUE #( user   = <ls_proc>-owner
                          source = zif_ca_ops_exc_contract=>gc_resp_source-process
                          ref    = iv_process_id ).
      RETURN.
    ENDIF.
    rs_owner-source = zif_ca_ops_exc_contract=>gc_resp_source-none.
  ENDMETHOD.


  METHOD load.
    mv_area = iv_area.
    SELECT chk~match_field, chk~match_value, chk~control_id, ctl~owner, ctl~team
      FROM zca_ops_ctlchk AS chk
      INNER JOIN zca_ops_control AS ctl ON  ctl~area       = chk~area
                                        AND ctl~control_id = chk~control_id
      WHERE chk~check_area = @iv_area
        AND ctl~active     = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @mt_cover.
    SELECT process_id, owner
      FROM zca_ops_proc
      WHERE area   = @iv_area
        AND active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @mt_proc.
  ENDMETHOD.


  METHOD by_control.
    " the lowest control ID of the matching rows (sorted key)
    LOOP AT mt_cover ASSIGNING FIELD-SYMBOL(<ls_cover>) WHERE match_field = iv_field AND match_value = iv_value.
      rs_cover = <ls_cover>.
      RETURN.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
