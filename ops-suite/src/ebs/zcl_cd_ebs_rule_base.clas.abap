*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_rule_base.clas.abap
*& Purpose:
*& Shared helpers for EBS rules: repository access through the factory, key
*& normalisation of bank references (lengths are parameters, not code),
*& parameter lists and statement lookup. Abstract: no behaviour of its own.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check register scoped to house bank account; DPAYH proposal runs excluded (review 3.2).
*& 2026-11-06 | House bank: statement without house bank matches only when one account is possible (audit 2026-11-06).
*& 2026-11-06 | Audit A25: account_key / account_of - one canonical account identity for all rules.
*& 2026-11-06 | Audit A07: company code in the register match; canonical check numbers (leading zeros).
*& 2026-11-06 | Audit A65: document keys checked against the DDIC key width and format before conversion (no truncation).
*& 2026-11-06 | FS-CD review: in-flight grace - not found within EBS_INFLIGHT_HOURS is AWAITING_LOT_TRANSFER (W, NOTIFY).
*& 2026-11-06 | Perf fix 1: DFKKCR read once per package (memo for R07C/R08/R12), rows canonicalised once (sorted index).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-07 | Parameters through ZCL_CD_OPS_FACTORY=>GET_PARAMS (ZIF_CA_OPS_PARAMS).
*& 2026-11-07 | EBS_ZTNUM_IGNORE_ZEROS is BOOL in ZCA_PARAM (blank value row = off); default from
*&            | GC_PARAM_DEFAULT.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - rule base</p>
CLASS zcl_cd_ebs_rule_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_rule
      ABSTRACT METHODS execute.

    "! Default length of document-number keys (OPBEL/AUGBL/DOC1R): ZCA_PARAM EBS_KEYLEN_DOCNO
    CONSTANTS gc_default_docno_length TYPE i VALUE 12.

    "! Default length of check-number keys: 0 = as delivered (ZCA_PARAM EBS_KEYLEN_ZTNUM)
    CONSTANTS gc_default_ztnum_length TYPE i VALUE 0.

    "! In-flight grace in hours when EBS_INFLIGHT_HOURS is not maintained: off
    CONSTANTS gc_default_inflight_hours TYPE i VALUE 0.
    CONSTANTS gc_seconds_per_hour TYPE i VALUE 3600.
    CONSTANTS gc_seconds_per_day TYPE i VALUE 86400.

    "! A65: characters a document-number key may contain (checked before conversion)
    CONSTANTS gc_key_alphabet TYPE string VALUE `0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ`.

    "! Performance fix 1: forget the check-register rows read for the current package. Called
    "! by the EBS injector (test isolation); a new package (other statement keys) clears it too
    CLASS-METHODS clear_memo.

  PROTECTED SECTION.
    TYPES tt_stmt_hash TYPE HASHED TABLE OF zif_cd_ebs_types=>ty_statement WITH UNIQUE KEY stmt_key.

    "! Register row with its canonical check number and account, computed once per row
    TYPES:
      BEGIN OF ty_register_row,
        canonical TYPE string,
        account   TYPE string,
        check     TYPE zif_cd_ebs_sap_dao=>ty_check,
      END OF ty_register_row.
    "! Non-unique sorted key: rows of one canonical number keep their read order
    TYPES tt_register_row TYPE SORTED TABLE OF ty_register_row WITH NON-UNIQUE KEY canonical.

    "! Check register of a line rule call: rows indexed by canonical number, the statements
    "! by key, and the two parameters that shape a check-number key (read once per call)
    TYPES:
      BEGIN OF ty_register,
        ztnum_length TYPE i,
        ignore_zeros TYPE abap_bool,
        statements   TYPE tt_stmt_hash,
        rows         TYPE tt_register_row,
      END OF ty_register.

    "! Register rows of one bank line: its check-number key, HOUSE_BANK_AMBIGUOUS and the
    "! rows scoped to the statement's house bank account (none when ambiguous)
    TYPES:
      BEGIN OF ty_register_match,
        ztnum     TYPE zif_cd_ebs_sap_dao=>ty_ztnum,
        ambiguous TYPE abap_bool,
        checks    TYPE zif_cd_ebs_sap_dao=>tt_check,
      END OF ty_register_match.

    METHODS sap_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_sap_dao.

    METHODS feb_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_feb_dao.

    METHODS param
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE string OPTIONAL
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Bank reference -> payment engine document number key (FEBEP-CHECT = DFKKOP-AUGBL)
    METHODS docno_key
      IMPORTING
        iv_reference  TYPE clike
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ebs_sap_dao=>ty_docno.

    "! Bank reference -> check register key (DFKKCR-ZTNUM = FEBEP-CHECT; as-is by default)
    METHODS ztnum_key
      IMPORTING
        iv_reference  TYPE clike
      RETURNING
        VALUE(rv_key) TYPE zif_cd_ebs_sap_dao=>ty_ztnum.

    METHODS docno_keys
      IMPORTING
        it_lines       TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_ebs_sap_dao=>tt_docno.

    "! A65: width in characters of a key type - the DDIC-modelled key type is the only source
    METHODS key_width
      IMPORTING
        iv_key          TYPE simple
      RETURNING
        VALUE(rv_width) TYPE i.

    "! A65: why a reference cannot become a key of iv_width characters (check code), blank
    "! when it can: configured length above the width (KEY_LENGTH_CONFIG), normalised
    "! reference longer than the width (REF_TOO_LONG - never truncated into another key) or,
    "! with iv_alphanumeric, characters outside 0-9 / A-Z (REF_FORMAT)
    METHODS key_problem
      IMPORTING
        iv_reference         TYPE clike
        iv_length            TYPE i
        iv_width             TYPE i
        iv_alphanumeric      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_check_code) TYPE zif_ca_ops_types=>ty_check_code.

    "! A65: finding of the rule for a line whose reference cannot become the key; initial if it can
    METHODS key_rejection
      IMPORTING
        is_rule           TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_line           TYPE zif_cd_ebs_types=>ty_line
        iv_length         TYPE i
        iv_width          TYPE i
        iv_alphanumeric   TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! A65: key_rejection for the payment engine document number (OPBEL / AUGBL / DOC1R)
    METHODS docno_rejection
      IMPORTING
        is_rule           TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_line           TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! FS-CD review: the finding for a lookup that found nothing. While the statement is
    "! younger than EBS_INFLIGHT_HOURS (default 0 = off) the payment / returns lot can
    "! still be in transfer: the finding is then AWAITING_LOT_TRANSFER (W, NOTIFY, the
    "! original message in DETAILS), otherwise the rule's own not-found finding.
    METHODS not_found_finding
      IMPORTING
        is_rule           TYPE zif_cd_ebs_types=>ty_rule_cfg
        is_line           TYPE zif_cd_ebs_types=>ty_line
        it_statements     TYPE zif_cd_ebs_types=>tt_statement
        iv_check_code     TYPE zif_ca_ops_types=>ty_check_code
        iv_message        TYPE clike
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Age of the line's statement in seconds: from its creation date/time, else from the
    "! start of its statement date (the longest possible age); -1 = unknown
    METHODS statement_age
      IMPORTING
        is_line          TYPE zif_cd_ebs_types=>ty_line
        it_statements    TYPE zif_cd_ebs_types=>tt_statement
      RETURNING
        VALUE(rv_age) TYPE i.

    "! EBS_KEYLEN_DOCNO, default gc_default_docno_length
    METHODS docno_length
      RETURNING
        VALUE(rv_length) TYPE i.

    "! EBS_KEYLEN_ZTNUM, default 0 (as delivered)
    METHODS ztnum_length
      RETURNING
        VALUE(rv_length) TYPE i.

    "! Check-register query keys of the lines: every form a check number can take in DFKKCR -
    "! as delivered, without leading zeros and padded to EBS_KEYLEN_ZTNUM
    METHODS ztnum_query_keys
      IMPORTING
        it_lines       TYPE zif_cd_ebs_types=>tt_line
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_ebs_sap_dao=>tt_ztnum.

    "! Canonical check number: condensed; leading zeros removed from an all-digit number
    "! when iv_ignore_zeros is set (EBS_ZTNUM_IGNORE_ZEROS, default X - one rule for bank
    "! CHECT and DFKKCR-ZTNUM)
    METHODS ztnum_canonical
      IMPORTING
        iv_value        TYPE clike
        iv_ignore_zeros TYPE abap_bool
      RETURNING
        VALUE(rv_value) TYPE string.

    "! EBS_ZTNUM_IGNORE_ZEROS (default X)
    METHODS ztnum_ignore_zeros
      RETURNING
        VALUE(rv_ignore) TYPE abap_bool.

    "! Check register of the lines: DFKKCR rows of every form of their check numbers (read
    "! once per package, see register_rows), each canonicalised once
    METHODS check_register
      IMPORTING
        it_lines           TYPE zif_cd_ebs_types=>tt_line
        it_statements      TYPE zif_cd_ebs_types=>tt_statement
      RETURNING
        VALUE(rs_register) TYPE ty_register.

    "! Check register rows of one check number, scoped to the house bank account of the
    "! line's statement (ZTNUM is unique only per account). Statement without house bank:
    "! rows only when they all belong to one account, else AMBIGUOUS (the register rows
    "! cannot be attributed - rules report HOUSE_BANK_AMBIGUOUS). A register row without
    "! house bank is accepted: HBKID is part of the DFKKCR key (VERIFY-DDIC), so it is never blank
    METHODS register_match
      IMPORTING
        is_register     TYPE ty_register
        is_line         TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rs_match) TYPE ty_register_match.

    "! Comma list from a rule parameter, or the default list when the parameter is blank
    METHODS value_list
      IMPORTING
        iv_values      TYPE clike
        iv_default     TYPE string OPTIONAL
      RETURNING
        VALUE(rt_list) TYPE string_table.

    METHODS in_list
      IMPORTING
        iv_value      TYPE clike
        it_list       TYPE string_table
      RETURNING
        VALUE(rv_hit) TYPE abap_bool.

    METHODS amount_param
      IMPORTING
        iv_value         TYPE clike
        iv_default       TYPE decfloat34 DEFAULT 0
      RETURNING
        VALUE(rv_amount) TYPE decfloat34.

    "! Rule tolerance; 0.00 when not configured
    METHODS tolerance
      IMPORTING
        is_rule             TYPE zif_cd_ebs_types=>ty_rule_cfg
      RETURNING
        VALUE(rv_tolerance) TYPE zif_ca_ops_types=>ty_amount.

    METHODS line_reference
      IMPORTING
        is_line             TYPE zif_cd_ebs_types=>ty_line
      RETURNING
        VALUE(rv_reference) TYPE zif_cd_ebs_types=>ty_text35.

    "! A25: canonical account identity of a statement - SAP house bank account
    "! (company code / house bank / account ID) when known, else the bank account number
    METHODS account_key
      IMPORTING
        is_statement  TYPE zif_cd_ebs_types=>ty_statement
      RETURNING
        VALUE(rv_key) TYPE string.

    "! A25 / A33: configured account of a statement - house bank identity first, then account number
    METHODS account_of
      IMPORTING
        it_accounts       TYPE zif_cd_ebs_types=>tt_account_cfg
        is_statement      TYPE zif_cd_ebs_types=>ty_statement
      RETURNING
        VALUE(rs_account) TYPE zif_cd_ebs_types=>ty_account_cfg.


    "! Identity of a package for package memos (fixes 1, 2): its statement keys in order
    METHODS package_fingerprint
      IMPORTING
        it_statements         TYPE zif_cd_ebs_types=>tt_statement
      RETURNING
        VALUE(rv_fingerprint) TYPE string.

  PRIVATE SECTION.
    TYPES tt_ztnum_hash TYPE HASHED TABLE OF zif_cd_ebs_sap_dao=>ty_ztnum WITH UNIQUE KEY table_line.

    "! Performance fix 1: DFKKCR rows already read for the current package, shared by every
    "! check rule (R07C, R08, R12 run on the same lines of a rule group). A key is read once
    "! per package; rows keep the order the repository returned them in
    CLASS-DATA gv_memo_package TYPE string.
    CLASS-DATA gt_memo_keys TYPE tt_ztnum_hash.
    CLASS-DATA gt_memo_checks TYPE zif_cd_ebs_sap_dao=>tt_check.

    "! DFKKCR rows of the query keys - exactly the rows one get_checks( it_ztnum ) returns,
    "! but keys already read in this package are served from the memo
    METHODS register_rows
      IMPORTING
        it_ztnum         TYPE zif_cd_ebs_sap_dao=>tt_ztnum
        it_statements    TYPE zif_cd_ebs_types=>tt_statement
      RETURNING
        VALUE(rt_checks) TYPE zif_cd_ebs_sap_dao=>tt_check.

