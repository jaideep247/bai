*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_src_dpayh.clas.abap
*& Purpose:
*& Delivered file source of the payment file lifecycle (role FILE) on the
*& SAP FI-CA payment run: the payments of the runs with a run date in the
*& window (DPAYH, fields confirmed on the reference system: LAUFD, LAUFI,
*& ORIGN, XVORL, PAYNO, SUBNO, BBUKR, RZAWE, HBKID, HKTID, WAERS, RWBTR,
*& DOC1R, GPA1R), only real payments (no proposal: XVORL blank, V171)
*& with a payment document (DOC1R), grouped into files by the fields of
*& the setting GROUP (default BBUKR, RZAWE, HBKID, HKTID - one payment
*& medium per paying company code, method and house bank account: V173;
*& the payment medium key PMF_KEY is not used for identity: V174). The
*& business date is the run date; the amount is RWBTR in WAERS as stored
*& (sign convention V172). Payment-order methods (setting ORDERS): the
*& run posts no payment document until the bank-confirmed order lot is
*& posted, so their payments count without DOC1R (V181). The run key is
*& DPAYH's (LAUFD / LAUFI), never derived from a job name. Setting:
*& GROUP=<fields>;RZAWE=<methods>;ORDERS=<methods> (comma lists; blank
*& RZAWE = every method). Read only, one statement per window, at most
*& the request's limit of payments (then partial).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - file source: FI-CA payment run</p>
CLASS zcl_ca_ops_pf_src_dpayh DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_file_src.

    "! A payment of a run as read from DPAYH
    TYPES:
      BEGIN OF ty_row,
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
      END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    "! The fields a file may be grouped by
    CONSTANTS gc_group_fields TYPE string VALUE `BBUKR,RZAWE,HBKID,HKTID`.
    "! Link registry object of a payment of a run (config/links/packages/fica.json)
    CONSTANTS gc_link_object TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'FICA_PAYMENT_RUN'.

    "! Files of a set of payment rows (grouping and payment keys; public for the tests)
    METHODS group
      IMPORTING
        it_rows         TYPE tt_row
      RETURNING
        VALUE(rt_files) TYPE zif_ca_ops_pf_types=>tt_src_file.

  PRIVATE SECTION.
    DATA mt_group TYPE string_table.
    DATA mt_methods TYPE RANGE OF char1.
    "! Payment-order methods: a payment without payment document is still a payment of the file
    DATA mt_orders TYPE RANGE OF char1.

ENDCLASS.



