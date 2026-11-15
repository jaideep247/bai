*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_dao.clas.abap
*& Purpose:
*& Data access of the account flow reconciliation: configuration reads
*& (ZCA_OPS_FLOW, _FLWACC, _FLWSTG, _FLWTIL, _FLWCTL,
*& _FLWRUL), the evaluation it
*& writes (ZCA_OPS_FLWEVL / _FLWEVI - the only class that writes them,
*& retention by key date) and the reads of the delivered sources: break
*& analysis snapshots and their explained groups (framework tables), open
*& FI-CA business partner items of a reconciliation account (DFKKOP - no
*& released view, documented clean-core exception) and open findings of
*& the checks of a stage (ZCA_OPS_FINDING). Every business read is
*& aggregated on the database; nothing of business data is changed.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - account flow data access</p>
"! The journal is not read here: movement, opening and closing positions are CDS over the released view
"! I_JournalEntryItem (docs/ACCOUNT_FLOW.md section 4). DFKKOP fields BUKRS, HKONT, WAERS, BETRW, BUDAT, AUGBL are
"! those the repository already reads; "open = no clearing document" is VERIFY-SE11 (V146), PlanViz FLOW-PV4.
CLASS zcl_ca_ops_flow_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_flow_dao.

ENDCLASS.



CLASS zcl_ca_ops_flow_dao IMPLEMENTATION.

  METHOD zif_ca_ops_flow_dao~get_flows.
    IF iv_flow_id IS INITIAL.
      SELECT area, flow_id, description, direction, jrnl_ledger, process_id, active
        FROM zca_ops_flow
        WHERE area   = @iv_area
          AND active = @abap_true
        ORDER BY flow_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_flows.
    ELSE.
      SELECT area, flow_id, description, direction, jrnl_ledger, process_id, active
        FROM zca_ops_flow
        WHERE area    = @iv_area
          AND flow_id = @iv_flow_id
          AND active  = @abap_true
        ORDER BY flow_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_flows.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~get_config.
    rs_config-flow = is_flow.
    SELECT area, flow_id, flow_acct, role, bukrs, currency, hkont_from, hkont_to, line_source, seq, eval_class,
           eval_category, description, active
      FROM zca_ops_flwacc
      WHERE area    = @is_flow-area
        AND flow_id = @is_flow-flow_id
        AND active  = @abap_true
      ORDER BY seq, flow_acct
      INTO CORRESPONDING FIELDS OF TABLE @rs_config-accounts.
    SELECT area, flow_id, stage_id, seq, description, expect_from, expect_to, active
      FROM zca_ops_flwstg
      WHERE area    = @is_flow-area
        AND flow_id = @is_flow-flow_id
        AND active  = @abap_true
      ORDER BY seq, stage_id
      INTO CORRESPONDING FIELDS OF TABLE @rs_config-stages.
    SELECT area, flow_id, tile, stage_id, role, side, description, active
      FROM zca_ops_flwtil
      WHERE area    = @is_flow-area
        AND flow_id = @is_flow-flow_id
        AND active  = @abap_true
      ORDER BY tile, stage_id, role
      INTO CORRESPONDING FIELDS OF TABLE @rs_config-tiles.
    SELECT area, flow_id, stage_id, check_area, check_id, description, active
      FROM zca_ops_flwctl
      WHERE area    = @is_flow-area
        AND flow_id = @is_flow-flow_id
        AND active  = @abap_true
      ORDER BY stage_id, check_area, check_id
      INTO CORRESPONDING FIELDS OF TABLE @rs_config-controls.
    SELECT area, flow_id, rule_seq, rule_id, stage_id, line_source, ref_type, doc_type, origin, main_trans,
           sub_trans, debit_credit, description, active
      FROM zca_ops_flwrul
      WHERE area    = @is_flow-area
        AND flow_id = @is_flow-flow_id
        AND active  = @abap_true
      ORDER BY rule_seq
      INTO CORRESPONDING FIELDS OF TABLE @rs_config-rules.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~save_evaluation.
    DATA lt_items TYPE STANDARD TABLE OF zca_ops_flwevi WITH EMPTY KEY.

    DATA(ls_header) = CORRESPONDING zca_ops_flwevl( is_eval ).
    INSERT zca_ops_flwevl FROM @ls_header.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_FLWEVL'.
    ENDIF.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      DATA(ls_item) = CORRESPONDING zca_ops_flwevi( <ls_item> ).
      ls_item-eval_id = is_eval-eval_id.
      INSERT ls_item INTO TABLE lt_items.
    ENDLOOP.
    IF lt_items IS NOT INITIAL.
      INSERT zca_ops_flwevi FROM TABLE @lt_items ACCEPTING DUPLICATE KEYS.
      IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_items ).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e010(zca_ops) WITH 'ZCA_OPS_FLWEVI'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~delete_evaluations.
    DATA lt_ids TYPE zif_ca_ops_flow_types=>tt_run_id.
    " index FLW (MANDT, AREA, FLOW_ID, KEY_DATE)
    SELECT eval_id
      FROM zca_ops_flwevl
      WHERE area     = @iv_area
        AND flow_id  = @iv_flow_id
        AND key_date < @iv_before
      INTO TABLE @lt_ids.
    LOOP AT lt_ids INTO DATA(lv_id).
      DELETE FROM zca_ops_flwevi WHERE eval_id = @lv_id.
      DELETE FROM zca_ops_flwevl WHERE eval_id = @lv_id.
      rv_count += sy-dbcnt.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~commit.
    COMMIT WORK.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~break_snapshots.
    DATA lt_runs TYPE zif_ca_ops_flow_types=>tt_break_snap.
    " index ACC (MANDT, AREA, ACCT_ID, KEY_DATE) is not usable without the area: the snapshot headers are few (one
    " per account and key date) - PlanViz FLOW-PV5
    SELECT snap_id, acct_id, hkont, key_date, status
      FROM zca_ops_brkrun
      WHERE bukrs    =  @iv_bukrs
        AND hkont    BETWEEN @iv_hkont_from AND @iv_hkont_to
        AND key_date BETWEEN @iv_from AND @iv_key_date
      ORDER BY acct_id, key_date DESCENDING, started_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_runs.
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      " the first row of an account is its latest snapshot of the window
      IF NOT line_exists( rt_snaps[ acct_id = <ls_run>-acct_id ] ).
        INSERT <ls_run> INTO TABLE rt_snaps.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~break_explained.
    DATA lt_ids TYPE SORTED TABLE OF zif_ca_ops_types=>ty_run_id WITH UNIQUE KEY table_line.
    IF it_snap_ids IS INITIAL.
      RETURN.
    ENDIF.
    lt_ids = VALUE #( FOR lv_id IN it_snap_ids ( lv_id ) ).
    SELECT grp~currency, SUM( grp~amount ) AS amount, COUNT( * ) AS item_count
      FROM zca_ops_brkgrp AS grp
      INNER JOIN @lt_ids AS ids ON ids~table_line = grp~snap_id
      WHERE grp~bucket <> @zif_ca_ops_brk_types=>gc_bucket_other
      GROUP BY grp~currency
      ORDER BY grp~currency
      INTO CORRESPONDING FIELDS OF TABLE @rt_sums.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~fica_open_items.
    " VERIFY-SE11 (V146): an item without clearing document (AUGBL) is open; amount BETRW in WAERS, signed as the
    " receivable (debit +). Aggregated on HANA - PlanViz FLOW-PV4 (company code + account range on DFKKOP)
    IF iv_currency IS INITIAL.
      SELECT waers AS currency, SUM( betrw ) AS amount, COUNT( * ) AS item_count
        FROM dfkkop
        WHERE bukrs = @iv_bukrs
          AND hkont BETWEEN @iv_hkont_from AND @iv_hkont_to
          AND budat <= @iv_key_date
          AND augbl =  @space
        GROUP BY waers
        ORDER BY waers
        INTO CORRESPONDING FIELDS OF TABLE @rt_sums.
    ELSE.
      SELECT waers AS currency, SUM( betrw ) AS amount, COUNT( * ) AS item_count
        FROM dfkkop
        WHERE bukrs = @iv_bukrs
          AND hkont BETWEEN @iv_hkont_from AND @iv_hkont_to
          AND waers = @iv_currency
          AND budat <= @iv_key_date
          AND augbl =  @space
        GROUP BY waers
        ORDER BY waers
        INTO CORRESPONDING FIELDS OF TABLE @rt_sums.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_flow_dao~open_findings.
    DATA lt_checks TYPE zif_ca_ops_flow_types=>tt_check_ref.
    IF it_checks IS INITIAL.
      RETURN.
    ENDIF.
    lt_checks = it_checks.
    " index OPN (MANDT, AREA, DISPOSITION, DUE_DATE): open (O) and assigned (A) exceptions of the checks
    IF iv_currency IS INITIAL.
      SELECT fnd~currency, SUM( fnd~amount ) AS amount, COUNT( * ) AS item_count
        FROM zca_ops_finding AS fnd
        INNER JOIN @lt_checks AS chk ON  chk~check_area = fnd~area
                                     AND chk~check_id   = fnd~group2
        WHERE fnd~bukrs = @iv_bukrs
          AND ( fnd~disposition = @zif_ca_ops_types=>gc_disposition-open
                OR fnd~disposition = @zif_ca_ops_types=>gc_disposition-assigned )
        GROUP BY fnd~currency
        ORDER BY fnd~currency
        INTO CORRESPONDING FIELDS OF TABLE @rt_sums.
    ELSE.
      SELECT fnd~currency, SUM( fnd~amount ) AS amount, COUNT( * ) AS item_count
        FROM zca_ops_finding AS fnd
        INNER JOIN @lt_checks AS chk ON  chk~check_area = fnd~area
                                     AND chk~check_id   = fnd~group2
        WHERE fnd~bukrs    = @iv_bukrs
          AND fnd~currency = @iv_currency
          AND ( fnd~disposition = @zif_ca_ops_types=>gc_disposition-open
                OR fnd~disposition = @zif_ca_ops_types=>gc_disposition-assigned )
        GROUP BY fnd~currency
        ORDER BY fnd~currency
        INTO CORRESPONDING FIELDS OF TABLE @rt_sums.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
