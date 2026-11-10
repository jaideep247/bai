*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_recon_dao.clas.abap
*& Purpose:
*& Reads of the three-way reconciliation check A_RECON_3WAY. Every leg is
*& aggregated on HANA in one set-based statement (GROUP BY with SUM / COUNT
*& / MIN / MAX, JOIN of the key table, NOT EXISTS for the returns lot,
*& HAVING for unmatched assignment groups); configuration rows are read
*& once per run (bank code roles: posting area ZBTR through ZCL_CD_OPS_POSTAREA).
*& No SELECT per document, no line-level copy, nothing
*& written. Field names not confirmed in this landscape carry a
*& VERIFY-DDIC marker (HCK_MORNING_REPORT.md section 15).
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*& 2026-11-08 | Table consolidation: bank code roles of the sets from ZCD_HCK_BTCROLE usage RECON (was
*&            | ZCD_HCK_RCBTC).
*& 2026-11-08 | Customer posting areas: get_btc_roles from ZBTR usage RECON through ZCL_CD_OPS_POSTAREA (was a SELECT
*&            | on ZCD_HCK_BTCROLE).
*& 2026-11-10 | get_sets reads TOLERANCE_SET (set tolerance maintained).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - three-way reconciliation reads (HANA)</p>
"! Access paths and the SQL-trace items: Performance_Review.md, section "Three-way
"! reconciliation reads".
CLASS zcl_cd_hck_recon_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_recon_dao.

  PRIVATE SECTION.
    TYPES tt_account_range TYPE RANGE OF zif_cd_hck_recon_types=>ty_account.
    TYPES tt_btc_range TYPE RANGE OF zif_cd_hck_recon_types=>ty_btc.

    METHODS account_range
      IMPORTING
        it_accounts     TYPE zif_cd_hck_recon_types=>tt_account
      RETURNING
        VALUE(rt_range) TYPE tt_account_range.

    METHODS btc_range
      IMPORTING
        it_btcs         TYPE zif_cd_hck_recon_types=>tt_btc
      RETURNING
        VALUE(rt_range) TYPE tt_btc_range.

ENDCLASS.



