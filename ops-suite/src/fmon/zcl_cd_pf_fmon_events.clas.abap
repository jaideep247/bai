*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_pf_fmon_events.clas.abap
*& Purpose:
*& Event source of the framework's payment file lifecycle over the suite's
*& file monitoring (roles TRANSFER and ACK: ZIF_CA_OPS_PF_TRANSFER_SRC,
*& ZIF_CA_OPS_PF_ACK_SRC): the audit trail of the outbound files of the
*& interfaces of the setting (ZCD_FMON_EVENT through ZIF_CD_FMON_DAO=>
*& GET_EVAL_FILES / GET_EVENTS - no SQL of its own on FMON's tables), each
*& event in the window one record: native status = the FMON stage
*& (GENERATED_IN_SAP, SENT_TO_PRISM, PRISM_RECEIVED, PRISM_DELIVERED,
*& PRISM_FAILED, FORWARDED_TO_BANK, ACK_RECEIVED, NACK_REJECTED - the
*& overlay's status mapping says which milestone each evidences, V183),
*& record ID = FMON file ID / event number, version 1, the file by its FMON
*& reference, the count the event carries (its amount has no currency in
*& FMON and is left out: never an amount without currency). Setting:
*& IFACES=<interface IDs> (required); STAGES=<stages> (optional: only
*& these stages). FMON keeps its own status model; this class reads it.
*& Read only; delivered inactive (docs/Payment_File_Overlay.md).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle, first customer's overlay).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - payment file events over file monitoring</p>
CLASS zcl_cd_pf_fmon_events DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_transfer_src.
    INTERFACES zif_ca_ops_pf_ack_src.

    "! The records of FMON events in the window (public for the tests)
    METHODS to_events
      IMPORTING
        it_files         TYPE zif_cd_fmon_types=>tt_file
        it_events        TYPE zif_cd_fmon_types=>tt_event
        iv_from          TYPE timestampl
        iv_to            TYPE timestampl
      RETURNING
        VALUE(rt_events) TYPE zif_ca_ops_pf_types=>tt_src_event.

  PRIVATE SECTION.
    DATA mt_ifaces TYPE RANGE OF zif_cd_fmon_types=>ty_iface_id.
    DATA mt_stages TYPE RANGE OF zif_cd_fmon_types=>ty_stage.

ENDCLASS.



CLASS zcl_cd_pf_fmon_events IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    CLEAR: mt_ifaces, mt_stages.
    SPLIT is_adapter-setting AT zif_cd_fmon_types=>gc_pf_setting-separator INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      SPLIT <lv_part> AT zif_cd_fmon_types=>gc_pf_setting-assign INTO DATA(lv_name) DATA(lv_value).
      CASE to_upper( condense( lv_name ) ).
        WHEN zif_cd_fmon_types=>gc_pf_setting-ifaces.
          LOOP AT zcl_ca_ops_util=>split_list( to_upper( lv_value ) ) ASSIGNING FIELD-SYMBOL(<lv_iface>).
            INSERT VALUE #( sign = 'I' option = 'EQ' low = <lv_iface> ) INTO TABLE mt_ifaces.
          ENDLOOP.
        WHEN zif_cd_fmon_types=>gc_pf_setting-stages.
          LOOP AT zcl_ca_ops_util=>split_list( to_upper( lv_value ) ) ASSIGNING FIELD-SYMBOL(<lv_stage>).
            INSERT VALUE #( sign = 'I' option = 'EQ' low = <lv_stage> ) INTO TABLE mt_stages.
          ENDLOOP.
      ENDCASE.
    ENDLOOP.
    IF mt_ifaces IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e386(zca_ops) WITH is_adapter-role is_adapter-file_type is_adapter-class_name
                                   zif_cd_fmon_types=>gc_pf_setting-ifaces.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_event_src~read_events.
    DATA lv_from TYPE d.
    DATA lv_to TYPE d.
    DATA lv_time TYPE t.

    CONVERT TIME STAMP is_request-from_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc INTO DATE lv_from TIME lv_time.
    CONVERT TIME STAMP is_request-to_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc INTO DATE lv_to TIME lv_time.
    DATA(lo_dao) = zcl_cd_fmon_factory=>get_dao( ).
    " the files still open since the window began (an answer for an older file is read too)
    DATA(lt_files) = lo_dao->get_eval_files( iv_date_from  = CONV d( lv_from - 1 )
                                             iv_date_to    = lv_to
                                             iv_open_since = CONV d( lv_from - 31 ) ).
    DELETE lt_files WHERE direction <> zif_cd_fmon_types=>gc_direction-outbound OR iface_id NOT IN mt_ifaces.
    IF lt_files IS INITIAL.
      rs_batch-as_of = is_request-to_ts.
      RETURN.
    ENDIF.
    DATA(lt_events) = lo_dao->get_events( VALUE #( FOR ls_file IN lt_files ( ls_file-file_id ) ) ).
    rs_batch-events = to_events( it_files  = lt_files
                                 it_events = lt_events
                                 iv_from   = is_request-from_ts
                                 iv_to     = is_request-to_ts ).
    rs_batch-as_of = is_request-to_ts.
  ENDMETHOD.


  METHOD to_events.
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>)
         WHERE event_at >= iv_from AND event_at <= iv_to AND stage IN mt_stages.
      READ TABLE it_files WITH KEY by_id COMPONENTS file_id = <ls_event>-file_id ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( source_event_id = |{ <ls_event>-file_id }{ zif_cd_fmon_types=>gc_pf_id_separator }{ <ls_event>-event_no }|
                      event_version   = 1
                      native_status   = <ls_event>-stage
                      native_key      = <ls_file>-file_ref
                      occurred_at     = <ls_event>-event_at
                      bus_date        = <ls_file>-business_date
                      item_count      = <ls_event>-record_count
                      info            = <ls_event>-info ) INTO TABLE rt_events.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
