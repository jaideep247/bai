*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_mem.clas.abap
*& Purpose:
*& In-memory posting areas (test double of ZIF_CD_OPS_POSTAREA_DAO): the
*& unit tests of the reader and of every consumer add FQC0 entries as they
*& would be maintained (keys and results as '/'-separated texts) and inject
*& it with ZCL_CD_OPS_POSTAREA_INJECTOR=>INJECT_DAO, so the real reader
*& (cache, FQC0 precedence, parameters) runs. Counts the reads (one read
*& per area and run). Production-safe: no database.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: in memory</p>
CLASS zcl_cd_ops_postarea_mem DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_postarea_dao.

    "! Adds an entry: key values and result values separated by '/' (FQC0 columns from the
    "! left; an empty position is a blank value, '*' the generic value)
    METHODS add
      IMPORTING
        iv_area    TYPE zif_cd_ops_postarea_types=>ty_area
        iv_keys    TYPE string
        iv_results TYPE string OPTIONAL.

    "! Number of reads so far (all areas)
    METHODS reads
      RETURNING
        VALUE(rv_reads) TYPE i.

    "! Application area and chart of accounts of the last read
    METHODS last_read
      RETURNING
        VALUE(rs_read) TYPE zif_cd_ops_postarea_types=>ty_keys.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_stored,
        area  TYPE zif_cd_ops_postarea_types=>ty_area,
        entry TYPE zif_cd_ops_postarea_types=>ty_entry,
      END OF ty_stored.

    DATA mt_stored TYPE STANDARD TABLE OF ty_stored WITH EMPTY KEY.
    DATA mv_reads  TYPE i.
    DATA ms_last   TYPE zif_cd_ops_postarea_types=>ty_keys.

ENDCLASS.



CLASS zcl_cd_ops_postarea_mem IMPLEMENTATION.

  METHOD add.
    DATA lt_keys    TYPE string_table.
    DATA lt_results TYPE string_table.
    DATA ls_stored  TYPE ty_stored.

    ls_stored-area = iv_area.
    SPLIT iv_keys AT zif_cd_ops_postarea_types=>gc_key_separator INTO TABLE lt_keys.
    SPLIT iv_results AT zif_cd_ops_postarea_types=>gc_key_separator INTO TABLE lt_results.
    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<lv_key>).
      ASSIGN COMPONENT sy-tabix OF STRUCTURE ls_stored-entry TO FIELD-SYMBOL(<lv_target>).
      IF sy-subrc = 0.
        <lv_target> = <lv_key>.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_results ASSIGNING FIELD-SYMBOL(<lv_result>).
      ASSIGN COMPONENT zif_cd_ops_postarea_types=>gc_key_count + sy-tabix
        OF STRUCTURE ls_stored-entry TO FIELD-SYMBOL(<lv_fun>).
      IF sy-subrc = 0.
        <lv_fun> = <lv_result>.
      ENDIF.
    ENDLOOP.
    INSERT ls_stored INTO TABLE mt_stored.
  ENDMETHOD.


  METHOD reads.
    rv_reads = mv_reads.
  ENDMETHOD.


  METHOD last_read.
    rs_read = ms_last.
  ENDMETHOD.


  METHOD zif_cd_ops_postarea_dao~read_entries.
    mv_reads += 1.
    ms_last-key01 = iv_applk.
    ms_last-key02 = iv_ktopl.
    LOOP AT mt_stored ASSIGNING FIELD-SYMBOL(<ls_stored>) WHERE area = iv_area.
      INSERT <ls_stored>-entry INTO TABLE rt_entries.
    ENDLOOP.
    SORT rt_entries BY key01 key02 key03 key04 key05 key06 key07 key08.
  ENDMETHOD.

ENDCLASS.
