*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_sap_dao.clas.abap
*& Purpose:
*& SQL for the payment engine lookups of the EBS rules: returns lots, payment
*& run, ACH retrieval log, check register, FI documents and the bank G/L
*& balance. Uses only the confirmed join paths of the landscape; every field
*& that is not confirmed is marked VERIFY-DDIC. Read-only.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check register scoped to house bank account; DPAYH proposal runs excluded (review 3.2).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-06 | Audit A07: optional company-code field of DFKKCR (configured, DDIC-validated).
*& 2026-11-06 | Audit A28: return reason from the configured FEBEP field.
*& 2026-11-06 | Operating model: posting state from the configured FEBEP posting-area flags.
*& 2026-11-06 | Performance fix 3: FEBEP reason / posting-flag reads moved into ZCL_CD_EBS_FEB_DAO get_items (one pass).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - payment engine read repository</p>
CLASS zcl_cd_ebs_sap_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_sap_dao.

    "! Ledger for the bank G/L balance (ZCD_OPS_PARAM EBS_GL_LEDGER)
    CONSTANTS gc_default_ledger TYPE c LENGTH 2 VALUE '0L'.
    "! Status field of ZCD_ACH_RTRV_LOG (ZCD_OPS_PARAM EBS_RTRV_STATUS_FIELD)
    CONSTANTS gc_default_rtrv_field TYPE string VALUE `ZZ_RTRV_STATUS`.
    "! ACH retrieval log (legacy custom table, status field configurable - parity D5)
    CONSTANTS gc_rtrv_table TYPE string VALUE `ZCD_ACH_RTRV_LOG`.

  PRIVATE SECTION.
    "! Check register and its static field list (A07 appends the configured company-code field)
    CONSTANTS gc_check_table TYPE string VALUE `DFKKCR`.
    CONSTANTS gc_check_fields TYPE string VALUE `ztnum, hbkid, hktid, doc1r, rwbtr AS amount, crstatus`.
    CONSTANTS gc_sql_separator TYPE string VALUE `, `.
    CONSTANTS gc_sql_as_bukrs TYPE string VALUE ` AS bukrs`.

    METHODS field_exists
      IMPORTING
        iv_table      TYPE string
        iv_field      TYPE string
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ebs_sap_dao IMPLEMENTATION.

  METHOD zif_cd_ebs_sap_dao~get_return_items.
    CHECK it_docno IS NOT INITIAL.
    " Confirmed: DFKKRP-SELW1 = DFKKOP-AUGBL (= FEBEP-CHECT).
    " VERIFY-DDIC: DFKKRK-STARS joined via OPBEL as in legacy v4 (ZCL_BAI_168_DISB)
    SELECT rp~selw1, rp~opbel, rk~stars AS lot_stars
      FROM dfkkrp AS rp
      LEFT OUTER JOIN dfkkrk AS rk ON rk~opbel = rp~opbel
      FOR ALL ENTRIES IN @it_docno
      WHERE rp~selw1 = @it_docno-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_items.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_payments.
    CHECK it_docno IS NOT INITIAL.
    " Confirmed: DPAYH LAUFD/LAUFI by DOC1R; live status DPAYH-ZZ_PAYMENT_STATUS
    " (legacy v4 used ZZPAYMENT_STATUS - see Legacy_Parity_Comparison.md)
    " DOC1R is not unique in DPAYH (re-runs, proposal runs): proposal rows are excluded and
    " the result is a standard table, never a unique-keyed one (review 3.2). VERIFY-DDIC: XVORL
    SELECT doc1r, laufd, laufi, zz_payment_status AS status
      FROM dpayh
      FOR ALL ENTRIES IN @it_docno
      WHERE doc1r = @it_docno-table_line
        AND xvorl = @space
      INTO CORRESPONDING FIELDS OF TABLE @rt_payments.
    SORT rt_payments BY doc1r laufd DESCENDING laufi DESCENDING.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_lookup_rows.
    CHECK it_keys IS NOT INITIAL.
    " Table and field names come from ZCD_EBS_LOOKUP; each is validated against the DDIC
    " before it reaches the statement (no unchecked dynamic SQL). Keys are bound host data.
    DATA(lv_table)  = to_upper( condense( CONV string( is_lookup-table_name ) ) ).
    DATA(lv_key)    = to_upper( condense( CONV string( is_lookup-key_field ) ) ).
    DATA(lv_status) = to_upper( condense( CONV string( is_lookup-status_field ) ) ).
    IF field_exists( iv_table = lv_table iv_field = lv_key ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e051(zcd_ops) WITH lv_key zif_cd_ebs_types=>gc_lookup_table.
    ENDIF.
    IF lv_status IS NOT INITIAL AND field_exists( iv_table = lv_table iv_field = lv_status ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e051(zcd_ops) WITH lv_status zif_cd_ebs_types=>gc_lookup_table.
    ENDIF.
    DATA(lv_select) = COND string( WHEN lv_status IS INITIAL THEN |{ lv_key } AS LOOKUP_KEY|
                                   ELSE |{ lv_key } AS LOOKUP_KEY, { lv_status } AS STATUS| ).
    " VERIFY-ADT: dynamic WHERE referring to the FOR ALL ENTRIES table (@IT_KEYS-TABLE_LINE,
    " strict mode) - confirm at first activation; fallback: one SELECT per key package
    DATA(lv_where) = |{ lv_key } = @IT_KEYS-TABLE_LINE|.
    TRY.
        SELECT (lv_select)
          FROM (lv_table)
          FOR ALL ENTRIES IN @it_keys
          WHERE (lv_where)
          INTO CORRESPONDING FIELDS OF TABLE @rt_rows.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e012(zcd_ops) WITH lv_table
          EXPORTING
            previous = lx_sql.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_retrievals.
    CHECK it_docno IS NOT INITIAL.
    " VERIFY-DDIC: the status field name differs between legacy versions
    " (ZZ_RTRV_STATUS in v4 168, ZZRETRIEVAL_STATUS in v4 468). It is a parameter,
    " validated against the DDIC before use - never concatenated unchecked.
    DATA(lv_field) = to_upper( zcl_cd_ops_factory=>get_store( )->get_param(
                                 iv_name    = zif_cd_ebs_types=>gc_param-rtrv_status_field
                                 iv_default = gc_default_rtrv_field ) ).
    IF field_exists( iv_table = gc_rtrv_table iv_field = lv_field ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e051(zcd_ops) WITH lv_field zif_cd_ebs_types=>gc_param-rtrv_status_field.
    ENDIF.
    DATA(lv_select) = |AUGBL, { lv_field } AS STATUS|.
    SELECT (lv_select)
      FROM zcd_ach_rtrv_log
      FOR ALL ENTRIES IN @it_docno
      WHERE augbl = @it_docno-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_retrievals.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_checks.
    CHECK it_ztnum IS NOT INITIAL.
    " Confirmed: DFKKCR-ZTNUM = FEBEP-CHECT, DFKKCR-DOC1R = DFKKOP-AUGBL.
    " VERIFY-DDIC: DFKKCR-RWBTR (amount) and CRSTATUS as used by legacy v4 581/255;
    " HBKID/HKTID returned so rules scope a check number to its house bank account
    " A07: optional company-code field (EBS_DFKKCR_BUKRS_FIELD), validated against the DDIC
    DATA(lv_fields) = gc_check_fields.
    DATA(lv_bukrs_field) = to_upper( condense( zcl_cd_ops_factory=>get_store( )->get_param(
                             iv_name = zif_cd_ebs_types=>gc_param-dfkkcr_bukrs_field ) ) ).
    IF lv_bukrs_field IS NOT INITIAL AND field_exists( iv_table = gc_check_table iv_field = lv_bukrs_field ) = abap_true.
      lv_fields = lv_fields && gc_sql_separator && lv_bukrs_field && gc_sql_as_bukrs.
    ENDIF.
    SELECT (lv_fields)
      FROM dfkkcr
      FOR ALL ENTRIES IN @it_ztnum
      WHERE ztnum = @it_ztnum-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_checks.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_fi_lines.
    CHECK it_keys IS NOT INITIAL.
    " Key access only (BUKRS/BELNR/GJAHR) - never BSEG by AUGBL or XREF2 (full scan)
    SELECT bukrs, belnr, gjahr, buzei, hkont, augbl
      FROM bseg
      FOR ALL ENTRIES IN @it_keys
      WHERE bukrs = @it_keys-bukrs
        AND belnr = @it_keys-belnr
        AND gjahr = @it_keys-gjahr
      INTO CORRESPONDING FIELDS OF TABLE @rt_lines.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_gl_balance.
    DATA(lv_ledger) = zcl_cd_ops_factory=>get_store( )->get_param( iv_name    = 'EBS_GL_LEDGER'
                                                                  iv_default = CONV #( gc_default_ledger ) ).
    " Aggregation at database level (ACDOCA) - VERIFY-DDIC: TSL/RTCUR for account-currency balance
    SELECT SUM( tsl )
      FROM acdoca
      WHERE rldnr  = @lv_ledger
        AND rbukrs = @iv_bukrs
        AND racct  = @iv_gl_account
        AND rtcur  = @iv_currency
        AND budat <= @iv_date
      INTO @rv_balance.
  ENDMETHOD.


  METHOD field_exists.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = iv_table
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    TRY.
        lo_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.
    rv_yes = xsdbool( line_exists( lo_struct->components[ name = iv_field ] ) ).
  ENDMETHOD.

ENDCLASS.
