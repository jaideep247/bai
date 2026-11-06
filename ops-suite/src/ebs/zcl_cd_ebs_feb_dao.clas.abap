*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_feb_dao.clas.abap
*& Purpose:
*& SQL for imported bank statements: FEBKO headers in scope, FEBEP items per
*& statement, the previous statement of a house bank account and the
*& duplicate check. Read-only. Field list limited to what the suite uses.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Audit A14: get_recent_items for rule R22.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - FEBKO/FEBEP repository</p>
CLASS zcl_cd_ebs_feb_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao.

ENDCLASS.



CLASS zcl_cd_ebs_feb_dao IMPLEMENTATION.

  METHOD zif_cd_ebs_feb_dao~get_headers.
    " VERIFY-DDIC: FEBKO-SSVOZ, ESVOZ (balance debit/credit), ANZES (number of items), EFART
    SELECT kukey, bukrs, hbkid, hktid, aznum, azdat, waers, ssbtr, ssvoz, esbtr, esvoz, anzes, efart
      FROM febko
      WHERE bukrs IN @is_selection-bukrs
        AND hbkid IN @is_selection-hbkid
        AND kukey IN @is_selection-kukey
        AND azdat BETWEEN @is_selection-date_from AND @is_selection-date_to
      ORDER BY bukrs, hbkid, hktid, azdat, aznum
      INTO CORRESPONDING FIELDS OF TABLE @rt_headers.
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~get_items.
    CHECK it_kukey IS NOT INITIAL.
    " VERIFY-DDIC: FEBEP-VORGC (BAI type code used by the legacy validators), VGEXT, EPVOZ, KWAER
    SELECT kukey, esnum, vorgc, vgext, vgint, epvoz, kwbtr, kwaer, budat, valut, chect, xblnr, belnr, gjahr
      FROM febep
      FOR ALL ENTRIES IN @it_kukey
      WHERE kukey = @it_kukey-table_line
      INTO CORRESPONDING FIELDS OF TABLE @rt_items.
    SORT rt_items BY kukey esnum.
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~get_prior_header.
    DATA lt_headers TYPE zif_cd_ebs_feb_dao=>tt_header.
    SELECT kukey, bukrs, hbkid, hktid, aznum, azdat, waers, ssbtr, ssvoz, esbtr, esvoz, anzes, efart
      FROM febko
      WHERE bukrs = @iv_bukrs
        AND hbkid = @iv_hbkid
        AND hktid = @iv_hktid
        AND ( azdat < @iv_before
           OR ( azdat = @iv_before AND aznum < @iv_aznum ) )
      ORDER BY azdat DESCENDING, aznum DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @lt_headers
      UP TO 1 ROWS.
    rs_header = VALUE #( lt_headers[ 1 ] OPTIONAL ).
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~get_recent_items.
    " A14: history of the account for the cross-statement duplicate rule R22.
    " VERIFY-DDIC: FEBEP-VORGC / VGEXT / EPVOZ as in get_items
    SELECT p~kukey, p~esnum, p~vorgc, p~vgext, p~vgint, p~epvoz, p~kwbtr, p~kwaer, p~budat, p~valut,
           p~chect, p~xblnr, p~belnr, p~gjahr
      FROM febep AS p
      INNER JOIN febko AS k ON k~kukey = p~kukey
      WHERE k~bukrs = @iv_bukrs
        AND k~hbkid = @iv_hbkid
        AND k~hktid = @iv_hktid
        AND k~azdat BETWEEN @iv_from AND @iv_to
      ORDER BY p~kukey, p~esnum
      INTO CORRESPONDING FIELDS OF TABLE @rt_items.
  ENDMETHOD.


  METHOD zif_cd_ebs_feb_dao~statement_exists.
    SELECT SINGLE @abap_true
      FROM febko
      WHERE bukrs = @iv_bukrs
        AND hbkid = @iv_hbkid
        AND hktid = @iv_hktid
        AND aznum = @iv_aznum
        AND azdat = @iv_azdat
      INTO @rv_exists.
  ENDMETHOD.

ENDCLASS.
