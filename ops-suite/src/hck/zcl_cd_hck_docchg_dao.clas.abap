*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_docchg_dao.clas.abap
*& Purpose:
*& SQL of the document-change risk check A_DOC_CHANGE (build C): reversed
*& payment documents of a window with their payment runs in one statement
*& (DFKKKO of the payment document, its reversal document by STBEL, DPAYH by
*& DOC1R without proposal runs). Read-only.
*& Modification log:
*& 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
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
    " Reversal evidence of the trace and the snapshot source REVERSALS: DFKKKO-STBEL on the payment
    " document's header. VERIFY-SE11: DFKKKO-STBEL / CPUDT / FIKEY (index on CPUDT as the snapshot,
    " Performance_Review.md section 10); DPAYH-XVORL / BUKRS / RWBTR / WAERS / ZZ_PAYMENT_STATUS by DOC1R
    " (index VERIFY-SE11, as the runtime DAO). One statement, no SELECT per payment.
    SELECT o~opbel AS payment_doc, o~stbel AS reversal_doc, r~fikey, r~cpudt AS reversed_on,
           p~laufd, p~laufi, p~bukrs, p~zz_payment_status AS status, p~rwbtr AS amount, p~waers AS currency
      FROM dfkkko AS o
      INNER JOIN dfkkko AS r ON r~opbel = o~stbel
      INNER JOIN dpayh AS p ON p~doc1r = o~opbel
      WHERE r~cpudt BETWEEN @iv_from AND @iv_to
        AND o~stbel <> @space
        AND p~xvorl = @space
      ORDER BY o~opbel, p~laufd DESCENDING, p~laufi DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_reversals
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.

ENDCLASS.
