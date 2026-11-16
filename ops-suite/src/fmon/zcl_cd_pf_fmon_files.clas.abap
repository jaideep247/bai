*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_pf_fmon_files.clas.abap
*& Purpose:
*& File source of the framework's payment file lifecycle (role FILE,
*& ZIF_CA_OPS_PF_FILE_SRC) over the suite's file monitoring: the outbound
*& files FMON registered for the interfaces of the setting (ZCD_FMON_FILE
*& through ZIF_CD_FMON_DAO=>GET_EVAL_FILES - no SQL of its own on FMON's
*& tables), native key = the FMON file reference, business date and
*& generation time from FMON, the payment run from the generation group
*& (ZCL_CD_FMON_ACK_ALERT=>RUN_KEY with the source's GROUP_FIELDS; V182)
*& and its payments from DPAYH (one grouped read for every run of the
*& window, the house bank / account of the group; fields confirmed on the
*& reference system), a regenerated file linked to the earlier generation
*& of its group (FMON rule 9). Setting: IFACES=<interface IDs> (required).
*& Read only; delivered inactive (docs/Payment_File_Overlay.md).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle, first customer's overlay).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - payment file source over file monitoring</p>
CLASS zcl_cd_pf_fmon_files DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_file_src.

    "! A payment of a run as read from DPAYH
    TYPES:
      BEGIN OF ty_pay,
        laufd TYPE d,
        laufi TYPE c LENGTH 5,
        orign TYPE c LENGTH 1,
        payno TYPE i,
        subno TYPE c LENGTH 6,
        bbukr TYPE bukrs,
        rzawe TYPE c LENGTH 1,
        hbkid TYPE c LENGTH 5,
        hktid TYPE c LENGTH 5,
        waers TYPE c LENGTH 5,
        rwbtr TYPE zif_ca_ops_pf_types=>ty_amount,
        doc1r TYPE c LENGTH 24,
        gpa1r TYPE c LENGTH 12,
      END OF ty_pay.
    TYPES tt_pay TYPE STANDARD TABLE OF ty_pay WITH EMPTY KEY.

    "! Files of FMON's register with their payments (public for the tests)
    METHODS to_files
      IMPORTING
        it_files        TYPE zif_cd_fmon_types=>tt_file
        it_sources      TYPE zif_cd_fmon_types=>tt_src
        it_payments     TYPE tt_pay
      RETURNING
        VALUE(rt_files) TYPE zif_ca_ops_pf_types=>tt_src_file.

  PRIVATE SECTION.
    TYPES tt_bank_range TYPE RANGE OF char5.
    DATA mt_ifaces TYPE RANGE OF zif_cd_fmon_types=>ty_iface_id.

    METHODS read_payments
      IMPORTING
        it_files           TYPE zif_cd_fmon_types=>tt_file
        it_sources         TYPE zif_cd_fmon_types=>tt_src
      RETURNING
        VALUE(rt_payments) TYPE tt_pay.

ENDCLASS.



CLASS zcl_cd_pf_fmon_files IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    CLEAR mt_ifaces.
    SPLIT is_adapter-setting AT zif_cd_fmon_types=>gc_pf_setting-separator INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      SPLIT <lv_part> AT zif_cd_fmon_types=>gc_pf_setting-assign INTO DATA(lv_name) DATA(lv_value).
      IF to_upper( condense( lv_name ) ) = zif_cd_fmon_types=>gc_pf_setting-ifaces.
        LOOP AT zcl_ca_ops_util=>split_list( to_upper( lv_value ) ) ASSIGNING FIELD-SYMBOL(<lv_iface>).
          INSERT VALUE #( sign = 'I' option = 'EQ' low = <lv_iface> ) INTO TABLE mt_ifaces.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
    " without an interface every FMON file would be a payment file of this type: refused
    IF mt_ifaces IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e386(zca_ops) WITH is_adapter-role is_adapter-file_type is_adapter-class_name
                                   zif_cd_fmon_types=>gc_pf_setting-ifaces.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_file_src~read_files.
    DATA lv_from TYPE d.
    DATA lv_to TYPE d.
    DATA lv_time TYPE t.

    CONVERT TIME STAMP is_request-from_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc INTO DATE lv_from TIME lv_time.
    CONVERT TIME STAMP is_request-to_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc INTO DATE lv_to TIME lv_time.
    DATA(lo_dao) = zcl_cd_fmon_factory=>get_dao( ).
    DATA(lt_files) = lo_dao->get_eval_files( iv_date_from  = CONV d( lv_from - 1 )
                                             iv_date_to    = lv_to
                                             iv_open_since = CONV d( lv_from - 1 ) ).
    DELETE lt_files WHERE direction <> zif_cd_fmon_types=>gc_direction-outbound OR iface_id NOT IN mt_ifaces.
    DATA(lt_sources) = lo_dao->get_sources( ).
    rs_batch-files = to_files( it_files    = lt_files
                               it_sources  = lt_sources
                               it_payments = read_payments( it_files = lt_files it_sources = lt_sources ) ).
    rs_batch-as_of = is_request-to_ts.
  ENDMETHOD.


  METHOD read_payments.
    DATA lt_laufd TYPE RANGE OF d.
    DATA lt_laufi TYPE RANGE OF char5.
    LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE gen_group IS NOT INITIAL.
      DATA(ls_key) = zcl_cd_fmon_ack_alert=>run_key(
                       iv_gen_group    = <ls_file>-gen_group
                       iv_group_fields = VALUE #( it_sources[ src_id = <ls_file>-src_id ]-group_fields OPTIONAL ) ).
      IF ls_key-laufd IS NOT INITIAL AND ls_key-laufi IS NOT INITIAL.
        INSERT VALUE #( sign = 'I' option = 'EQ' low = ls_key-laufd ) INTO TABLE lt_laufd.
        INSERT VALUE #( sign = 'I' option = 'EQ' low = ls_key-laufi ) INTO TABLE lt_laufi.
      ENDIF.
    ENDLOOP.
    IF lt_laufd IS INITIAL.
      RETURN.
    ENDIF.
    SORT lt_laufd BY low.
    DELETE ADJACENT DUPLICATES FROM lt_laufd COMPARING low.
    SORT lt_laufi BY low.
    DELETE ADJACENT DUPLICATES FROM lt_laufi COMPARING low.
    " one grouped read for every run of the window (real payments only: no proposal, VERIFY V171 of the framework)
    SELECT laufd, laufi, orign, payno, subno, bbukr, rzawe, hbkid, hktid, waers, rwbtr, doc1r, gpa1r
      FROM dpayh
      WHERE laufd IN @lt_laufd
        AND laufi IN @lt_laufi
        AND xvorl = @space
      ORDER BY laufd, laufi, orign, payno, subno
      INTO CORRESPONDING FIELDS OF TABLE @rt_payments.
  ENDMETHOD.


  METHOD to_files.
    LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      DATA(ls_key) = zcl_cd_fmon_ack_alert=>run_key(
                       iv_gen_group    = <ls_file>-gen_group
                       iv_group_fields = VALUE #( it_sources[ src_id = <ls_file>-src_id ]-group_fields OPTIONAL ) ).
      DATA(ls_out) = VALUE zif_ca_ops_pf_types=>ty_src_file( native_key = <ls_file>-file_ref
                                                             run_date   = ls_key-laufd
                                                             run_id     = ls_key-laufi
                                                             house_bank = ls_key-hbkid
                                                             account_id = ls_key-hktid
                                                             pay_method = <ls_file>-pay_method
                                                             bus_date   = <ls_file>-business_date
                                                             gen_at     = <ls_file>-first_event_at
                                                             pay_count  = <ls_file>-record_count ).
      " a regenerated file (FMON rule 9): the earlier generation of the same interface and group
      LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_earlier>)
           WHERE iface_id = <ls_file>-iface_id AND gen_group = <ls_file>-gen_group AND gen_group IS NOT INITIAL
             AND file_id <> <ls_file>-file_id AND first_event_at < <ls_file>-first_event_at.
        ls_out-predecessor_key = <ls_earlier>-file_ref.
      ENDLOOP.
      " a group without house bank / account takes every house bank / account of the run
      DATA(lt_hbkid) = COND tt_bank_range( WHEN ls_key-hbkid IS NOT INITIAL
                                           THEN VALUE #( ( sign = 'I' option = 'EQ' low = ls_key-hbkid ) ) ).
      DATA(lt_hktid) = COND tt_bank_range( WHEN ls_key-hktid IS NOT INITIAL
                                           THEN VALUE #( ( sign = 'I' option = 'EQ' low = ls_key-hktid ) ) ).
      LOOP AT it_payments ASSIGNING FIELD-SYMBOL(<ls_pay>)
           WHERE laufd = ls_key-laufd AND laufi = ls_key-laufi AND hbkid IN lt_hbkid AND hktid IN lt_hktid.
        ls_out-bukrs = <ls_pay>-bbukr.
        INSERT VALUE #( pay_key      = |{ <ls_pay>-laufd }/{ <ls_pay>-laufi }/{ <ls_pay>-orign }/{ <ls_pay>-payno }/|
                                    && |{ <ls_pay>-subno }|
                        bukrs        = <ls_pay>-bbukr
                        currency     = <ls_pay>-waers
                        amount       = <ls_pay>-rwbtr
                        amount_known = xsdbool( <ls_pay>-waers IS NOT INITIAL )
                        partner      = <ls_pay>-gpa1r
                        pay_doc      = <ls_pay>-doc1r
                        pay_method   = <ls_pay>-rzawe ) INTO TABLE ls_out-payments.
      ENDLOOP.
      IF ls_key-laufd IS NOT INITIAL.
        ls_out-link_object = zif_cd_fmon_types=>gc_pf_link-payrun.
        ls_out-link_value  = zcl_ca_ops_exc_contract=>link_value(
                               VALUE #( ( fieldname = zif_cd_fmon_types=>gc_pf_link-laufd value = ls_key-laufd )
                                        ( fieldname = zif_cd_fmon_types=>gc_pf_link-laufi value = ls_key-laufi ) ) ).
      ENDIF.
      INSERT ls_out INTO TABLE rt_files.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