CLASS zcl_cd_hck_recon_dao IMPLEMENTATION.

  METHOD zif_cd_hck_recon_dao~get_sets.
    SELECT set_id, kind, side, bukrs, hkont, waers, hbkid, hktid, invert_bank, leg_bank, leg_fica,
           tolerance, tolerance_set, description
      FROM zcd_hck_rcset
      WHERE active = @abap_true
      ORDER BY set_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_sets.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_btc_roles.
    " ZBTR (FQC0) keys USAGE / SCOPE / SCHEME / CODE, result ROLE. Reconciliation entries only: SCOPE =
    " set id, BAI2 type codes (FEBEP-VORGC); lifecycle roles never reach the reconciliation; '*' is
    " not a reconciliation key (an unmapped code is a variance - configuration check POSTAREA_INVALID)
    LOOP AT zcl_cd_ops_postarea_factory=>get_reader( )->entries( zif_cd_ops_postarea_types=>gc_purpose-btc_role )
         ASSIGNING FIELD-SYMBOL(<ls_entry>)
         WHERE key01 = zif_cd_hck_types=>gc_btc_usage-recon
           AND key03 = zif_cd_ebs_types=>gc_scheme-bai2
           AND key02 <> zif_cd_ops_postarea_types=>gc_generic
           AND key04 <> zif_cd_ops_postarea_types=>gc_generic.
      INSERT VALUE #( set_id = <ls_entry>-key02 btc = <ls_entry>-key04 role = <ls_entry>-fun01 ) INTO TABLE rt_roles.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_bank_days.
    DATA(lt_accounts) = account_range( it_accounts ).
    IF lt_accounts IS INITIAL.
      RETURN.
    ENDIF.
    " HANA aggregates the lines of the window; the account is the XBLNR account of the view
    SELECT peaccount AS account, currency, bookingdate AS day, baicode AS btc, debitcreditind AS cdi,
           SUM( amount ) AS amount, COUNT(*) AS line_count
      FROM zi_cd_hckrcbankline
      WHERE peaccount IN @lt_accounts
        AND bookingdate BETWEEN @iv_from AND @iv_to
      GROUP BY peaccount, currency, bookingdate, baicode, debitcreditind
      ORDER BY peaccount, currency, bookingdate, baicode, debitcreditind
      INTO CORRESPONDING FIELDS OF TABLE @rt_days.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_bank_last_days.
    DATA(lt_accounts) = account_range( it_accounts ).
    IF lt_accounts IS INITIAL.
      RETURN.
    ENDIF.
    SELECT peaccount AS account, MAX( bookingdate ) AS last_day
      FROM zi_cd_hckrcbankline
      WHERE peaccount IN @lt_accounts
        AND bookingdate BETWEEN @iv_from AND @iv_to
      GROUP BY peaccount
      ORDER BY peaccount
      INTO CORRESPONDING FIELDS OF TABLE @rt_last.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_bank_days_no_lot.
    DATA(lt_accounts) = account_range( it_accounts ).
    DATA(lt_btcs) = btc_range( it_btcs ).
    IF lt_accounts IS INITIAL OR lt_btcs IS INITIAL.
      RETURN.
    ENDIF.
    " Confirmed path: DFKKRP-SELW1 = payment document = FEBEP-CHECT (methods E G H I J K L).
    " VERIFY-DDIC: CHECT and SELW1 in the same form (leading zeros) - index DFKKRP SELW1
    SELECT l~peaccount AS account, l~currency, l~bookingdate AS day, l~baicode AS btc,
           l~debitcreditind AS cdi, SUM( l~amount ) AS amount, COUNT(*) AS line_count
      FROM zi_cd_hckrcbankline AS l
      WHERE l~peaccount IN @lt_accounts
        AND l~baicode IN @lt_btcs
        AND l~bookingdate BETWEEN @iv_from AND @iv_to
        AND NOT EXISTS ( SELECT selw1 FROM dfkkrp WHERE selw1 = l~bankreference )
      GROUP BY l~peaccount, l~currency, l~bookingdate, l~baicode, l~debitcreditind
      ORDER BY l~peaccount, l~currency, l~bookingdate, l~baicode, l~debitcreditind
      INTO CORRESPONDING FIELDS OF TABLE @rt_days.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_gl_days.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    " VERIFY-DDIC: ACDOCA RLDNR, RBUKRS, RACCT, RWCUR / WSL (transaction currency, signed), BUDAT,
    " AWTYP. One statement for all sets: the key table is joined on HANA (as EBS R18)
    SELECT a~rbukrs AS bukrs, a~racct AS hkont, a~rwcur AS currency, a~budat AS day, a~awtyp,
           SUM( a~wsl ) AS amount, COUNT(*) AS line_count
      FROM acdoca AS a
      INNER JOIN @it_keys AS k ON  a~rbukrs = k~bukrs
                               AND a~racct  = k~hkont
                               AND a~rwcur  = k~currency
      WHERE a~rldnr = @iv_ledger
        AND a~budat BETWEEN @iv_from AND @iv_to
      GROUP BY a~rbukrs, a~racct, a~rwcur, a~budat, a~awtyp
      ORDER BY a~rbukrs, a~racct, a~rwcur, a~budat, a~awtyp
      INTO CORRESPONDING FIELDS OF TABLE @rt_days.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_fica_days.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    " Confirmed path: DFKKSUMC-FIKEY = DFKKKO-FIKEY = BSEG-AWKEY (the transfer reached G/L).
    " VERIFY-DDIC: DFKKSUMC BUKRS, HKONT, WAERS, BUDAT, BETRW signed in transaction currency
    SELECT s~bukrs, s~hkont, s~waers AS currency, s~budat AS day,
           SUM( s~betrw ) AS amount, COUNT(*) AS line_count
      FROM dfkksumc AS s
      INNER JOIN @it_keys AS k ON  s~bukrs = k~bukrs
                               AND s~hkont = k~hkont
                               AND s~waers = k~currency
      WHERE s~budat BETWEEN @iv_from AND @iv_to
      GROUP BY s~bukrs, s~hkont, s~waers, s~budat
      ORDER BY s~bukrs, s~hkont, s~waers, s~budat
      INTO CORRESPONDING FIELDS OF TABLE @rt_days.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_payment_days.
    IF it_banks IS INITIAL.
      RETURN.
    ENDIF.
    " Confirmed: DPAYH LAUFD / DOC1R. VERIFY-DDIC: DPAYH XVORL, BUKRS, HBKID, HKTID, RWBTR, WAERS
    SELECT p~bukrs, p~hbkid, p~hktid, p~waers AS currency, p~laufd AS day,
           SUM( p~rwbtr ) AS amount, COUNT(*) AS line_count
      FROM dpayh AS p
      INNER JOIN @it_banks AS b ON  p~bukrs = b~bukrs
                                AND p~hbkid = b~hbkid
                                AND p~hktid = b~hktid
                                AND p~waers = b~currency
      WHERE p~laufd BETWEEN @iv_from AND @iv_to
        AND p~xvorl = @space
        AND p~doc1r <> @space
      GROUP BY p~bukrs, p~hbkid, p~hktid, p~waers, p~laufd
      ORDER BY p~bukrs, p~hbkid, p~hktid, p~waers, p~laufd
      INTO CORRESPONDING FIELDS OF TABLE @rt_days.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_deposits.
    DATA(lt_accounts) = account_range( it_accounts ).
    DATA(lt_btcs) = btc_range( it_btcs ).
    IF lt_accounts IS INITIAL OR lt_btcs IS INITIAL.
      RETURN.
    ENDIF.
    SELECT peaccount AS account, currency, companycode AS bukrs, postingdocument AS belnr,
           postingyear AS gjahr, bookingdate AS day, debitcreditind AS cdi,
           SUM( amount ) AS amount, COUNT(*) AS line_count
      FROM zi_cd_hckrcbankline
      WHERE peaccount IN @lt_accounts
        AND baicode IN @lt_btcs
        AND bookingdate BETWEEN @iv_from AND @iv_to
      GROUP BY peaccount, currency, companycode, postingdocument, postingyear, bookingdate, debitcreditind
      ORDER BY peaccount, currency, companycode, postingdocument, postingyear, bookingdate, debitcreditind
      INTO CORRESPONDING FIELDS OF TABLE @rt_deposits.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_doc_assignments.
    IF it_docs IS INITIAL.
      RETURN.
    ENDIF.
    " VERIFY-DDIC: ACDOCA ZUONR (assignment = Stripe descriptor after payout processing), DRCRK
    SELECT a~rbukrs AS bukrs, a~belnr, a~gjahr, a~zuonr, a~drcrk AS cdi,
           SUM( a~wsl ) AS amount, COUNT(*) AS line_count
      FROM acdoca AS a
      INNER JOIN @it_docs AS d ON  a~rbukrs = d~bukrs
                               AND a~belnr  = d~belnr
                               AND a~gjahr  = d~gjahr
      WHERE a~rldnr = @iv_ledger
        AND a~racct = @iv_hkont
      GROUP BY a~rbukrs, a~belnr, a~gjahr, a~zuonr, a~drcrk
      ORDER BY a~rbukrs, a~belnr, a~gjahr, a~zuonr, a~drcrk
      INTO CORRESPONDING FIELDS OF TABLE @rt_assigns.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_assignment_sums.
    DATA lt_zuonr TYPE RANGE OF zif_cd_hck_recon_types=>ty_zuonr.
    IF it_zuonr IS INITIAL.
      RETURN.
    ENDIF.
    lt_zuonr = VALUE #( FOR lv_zuonr IN it_zuonr ( sign   = zif_ca_ops_types=>gc_range-sign_include
                                                   option = zif_ca_ops_types=>gc_range-option_equal
                                                   low    = lv_zuonr ) ).
    SELECT a~zuonr, a~drcrk AS cdi, SUM( a~wsl ) AS amount, COUNT(*) AS line_count
      FROM acdoca AS a
      WHERE a~rldnr  = @iv_ledger
        AND a~rbukrs = @is_key-bukrs
        AND a~racct  = @is_key-hkont
        AND a~rwcur  = @is_key-currency
        AND a~budat BETWEEN @iv_from AND @iv_to
        AND a~zuonr IN @lt_zuonr
      GROUP BY a~zuonr, a~drcrk
      ORDER BY a~zuonr, a~drcrk
      INTO CORRESPONDING FIELDS OF TABLE @rt_sums.
  ENDMETHOD.


  METHOD zif_cd_hck_recon_dao~get_open_assignments.
    IF iv_max_rows <= 0.
      RETURN.
    ENDIF.
    " ACH collections are cleared one-to-one by assignment (F.13): a group that does not net to zero
    " is open; a line without assignment is not part of that model (the day leg covers it).
    " Read on ACDOCA (account in the key) - BSEG has no account index (Performance_Review.md)
    SELECT a~zuonr, MIN( a~budat ) AS first_day, SUM( a~wsl ) AS amount, COUNT(*) AS line_count
      FROM acdoca AS a
      WHERE a~rldnr  = @iv_ledger
        AND a~rbukrs = @is_key-bukrs
        AND a~racct  = @is_key-hkont
        AND a~rwcur  = @is_key-currency
        AND a~budat BETWEEN @iv_from AND @iv_to
        AND a~zuonr <> @space
      GROUP BY a~zuonr
      HAVING SUM( a~wsl ) <> 0
      ORDER BY first_day, a~zuonr
      INTO CORRESPONDING FIELDS OF TABLE @rt_open
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD account_range.
    rt_range = VALUE #( FOR lv_account IN it_accounts WHERE ( table_line IS NOT INITIAL )
                        ( sign   = zif_ca_ops_types=>gc_range-sign_include
                          option = zif_ca_ops_types=>gc_range-option_equal
                          low    = lv_account ) ).
  ENDMETHOD.


  METHOD btc_range.
    rt_range = VALUE #( FOR lv_btc IN it_btcs WHERE ( table_line IS NOT INITIAL )
                        ( sign   = zif_ca_ops_types=>gc_range-sign_include
                          option = zif_ca_ops_types=>gc_range-option_equal
                          low    = lv_btc ) ).
  ENDMETHOD.

ENDCLASS.
