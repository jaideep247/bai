*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_cheque_dao.clas.abap
*& Purpose:
*& SQL of the cheque pilot checks (build R). Cheque register rows of a set of
*& cheque numbers (DFKKCR by ZTNUM, FOR ALL ENTRIES after a driver check) and
*& one anti-join of the cheque payments of a run-date window (DPAYH, no
*& proposal run, cheque methods) without a DFKKCR row of the same payment
*& document and run date with a cheque number. Fields of DFKKCR and DPAYH as
*& seen on the reference system S/4HANA 2025 (ddic/a4h). Read-only.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - cheque pilot reads (SQL)</p>
CLASS zcl_cd_hck_cheque_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_cheque_dao.

ENDCLASS.



CLASS zcl_cd_hck_cheque_dao IMPLEMENTATION.

  METHOD zif_cd_hck_cheque_dao~get_register.
    CHECK it_cheques IS NOT INITIAL.
    IF iv_max_rows <= 0.
      RETURN.
    ENDIF.
    " DFKKCR-ZTNUM = cheque number (link of ZCD_CHECK_HIST, user 2026-11-07); ZTNUM is the last key field
    " of DFKKCR - no index starts with it on the reference system (PlanViz in QA1, V246)
    SELECT ztnum, doc1r, bbukr AS bukrs, hbkid, rbetr AS amount, waers AS currency, laufd, state, bnkdt
      FROM dfkkcr
      FOR ALL ENTRIES IN @it_cheques
      WHERE ztnum = @it_cheques-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_register.
    SORT rt_register BY ztnum laufd DESCENDING.
    DATA(lv_first_over) = iv_max_rows + 1.
    IF lines( rt_register ) >= lv_first_over.
      DELETE rt_register FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_cheque_dao~get_payments_without_cheque.
    DATA lt_methods TYPE RANGE OF zif_cd_hck_cheque_types=>ty_pymet.
    IF it_methods IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    lt_methods = VALUE #( FOR lv_method IN it_methods ( sign   = zif_ca_ops_types=>gc_range-sign_include
                                                    option = zif_ca_ops_types=>gc_range-option_equal
                                                    low    = lv_method ) ).
    " Confirmed: DPAYH-DOC1R = DFKKCR-DOC1R = DFKKOP-AUGBL; DPAYH XVORL / BBUKR / RZAWE / RBETR / WAERS and
    " DFKKCR LAUFD / DOC1R / ZTNUM seen on the reference system S/4HANA 2025. DFKKCR has no index on
    " DOC1R or LAUFD there: the anti-join is bounded by the run-date window of DPAYH (V246)
    SELECT p~doc1r, p~laufd, p~laufi, p~bbukr AS bukrs, p~rzawe AS pymet, p~hbkid,
           p~rbetr AS amount, p~waers AS currency
      FROM dpayh AS p
      WHERE p~laufd BETWEEN @iv_from AND @iv_to
        AND p~xvorl = @space
        AND p~doc1r <> @space
        AND p~rzawe IN @lt_methods
        AND NOT EXISTS ( SELECT doc1r FROM dfkkcr AS c
                           WHERE c~doc1r = p~doc1r
                             AND c~laufd = p~laufd
                             AND c~ztnum <> @space )
      ORDER BY p~laufd, p~laufi, p~doc1r
      INTO CORRESPONDING FIELDS OF TABLE @rt_payments
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.

ENDCLASS.
