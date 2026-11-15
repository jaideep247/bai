*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lic_policy.clas.abap
*& Purpose:
*& The decision of the licence, pure (no database, no SSF, no clock): from
*& what ZCL_CA_OPS_LICENSE gathered - is a licence installed, did SSF accept
*& the signature and was the signer the vendor, the payload, this system's
*& identity, today, LIC_WARN_DAYS, LIC_ENFORCE and the module map - the
*& state of the licence (VALID, MISSING, SIGNATURE, BINDING, VERSION) and
*& of every module: INCLUDED (CORE), LICENSED, EXPIRING (ends within the
*& warning days), GRACE (ended, within the grace days of the licence),
*& EXPIRED, UNLICENSED (not granted, not yet valid, or no valid licence).
*& A module runs when it is included, licensed, expiring or in grace, or
*& whatever its state when the enforcement is W (warn only). The twin of
*& this decision for the vendor's tools is tools/abaptools/licensing.py.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence decision (pure)</p>
CLASS zcl_ca_ops_lic_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! State of the licence and of every module of the map (rows of kind MOD)
    CLASS-METHODS evaluate
      IMPORTING
        is_input         TYPE zif_ca_ops_lic_types=>ty_input
      RETURNING
        VALUE(rs_status) TYPE zif_ca_ops_lic_types=>ty_status.

    "! Decision for one module of a status; a module the map does not know is not licensed
    CLASS-METHODS decide
      IMPORTING
        is_status          TYPE zif_ca_ops_lic_types=>ty_status
        iv_module          TYPE zif_ca_ops_lic_types=>ty_module
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_lic_types=>ty_decision.

    "! The release lies in the range: missing parts of FROM count as 0, missing parts of TO as any (TO 1 = 1.x.y)
    CLASS-METHODS version_in_range
      IMPORTING
        iv_version         TYPE clike
        iv_from            TYPE clike
        iv_to              TYPE clike
      RETURNING
        VALUE(rv_in_range) TYPE abap_bool.

    "! A date of the payload (YYYYMMDD); initial when the text is no valid date
    CLASS-METHODS to_date
      IMPORTING
        iv_text        TYPE clike
      RETURNING
        VALUE(rv_date) TYPE d.

  PRIVATE SECTION.
    CONSTANTS gc_any_part TYPE i VALUE 999999.
    CONSTANTS gc_date_pcre TYPE string VALUE `^[0-9]{8}$`.
    CONSTANTS gc_version_pcre TYPE string VALUE `^[0-9]+(\.[0-9]+){0,2}$`.

    TYPES tt_part TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    "! State of the licence itself and why it is not VALID
    CLASS-METHODS licence_state
      IMPORTING
        is_input  TYPE zif_ca_ops_lic_types=>ty_input
      EXPORTING
        ev_state  TYPE zif_ca_ops_lic_types=>ty_state
        ev_detail TYPE string.

    "! The signer is the vendor: subject and, when both are known, the certificate fingerprint
    CLASS-METHODS signer_trusted
      IMPORTING
        is_verified       TYPE zif_ca_ops_lic_types=>ty_verified
      RETURNING
        VALUE(rv_trusted) TYPE abap_bool.

    "! This system is one of the licence: an installation number and the system ID (and client when given)
    CLASS-METHODS bound
      IMPORTING
        is_payload      TYPE zif_ca_ops_lic_types=>ty_payload
        is_system       TYPE zif_ca_ops_lic_types=>ty_system_id
      RETURNING
        VALUE(rv_bound) TYPE abap_bool.

    "! State of one granted module today
    CLASS-METHODS module_state
      IMPORTING
        is_grant        TYPE zif_ca_ops_lic_types=>ty_grant
        iv_today        TYPE d
        iv_warn_days    TYPE i
        iv_grace_days   TYPE i
      RETURNING
        VALUE(rs_state) TYPE zif_ca_ops_lic_types=>ty_module_state.

    CLASS-METHODS parts
      IMPORTING
        iv_version      TYPE clike
        iv_fill         TYPE i
      RETURNING
        VALUE(rt_parts) TYPE tt_part.

ENDCLASS.



