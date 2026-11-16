*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ma_dao.clas.abap
*& Purpose:
*& Data access of the FI-CA mass activity check (ZIF_CA_OPS_MA_DAO): the
*& active mass activities of an area (ZCA_OPS_MAACT) and the dunning
*& notices per run and currency (FKKMAKO, count and SUM of the dunning
*& balance on the database, the window on the first key field LAUFD).
*& Only fields seen in the reference system's dictionary export of FKKMAKO
*& are read (house check ddic_fields). Read only; a failed read raises
*& message 521 with the database error as previous.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA mass activities - data access (SQL)</p>
CLASS zcl_ca_ops_ma_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_ma_dao.

  PRIVATE SECTION.
    "! Raise the read error of a source (message 521, the database error as previous)
    METHODS read_failed
      IMPORTING
        iv_source TYPE zif_ca_ops_types=>ty_reference
        ix_error  TYPE REF TO cx_root
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_ma_dao IMPLEMENTATION.

  METHOD zif_ca_ops_ma_dao~activities.
    TRY.
        SELECT area, act_id, description, aktyp, parent_program, job_pattern, output_kind, min_output, run_limit_min
          FROM zca_ops_maact
          WHERE area   = @iv_area
            AND active = @abap_true
          ORDER BY act_id
          INTO CORRESPONDING FIELDS OF TABLE @rt_activities.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_ma_types=>gc_source-activities ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_ma_dao~dunning_notices.
    " FKKMAKO key MANDT, LAUFD, LAUFI, GPART, VKONT, MAZAE: the window on the first key field
    TRY.
        SELECT laufd AS run_date, laufi AS run_id, waers AS currency, COUNT(*) AS item_count,
               SUM( msalm ) AS amount
          FROM fkkmako
          WHERE laufd BETWEEN @iv_from AND @iv_to
          GROUP BY laufd, laufi, waers
          ORDER BY run_date, run_id, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_ma_types=>gc_source-dunning ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD read_failed.
    RAISE EXCEPTION TYPE zcx_ca_ops_error
      MESSAGE e521(zca_ops) WITH iv_source
      EXPORTING
        previous = ix_error.
  ENDMETHOD.

ENDCLASS.
