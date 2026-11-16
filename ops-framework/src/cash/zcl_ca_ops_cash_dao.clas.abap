*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_dao.clas.abap
*& Purpose:
*& Data access of the FI-CA cash operations checks (ZIF_CA_OPS_CASH_DAO):
*& set-based reads of SAP standard tables - every count, sum and oldest
*& date is computed on the database, grouped by source object, company
*& code and currency, oldest first, capped at iv_max rows; the G/L side
*& through the released view I_JournalEntry (ZI_CA_OpsCashJrnl); the owner
*& of a check from the control register and the process register; the
*& factory calendar (DATE_CONVERT_TO_FACTORYDATE, the only call, in a test
*& seam). A database error raises ZCX_CA_OPS_ERROR 521 with the source
*& (the previous exception kept). Read-only: nothing is changed.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - data access</p>
"! FI-CA tables have no released view on the target release: direct table reads, the clean-core exception the
"! repository documents (as ZCL_CA_OPS_FLOW_DAO). Fields as seen on the reference system S/4HANA 2025 (code scanner
"! ddic_export.py); the meaning of indicator and status fields is VERIFY V221 ff.; PlanViz CASH-PV1 .. CASH-PV6.
CLASS zcl_ca_ops_cash_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao.

  PRIVATE SECTION.
    "! Raise the read error of a source (message 521, the database error as previous)
    METHODS read_failed
      IMPORTING
        iv_source TYPE zif_ca_ops_types=>ty_reference
        ix_error  TYPE REF TO cx_root
      RAISING
        zcx_ca_ops_error.

    "! LIKE pattern of a job name parameter: % and _ escaped, * = any characters
    METHODS like_pattern
      IMPORTING
        iv_pattern     TYPE csequence
      RETURNING
        VALUE(rv_like) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_cash_dao IMPLEMENTATION.

  METHOD zif_ca_ops_cash_dao~payment_runs.
    " DPAYH key LAUFD, LAUFI, ORIGN, XVORL, PAYNO, SUBNO: the window on the first key field (PlanViz CASH-PV1)
    TRY.
        SELECT laufd AS run_date, laufi AS run_id, xvorl AS proposal, bbukr AS company_code, waers AS currency,
               rzawe AS pay_method, COUNT(*) AS item_count, SUM( rwbtr ) AS amount,
               SUM( CASE WHEN doc1r = @space THEN 1 ELSE 0 END ) AS nodoc_count,
               SUM( CASE WHEN doc1r = @space THEN rwbtr ELSE 0 END ) AS nodoc_amount
          FROM dpayh
          WHERE laufd BETWEEN @iv_from AND @iv_to
          GROUP BY laufd, laufi, xvorl, bbukr, waers, rzawe
          ORDER BY run_date, run_id, proposal, company_code, currency, pay_method
          INTO CORRESPONDING FIELDS OF TABLE @rt_runs
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-payments ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~jobs.
    DATA(lv_like) = like_pattern( iv_pattern ).
    " TBTCO statuses: ZIF_CA_OPS_JOB_TYPES=>GC_STATUS (V58); indexes on STRTDATE and SDLSTRTDT
    TRY.
        SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, strtdate, strttime, enddate, endtime
          FROM tbtco
          WHERE jobname LIKE @lv_like ESCAPE @zif_ca_ops_cash_types=>gc_like_escape
            AND ( strtdate BETWEEN @iv_from AND @iv_to
                  OR sdlstrtdt BETWEEN @iv_from AND @iv_to )
          ORDER BY strtdate, strttime, jobname, jobcount
          INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-jobs ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~open_lots.
    " VERIFY V222: DFKKZK-STAZS is the status of the lot (done values = CASH_LOT_DONE_STATUS), ERDAT its creation
    TRY.
        SELECT zk~keyz1 AS object_id, zp~bukrs AS company_code, zp~waers AS currency,
               COUNT(*) AS item_count, SUM( zp~betrz ) AS amount, MIN( zk~erdat ) AS oldest
          FROM dfkkzk AS zk
          INNER JOIN dfkkzp AS zp ON zp~keyz1 = zk~keyz1
          WHERE zk~erdat <= @iv_created_to
            AND zk~stazs NOT IN @it_done
          GROUP BY zk~keyz1, zp~bukrs, zp~waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-lots ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~lot_clarifications.
    " VERIFY V223: DFKKZP-XKLAE set = the item waits in clarification
    TRY.
        SELECT keyz1 AS object_id, bukrs AS company_code, waers AS currency,
               COUNT(*) AS item_count, SUM( betrz ) AS amount, MIN( budat ) AS oldest
          FROM dfkkzp
          WHERE xklae <> @space
            AND budat <= @iv_posted_to
          GROUP BY keyz1, bukrs, waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-lots ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~open_returns_lots.
    " VERIFY V224: DFKKRK-STARS is the status of the returns lot (done values = CASH_RET_DONE_STATUS)
    TRY.
        SELECT rk~keyr1 AS object_id, rp~bukrs AS company_code, rp~waers AS currency,
               COUNT(*) AS item_count, SUM( rp~betrr ) AS amount, MIN( rk~erdat ) AS oldest
          FROM dfkkrk AS rk
          INNER JOIN dfkkrp AS rp ON rp~keyr1 = rk~keyr1
          WHERE rk~erdat <= @iv_created_to
            AND rk~stars NOT IN @it_done
          GROUP BY rk~keyr1, rp~bukrs, rp~waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-returns ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~return_clarifications.
    " VERIFY V225: DFKKRP-XKLAE set = the return waits in clarification
    TRY.
        SELECT keyr1 AS object_id, bukrs AS company_code, waers AS currency,
               COUNT(*) AS item_count, SUM( betrr ) AS amount, MIN( budat ) AS oldest
          FROM dfkkrp
          WHERE xklae <> @space
            AND budat <= @iv_posted_to
          GROUP BY keyr1, bukrs, waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-returns ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~returns_without_document.
    " VERIFY V225: DFKKRP-RLBEL initial = no returns document yet (the reversal of the payment is pending)
    TRY.
        SELECT keyr1 AS object_id, bukrs AS company_code, waers AS currency,
               COUNT(*) AS item_count, SUM( betrr ) AS amount, MIN( budat ) AS oldest
          FROM dfkkrp
          WHERE rlbel = @space
            AND budat <= @iv_posted_to
          GROUP BY keyr1, bukrs, waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-returns ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~statement_days.
    " VERIFY V226: FEBKO-AZDAT is the statement date the business calendar expects (one statement per account
    " and working day)
    TRY.
        SELECT bukrs AS company_code, hbkid AS house_bank, hktid AS account_id, azdat AS statement_date,
               COUNT(*) AS statement_count
          FROM febko
          WHERE azdat BETWEEN @iv_from AND @iv_to
          GROUP BY bukrs, hbkid, hktid, azdat
          ORDER BY company_code, house_bank, account_id, statement_date
          INTO CORRESPONDING FIELDS OF TABLE @rt_days
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-statement ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~unposted_lines.
    " VERIFY V226: FEBEP-VB1OK set = the line is posted in posting area 1 (as S4_EBS_UNPOSTED, V129); FEBKO-EDATE
    " the import date
    TRY.
        SELECT ko~kukey AS object_id, ko~bukrs AS company_code, ko~hbkid AS house_bank, ko~hktid AS account_id,
               ep~kwaer AS currency, COUNT(*) AS item_count, SUM( ep~kwbtr ) AS amount, MIN( ko~azdat ) AS oldest
          FROM febko AS ko
          INNER JOIN febep AS ep ON ep~kukey = ko~kukey
          WHERE ko~edate <= @iv_imported_to
            AND ep~vb1ok = @space
          GROUP BY ko~kukey, ko~bukrs, ko~hbkid, ko~hktid, ep~kwaer
          ORDER BY oldest, object_id, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-statement ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~lines_not_in_fica.
    " VERIFY V227: a statement transferred to FI-CA has a payment lot with its KUKEY (DFKKZK-KUKEY)
    TRY.
        SELECT ko~kukey AS object_id, ko~bukrs AS company_code, ko~hbkid AS house_bank, ko~hktid AS account_id,
               ep~kwaer AS currency, COUNT(*) AS item_count, SUM( ep~kwbtr ) AS amount, MIN( ko~azdat ) AS oldest
          FROM febko AS ko
          INNER JOIN febep AS ep ON ep~kukey = ko~kukey
          WHERE ko~hbkid IN @it_banks
            AND ko~edate <= @iv_imported_to
            AND NOT EXISTS ( SELECT keyz1 FROM dfkkzk WHERE kukey = ko~kukey )
          GROUP BY ko~kukey, ko~bukrs, ko~hbkid, ko~hktid, ep~kwaer
          ORDER BY oldest, object_id, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-to_fica ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~paid_clearing_resets.
    " VERIFY V228: DFKKRAPT = items whose clearing was reset (STDAT reset date, AUGBL the clearing document);
    " DPAYH-DOC1R = the payment document that cleared the item (as DFKKOP-AUGBL, confirmed in the repository)
    TRY.
        SELECT ra~augbl AS object_id, ra~bukrs AS company_code, ra~waers AS currency,
               COUNT(*) AS item_count, SUM( ra~betrw ) AS amount, MIN( ra~stdat ) AS oldest
          FROM dfkkrapt AS ra
          WHERE ra~stdat >= @iv_reset_from
            AND ra~augrd IN @it_augrd
            AND EXISTS ( SELECT doc1r FROM dpayh WHERE doc1r = ra~augbl AND xvorl = @space )
          GROUP BY ra~augbl, ra~bukrs, ra~waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-resets ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~reversed_payments.
    " Reversal direction (seen on the reference system): the ORIGINAL document points to its reversal through
    " DFKKKO-STORB; STBEL is filled on the reversal document and names the original (never STBEL on the original).
    " Both joins on the key OPBEL; the reversal's entry date CPUDT is the event (VERIFY V228)
    TRY.
        SELECT p~doc1r AS object_id, concat( p~laufd, p~laufi ) AS object_sub, p~bbukr AS company_code,
               p~waers AS currency, COUNT(*) AS item_count, SUM( p~rwbtr ) AS amount, MIN( rv~cpudt ) AS oldest
          FROM dpayh AS p
          INNER JOIN dfkkko AS ko ON ko~opbel = p~doc1r
          INNER JOIN dfkkko AS rv ON rv~opbel = ko~storb
          WHERE p~xvorl  =  @space
            AND p~doc1r  <> @space
            AND ko~storb <> @space
            AND rv~cpudt >= @iv_reversed_from
          GROUP BY p~doc1r, p~laufd, p~laufi, p~bbukr, p~waers
          ORDER BY oldest, object_id, object_sub, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-reversals ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~open_keys.
    " VERIFY V229: DFKKSUMC-XCLOS set = the key is closed, CPUDT its creation; totals DFKKSUM per company code and
    " currency, the debit side (SHKZG not H) as the key's gross volume (DFKKSUM index 1: FIKEY, BUKRS, BUDAT)
    TRY.
        SELECT c~fikey AS object_id, s~bukrs AS company_code, s~waers AS currency,
               COUNT(*) AS item_count, SUM( abs( s~betrw ) ) AS amount, MIN( c~cpudt ) AS oldest
          FROM dfkksumc AS c
          INNER JOIN dfkksum AS s ON s~fikey = c~fikey
          WHERE c~xclos =  @space
            AND c~cpudt <= @iv_created_to
            AND s~shkzg <> @zif_ca_ops_cash_types=>gc_shkzg_credit
          GROUP BY c~fikey, s~bukrs, s~waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-keys ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~error_keys.
    " VERIFY V229: DFKKSUMC-XERRO set = the transfer of the key to the G/L ended in error
    TRY.
        SELECT c~fikey AS object_id, s~bukrs AS company_code, s~waers AS currency,
               COUNT(*) AS item_count, SUM( abs( s~betrw ) ) AS amount, MIN( c~cpudt ) AS oldest
          FROM dfkksumc AS c
          INNER JOIN dfkksum AS s ON s~fikey = c~fikey
          WHERE c~xerro <> @space
            AND s~shkzg <> @zif_ca_ops_cash_types=>gc_shkzg_credit
          GROUP BY c~fikey, s~bukrs, s~waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-keys ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~keys_not_in_gl.
    DATA lv_awtyp TYPE c LENGTH 5.
    lv_awtyp = iv_awtyp.
    " Confirmed path in the repository: DFKKSUM-FIKEY = BKPF-AWKEY of the G/L transfer document; reference type
    " CASH_GL_AWTYP (VERIFY V229); an unreversed document of the company code closes the gap
    TRY.
        SELECT c~fikey AS object_id, s~bukrs AS company_code, s~waers AS currency,
               COUNT(*) AS item_count, SUM( abs( s~betrw ) ) AS amount, MIN( c~cldat ) AS oldest
          FROM dfkksumc AS c
          INNER JOIN dfkksum AS s ON s~fikey = c~fikey
          WHERE c~xclos <> @space
            AND c~cldat <= @iv_closed_to
            AND s~shkzg <> @zif_ca_ops_cash_types=>gc_shkzg_credit
            AND NOT EXISTS ( SELECT accountingdocument FROM zi_ca_opscashjrnl
                               WHERE referencedocumenttype     = @lv_awtyp
                                 AND originalreferencedocument = s~fikey
                                 AND companycode               = s~bukrs
                                 AND reversedocument           = @space )
          GROUP BY c~fikey, s~bukrs, s~waers
          ORDER BY oldest, object_id, company_code, currency
          INTO CORRESPONDING FIELDS OF TABLE @rt_sums
          UP TO @iv_max ROWS.
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        read_failed( iv_source = zif_ca_ops_cash_types=>gc_source-journal ix_error = lx_sql ).
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~owner.
    " The precedence of ZI_CA_OpsCheckTeam for GROUP2 = check ID: active controls covering the check, first by ID
    SELECT ctl~control_id, ctl~owner, ctl~backup, ctl~team, ctl~cutoff_time
      FROM zca_ops_ctlchk AS chk
      INNER JOIN zca_ops_control AS ctl ON  ctl~area       = chk~area
                                        AND ctl~control_id = chk~control_id
      WHERE chk~check_area  = @iv_area
        AND chk~match_field = @zif_ca_ops_ctl_types=>gc_match_field-group2
        AND chk~match_value = @iv_check_id
        AND ctl~active      = @abap_true
      ORDER BY ctl~control_id
      INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_controls)
      UP TO 1 ROWS.
    IF lt_controls IS NOT INITIAL.
      rs_owner = CORRESPONDING #( lt_controls[ 1 ] ).
    ENDIF.
    IF rs_owner-owner IS INITIAL AND iv_process_id IS NOT INITIAL.
      SELECT SINGLE owner, backup
        FROM zca_ops_proc
        WHERE area       = @iv_area
          AND process_id = @iv_process_id
        INTO (@rs_owner-owner, @rs_owner-backup).
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_cash_dao~working_day.
    DATA lv_indicator TYPE c LENGTH 1.
    DATA lv_factory_date TYPE scal-facdate.
    DATA lv_calendar TYPE c LENGTH 2.
    DATA lv_subrc TYPE sysubrc.

    lv_calendar = iv_calendar.
    " VERIFY V230: parameter names of DATE_CONVERT_TO_FACTORYDATE (SE37); indicator blank on a working day
    TEST-SEAM factory_date.
      CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
        EXPORTING
          correct_option       = '+'
          date                 = iv_date
          factory_calendar_id  = lv_calendar
        IMPORTING
          factorydate          = lv_factory_date
          workingday_indicator = lv_indicator
        EXCEPTIONS
          error_message        = 98
          OTHERS               = 99.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e522(zca_ops) WITH iv_calendar iv_date.
    ENDIF.
    rv_working = xsdbool( lv_indicator IS INITIAL ).
  ENDMETHOD.


  METHOD read_failed.
    RAISE EXCEPTION TYPE zcx_ca_ops_error
      MESSAGE e521(zca_ops) WITH iv_source
      EXPORTING
        previous = ix_error.
  ENDMETHOD.


  METHOD like_pattern.
    rv_like = replace( val = condense( iv_pattern ) pcre = `[#%_]` with = `#$0` occ = 0 ).
    rv_like = replace( val = rv_like sub = zif_ca_ops_cash_types=>gc_job_mask with = `%` occ = 0 ).
  ENDMETHOD.

ENDCLASS.
