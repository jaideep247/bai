*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_util.clas.abap
*& Purpose:
*& Stateless FMON helpers: finding builder, check-parameter parsing,
*& time stamp arithmetic and file reference normalisation. No database.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A52: IS_NUMBER for numeric source fields.
*& 2026-11-06 | Long references keep their identity through a SHA-1 digest; IS_DIGEST_REF, CANONICAL_NAME (audit A100).
*& 2026-11-06 | PCRE instead of the obsolete POSIX regex in matches( ).
*& 2026-11-07 | IFACE_DAY_KEY: one object key of interface-day findings (expected files, stage deadlines).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - pure helper functions</p>
CLASS zcl_cd_fmon_util DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Finding about one registered file (object FILE, key = file name,
    "! group1 = interface, group2 = payment method, reference = file ID in hex).
    "! Severity: iv_severity, else the check's configured severity, else E.
    CLASS-METHODS new_finding
      IMPORTING
        is_file           TYPE zif_cd_fmon_types=>ty_file
        is_check          TYPE zif_cd_fmon_types=>ty_chk
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_message        TYPE clike
        iv_severity       TYPE zif_ca_ops_types=>ty_severity OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Finding without a registered file (expected file, source, check)
    CLASS-METHODS new_key_finding
      IMPORTING
        iv_iface_id       TYPE zif_cd_fmon_types=>ty_iface_id OPTIONAL
        iv_object_key     TYPE clike
        is_check          TYPE zif_cd_fmon_types=>ty_chk
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_message        TYPE clike
        iv_severity       TYPE zif_ca_ops_types=>ty_severity OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Value of NAME in a 'NAME=VALUE;NAME2=VALUE2' parameter string
    CLASS-METHODS param
      IMPORTING
        iv_params       TYPE clike
        iv_name         TYPE clike
        iv_default      TYPE string OPTIONAL
      RETURNING
        VALUE(rv_value) TYPE string.

    CLASS-METHODS param_int
      IMPORTING
        iv_params       TYPE clike
        iv_name         TYPE clike
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    "! Whole minutes from iv_from to iv_to (negative when iv_to is earlier)
    CLASS-METHODS minutes_between
      IMPORTING
        iv_from           TYPE timestampl
        iv_to             TYPE timestampl
      RETURNING
        VALUE(rv_minutes) TYPE i.

    CLASS-METHODS add_minutes
      IMPORTING
        iv_timestamp        TYPE timestampl
        iv_minutes          TYPE i
      RETURNING
        VALUE(rv_timestamp) TYPE timestampl.

    "! Cross-source correlation key: condensed, upper case. A canonical value longer than the
    "! key keeps its identity as prefix + marker + SHA-1 of the whole value (audit A100); blank
    "! when the digest cannot be computed - callers reject a blank reference
    CLASS-METHODS normalize_ref
      IMPORTING
        iv_value      TYPE clike
      RETURNING
        VALUE(rv_ref) TYPE zif_cd_fmon_types=>ty_file_ref.

    "! The reference was built from a digest (a long name): verify the full name before use
    CLASS-METHODS is_digest_ref
      IMPORTING
        iv_ref           TYPE zif_cd_fmon_types=>ty_file_ref
      RETURNING
        VALUE(rv_digest) TYPE abap_bool.

    "! Canonical form of a file name or key: condensed, upper case, full length
    CLASS-METHODS canonical_name
      IMPORTING
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_name) TYPE string.

    "! Unformatted number as written by the dynamic reader: optional sign (leading or
    "! trailing), digits, optional decimals (audit A52 - no silent zero for garbage)
    CLASS-METHODS is_number
      IMPORTING
        iv_text       TYPE clike
      RETURNING
        VALUE(rv_ok)  TYPE abap_bool.

    "! Object key of a finding about an interface and business date (no registered file):
    "! FILE_MISSING / UNEXPECTED_FILE / STAGE_DEADLINE_MISSED, reconciled by the engine
    CLASS-METHODS iface_day_key
      IMPORTING
        iv_iface_id   TYPE zif_cd_fmon_types=>ty_iface_id
        iv_date       TYPE d
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.

    CLASS-METHODS file_hex
      IMPORTING
        iv_file_id    TYPE zif_cd_fmon_types=>ty_file_id
      RETURNING
        VALUE(rv_hex) TYPE zif_ca_ops_types=>ty_reference.

  PRIVATE SECTION.
    CONSTANTS gc_number_pattern TYPE string VALUE `^[+-]?[0-9]+([.][0-9]+)?[+-]?$`.

ENDCLASS.



