*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_purge.clas.abap
*& Purpose:
*& Purge target BREAK of the clearing-account break analysis (registry row
*& of ZCA_OPS_PURGE, retention RETENTION_DAYS_BREAK): snapshots started
*& before the cutoff with their groups and lines (ZCA_OPS_BRKRUN, _BRKGRP,
*& _BRKITM), one package of snapshots at a time; the latest snapshot of an
*& account is never purged (the check and the list read it). No commit: the
*& purge commits per package.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - purge target break snapshots</p>
CLASS zcl_ca_ops_brk_purge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_target.

  PRIVATE SECTION.
    "! Snapshots started before the cutoff that a later snapshot of the same account replaced
    METHODS purgeable
      IMPORTING
        iv_cutoff           TYPE timestampl
        iv_max              TYPE i
      RETURNING
        VALUE(rt_snapshots) TYPE zif_ca_ops_brk_types=>tt_snapshot.

ENDCLASS.



CLASS zcl_ca_ops_brk_purge IMPLEMENTATION.

  METHOD zif_ca_ops_purge_target~count_purgeable.
    rv_count = lines( purgeable( iv_cutoff = iv_cutoff iv_max = 0 ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_purge_target~delete_package.
    CLEAR: ev_dependent, ev_history.
    DATA(lt_snapshots) = purgeable( iv_cutoff = iv_cutoff iv_max = iv_max ).
    LOOP AT lt_snapshots ASSIGNING FIELD-SYMBOL(<ls_snapshot>).
      DELETE FROM zca_ops_brkitm WHERE snap_id = @<ls_snapshot>-snap_id.
      ev_dependent += sy-dbcnt.
      DELETE FROM zca_ops_brkgrp WHERE snap_id = @<ls_snapshot>-snap_id.
      ev_dependent += sy-dbcnt.
      DELETE FROM zca_ops_brkrun WHERE snap_id = @<ls_snapshot>-snap_id.
      rv_count += sy-dbcnt.
    ENDLOOP.
  ENDMETHOD.


  METHOD purgeable.
    " a snapshot is purgeable only when a later one of the same account exists (the latest is always kept)
    SELECT old~snap_id, old~area, old~acct_id, old~started_at
      FROM zca_ops_brkrun AS old
      WHERE old~started_at < @iv_cutoff
        AND EXISTS ( SELECT snap_id FROM zca_ops_brkrun AS new
                       WHERE new~area       = old~area
                         AND new~acct_id    = old~acct_id
                         AND new~started_at > old~started_at )
      ORDER BY old~started_at, old~snap_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_snapshots.
    IF iv_max > 0 AND lines( rt_snapshots ) > iv_max.
      DELETE rt_snapshots FROM iv_max + 1.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
