*&---------------------------------------------------------------------*
*& Artifact: zif_ca_param.intf.abap
*& Purpose:
*& Public read API of the parameter framework. A parameter is identified
*& by area + name; its value rows may differ by context (up to four
*& dimensions declared on the definition, e.g. SOURCE). Every read validates
*& the value against the definition; an unknown area or name, a missing
*& mandatory value, a configuration error or an invalid value raises
*& ZCX_CA_PARAM - never a silent default, never a dump. Obtain it from
*& ZCL_CA_PARAM_FACTORY=>GET; tests build it over ZCL_CA_PARAM_DAO_MEM
*& (ZCL_CA_PARAM_BUILDER). Maintenance: SM30 / SPRO (docs/OPERATIONS.md).
*& Modification log:
*& 2026-11-07 | Initial version.
*& 2026-11-10 | CHECK_AREA: the area is registered and active (one area register for consumers such as the
*&            | operations framework ZCA_OPS, release 1.1.0).
*& 2026-11-24 | IT_CONTEXT (optional) on every value read: the most specific context with value rows wins
*&            | (docs/DESIGN.md section 3a). Callers without context read exactly as before.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - read API</p>
"! Reads parameters by area + name (+ optional context). Semantics (docs/DESIGN.md, section 3):
"! no value row = DEFAULT_VALUE (exception if MANDATORY and no default);
"! BOOL: row X = true, row blank = false, no row = default; kind P with more
"! than one row = configuration error; kind S = all rows ordered by NUMB.
"! Context (section 3a): the caller passes its facts by dimension name (SOURCE = SRC_A, ...);
"! the rows of the most specific matching context are used - all of them, never a mix of
"! contexts - else the default. Facts for dimensions a definition does not declare are ignored.
INTERFACE zif_ca_param
  PUBLIC.

  "! Value of a single-value parameter (kind P) as maintained, any value type
  "! @parameter iv_area | Parameter area
  "! @parameter iv_name | Parameter name
  "! @parameter it_context | Facts of the caller by dimension name (optional; blank = general rows only)
  "! @parameter rv_value | Value (blank when neither a value nor a default exists)
  "! @raising zcx_ca_param | Unknown area / name, kind S, invalid value, mandatory missing
  METHODS get_value
    IMPORTING
      iv_area         TYPE zif_ca_param_types=>ty_area
      iv_name         TYPE zif_ca_param_types=>ty_name
      it_context      TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE string
    RAISING
      zcx_ca_param.

  "! Integer value (value type INT); a blank value raises (message 018)
  METHODS get_int
    IMPORTING
      iv_area         TYPE zif_ca_param_types=>ty_area
      iv_name         TYPE zif_ca_param_types=>ty_name
      it_context      TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE i
    RAISING
      zcx_ca_param.

  "! Decimal value (value type DEC or INT); a blank value raises (message 018)
  METHODS get_dec
    IMPORTING
      iv_area         TYPE zif_ca_param_types=>ty_area
      iv_name         TYPE zif_ca_param_types=>ty_name
      it_context      TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE zif_ca_param_types=>ty_decimal
    RAISING
      zcx_ca_param.

  "! Flag (value type BOOL): X = abap_true, blank = abap_false (explicit off)
  METHODS get_bool
    IMPORTING
      iv_area         TYPE zif_ca_param_types=>ty_area
      iv_name         TYPE zif_ca_param_types=>ty_name
      it_context      TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE abap_bool
    RAISING
      zcx_ca_param.

  "! Date (value type DATE, YYYYMMDD); a blank value raises (message 018)
  METHODS get_date
    IMPORTING
      iv_area         TYPE zif_ca_param_types=>ty_area
      iv_name         TYPE zif_ca_param_types=>ty_name
      it_context      TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE d
    RAISING
      zcx_ca_param.

  "! Time (value type TIME, HHMMSS); a blank value raises (message 018)
  METHODS get_time
    IMPORTING
      iv_area         TYPE zif_ca_param_types=>ty_area
      iv_name         TYPE zif_ca_param_types=>ty_name
      it_context      TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rv_value) TYPE t
    RAISING
      zcx_ca_param.

  "! List: kind S = LOW of every row (each row I EQ) ordered by NUMB;
  "! kind P with value type LIST = the value split at comma / semicolon,
  "! elements condensed, blank elements dropped
  METHODS get_list
    IMPORTING
      iv_area        TYPE zif_ca_param_types=>ty_area
      iv_name        TYPE zif_ca_param_types=>ty_name
      it_context     TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rt_list) TYPE zif_ca_param_types=>tt_list
    RAISING
      zcx_ca_param.

  "! Select-option of a kind S parameter, rows ordered by NUMB. An empty range
  "! means "nothing maintained and no default" - never use it as "all values"
  METHODS get_range
    IMPORTING
      iv_area         TYPE zif_ca_param_types=>ty_area
      iv_name         TYPE zif_ca_param_types=>ty_name
      it_context      TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rt_range) TYPE zif_ca_param_types=>tt_range
    RAISING
      zcx_ca_param.

  "! True when at least one value row is maintained (the default does not count)
  METHODS is_set
    IMPORTING
      iv_area       TYPE zif_ca_param_types=>ty_area
      iv_name       TYPE zif_ca_param_types=>ty_name
      it_context    TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rv_set) TYPE abap_bool
    RAISING
      zcx_ca_param.

  "! Which context a read with this context uses, and how many value rows it has there
  "! (0 = no rows in any matching context: the default applies). For support and test
  "! evidence: shows which configuration row drives a process without running it.
  METHODS get_effective_context
    IMPORTING
      iv_area             TYPE zif_ca_param_types=>ty_area
      iv_name             TYPE zif_ca_param_types=>ty_name
      it_context          TYPE zif_ca_param_types=>tt_context OPTIONAL
    RETURNING
      VALUE(rs_effective) TYPE zif_ca_param_types=>ty_effective
    RAISING
      zcx_ca_param.

  "! Definition of a parameter (for tools and user interfaces)
  METHODS get_definition
    IMPORTING
      iv_area              TYPE zif_ca_param_types=>ty_area
      iv_name              TYPE zif_ca_param_types=>ty_name
    RETURNING
      VALUE(rs_definition) TYPE zif_ca_param_types=>ty_definition
    RAISING
      zcx_ca_param.

  "! The area exists in ZCA_PARAM_AREA and is active - the one area register of every consumer
  "! (e.g. the area of a run of the operations framework ZCA_OPS). Same buffer as the reads.
  "! @raising zcx_ca_param | Unknown area (001) or inactive area (002)
  METHODS check_area
    IMPORTING
      iv_area TYPE zif_ca_param_types=>ty_area
    RAISING
      zcx_ca_param.

  "! Drop the buffer of one area (or of every area): the next read sees the database.
  "! Long-running jobs call it at the start of each run.
  METHODS refresh
    IMPORTING
      iv_area TYPE zif_ca_param_types=>ty_area OPTIONAL.

ENDINTERFACE.
