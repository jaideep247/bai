*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_runtime_dao.clas.abap
*& Purpose:
*& SQL of the runtime checks of the morning report: NRIV intervals by
*& object (internal intervals, current / next year), queue entries grouped
*& per queue / destination / state / day (table and field names validated
*& against the runtime DDIC and, for a configured table, ZCD_HCK_TABWL),
*& DPAYH payments in a run-date window with the collection indicator of
*& their method (TFK042Z via T001), G/L lines by XREF2 (BSEG) and the
*& active rows of the in-flight configuration (ZCD_HCK_PMCLASS, _CLRRULE,
*& _PMBANK, _BTCROLE, _SEQOUT).
*& Every read is keyed or window-bounded and capped. Read-only: no INSERT
*& / UPDATE / DELETE, no lock, no queue or interval is changed.
*& Unconfirmed names: VERIFY-DDIC (Release_Readiness.md).
*& Modification log:
*& 2026-11-07 | Initial version (checks E_NUMRANGE, E_QUEUES, A_INFLIGHT).
*& 2026-11-07 | BSAS assignment read replaced by BSEG XREF2; in-flight configuration reads.
*& 2026-11-07 | get_issued_payments_by_doc: payment runs by payment document (canonical payment
*&            | outcome, trace and 5-minute snapshot); one join for both reads.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - runtime reads (SQL)</p>
CLASS zcl_cd_hck_runtime_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao.

  PRIVATE SECTION.
    "! Fragments of the dynamic queue statement (aliases = components of TY_QUEUE_GROUP)
    CONSTANTS:
      BEGIN OF gc_sql,
        as_name    TYPE string VALUE ` AS name`,
        as_dest    TYPE string VALUE ` AS dest`,
        as_state   TYPE string VALUE ` AS state`,
        as_date    TYPE string VALUE ` AS qdate`,
        min_open   TYPE string VALUE `MIN( `,
        as_time    TYPE string VALUE ` ) AS qtime`,
        count_rows TYPE string VALUE `COUNT(*) AS entries`,
        separator  TYPE string VALUE `, `,
        as_ref     TYPE string VALUE ` AS ref`,
        as_rtype   TYPE string VALUE ` AS rtype`,
        as_amount  TYPE string VALUE ` AS amount`,
        as_curr    TYPE string VALUE ` AS currency`,
        as_grp     TYPE string VALUE ` AS grp`,
        as_rdate   TYPE string VALUE ` AS rdate`,
        as_status  TYPE string VALUE ` AS status`,
        eq_ref     TYPE string VALUE ` = @IT_REFS-TABLE_LINE`,
      END OF gc_sql.

    "! A validated column with its alias; nothing when the role has no field
    METHODS add_column
      IMPORTING
        iv_name   TYPE string
        iv_alias  TYPE string
      CHANGING
        ct_select TYPE string_table.

    "! Validated field of a queue source (upper case); blank when the role is not used
    METHODS checked_field
      IMPORTING
        iv_field       TYPE zif_cd_hck_types=>ty_fieldname
        iv_tabname     TYPE zif_cd_hck_types=>ty_tabname
        it_fields      TYPE zif_cd_hck_types=>tt_field
        iv_type_kind   TYPE zif_cd_hck_types=>ty_type_kind OPTIONAL
      RETURNING
        VALUE(rv_name) TYPE string
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS zcl_cd_hck_runtime_dao IMPLEMENTATION.

  METHOD zif_cd_hck_runtime_dao~get_number_ranges.
    DATA lt_objects TYPE RANGE OF zif_cd_hck_runtime_types=>ty_nr_object.
    " An empty range would read every object: nothing configured = nothing read
    IF it_objects IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    lt_objects = VALUE #( FOR lv_object IN it_objects ( sign   = zif_cd_ops_types=>gc_range-sign_include
                                                    option = zif_cd_ops_types=>gc_range-option_equal
                                                    low    = lv_object ) ).
    " VERIFY-DDIC: NRIV-OBJECT, SUBOBJECT, NRRANGENR, TOYEAR, FROMNUMBER, TONUMBER, NRLEVEL,
    " EXTERNIND (standard number range intervals, key OBJECT / SUBOBJECT / NRRANGENR / TOYEAR)
    SELECT object, subobject, nrrangenr, toyear, fromnumber, tonumber, nrlevel
      FROM nriv
      WHERE object IN @lt_objects
        AND externind = @space
        AND ( toyear = @zif_cd_hck_runtime_types=>gc_nr_no_year
              OR toyear BETWEEN @iv_year_from AND @iv_year_to )
      ORDER BY object, subobject, nrrangenr, toyear
      INTO CORRESPONDING FIELDS OF TABLE @rt_intervals
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_queue_groups.
    DATA lt_select TYPE string_table.
    DATA lt_group TYPE string_table.
    IF iv_max_rows <= 0.
      RETURN.
    ENDIF.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lv_tabname) = CONV zif_cd_hck_types=>ty_tabname( to_upper( condense( is_source-tabname ) ) ).
    " A configured table name (bgRFC) passes the security boundary of the health check first
    IF is_source-configured = abap_true AND lo_dao->is_table_whitelisted( lv_tabname ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e302(zcd_ops) WITH lv_tabname.
    ENDIF.
    DATA(lt_fields) = lo_dao->get_table_fields( lv_tabname ).
    DATA(lv_name)  = checked_field( iv_field = is_source-name_field iv_tabname = lv_tabname it_fields = lt_fields ).
    DATA(lv_dest)  = checked_field( iv_field = is_source-dest_field iv_tabname = lv_tabname it_fields = lt_fields ).
    DATA(lv_state) = checked_field( iv_field = is_source-state_field iv_tabname = lv_tabname it_fields = lt_fields ).
    DATA(lv_date)  = checked_field( iv_field     = is_source-date_field
                                    iv_tabname   = lv_tabname
                                    it_fields    = lt_fields
                                    iv_type_kind = cl_abap_typedescr=>typekind_date ).
    DATA(lv_time)  = checked_field( iv_field     = is_source-time_field
                                    iv_tabname   = lv_tabname
                                    it_fields    = lt_fields
                                    iv_type_kind = cl_abap_typedescr=>typekind_time ).
    " The queue name and the day are required: without them nothing can be grouped or aged
    IF lv_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e304(zcd_ops) WITH is_source-name_field lv_tabname.
    ENDIF.
    IF lv_date IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e323(zcd_ops) WITH lv_tabname.
    ENDIF.

    INSERT |{ lv_name }{ gc_sql-as_name }| INTO TABLE lt_select.
    INSERT lv_name INTO TABLE lt_group.
    IF lv_dest IS NOT INITIAL.
      INSERT |{ lv_dest }{ gc_sql-as_dest }| INTO TABLE lt_select.
      INSERT lv_dest INTO TABLE lt_group.
    ENDIF.
    IF lv_state IS NOT INITIAL.
      INSERT |{ lv_state }{ gc_sql-as_state }| INTO TABLE lt_select.
      INSERT lv_state INTO TABLE lt_group.
    ENDIF.
    INSERT |{ lv_date }{ gc_sql-as_date }| INTO TABLE lt_select.
    INSERT lv_date INTO TABLE lt_group.
    IF lv_time IS NOT INITIAL.
      INSERT |{ gc_sql-min_open }{ lv_time }{ gc_sql-as_time }| INTO TABLE lt_select.
    ENDIF.
    INSERT gc_sql-count_rows INTO TABLE lt_select.

    DATA(lv_select) = concat_lines_of( table = lt_select sep = gc_sql-separator ).
    DATA(lv_groups) = concat_lines_of( table = lt_group sep = gc_sql-separator ).
    DATA(lv_from)   = CONV string( lv_tabname ).
    " Names are DDIC-checked identifiers; no value of the statement comes from input
    TRY.
        SELECT (lv_select)
          FROM (lv_from)
          GROUP BY (lv_groups)
          ORDER BY (lv_groups)
          INTO CORRESPONDING FIELDS OF TABLE @rt_groups
          UP TO @iv_max_rows ROWS.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e308(zcd_ops) WITH lv_tabname is_source-kind
          EXPORTING
            previous = lx_error.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_issued_payments.
    DATA lt_methods TYPE RANGE OF zif_cd_hck_runtime_types=>ty_pymet.
    IF it_methods IS INITIAL OR iv_max_rows <= 0.
      RETURN.
    ENDIF.
    lt_methods = VALUE #( FOR lv_method IN it_methods ( sign   = zif_cd_ops_types=>gc_range-sign_include
                                                    option = zif_cd_ops_types=>gc_range-option_equal
                                                    low    = lv_method ) ).
    " Confirmed: DPAYH LAUFD / LAUFI / DOC1R (payment document = DFKKOP-AUGBL), TFK042Z-XEINZ
    " collections vs disbursements. VERIFY-DDIC: DPAYH-XVORL, BUKRS, PYMET, HBKID, VALUT, RWBTR, WAERS;
    " TFK042Z key LAND1 / ZLSCH via T001-LAND1 (as ZCL_CD_OPS_TRACE_DAO=>GET_METHOD_KIND).
    " Index: DPAYH by LAUFD (run date window) - performance check in QA1
    SELECT p~doc1r, p~laufd, p~laufi, p~bukrs, p~pymet, p~hbkid, p~valut,
           p~rwbtr AS amount, p~waers AS currency, z~xeinz
      FROM dpayh AS p
      INNER JOIN t001 AS t ON t~bukrs = p~bukrs
      INNER JOIN tfk042z AS z ON  z~land1 = t~land1
                              AND z~zlsch = p~pymet
      WHERE p~laufd BETWEEN @iv_from AND @iv_to
        AND p~xvorl = @space
        AND p~doc1r <> @space
        AND p~pymet IN @lt_methods
      ORDER BY p~laufd, p~laufi, p~doc1r
      INTO CORRESPONDING FIELDS OF TABLE @rt_payments
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_issued_payments_by_doc.
    CHECK it_docno IS NOT INITIAL.
    IF iv_max_rows <= 0.
      RETURN.
    ENDIF.
    " The join of GET_ISSUED_PAYMENTS by payment document (DPAYH-DOC1R = DFKKOP-AUGBL, confirmed);
    " DOC1R is not unique in DPAYH (re-runs): every run is returned, the caller picks the latest.
    " VERIFY-DDIC as GET_ISSUED_PAYMENTS; index on DPAYH-DOC1R expected (Performance_Review.md)
    SELECT p~doc1r, p~laufd, p~laufi, p~bukrs, p~pymet, p~hbkid, p~valut,
           p~rwbtr AS amount, p~waers AS currency, z~xeinz
      FROM dpayh AS p
      INNER JOIN t001 AS t ON t~bukrs = p~bukrs
      INNER JOIN tfk042z AS z ON  z~land1 = t~land1
                              AND z~zlsch = p~pymet
      FOR ALL ENTRIES IN @it_docno
      WHERE p~doc1r = @it_docno-table_line
        AND p~xvorl = @space
      INTO CORRESPONDING FIELDS OF TABLE @rt_payments.
    SORT rt_payments BY doc1r laufd DESCENDING laufi DESCENDING.
    DATA(lv_first_over) = iv_max_rows + 1.
    IF lines( rt_payments ) >= lv_first_over.
      DELETE rt_payments FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_gl_lines_by_xref2.
    DATA lt_hkont TYPE RANGE OF zif_cd_hck_runtime_types=>ty_hkont.
    CHECK it_keys IS NOT INITIAL.
    IF iv_max_rows <= 0.
      RETURN.
    ENDIF.
    " Empty account list = no account restriction (documented: PARAM1 of the evidence rule)
    lt_hkont = VALUE #( FOR lv_hkont IN it_hkont ( sign   = zif_cd_ops_types=>gc_range-sign_include
                                                   option = zif_cd_ops_types=>gc_range-option_equal
                                                   low    = lv_hkont ) ).
    " User rule 3 (2026-11-07): collection cleared = BSEG line with XREF2 = AUGBL whose AUGBL is
    " filled (XREF2 is the stable key: Stripe payout processing overwrites ZUONR with the statement
    " descriptor). Bounded by company code, fiscal year window and XREF2 key set (FOR ALL ENTRIES);
    " BSEG has no index on XREF2 - access path VERIFY in a QA1 SQL trace (Performance_Review.md):
    " secondary index BUKRS / XREF2 or the G/L clearing accounts in PARAM1 of the rule
    SELECT bukrs, belnr, gjahr, buzei, xref2, zuonr, augbl
      FROM bseg
      FOR ALL ENTRIES IN @it_keys
      WHERE bukrs = @it_keys-bukrs
        AND xref2 = @it_keys-xref2
        AND gjahr BETWEEN @iv_gjahr_from AND @iv_gjahr_to
        AND hkont IN @lt_hkont
      INTO CORRESPONDING FIELDS OF TABLE @rt_lines.
    SORT rt_lines BY bukrs xref2 gjahr belnr buzei.
    DATA(lv_first_over) = iv_max_rows + 1.
    IF lines( rt_lines ) >= lv_first_over.
      DELETE rt_lines FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_pm_classes.
    SELECT flow, method_class, pay_methods, age_basis, calendar, description
      FROM zcd_hck_pmclass
      WHERE active = @abap_true
      ORDER BY flow, method_class
      INTO CORRESPONDING FIELDS OF TABLE @rt_classes.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_pm_banks.
    SELECT flow, method_class, hbkid, calendar
      FROM zcd_hck_pmbank
      WHERE active = @abap_true
      ORDER BY flow, method_class, hbkid
      INTO CORRESPONDING FIELDS OF TABLE @rt_banks.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_evidence_settings.
    SELECT name, value
      FROM zcd_hck_evset
      WHERE set_id = @iv_set_id
        AND active = @abap_true
      ORDER BY name
      INTO CORRESPONDING FIELDS OF TABLE @rt_settings.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_reference_rows.
    DATA lt_select TYPE string_table.
    CHECK it_refs IS NOT INITIAL.
    IF iv_max_rows <= 0.
      RETURN.
    ENDIF.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lv_tabname) = CONV zif_cd_hck_types=>ty_tabname( to_upper( condense( is_source-tabname ) ) ).
    " A configured table name passes the security boundary of the health check first
    IF lo_dao->is_table_whitelisted( lv_tabname ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e302(zcd_ops) WITH lv_tabname.
    ENDIF.
    DATA(lt_fields) = lo_dao->get_table_fields( lv_tabname ).
    DATA(lv_ref) = checked_field( iv_field = is_source-ref_field iv_tabname = lv_tabname it_fields = lt_fields ).
    IF lv_ref IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e304(zcd_ops) WITH is_source-ref_field lv_tabname.
    ENDIF.
    INSERT |{ lv_ref }{ gc_sql-as_ref }| INTO TABLE lt_select.
    add_column( EXPORTING iv_name   = checked_field( iv_field = is_source-type_field iv_tabname = lv_tabname it_fields = lt_fields )
                          iv_alias  = gc_sql-as_rtype
                CHANGING  ct_select = lt_select ).
    add_column( EXPORTING iv_name   = checked_field( iv_field = is_source-amount_field iv_tabname = lv_tabname it_fields = lt_fields )
                          iv_alias  = gc_sql-as_amount
                CHANGING  ct_select = lt_select ).
    add_column( EXPORTING iv_name   = checked_field( iv_field = is_source-currency_field iv_tabname = lv_tabname it_fields = lt_fields )
                          iv_alias  = gc_sql-as_curr
                CHANGING  ct_select = lt_select ).
    add_column( EXPORTING iv_name   = checked_field( iv_field = is_source-group_field iv_tabname = lv_tabname it_fields = lt_fields )
                          iv_alias  = gc_sql-as_grp
                CHANGING  ct_select = lt_select ).
    add_column( EXPORTING iv_name   = checked_field( iv_field     = is_source-date_field
                                                     iv_tabname   = lv_tabname
                                                     it_fields    = lt_fields
                                                     iv_type_kind = cl_abap_typedescr=>typekind_date )
                          iv_alias  = gc_sql-as_rdate
                CHANGING  ct_select = lt_select ).
    add_column( EXPORTING iv_name   = checked_field( iv_field = is_source-status_field iv_tabname = lv_tabname it_fields = lt_fields )
                          iv_alias  = gc_sql-as_status
                CHANGING  ct_select = lt_select ).
    DATA(lv_select) = concat_lines_of( table = lt_select sep = gc_sql-separator ).
    DATA(lv_from)   = CONV string( lv_tabname ).
    DATA(lv_where)  = |{ lv_ref }{ gc_sql-eq_ref }|.
    " Names are DDIC-checked identifiers; the reference values are bound (FOR ALL ENTRIES)
    TRY.
        SELECT (lv_select)
          FROM (lv_from)
          FOR ALL ENTRIES IN @it_refs
          WHERE (lv_where)
          INTO CORRESPONDING FIELDS OF TABLE @rt_rows.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e308(zcd_ops) WITH lv_tabname is_source-ref_field
          EXPORTING
            previous = lx_error.
    ENDTRY.
    SORT rt_rows BY ref rdate rtype.
    DATA(lv_first_over) = iv_max_rows + 1.
    IF lines( rt_rows ) >= lv_first_over.
      DELETE rt_rows FROM lv_first_over.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_clearing_rules.
    SELECT flow, method_class, purpose, seq, evidence_class, param1, param2, param3, required, description
      FROM zcd_hck_clrrule
      WHERE active = @abap_true
      ORDER BY flow, method_class, purpose, seq
      INTO CORRESPONDING FIELDS OF TABLE @rt_rules.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_btc_roles.
    SELECT flow, method_class, scheme, btc_code, role, compare_amount
      FROM zcd_hck_btcrole
      WHERE active = @abap_true
      ORDER BY flow, method_class, scheme, btc_code
      INTO CORRESPONDING FIELDS OF TABLE @rt_roles.
  ENDMETHOD.


  METHOD zif_cd_hck_runtime_dao~get_seq_outcomes.
    SELECT flow, method_class, seq, seq_pattern, outcome, expected_dfkkrp, max_age_days, severity, description,
           reg_state, finding
      FROM zcd_hck_seqout
      WHERE active = @abap_true
      ORDER BY flow, method_class, seq
      INTO CORRESPONDING FIELDS OF TABLE @rt_outcomes.
  ENDMETHOD.


  METHOD add_column.
    IF iv_name IS NOT INITIAL.
      INSERT |{ iv_name }{ iv_alias }| INTO TABLE ct_select.
    ENDIF.
  ENDMETHOD.


  METHOD checked_field.
    DATA(lv_field) = CONV zif_cd_hck_types=>ty_fieldname( to_upper( condense( iv_field ) ) ).
    IF lv_field IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_field) = VALUE #( it_fields[ fieldname = lv_field ] OPTIONAL ).
    IF ls_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e304(zcd_ops) WITH lv_field iv_tabname.
    ENDIF.
    IF iv_type_kind IS NOT INITIAL AND ls_field-type_kind <> iv_type_kind.
      IF iv_type_kind = cl_abap_typedescr=>typekind_date.
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e309(zcd_ops) WITH lv_field iv_tabname.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e394(zcd_ops) WITH lv_field iv_tabname.
    ENDIF.
    rv_name = lv_field.
  ENDMETHOD.

ENDCLASS.
