*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_adapter_prism.clas.abap
*& Purpose:
*& Source adapter of ZCD_FMON_PRISM (PRISM status API) for the ZCD_FMON_SRC
*& row with ADAPTER_CLASS = ZCL_CD_FMON_ADAPTER_PRISM. The 5-minute run reads
*& only events no instant unit applied (safety net); the unit converts its one
*& event. Rows become status records with the configured field names and the
*& generic adapter's rules (file key, digest, business date, stage map).
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, instant bgPF processing).
*& 2026-11-08 | Table consolidation: approved tables read from ZCD_OPS_TABWL (area FMON, purpose SOURCE; was
*&            | ZCD_FMON_TABWL).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - source adapter for PRISM status events</p>
"! Differences to ZCL_CD_FMON_ADAPTER_GENERIC (deliberate, documented in FMON_FILE_MONITORING.md):
"! <ul><li>reads the suite's own table through ZIF_CD_FMON_PRISM_DAO (no dynamic SQL, no
"! ZCD_OPS_TABWL / S_TABU_NAM needed), window on RECEIVED_AT, PROCESSED_AT initial only;</li>
"! <li>an interfaceId sent by PRISM selects the interface; without it the name pattern decides.</li></ul>
CLASS zcl_cd_fmon_adapter_prism DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_adapter.

    "! Stored events -> status records (pure apart from the configuration check)
    "! @raising zcx_cd_ops_error | a required role is not configured (204) or a configured
    "!                             field is not a column of ZCD_FMON_PRISM (201)
    CLASS-METHODS to_records
      IMPORTING
        is_request        TYPE zif_cd_fmon_types=>ty_read_request
        it_rows           TYPE zif_cd_fmon_prism_types=>tt_row
      RETURNING
        VALUE(rt_records) TYPE zif_cd_fmon_types=>tt_src_record
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    CONSTANTS gc_table TYPE zif_cd_fmon_types=>ty_tabname VALUE 'ZCD_FMON_PRISM'.

    "! Value of a configured column of the row as text (blank field name = no value)
    CLASS-METHODS column
      IMPORTING
        is_row          TYPE zif_cd_fmon_prism_types=>ty_row
        iv_field        TYPE zif_cd_fmon_types=>ty_fieldname
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS zcl_cd_fmon_adapter_prism IMPLEMENTATION.

  METHOD zif_cd_fmon_adapter~read.
    DATA lv_from TYPE timestampl.
    DATA lv_to TYPE timestampl.
    " Same half-open window as the generic adapter (audit A52), on the time SAP received the call:
    " an event that arrives late is still read once it is in SAP
    CONVERT DATE is_request-date_from TIME zif_cd_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_from TIME ZONE is_request-time_zone.
    CONVERT DATE is_request-date_to + 1 TIME zif_cd_ops_types=>gc_time-day_start
      INTO TIME STAMP lv_to TIME ZONE is_request-time_zone.
    rt_records = to_records( is_request = is_request
                             it_rows    = zcl_cd_fmon_factory=>get_prism_dao( )->read_unprocessed(
                                            iv_from     = lv_from
                                            iv_to       = lv_to
                                            iv_max_rows = is_request-max_rows ) ).
  ENDMETHOD.


  METHOD to_records.
    DATA ls_raw TYPE zif_cd_fmon_types=>ty_raw_row.

    " Same configuration rules as the generic adapter (file, date and status roles required)
    zcl_cd_fmon_adapter_generic=>build_query( is_request ).
    DATA(ls_src) = is_request-src.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      CLEAR ls_raw.
      ls_raw-file_key  = column( is_row = <ls_row> iv_field = ls_src-file_key_field ).
      ls_raw-file_name = column( is_row = <ls_row> iv_field = ls_src-file_name_field ).
      ls_raw-ev_date   = column( is_row = <ls_row> iv_field = ls_src-date_field ).
      ls_raw-ev_time   = column( is_row = <ls_row> iv_field = ls_src-time_field ).
      ls_raw-ev_ts     = column( is_row = <ls_row> iv_field = ls_src-ts_field ).
      ls_raw-status    = column( is_row = <ls_row> iv_field = ls_src-status_field ).
      ls_raw-rec_count = column( is_row = <ls_row> iv_field = ls_src-count_field ).
      ls_raw-amount    = column( is_row = <ls_row> iv_field = ls_src-amount_field ).
      ls_raw-size      = column( is_row = <ls_row> iv_field = ls_src-size_field ).
      ls_raw-checksum  = column( is_row = <ls_row> iv_field = ls_src-checksum_field ).
      ls_raw-source    = column( is_row = <ls_row> iv_field = ls_src-source_field ).
      ls_raw-lob       = column( is_row = <ls_row> iv_field = ls_src-lob_field ).
      ls_raw-item_key  = column( is_row = <ls_row> iv_field = ls_src-item_key_field ).
      DATA(ls_record) = zcl_cd_fmon_adapter_generic=>to_record( is_request = is_request
                                                                is_raw     = ls_raw ).
      " The interface PRISM names wins over the name pattern (unknown / inactive = UNMAPPED_FILE)
      IF <ls_row>-iface_id IS NOT INITIAL.
        ls_record-iface_id = <ls_row>-iface_id.
      ENDIF.
      IF ls_record-file_ref IS NOT INITIAL.
        INSERT ls_record INTO TABLE rt_records.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD column.
    IF iv_field IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_field) = to_upper( condense( iv_field ) ).
    ASSIGN COMPONENT lv_field OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_value>).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e201(zcd_ops) WITH lv_field gc_table.
    ENDIF.
    rv_value = |{ <lv_value> }|.
  ENDMETHOD.

ENDCLASS.
