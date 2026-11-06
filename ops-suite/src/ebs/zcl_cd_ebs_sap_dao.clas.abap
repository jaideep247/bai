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

  PRIVATE SECTION.
    METHODS field_exists
      IMPORTING
        iv_table      TYPE string
        iv_field      TYPE string
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ebs_sap_dao IMPLEMENTATION.

  METHOD zif_cd_ebs_sap_dao~get_return_items.
    IF it_docno IS INITIAL.
      RETURN.
    ENDIF.
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
    IF it_docno IS INITIAL.
      RETURN.
    ENDIF.
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


  METHOD zif_cd_ebs_sap_dao~get_retrievals.
    IF it_docno IS INITIAL.
      RETURN.
    ENDIF.
    " VERIFY-DDIC: the status field name differs between legacy versions
    " (ZZ_RTRV_STATUS in v4 168, ZZRETRIEVAL_STATUS in v4 468). It is a parameter,
    " validated against the DDIC before use - never concatenated unchecked.
    DATA(lv_field) = to_upper( zcl_cd_ops_factory=>get_store( )->get_param(
                                 iv_name    = 'EBS_RTRV_STATUS_FIELD'
                                 iv_default = gc_default_rtrv_field ) ).
    IF field_exists( iv_table = `ZCD_ACH_RTRV_LOG` iv_field = lv_field ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e051(zcd_ops) WITH lv_field 'EBS_RTRV_STATUS_FIELD'.
    ENDIF.
    DATA(lv_select) = |AUGBL, { lv_field } AS STATUS|.
    SELECT (lv_select)
      FROM zcd_ach_rtrv_log
      FOR ALL ENTRIES IN @it_docno
      WHERE augbl = @it_docno-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_retrievals.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_checks.
    IF it_ztnum IS INITIAL.
      RETURN.
    ENDIF.
    " Confirmed: DFKKCR-ZTNUM = FEBEP-CHECT, DFKKCR-DOC1R = DFKKOP-AUGBL.
    " VERIFY-DDIC: DFKKCR-RWBTR (amount) and CRSTATUS as used by legacy v4 581/255;
    " HBKID/HKTID returned so rules scope a check number to its house bank account
    SELECT ztnum, hbkid, hktid, doc1r, rwbtr AS amount, crstatus
      FROM dfkkcr
      FOR ALL ENTRIES IN @it_ztnum
      WHERE ztnum = @it_ztnum-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_checks.
  ENDMETHOD.


  METHOD zif_cd_ebs_sap_dao~get_fi_lines.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
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