CLASS zcl_cd_fmon_util IMPLEMENTATION.

  METHOD is_number.
    rv_ok = xsdbool( matches( val = condense( CONV string( iv_text ) ) pcre = gc_number_pattern ) ).
  ENDMETHOD.



  METHOD new_finding.
    rs_finding = new_key_finding(
      iv_iface_id   = is_file-iface_id
      iv_object_key = COND string( WHEN is_file-file_name IS NOT INITIAL THEN is_file-file_name
                                   ELSE is_file-file_ref )
      is_check      = is_check
      iv_code       = iv_code
      iv_message    = iv_message
      iv_severity   = iv_severity ).
    rs_finding-group2    = is_file-pay_method.
    rs_finding-reference = file_hex( is_file-file_id ).
    rs_finding-amount    = is_file-control_total.
  ENDMETHOD.


  METHOD new_key_finding.
    rs_finding-object_type = zif_cd_fmon_types=>gc_object_type.
    rs_finding-object_key  = iv_object_key.
    rs_finding-group1      = iv_iface_id.
    rs_finding-rule_id     = is_check-check_id.
    rs_finding-check_code  = iv_code.
    rs_finding-severity    = COND #( WHEN iv_severity IS NOT INITIAL THEN iv_severity
                                     WHEN is_check-severity IS NOT INITIAL THEN is_check-severity
                                     ELSE zif_ca_ops_types=>gc_severity-error ).
    rs_finding-action      = COND #( WHEN zcl_ca_ops_util=>severity_rank( rs_finding-severity ) >= 2
                                     THEN zif_ca_ops_types=>gc_action-exception
                                     ELSE zif_ca_ops_types=>gc_action-notify ).
    rs_finding-message     = iv_message.
  ENDMETHOD.


  METHOD param.
    DATA(lv_name) = to_upper( condense( CONV string( iv_name ) ) ).
    SPLIT CONV string( iv_params ) AT `;` INTO TABLE DATA(lt_pairs).
    LOOP AT lt_pairs INTO DATA(lv_pair).
      SPLIT lv_pair AT `=` INTO DATA(lv_key) DATA(lv_value).
      lv_value = condense( lv_value ).
      IF to_upper( condense( lv_key ) ) = lv_name AND lv_value IS NOT INITIAL.
        rv_value = lv_value.
        RETURN.
      ENDIF.
    ENDLOOP.
    rv_value = iv_default.
  ENDMETHOD.


  METHOD param_int.
    rv_value = zcl_ca_ops_util=>to_decimal( iv_value   = param( iv_params = iv_params iv_name = iv_name )
                                            iv_default = iv_default ).
  ENDMETHOD.


  METHOD minutes_between.
    IF iv_from IS INITIAL OR iv_to IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = iv_to
                                                    tstmp2 = iv_from ).
        rv_minutes = trunc( lv_seconds / 60 ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_minutes = 0.
    ENDTRY.
  ENDMETHOD.


  METHOD add_minutes.
    TRY.
        rv_timestamp = cl_abap_tstmp=>add( tstmp = iv_timestamp
                                           secs  = iv_minutes * 60 ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_timestamp = iv_timestamp.
    ENDTRY.
  ENDMETHOD.


  METHOD normalize_ref.
    DATA lv_hash TYPE string.
    DATA(lv_canonical) = canonical_name( iv_value ).
    IF strlen( lv_canonical ) <= zif_cd_fmon_types=>gc_ref_digest-width.
      rv_ref = lv_canonical.
      RETURN.
    ENDIF.
    TRY.
        " VERIFY-ADT: CL_ABAP_MESSAGE_DIGEST=>CALCULATE_HASH_FOR_CHAR (same call as the alert intent key)
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = zif_cd_fmon_types=>gc_ref_digest-algorithm
            if_data       = lv_canonical
          IMPORTING
            ef_hashstring = lv_hash ).
      CATCH cx_abap_message_digest.
        " no reference rather than a truncated one: the adapter quarantines the row
        CLEAR rv_ref.
        RETURN.
    ENDTRY.
    rv_ref = |{ substring( val = lv_canonical len = zif_cd_fmon_types=>gc_ref_digest-prefix ) }|
          && |{ zif_cd_fmon_types=>gc_ref_digest-marker }{ to_upper( lv_hash ) }|.
  ENDMETHOD.


  METHOD is_digest_ref.
    DATA(lv_ref) = CONV string( iv_ref ).
    rv_digest = xsdbool( strlen( lv_ref ) = zif_cd_fmon_types=>gc_ref_digest-width
                         AND substring( val = lv_ref off = zif_cd_fmon_types=>gc_ref_digest-prefix len = 1 )
                             = zif_cd_fmon_types=>gc_ref_digest-marker ).
  ENDMETHOD.


  METHOD canonical_name.
    rv_name = to_upper( condense( CONV string( iv_value ) ) ).
  ENDMETHOD.


  METHOD iface_day_key.
    rv_key = |{ iv_iface_id }/{ iv_date }|.
  ENDMETHOD.


  METHOD file_hex.
    IF iv_file_id IS INITIAL.
      RETURN.
    ENDIF.
    rv_hex = |{ iv_file_id }|.
  ENDMETHOD.

ENDCLASS.