CLASS zcl_ca_ops_lic_policy IMPLEMENTATION.

  METHOD evaluate.
    licence_state( EXPORTING is_input  = is_input
                   IMPORTING ev_state  = rs_status-state
                             ev_detail = rs_status-detail ).
    rs_status-enforce = COND #( WHEN is_input-enforce = zif_ca_ops_lic_types=>gc_enforce-refuse
                                THEN zif_ca_ops_lic_types=>gc_enforce-refuse
                                ELSE zif_ca_ops_lic_types=>gc_enforce-warn ).
    IF is_input-readable = abap_true.
      rs_status-license_id = is_input-payload-license_id.
      rs_status-customer   = is_input-payload-customer.
    ENDIF.
    IF rs_status-state = zif_ca_ops_lic_types=>gc_lic_state-valid.
      rs_status-grace_days = nmax( val1 = is_input-payload-grace_days val2 = 0 ).
    ENDIF.

    LOOP AT is_input-map ASSIGNING FIELD-SYMBOL(<ls_map>) WHERE obj_kind = zif_ca_ops_lic_types=>gc_kind-module.
      DATA(ls_state) = VALUE zif_ca_ops_lic_types=>ty_module_state( module = <ls_map>-module
                                                                    state  = zif_ca_ops_lic_types=>gc_state-unlicensed ).
      IF <ls_map>-always = abap_true.
        ls_state-state = zif_ca_ops_lic_types=>gc_state-included.
      ELSEIF rs_status-state = zif_ca_ops_lic_types=>gc_lic_state-valid.
        READ TABLE is_input-payload-modules ASSIGNING FIELD-SYMBOL(<ls_grant>) WITH KEY code = <ls_map>-module.
        IF sy-subrc = 0.
          ls_state = module_state( is_grant      = <ls_grant>
                                   iv_today      = is_input-today
                                   iv_warn_days  = is_input-warn_days
                                   iv_grace_days = rs_status-grace_days ).
        ENDIF.
      ENDIF.
      ls_state-runs = xsdbool( ls_state-state = zif_ca_ops_lic_types=>gc_state-included
                            OR ls_state-state = zif_ca_ops_lic_types=>gc_state-licensed
                            OR ls_state-state = zif_ca_ops_lic_types=>gc_state-expiring
                            OR ls_state-state = zif_ca_ops_lic_types=>gc_state-grace
                            OR rs_status-enforce <> zif_ca_ops_lic_types=>gc_enforce-refuse ).
      ls_state-warn = xsdbool( ls_state-state <> zif_ca_ops_lic_types=>gc_state-included
                           AND ls_state-state <> zif_ca_ops_lic_types=>gc_state-licensed ).
      INSERT ls_state INTO TABLE rs_status-modules.
    ENDLOOP.
  ENDMETHOD.


  METHOD decide.
    rs_decision = VALUE #( module    = iv_module
                           lic_state = is_status-state ).
    READ TABLE is_status-modules ASSIGNING FIELD-SYMBOL(<ls_state>) WITH TABLE KEY module = iv_module.
    IF sy-subrc = 0.
      rs_decision-state   = <ls_state>-state.
      rs_decision-allowed = <ls_state>-runs.
      rs_decision-warn    = <ls_state>-warn.
      RETURN.
    ENDIF.
    " a module this release does not know: not licensed (refused only under X)
    rs_decision-state   = zif_ca_ops_lic_types=>gc_state-unlicensed.
    rs_decision-allowed = xsdbool( is_status-enforce <> zif_ca_ops_lic_types=>gc_enforce-refuse ).
    rs_decision-warn    = abap_true.
  ENDMETHOD.


  METHOD licence_state.
    CLEAR ev_detail.
    IF is_input-installed = abap_false.
      ev_state = zif_ca_ops_lic_types=>gc_lic_state-missing.
      RETURN.
    ENDIF.
    IF is_input-verified-ok = abap_false OR signer_trusted( is_input-verified ) = abap_false
       OR is_input-readable = abap_false OR is_input-payload-format <> zif_ca_ops_lic_types=>gc_format
       OR is_input-payload-product <> zif_ca_ops_lic_types=>gc_vendor-product.
      ev_state  = zif_ca_ops_lic_types=>gc_lic_state-signature.
      ev_detail = COND #( WHEN is_input-verified-return_code IS NOT INITIAL THEN is_input-verified-return_code
                          ELSE is_input-verified-signer ).
      RETURN.
    ENDIF.
    IF bound( is_payload = is_input-payload
              is_system  = is_input-system ) = abap_false.
      ev_state  = zif_ca_ops_lic_types=>gc_lic_state-binding.
      ev_detail = |{ concat_lines_of( table = is_input-system-installations sep = `,` ) }/{ is_input-system-sysid }/{
                     is_input-system-client }|.
      RETURN.
    ENDIF.
    IF version_in_range( iv_version = is_input-system-version
                         iv_from    = is_input-payload-version_from
                         iv_to      = is_input-payload-version_to ) = abap_false.
      ev_state  = zif_ca_ops_lic_types=>gc_lic_state-version.
      ev_detail = is_input-system-version.
      RETURN.
    ENDIF.
    ev_state = zif_ca_ops_lic_types=>gc_lic_state-valid.
  ENDMETHOD.


  METHOD signer_trusted.
    IF to_upper( condense( is_verified-signer ) ) <> to_upper( zif_ca_ops_lic_types=>gc_vendor-subject ).
      RETURN.
    ENDIF.
    IF zif_ca_ops_lic_types=>gc_vendor-cert_sha256 IS NOT INITIAL AND is_verified-cert_sha256 IS NOT INITIAL
       AND to_upper( is_verified-cert_sha256 ) <> to_upper( zif_ca_ops_lic_types=>gc_vendor-cert_sha256 ).
      RETURN.
    ENDIF.
    rv_trusted = abap_true.
  ENDMETHOD.


  METHOD bound.
    DATA(lv_installation) = abap_false.
    LOOP AT is_system-installations ASSIGNING FIELD-SYMBOL(<lv_own>).
      IF line_exists( is_payload-installations[ table_line = <lv_own> ] ).
        lv_installation = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF lv_installation = abap_false.
      RETURN.
    ENDIF.
    LOOP AT is_payload-systems ASSIGNING FIELD-SYMBOL(<ls_system>)
         WHERE sid = is_system-sysid.
      IF <ls_system>-client IS INITIAL OR <ls_system>-client = is_system-client.
        rv_bound = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD module_state.
    rs_state = VALUE #( module     = is_grant-code
                        state      = zif_ca_ops_lic_types=>gc_state-unlicensed
                        valid_from = to_date( is_grant-valid_from )
                        valid_to   = to_date( is_grant-valid_to ) ).
    IF rs_state-valid_from IS INITIAL OR rs_state-valid_to IS INITIAL OR rs_state-valid_from > iv_today.
      " not readable or not yet valid: not licensed today
      RETURN.
    ENDIF.
    rs_state-grace_to  = rs_state-valid_to + iv_grace_days.
    rs_state-days_left = rs_state-valid_to - iv_today.
    rs_state-state = COND #( WHEN rs_state-days_left >= 0 AND rs_state-days_left < iv_warn_days
                             THEN zif_ca_ops_lic_types=>gc_state-expiring
                             WHEN rs_state-days_left >= 0
                             THEN zif_ca_ops_lic_types=>gc_state-licensed
                             WHEN iv_today <= rs_state-grace_to
                             THEN zif_ca_ops_lic_types=>gc_state-grace
                             ELSE zif_ca_ops_lic_types=>gc_state-expired ).
  ENDMETHOD.


  METHOD version_in_range.
    IF NOT matches( val = condense( iv_version ) pcre = gc_version_pcre )
       OR NOT matches( val = condense( iv_from ) pcre = gc_version_pcre )
       OR NOT matches( val = condense( iv_to ) pcre = gc_version_pcre ).
      RETURN.
    ENDIF.
    DATA(lt_version) = parts( iv_version = iv_version iv_fill = 0 ).
    DATA(lt_from) = parts( iv_version = iv_from iv_fill = 0 ).
    DATA(lt_to) = parts( iv_version = iv_to iv_fill = gc_any_part ).
    DATA(lv_above_from) = abap_true.
    DATA(lv_below_to) = abap_true.
    " compare part by part: the first part that differs decides
    DO 3 TIMES.
      DATA(lv_index) = sy-index.
      IF lt_version[ lv_index ] <> lt_from[ lv_index ].
        lv_above_from = xsdbool( lt_version[ lv_index ] > lt_from[ lv_index ] ).
        EXIT.
      ENDIF.
    ENDDO.
    DO 3 TIMES.
      lv_index = sy-index.
      IF lt_version[ lv_index ] <> lt_to[ lv_index ].
        lv_below_to = xsdbool( lt_version[ lv_index ] < lt_to[ lv_index ] ).
        EXIT.
      ENDIF.
    ENDDO.
    rv_in_range = xsdbool( lv_above_from = abap_true AND lv_below_to = abap_true ).
  ENDMETHOD.


  METHOD parts.
    SPLIT condense( iv_version ) AT '.' INTO TABLE DATA(lt_text).
    LOOP AT lt_text ASSIGNING FIELD-SYMBOL(<lv_text>).
      INSERT CONV i( <lv_text> ) INTO TABLE rt_parts.
    ENDLOOP.
    WHILE lines( rt_parts ) < 3.
      INSERT iv_fill INTO TABLE rt_parts.
    ENDWHILE.
  ENDMETHOD.


  METHOD to_date.
    IF NOT matches( val = condense( iv_text ) pcre = gc_date_pcre ).
      RETURN.
    ENDIF.
    rv_date = condense( iv_text ).
    " an impossible date (20261131) converts to the number 0
    IF CONV i( rv_date ) = 0.
      CLEAR rv_date.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
