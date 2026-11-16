*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_docchg_dao.clas.abap
*& Purpose:
*& SQL of the document-change risk check A_DOC_CHANGE (build C): reversed
*& payment documents of a window with their payment runs in one statement
*& (DFKKKO of the reversal document by entry date, the payment document it
*& reverses by the reversal's STBEL, DPAYH by DOC1R without proposal runs).
*& Read-only.
*& Modification log:
*& 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
*& 2026-11-15 | DPAYH paying company code BBUKR and method RZAWE (DPAYH has no BUKRS / PYMET; reference system S/4HANA
*&            | 2025).
*& 2026-11-16 | Reversal direction (reference system A4H): DFKKKO-STBEL is filled on the reversal document and
*&            | names the reversed original - join the reversal's STBEL to the payment document (was: STBEL
*&            | of the payment document).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - document-change reads (SQL)</p>
CLASS zcl_cd_hck_docchg_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_docchg_dao.

ENDCLASS.



CLASS zcl_cd_hck_docchg_dao IMPLEMENTATION.

  METHOD zif_cd_hck_docchg_dao~get_reversed_payments.
    IF iv_max_rows <= 0.
      RETURN.
    ENDIF.
    " Reversal evidence of the snapshot source REVERSALS: the reversal document's header carries the
    " reversed payment document in DFKKKO-STBEL (seen on the reference system A4H; the original's
    " pointer is STORB). The reversal is found by its entry date, the payment document by key.
    " VERIFY-SE11: DFKKKO-CPUDT / FIKEY (index on CPUDT as the snapshot, Performance_Review.md section 10);
    " DPAYH-XVORL / BBUKR / RWBTR / WAERS / ZZ_PAYMENT_STATUS by DOC1R (index VERIFY-SE11, as the runtime
    " DAO). One statement, no SELECT per payment.
    SELECT o~opbel AS payment_doc, r~opbel AS reversal_doc, r~fikey, r~cpudt AS reversed_on,
           p~laufd, p~laufi, p~bbukr AS bukrs, p~zz_payment_status AS status, p~rwbtr AS amount, p~waers AS currency
      FROM dfkkko AS r
      INNER JOIN dfkkko AS o ON o~opbel = r~stbel
      INNER JOIN dpayh AS p ON p~doc1r = o~opbel
      WHERE r~cpudt BETWEEN @iv_from AND @iv_to
        AND r~stbel <> @space
        AND p~xvorl = @space
      ORDER BY o~opbel, p~laufd DESCENDING, p~laufi DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_reversals
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.

ENDCLASS.