CLASS zcl_ca_ops_pf_src_dpayh IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    CLEAR: mt_group, mt_methods, mt_orders.
    SPLIT is_adapter-setting AT ';' INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      SPLIT <lv_part> AT '=' INTO DATA(lv_name) DATA(lv_value).
      CASE to_upper( condense( lv_name ) ).
        WHEN 'GROUP'.
          LOOP AT zcl_ca_ops_util=>split_list( to_upper( lv_value ) ) ASSIGNING FIELD-SYMBOL(<lv_field>).
            IF NOT matches( val = <lv_field> pcre = `BBUKR|RZAWE|HBKID|HKTID` ).
              RAISE EXCEPTION TYPE zcx_ca_ops_error
                MESSAGE e386(zca_ops) WITH is_adapter-role is_adapter-file_type is_adapter-class_name <lv_field>.
            ENDIF.
            INSERT <lv_field> INTO TABLE mt_group.
          ENDLOOP.
        WHEN 'RZAWE'.
          LOOP AT zcl_ca_ops_util=>split_list( lv_value ) ASSIGNING FIELD-SYMBOL(<lv_method>).
            INSERT VALUE #( sign = 'I' option = 'EQ' low = <lv_method> ) INTO TABLE mt_methods.
          ENDLOOP.
        WHEN 'ORDERS'.
          LOOP AT zcl_ca_ops_util=>split_list( lv_value ) ASSIGNING FIELD-SYMBOL(<lv_order>).
            INSERT VALUE #( sign = 'I' option = 'EQ' low = <lv_order> ) INTO TABLE mt_orders.
          ENDLOOP.
      ENDCASE.
    ENDLOOP.
    IF mt_group IS INITIAL.
      mt_group = zcl_ca_ops_util=>split_list( gc_group_fields ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_file_src~read_files.
    DATA lt_rows TYPE tt_row.
    DATA lv_from TYPE d.
    DATA lv_to TYPE d.
    DATA lv_time TYPE t.

    IF mt_group IS INITIAL.
      mt_group = zcl_ca_ops_util=>split_list( gc_group_fields ).
    ENDIF.
    " run dates of the window (UTC dates; a day on each side - an observation read twice is stored once)
    CONVERT TIME STAMP is_request-from_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc INTO DATE lv_from TIME lv_time.
    CONVERT TIME STAMP is_request-to_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc INTO DATE lv_to TIME lv_time.
    lv_from -= 1.
    lv_to += 1.
    DATA(lv_max) = COND i( WHEN is_request-max > 0 THEN is_request-max ELSE 50000 ).
    " VERIFY-SE11 (V171): XVORL = X marks the payments of a proposal run (simulation), never paid
    TEST-SEAM pf_dpayh_read.
      SELECT laufd, laufi, orign, payno, subno, bbukr, rzawe, hbkid, hktid, waers, rwbtr, doc1r, gpa1r
        FROM dpayh
        WHERE laufd BETWEEN @lv_from AND @lv_to
          AND xvorl = @space
          AND rzawe IN @mt_methods
        ORDER BY laufd, laufi, orign, payno, subno
        INTO CORRESPONDING FIELDS OF TABLE @lt_rows
        UP TO @lv_max ROWS.
    END-TEST-SEAM.
    rs_batch-partial = xsdbool( lines( lt_rows ) >= lv_max ).
    rs_batch-as_of = is_request-to_ts.
    " a payment without payment document is not paid - unless its method is a payment order (document later)
    IF mt_orders IS INITIAL.
      DELETE lt_rows WHERE doc1r IS INITIAL.
    ELSE.
      DELETE lt_rows WHERE doc1r IS INITIAL AND rzawe NOT IN mt_orders.
    ENDIF.
    rs_batch-files = group( lt_rows ).
  ENDMETHOD.


  METHOD group.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_key) = |{ <ls_row>-laufd }/{ <ls_row>-laufi }|.
      LOOP AT mt_group ASSIGNING FIELD-SYMBOL(<lv_field>).
        ASSIGN COMPONENT <lv_field> OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc = 0.
          lv_key = |{ lv_key }/{ <lv_value> }|.
        ENDIF.
      ENDLOOP.
      READ TABLE rt_files WITH KEY native_key = CONV zif_ca_ops_pf_types=>ty_native_key( lv_key )
           ASSIGNING FIELD-SYMBOL(<ls_file>).
      IF sy-subrc <> 0.
        INSERT VALUE #( native_key  = lv_key
                        bukrs       = <ls_row>-bbukr
                        run_date    = <ls_row>-laufd
                        run_id      = <ls_row>-laufi
                        pay_method  = <ls_row>-rzawe
                        house_bank  = <ls_row>-hbkid
                        account_id  = <ls_row>-hktid
                        bus_date    = <ls_row>-laufd
                        link_object = gc_link_object
                        link_value  = zcl_ca_ops_exc_contract=>link_value(
                                        VALUE #( ( fieldname = 'LAUFD' value = <ls_row>-laufd )
                                                 ( fieldname = 'LAUFI' value = <ls_row>-laufi ) ) ) )
               INTO TABLE rt_files ASSIGNING <ls_file>.
      ENDIF.
      INSERT VALUE #( pay_key      = |{ <ls_row>-laufd }/{ <ls_row>-laufi }/{ <ls_row>-orign }/{ <ls_row>-payno }/{ <ls_row>-subno }|
                      bukrs        = <ls_row>-bbukr
                      currency     = <ls_row>-waers
                      amount       = <ls_row>-rwbtr
                      amount_known = xsdbool( <ls_row>-waers IS NOT INITIAL )
                      partner      = <ls_row>-gpa1r
                      pay_doc      = <ls_row>-doc1r
                      pay_method   = <ls_row>-rzawe ) INTO TABLE <ls_file>-payments.
      <ls_file>-pay_count += 1.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
