*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_demo_dao.clas.abap
*& Purpose:
*& Job counts of the demo consumer ZCA_OPS_DEMO from TBTCO (SAP standard,
*& read only, COUNT only - no row is transferred): jobs of this client
*& (AUTHCKMAN) by status, by end time or by planned start time, between two
*& points in time given as server date and time. Writes nothing.
*& Modification log:
*& 2026-11-10 | Initial version (demo consumer of the operations framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework demo - job counts (TBTCO)</p>
CLASS zcl_ca_ops_demo_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_demo_dao.

ENDCLASS.



CLASS zcl_ca_ops_demo_dao IMPLEMENTATION.

  METHOD zif_ca_ops_demo_dao~count_ended.
    SELECT COUNT(*)
      FROM tbtco
      WHERE authckman = @sy-mandt
        AND status    = @iv_status
        AND ( enddate > @is_from-date OR ( enddate = @is_from-date AND endtime >= @is_from-time ) )
        AND ( enddate < @is_to-date OR ( enddate = @is_to-date AND endtime <= @is_to-time ) )
      INTO @rv_count.
  ENDMETHOD.


  METHOD zif_ca_ops_demo_dao~count_planned.
    SELECT COUNT(*)
      FROM tbtco
      WHERE authckman = @sy-mandt
        AND status    = @iv_status
        AND ( sdlstrtdt > @is_from-date OR ( sdlstrtdt = @is_from-date AND sdlstrttm >= @is_from-time ) )
        AND ( sdlstrtdt < @is_to-date OR ( sdlstrtdt = @is_to-date AND sdlstrttm <= @is_to-time ) )
      INTO @rv_count.
  ENDMETHOD.

ENDCLASS.