ENDCLASS.



CLASS zcl_cd_ebs_rule_base IMPLEMENTATION.

  METHOD clear_memo.
    CLEAR: gv_memo_package, gt_memo_keys, gt_memo_checks.
  ENDMETHOD.


  METHOD sap_dao.
    ro_dao = zcl_cd_ebs_factory=>get_sap_dao( ).
  ENDMETHOD.


  METHOD feb_dao.
    ro_dao = zcl_cd_ebs_factory=>get_feb_dao( ).
  ENDMETHOD.


  METHOD param.
    rv_value = zcl_cd_ops_factory=>get_params( )->get_param( iv_name = iv_name iv_default = iv_default ).
  ENDMETHOD.


  METHOD docno_key.
    " A65: an overlength or malformed reference yields no key - it is never truncated
    DATA(lv_length) = docno_length( ).
    IF key_problem( iv_reference    = iv_reference
                    iv_length       = lv_length
                    iv_width        = key_width( rv_key )
                    iv_alphanumeric = abap_true ) IS NOT INITIAL.
      RETURN.
    ENDIF.
    rv_key = zcl_cd_ops_util=>normalize_key( iv_reference = iv_reference iv_length = lv_length ).
  ENDMETHOD.


  METHOD ztnum_key.
    rv_key = zcl_cd_ops_util=>normalize_key( iv_reference = iv_reference iv_length = ztnum_length( ) ).
  ENDMETHOD.


  METHOD docno_length.
    rv_length = CONV i( zcl_ca_ops_util=>to_decimal(
      iv_value   = param( iv_name = zif_cd_ebs_types=>gc_param-keylen_docno iv_default = |{ gc_default_docno_length }| )
      iv_default = gc_default_docno_length ) ).
  ENDMETHOD.


  METHOD ztnum_length.
    rv_length = CONV i( zcl_ca_ops_util=>to_decimal(
      iv_value = param( iv_name = zif_cd_ebs_types=>gc_param-keylen_ztnum iv_default = |{ gc_default_ztnum_length }| ) ) ).
  ENDMETHOD.


  METHOD key_width.
    rv_width = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_data( iv_key ) )->output_length.
  ENDMETHOD.


  METHOD key_problem.
    IF iv_length > iv_width.
      rv_check_code = zif_cd_ebs_types=>gc_check_code-key_length_config.
      RETURN.
    ENDIF.
    DATA(lv_key) = zcl_cd_ops_util=>normalize_key( iv_reference = iv_reference iv_length = iv_length ).
    IF strlen( lv_key ) > iv_width.
      rv_check_code = zif_cd_ebs_types=>gc_check_code-ref_too_long.
    ELSEIF iv_alphanumeric = abap_true AND lv_key IS NOT INITIAL AND lv_key CN gc_key_alphabet.
      rv_check_code = zif_cd_ebs_types=>gc_check_code-ref_format.
    ENDIF.
  ENDMETHOD.


  METHOD key_rejection.
    DATA(lv_reference) = line_reference( is_line ).
    IF lv_reference IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_problem) = key_problem( iv_reference    = lv_reference
                                    iv_length       = iv_length
                                    iv_width        = iv_width
                                    iv_alphanumeric = iv_alphanumeric ).
    IF lv_problem IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_key) = zcl_cd_ops_util=>normalize_key( iv_reference = lv_reference iv_length = iv_length ).
    DATA(lv_key_length) = strlen( lv_key ).
    DATA(lv_message) = SWITCH string(
      lv_problem
      WHEN zif_cd_ebs_types=>gc_check_code-key_length_config
      THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-key_length_config
                                  iv_v1    = iv_length
                                  iv_v2    = iv_width )
      WHEN zif_cd_ebs_types=>gc_check_code-ref_too_long
      THEN zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ref_too_long
                                  iv_v1    = lv_key
                                  iv_v2    = lv_key_length
                                  iv_v3    = iv_width )
      ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ref_format
                                  iv_v1    = lv_key ) ).
    rs_finding = zcl_cd_ebs_finding=>for_rule_line( is_rule       = is_rule
                                                     is_line       = is_line
                                                     iv_check_code = lv_problem
                                                     iv_message    = lv_message ).
  ENDMETHOD.


  METHOD not_found_finding.
    DATA(lv_hours) = CONV i( zcl_ca_ops_util=>to_decimal(
      iv_value   = param( iv_name = zif_cd_ebs_types=>gc_param-inflight_hours iv_default = |{ gc_default_inflight_hours }| )
      iv_default = gc_default_inflight_hours ) ).
    DATA(lv_age) = COND i( WHEN lv_hours > 0 THEN statement_age( is_line = is_line it_statements = it_statements )
                           ELSE -1 ).
    IF lv_age < 0 OR lv_age >= lv_hours * gc_seconds_per_hour.
      rs_finding = zcl_cd_ebs_finding=>for_rule_line( is_rule       = is_rule
                                                       is_line       = is_line
                                                       iv_check_code = iv_check_code
                                                       iv_message    = iv_message ).
      RETURN.
    ENDIF.
    rs_finding = zcl_cd_ebs_finding=>for_rule_line(
                   is_rule       = is_rule
                   is_line       = is_line
                   iv_check_code = zif_cd_ebs_types=>gc_check_code-awaiting_lot_transfer
                   iv_message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-awaiting_lot_transfer
                                                          iv_v1    = zcl_cd_ebs_finding=>line_key( is_line )
                                                          iv_v2    = iv_check_code
                                                          iv_v3    = lv_hours )
                   iv_details    = CONV #( iv_message ) ).
    rs_finding-severity = zif_ca_ops_types=>gc_severity-warning.
    rs_finding-action   = zif_ca_ops_types=>gc_action-notify.
  ENDMETHOD.


  METHOD statement_age.
    rv_age = -1.
    DATA(ls_statement) = VALUE #( it_statements[ stmt_key = is_line-stmt_key ] OPTIONAL ).
    DATA(lv_date) = COND d( WHEN ls_statement-created_date IS NOT INITIAL THEN ls_statement-created_date
                            ELSE ls_statement-stmt_date ).
    IF lv_date IS INITIAL.
      RETURN.
    ENDIF.
    " VERIFY: FEBKO / bank file creation times are system local time, like the clock's today/time
    DATA(lv_time) = COND t( WHEN ls_statement-created_date IS NOT INITIAL THEN ls_statement-created_time ).
    DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).
    rv_age = ( lo_clock->today( ) - lv_date ) * gc_seconds_per_day + ( lo_clock->time( ) - lv_time ).
    " A creation time in the future is treated as just created
    rv_age = nmax( val1 = rv_age val2 = 0 ).
  ENDMETHOD.


  METHOD docno_rejection.
    DATA lv_docno TYPE zif_cd_ebs_sap_dao=>ty_docno.
    rs_finding = key_rejection( is_rule         = is_rule
                                is_line         = is_line
                                iv_length       = docno_length( )
                                iv_width        = key_width( lv_docno )
                                iv_alphanumeric = abap_true ).
  ENDMETHOD.


  METHOD ztnum_query_keys.
    " Parameters read once per call, not once per line
    DATA(lv_length) = ztnum_length( ).
    DATA(lv_ignore_zeros) = ztnum_ignore_zeros( ).
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      DATA(lv_reference) = condense( CONV string( line_reference( <ls_line> ) ) ).
      IF lv_reference IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT CONV zif_cd_ebs_sap_dao=>ty_ztnum( lv_reference ) INTO TABLE rt_keys.
      " = ztnum_key( lv_reference ) with the length read above
      DATA(lv_key) = CONV zif_cd_ebs_sap_dao=>ty_ztnum(
        zcl_cd_ops_util=>normalize_key( iv_reference = lv_reference iv_length = lv_length ) ).
      INSERT lv_key INTO TABLE rt_keys.
      INSERT CONV zif_cd_ebs_sap_dao=>ty_ztnum( ztnum_canonical( iv_value        = lv_reference
                                                                 iv_ignore_zeros = lv_ignore_zeros ) ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD ztnum_canonical.
    rv_value = condense( CONV string( iv_value ) ).
    IF iv_ignore_zeros = abap_true AND rv_value CO zif_cd_ebs_types=>gc_digits.
      SHIFT rv_value LEFT DELETING LEADING '0'.
    ENDIF.
  ENDMETHOD.


  METHOD ztnum_ignore_zeros.
    rv_ignore = xsdbool( param( iv_name    = zif_cd_ebs_types=>gc_param-ztnum_ignore_zeros
                                iv_default = zif_cd_ebs_types=>gc_param_default-ztnum_ignore_zeros ) = abap_true ).
  ENDMETHOD.


  METHOD check_register.
    DATA ls_row TYPE ty_register_row.
    rs_register-ztnum_length = ztnum_length( ).
    rs_register-ignore_zeros = ztnum_ignore_zeros( ).
    " First statement of a key wins, as it_statements[ stmt_key = ... ] did (no duplicate-key dump)
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      INSERT <ls_statement> INTO TABLE rs_register-statements.
    ENDLOOP.
    " Every form the check number can take in the register (leading zeros)
    DATA(lt_checks) = register_rows( it_ztnum      = ztnum_query_keys( it_lines )
                                     it_statements = it_statements ).
    " Each register row is canonicalised once (not once per bank line)
    LOOP AT lt_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      ls_row-canonical = ztnum_canonical( iv_value        = <ls_check>-ztnum
                                          iv_ignore_zeros = rs_register-ignore_zeros ).
      ls_row-account   = |{ <ls_check>-bukrs }/{ <ls_check>-hbkid }/{ <ls_check>-hktid }|.
      ls_row-check     = <ls_check>.
      INSERT ls_row INTO TABLE rs_register-rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD register_rows.
    DATA lt_missing TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    " A new package (other statement keys) starts a new memo
    DATA(lv_package) = package_fingerprint( it_statements ).
    IF lv_package <> gv_memo_package.
      clear_memo( ).
      gv_memo_package = lv_package.
    ENDIF.
    LOOP AT it_ztnum ASSIGNING FIELD-SYMBOL(<lv_ztnum>).
      IF NOT line_exists( gt_memo_keys[ table_line = <lv_ztnum> ] ).
        INSERT <lv_ztnum> INTO TABLE lt_missing.
      ENDIF.
    ENDLOOP.
    IF lt_missing IS NOT INITIAL.
      INSERT LINES OF sap_dao( )->get_checks( lt_missing ) INTO TABLE gt_memo_checks.
      INSERT LINES OF lt_missing INTO TABLE gt_memo_keys.
    ENDIF.
    " Only the rows of the requested keys, in read order - the rows one read of it_ztnum returns
    LOOP AT gt_memo_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      IF line_exists( it_ztnum[ table_line = <ls_check>-ztnum ] ).
        INSERT <ls_check> INTO TABLE rt_checks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD package_fingerprint.
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      rv_fingerprint = rv_fingerprint && <ls_statement>-stmt_key && cl_abap_char_utilities=>horizontal_tab.
    ENDLOOP.
  ENDMETHOD.


  METHOD docno_keys.
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      DATA(lv_reference) = line_reference( <ls_line> ).
      IF lv_reference IS NOT INITIAL.
        INSERT docno_key( lv_reference ) INTO TABLE rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD value_list.
    DATA(lv_values) = condense( CONV string( iv_values ) ).
    rt_list = zcl_ca_ops_util=>split_list( COND string( WHEN lv_values IS INITIAL THEN iv_default
                                                         ELSE lv_values ) ).
  ENDMETHOD.


  METHOD in_list.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    rv_hit = xsdbool( line_exists( it_list[ table_line = lv_value ] ) ).
  ENDMETHOD.


  METHOD amount_param.
    rv_amount = zcl_ca_ops_util=>to_decimal( iv_value = iv_value iv_default = iv_default ).
  ENDMETHOD.


  METHOD tolerance.
    rv_tolerance = abs( is_rule-tolerance ).
  ENDMETHOD.


  METHOD register_match.
    DATA lv_first TYPE string.
    rs_match-ztnum = zcl_cd_ops_util=>normalize_key( iv_reference = line_reference( is_line )
                                                     iv_length    = is_register-ztnum_length ).
    IF rs_match-ztnum IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_statement) = VALUE #( is_register-statements[ stmt_key = is_line-stmt_key ] OPTIONAL ).
    DATA(lv_canonical) = ztnum_canonical( iv_value        = rs_match-ztnum
                                          iv_ignore_zeros = is_register-ignore_zeros ).
    " Statement without house bank: the rows of the number must all belong to one account
    IF ls_statement-hbkid IS INITIAL.
      LOOP AT is_register-rows ASSIGNING FIELD-SYMBOL(<ls_any>) WHERE canonical = lv_canonical.
        IF lv_first IS INITIAL.
          lv_first = <ls_any>-account.
        ELSEIF <ls_any>-account <> lv_first.
          rs_match-ambiguous = abap_true.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDIF.
    LOOP AT is_register-rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE canonical = lv_canonical.
      IF ls_statement-hbkid IS NOT INITIAL AND <ls_row>-check-hbkid IS NOT INITIAL
         AND ( <ls_row>-check-hbkid <> ls_statement-hbkid OR <ls_row>-check-hktid <> ls_statement-hktid ).
        CONTINUE.
      ENDIF.
      " A07: a house bank ID is unique only within its company code
      IF ls_statement-bukrs IS NOT INITIAL AND <ls_row>-check-bukrs IS NOT INITIAL
         AND <ls_row>-check-bukrs <> ls_statement-bukrs.
        CONTINUE.
      ENDIF.
      INSERT <ls_row>-check INTO TABLE rs_match-checks.
    ENDLOOP.
  ENDMETHOD.


  METHOD account_key.
    rv_key = COND #( WHEN is_statement-hbkid IS NOT INITIAL
                     THEN |{ is_statement-bukrs }/{ is_statement-hbkid }/{ is_statement-hktid }|
                     ELSE condense( CONV string( is_statement-account_no ) ) ).
  ENDMETHOD.


  METHOD account_of.
    IF is_statement-hbkid IS NOT INITIAL.
      rs_account = VALUE #( it_accounts[ bukrs  = is_statement-bukrs
                                         hbkid  = is_statement-hbkid
                                         hktid  = is_statement-hktid
                                         active = abap_true ] OPTIONAL ).
    ENDIF.
    IF rs_account IS INITIAL AND is_statement-account_no IS NOT INITIAL.
      rs_account = VALUE #( it_accounts[ account_no = is_statement-account_no active = abap_true ] OPTIONAL ).
    ENDIF.
  ENDMETHOD.


  METHOD line_reference.
    rv_reference = COND #( WHEN is_line-reference IS NOT INITIAL THEN is_line-reference
                           WHEN is_line-check_no  IS NOT INITIAL THEN is_line-check_no
                           ELSE is_line-end_to_end_id ).
  ENDMETHOD.

ENDCLASS.
