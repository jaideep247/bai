*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_mem.clas.abap
*& Purpose:
*& In-memory mappings (test double of ZIF_CD_OPS_POSTAREA_DAO and of
*& ZIF_CD_OPS_PAMAP_DAO): the unit tests of the reader and of every consumer
*& add FQC0 entries of a posting area (ADD) or rows of a version of a typed
*& table (ADD_TYPED) as they would be maintained (keys and results as
*& '/'-separated texts) and inject it with ZCL_CD_OPS_POSTAREA_INJECTOR=>
*& INJECT_DAO, so the real reader (cache, source, version, FQC0 precedence,
*& parameters) runs. Counts the reads of both sources (one read per purpose
*& and run); rows inserted by the migration are kept as typed rows.
*& Production-safe: no database.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*& 2026-11-15 | Typed product mapping tables (ADD_TYPED, versions, INSERT_ENTRIES), reads per source.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: in memory</p>
CLASS zcl_cd_ops_postarea_mem DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_postarea_dao.
    INTERFACES zif_cd_ops_pamap_dao.

    "! Mapping version of a row added without one (the delivered active version)
    CONSTANTS gc_first_version TYPE zif_cd_ops_postarea_types=>ty_version VALUE '0001'.

    "! Adds an entry: key values and result values separated by '/' (FQC0 columns from the
    "! left; an empty position is a blank value, '*' the generic value)
    METHODS add
      IMPORTING
        iv_area    TYPE zif_cd_ops_postarea_types=>ty_area
        iv_keys    TYPE string
        iv_results TYPE string OPTIONAL.

    "! Adds a row of a typed table: the purpose, the mapping version (default 1), key values and
    "! result values separated by '/' in column order
    METHODS add_typed
      IMPORTING
        iv_purpose TYPE zif_cd_ops_postarea_types=>ty_purpose
        iv_keys    TYPE string
        iv_results TYPE string OPTIONAL
        iv_version TYPE zif_cd_ops_postarea_types=>ty_version DEFAULT gc_first_version.

    "! Number of reads of the typed tables so far (all purposes)
    METHODS typed_reads
      RETURNING
        VALUE(rv_reads) TYPE i.

    "! Number of reads of the posting areas so far (all areas)
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

    TYPES:
      BEGIN OF ty_typed,
        purpose TYPE zif_cd_ops_postarea_types=>ty_purpose,
        version TYPE zif_cd_ops_postarea_types=>ty_version,
        entry   TYPE zif_cd_ops_postarea_types=>ty_entry,
      END OF ty_typed.

    DATA mt_stored TYPE STANDARD TABLE OF ty_stored WITH EMPTY KEY.
    DATA mt_typed  TYPE STANDARD TABLE OF ty_typed WITH EMPTY KEY.
    DATA mv_reads  TYPE i.
    DATA mv_typed_reads TYPE i.
    DATA ms_last   TYPE zif_cd_ops_postarea_types=>ty_keys.

    "! Entry from '/'-separated key and result texts (FQC0 / column order)
    CLASS-METHODS entry
      IMPORTING
        iv_keys         TYPE string
        iv_results      TYPE string
      RETURNING
        VALUE(rs_entry) TYPE zif_cd_ops_postarea_types=>ty_entry.

ENDCLASS.



CLASS zcl_cd_ops_postarea_mem IMPLEMENTATION.

  METHOD add.
    INSERT VALUE #( area = iv_area entry = entry( iv_keys = iv_keys iv_results = iv_results ) ) INTO TABLE mt_stored.
  ENDMETHOD.


  METHOD add_typed.
    INSERT VALUE #( purpose = iv_purpose
                    version = iv_version
                    entry   = entry( iv_keys = iv_keys iv_results = iv_results ) ) INTO TABLE mt_typed.
  ENDMETHOD.


  METHOD entry.
    DATA lt_keys    TYPE string_table.
    DATA lt_results TYPE string_table.

    SPLIT iv_keys AT zif_cd_ops_postarea_types=>gc_key_separator INTO TABLE lt_keys.
    SPLIT iv_results AT zif_cd_ops_postarea_types=>gc_key_separator INTO TABLE lt_results.
    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<lv_key>).
      ASSIGN COMPONENT sy-tabix OF STRUCTURE rs_entry TO FIELD-SYMBOL(<lv_target>).
      IF sy-subrc = 0.
        <lv_target> = <lv_key>.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_results ASSIGNING FIELD-SYMBOL(<lv_result>).
      ASSIGN COMPONENT zif_cd_ops_postarea_types=>gc_key_count + sy-tabix
        OF STRUCTURE rs_entry TO FIELD-SYMBOL(<lv_fun>).
      IF sy-subrc = 0.
        <lv_fun> = <lv_result>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD typed_reads.
    rv_reads = mv_typed_reads.
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


  METHOD zif_cd_ops_pamap_dao~read_entries.
    mv_typed_reads += 1.
    LOOP AT mt_typed ASSIGNING FIELD-SYMBOL(<ls_typed>) WHERE purpose = iv_purpose AND version = iv_version.
      INSERT <ls_typed>-entry INTO TABLE rt_entries.
    ENDLOOP.
    SORT rt_entries BY key01 key02 key03 key04 key05 key06 key07 key08.
  ENDMETHOD.


  METHOD zif_cd_ops_pamap_dao~insert_entries.
    LOOP AT it_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      INSERT VALUE #( purpose = iv_purpose version = iv_version entry = <ls_entry> ) INTO TABLE mt_typed.
    ENDLOOP.
    rr_rows = NEW zif_cd_ops_postarea_types=>tt_entry( it_entries ).
  ENDMETHOD.

ENDCLASS.
