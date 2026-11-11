*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_dao.clas.abap
*& Purpose:
*& Data access of the clearing-account break analysis: configuration reads
*& (ZCA_OPS_BRKACC, _BRKBKT, _BRKRUL, _BRKCND), the journal reads of one
*& clearing account on ACDOCA (grouped by assignment and currency with
*& HAVING SUM <> 0 and a row cap - only the breaks come back; then the lines
*& of a package of assignments, IN list, windowed by posting date) and the
*& snapshot (ZCA_OPS_BRKRUN / _BRKGRP / _BRKITM) - the only class that
*& writes it. The journal is only read: no posting, no clearing.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - break analysis data access</p>
"! Released-view rule (D-C8): the journal reads stay on ACDOCA - grouping with HAVING and a row cap and an
"! assignment IN list on the busiest clearing account are the kind of statement whose plan through the
"! released view I_JournalEntryItem is unproven (LDG-PV7); PlanViz BRK-PV1 / BRK-PV2 decide (VERIFY V135).
CLASS zcl_ca_ops_brk_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_brk_dao.

ENDCLASS.



CLASS zcl_ca_ops_brk_dao IMPLEMENTATION.

  METHOD zif_ca_ops_brk_dao~get_accounts.
    IF iv_acct_id IS INITIAL.
      SELECT area, acct_id, bukrs, hkont, ledger, process_id, lookback_days, forward_days, max_groups,
             description, active
        FROM zca_ops_brkacc
        WHERE area   = @iv_area
          AND active = @abap_true
        ORDER BY acct_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_accounts.
    ELSE.
      SELECT area, acct_id, bukrs, hkont, ledger, process_id, lookback_days, forward_days, max_groups,
             description, active
        FROM zca_ops_brkacc
        WHERE area    = @iv_area
          AND acct_id = @iv_acct_id
          AND active  = @abap_true
        ORDER BY acct_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_accounts.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~get_buckets.
    SELECT bucket, description, explained, layer_id, seq, active
      FROM zca_ops_brkbkt
      ORDER BY bucket
      INTO CORRESPONDING FIELDS OF TABLE @rt_buckets.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~get_rules.
    SELECT area, rule_id, layer_id, seq, bucket, acct_pattern, reason, description, active
      FROM zca_ops_brkrul
      WHERE ( area = @iv_area OR area = @zif_ca_ops_brk_types=>gc_area_any )
        AND active = @abap_true
      ORDER BY seq, rule_id, area
      INTO CORRESPONDING FIELDS OF TABLE @rt_rules.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~get_conds.
    SELECT area, rule_id, cond_no, cond_kind, field, operator, cond_value, link_id, min_count
      FROM zca_ops_brkcnd
      WHERE area = @iv_area OR area = @zif_ca_ops_brk_types=>gc_area_any
      ORDER BY area, rule_id, cond_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_conds.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~open_groups.
    IF iv_max <= 0.
      RETURN.
    ENDIF.
    " A clearing account keeps every posting as an open item: a group of one assignment and currency that does not
    " net to zero is a break. Grouped and filtered on HANA - netting groups never leave the database; the cap bounds
    " memory (oldest first). Stays on the journal table (D-C8, LDG-PV7 reasoning, PlanViz BRK-PV1)
    SELECT zuonr AS assignment, rwcur AS currency, SUM( wsl ) AS amount, COUNT(*) AS line_count,
           MIN( budat ) AS first_date, MAX( budat ) AS last_date
      FROM acdoca
      WHERE rldnr  = @iv_ledger
        AND rbukrs = @is_account-bukrs
        AND racct  = @is_account-hkont
        AND budat BETWEEN @iv_from AND @iv_key_date
      GROUP BY zuonr, rwcur
      HAVING SUM( wsl ) <> 0
      ORDER BY first_date, assignment, currency
      INTO CORRESPONDING FIELDS OF TABLE @rt_sums
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~group_lines.
    IF it_assignments IS INITIAL OR iv_max <= 0.
      RETURN.
    ENDIF.
    " The lines of a package of break groups only (assignment IN list of the package, PlanViz BRK-PV2): the lines up
    " to the key date and those of the forward window that may bring a group to zero
    SELECT rldnr AS ledger, rbukrs AS bukrs, gjahr, belnr, docln, racct AS hkont, zuonr AS assignment,
           rwcur AS currency, wsl AS amount, budat AS posting_date, bldat AS document_date, blart AS doc_type,
           drcrk AS debit_credit, awtyp AS ref_type, awref, aworg
      FROM acdoca
      WHERE rldnr  = @iv_ledger
        AND rbukrs = @is_account-bukrs
        AND racct  = @is_account-hkont
        AND budat BETWEEN @iv_from AND @iv_to
        AND zuonr IN @it_assignments
      ORDER BY zuonr, budat, belnr, docln
      INTO TABLE @DATA(lt_lines)
      UP TO @iv_max ROWS.
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      INSERT VALUE #( ledger        = <ls_line>-ledger
                      bukrs         = <ls_line>-bukrs
                      gjahr         = <ls_line>-gjahr
                      belnr         = <ls_line>-belnr
                      docln         = <ls_line>-docln
                      hkont         = <ls_line>-hkont
                      assignment    = <ls_line>-assignment
                      currency      = <ls_line>-currency
                      amount        = <ls_line>-amount
                      posting_date  = <ls_line>-posting_date
                      document_date = <ls_line>-document_date
                      doc_type      = <ls_line>-doc_type
                      debit_credit  = <ls_line>-debit_credit
                      ref_type      = <ls_line>-ref_type
                      recon_key     = condense( |{ <ls_line>-awref }{ <ls_line>-aworg }| )
                      later         = xsdbool( <ls_line>-posting_date > iv_key_date ) ) INTO TABLE rt_items.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~save_snapshot.
    DATA lt_groups TYPE STANDARD TABLE OF zca_ops_brkgrp WITH EMPTY KEY.
    DATA lt_items TYPE STANDARD TABLE OF zca_ops_brkitm WITH EMPTY KEY.
    DATA ls_header TYPE zca_ops_brkrun.

    ls_header = CORRESPONDING #( is_snapshot ).
    INSERT zca_ops_brkrun FROM @ls_header.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_BRKRUN'.
    ENDIF.
    LOOP AT it_groups ASSIGNING FIELD-SYMBOL(<ls_group>).
      DATA(ls_group) = CORRESPONDING zca_ops_brkgrp( <ls_group> ).
      ls_group-snap_id = is_snapshot-snap_id.
      INSERT ls_group INTO TABLE lt_groups.
    ENDLOOP.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      DATA(ls_item) = CORRESPONDING zca_ops_brkitm( <ls_item>-item ).
      ls_item-snap_id     = is_snapshot-snap_id.
      ls_item-group_no    = <ls_item>-group_no.
      ls_item-item_no     = <ls_item>-item_no.
      ls_item-bucket      = <ls_item>-bucket.
      ls_item-rule_id     = <ls_item>-rule_id.
      ls_item-link_object = <ls_item>-link_object.
      ls_item-link_key    = <ls_item>-link_key.
      ls_item-link_value  = <ls_item>-link_value.
      INSERT ls_item INTO TABLE lt_items.
    ENDLOOP.
    IF lt_groups IS NOT INITIAL.
      INSERT zca_ops_brkgrp FROM TABLE @lt_groups ACCEPTING DUPLICATE KEYS.
      IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_groups ).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e010(zca_ops) WITH 'ZCA_OPS_BRKGRP'.
      ENDIF.
    ENDIF.
    IF lt_items IS NOT INITIAL.
      INSERT zca_ops_brkitm FROM TABLE @lt_items ACCEPTING DUPLICATE KEYS.
      IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_items ).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e010(zca_ops) WITH 'ZCA_OPS_BRKITM'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~latest_snapshot.
    DATA lt_latest TYPE zif_ca_ops_brk_types=>tt_snapshot.
    " index ACC (MANDT, AREA, ACCT_ID, KEY_DATE)
    SELECT snap_id, area, acct_id, bukrs, hkont, ledger, key_date, from_date, to_date, status, cfg_version,
           group_count, item_count, other_count, started_at, ended_at, created_by, message
      FROM zca_ops_brkrun
      WHERE area    = @iv_area
        AND acct_id = @iv_acct_id
      ORDER BY key_date DESCENDING, started_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_latest
      UP TO 1 ROWS.
    IF lt_latest IS NOT INITIAL.
      rs_snapshot = lt_latest[ 1 ].
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~open_breaks.
    IF iv_max <= 0.
      RETURN.
    ENDIF.
    SELECT snap_id, group_no, assignment, currency, amount, first_date, age_days, line_count
      FROM zca_ops_brkgrp
      WHERE snap_id  = @iv_snap_id
        AND bucket   = @zif_ca_ops_brk_types=>gc_bucket_other
        AND age_days >= @iv_min_age
      ORDER BY age_days DESCENDING, group_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_breaks
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~count_open_breaks.
    SELECT COUNT(*)
      FROM zca_ops_brkgrp
      WHERE snap_id  = @iv_snap_id
        AND bucket   = @zif_ca_ops_brk_types=>gc_bucket_other
        AND age_days >= @iv_min_age
      INTO @rv_count.
  ENDMETHOD.


  METHOD zif_ca_ops_brk_dao~commit.
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
