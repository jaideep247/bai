*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_postarea_types.intf.abap
*& Purpose:
*& Named types and constants of the FI-CA customer posting areas the suite
*& reads its mapping tables from (user decision 2026-11-08: ZRSN return
*& reasons, ZPMC payment method classes, ZBTM bank transaction codes, ZBTR
*& bank code roles - maintained by the FI-CA team in FQC0) and of the typed
*& product mapping tables ZCD_OPS_MAP* (product review 2026-11-15): the
*& source of each purpose is a parameter (P posting area, T typed table).
*& An entry is the key values KEY01..KEY08 and the result values
*& FUN01..FUN07 - TFK033D holds FUN01..FUN06 (CHAR 12), the 7th result
*& exists in the typed table only; values are strings, so nothing is
*& truncated on read - the configuration check compares each value with
*& the length its reader needs. No logic.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas replace ZCD_EBS_RSN_MAP, ZCD_HCK_PMCLASS,
*&            | ZCD_BTC_MAP and ZCD_HCK_BTCROLE).
*& 2026-11-15 | Source per purpose (POSTAREA_SOURCE_*), active version of a typed table
*&            | (POSTAREA_VERSION_*), capacity of TFK033D (reference system), typed tables, layout
*&            | types (from ZCL_CD_OPS_CFG_CHECKS); FUN08 removed (VERIFY V161 closed).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: types</p>
INTERFACE zif_cd_ops_postarea_types
  PUBLIC.

  "! TFK033D-APPLK application area of the payment engine (VERIFY-SE11)
  TYPES ty_applk TYPE c LENGTH 1.
  "! TFK033D-BUBER posting area (customer posting areas start with Z)
  TYPES ty_area TYPE c LENGTH 4.
  "! TFK033D-KTOPL chart of accounts (blank: the posting area does not depend on it)
  TYPES ty_ktopl TYPE c LENGTH 4.
  "! One key or result value of an entry (TFK033D-KEYnn / FUNnn as read, condensed)
  TYPES ty_value TYPE string.
  "! What a posting area is for (one of GC_PURPOSE); its name is a parameter
  TYPES ty_purpose TYPE c LENGTH 3.
  "! Where the entries of a purpose are read from (one of GC_SOURCE; parameter POSTAREA_SOURCE_*)
  TYPES ty_source TYPE c LENGTH 1.
  "! Mapping version of a typed table (the active one is the parameter POSTAREA_VERSION_*)
  TYPES ty_version TYPE n LENGTH 4.

  "! Key fields of an entry (FQC0 columns from the left); '*' = any value (generic)
  TYPES:
    BEGIN OF ty_keys,
      key01 TYPE ty_value,
      key02 TYPE ty_value,
      key03 TYPE ty_value,
      key04 TYPE ty_value,
      key05 TYPE ty_value,
      key06 TYPE ty_value,
      key07 TYPE ty_value,
      key08 TYPE ty_value,
    END OF ty_keys.

  "! Result fields of an entry
  TYPES:
    BEGIN OF ty_results,
      fun01 TYPE ty_value,
      fun02 TYPE ty_value,
      fun03 TYPE ty_value,
      fun04 TYPE ty_value,
      fun05 TYPE ty_value,
      fun06 TYPE ty_value,
      "! Typed table only (ZCD_OPS_MAPBTM-DISPOSITION): TFK033D has no 7th result
      fun07 TYPE ty_value,
    END OF ty_results.

  "! One entry of a posting area (application area and chart of accounts of the read)
  TYPES BEGIN OF ty_entry.
  INCLUDE TYPE ty_keys.
  INCLUDE TYPE ty_results.
  TYPES END OF ty_entry.
  TYPES tt_entry TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.

  "! Generic key value of FQC0: matches any value; an exact value of the same key wins
  CONSTANTS gc_generic TYPE c LENGTH 1 VALUE '*'.
  "! Number of key fields of an entry (KEY01..KEY08)
  CONSTANTS gc_key_count TYPE i VALUE 8.
  "! Separator of the key values in an entry key text (findings: object key, messages)
  CONSTANTS gc_key_separator TYPE c LENGTH 1 VALUE '/'.

  "! What TFK033D holds (reference system S/4HANA 2025, ddic/a4h/TFK033D.fields.csv): KEY01..KEY08
  "! (KEYNN_KK) and FUN01..FUN06 (FUNNN_KK), all CHAR 12 - a layout with more results or longer
  "! fields cannot be a posting area (source T)
  CONSTANTS:
    BEGIN OF gc_postarea_capacity,
      keys    TYPE i VALUE 8,
      results TYPE i VALUE 6,
      length  TYPE i VALUE 12,
    END OF gc_postarea_capacity.

  "! Source of the entries of a purpose (product review 2026-11-15)
  CONSTANTS:
    BEGIN OF gc_source,
      "! FI-CA customer posting area (FQC0 entries, TFK033D) - where the layout fits
      posting_area TYPE ty_source VALUE 'P',
      "! Typed product mapping table of the suite (ZCD_OPS_MAP*, configuration app ZUI_CD_OPS_CFG)
      typed        TYPE ty_source VALUE 'T',
    END OF gc_source.

  "! Typed mapping table of each purpose (one row = one entry of a mapping version)
  CONSTANTS:
    BEGIN OF gc_table,
      reason   TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZCD_OPS_MAPRSN',
      pm_class TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZCD_OPS_MAPPMC',
      btc_map  TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZCD_OPS_MAPBTM',
      btc_role TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZCD_OPS_MAPBTR',
    END OF gc_table.

  "! Entity of each typed table in the configuration app ZUI_CD_OPS_CFG (transport recording)
  CONSTANTS:
    BEGIN OF gc_entity,
      reason   TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'MapReason',
      pm_class TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'MapMethodClass',
      btc_map  TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'MapBtcCode',
      btc_role TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'MapBtcRole',
    END OF gc_entity.

  "! The four mappings held in customer posting areas
  CONSTANTS:
    BEGIN OF gc_purpose,
      "! Bank return / NOC reason -> payment engine return reason, NOC flag (was ZCD_EBS_RSN_MAP)
      reason   TYPE ty_purpose VALUE 'RSN',
      "! Flow + payment method + house bank -> method class, ageing basis, calendar (was ZCD_HCK_PMCLASS)
      pm_class TYPE ty_purpose VALUE 'PMC',
      "! Bank transaction code -> category, rule group, ... (was ZCD_BTC_MAP)
      btc_map  TYPE ty_purpose VALUE 'BTM',
      "! Usage + scope + bank transaction code -> role, compare amount (was ZCD_HCK_BTCROLE)
      btc_role TYPE ty_purpose VALUE 'BTR',
    END OF gc_purpose.

  "! Parameters (ZCA_PARAM, area CD_OPS): names of the posting areas, application area and
  "! chart of accounts - renamed without code (user decision 2026-11-08)
  CONSTANTS:
    BEGIN OF gc_param,
      "! TFK033D-APPLK of the payment engine (FS-CD); VERIFY-SE11 in DV1 (FQC0 header)
      applk    TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_APPLK',
      "! TFK033D-KTOPL of the entries; blank = posting areas defined without chart of accounts
      ktopl    TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_KTOPL',
      reason   TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_RSN',
      pm_class TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_PMC',
      btc_map  TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_BTM',
      btc_role TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_BTR',
      "! Source per purpose: P posting area / T typed table (product review 2026-11-15)
      source_reason   TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_SOURCE_RSN',
      source_pm_class TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_SOURCE_PMC',
      source_btc_map  TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_SOURCE_BTM',
      source_btc_role TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_SOURCE_BTR',
      "! Active mapping version of the typed table per purpose (rollback = the previous number)
      version_reason   TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_VERSION_RSN',
      version_pm_class TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_VERSION_PMC',
      version_btc_map  TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_VERSION_BTM',
      version_btc_role TYPE zif_ca_ops_types=>ty_param_name VALUE 'POSTAREA_VERSION_BTR',
    END OF gc_param.

  "! Delivered defaults of the parameters (names fixed by the user 2026-11-08)
  CONSTANTS:
    BEGIN OF gc_param_default,
      "! V = insurance (FS-CD) - VERIFY-SE11 (domain APPLK_KK)
      applk    TYPE string VALUE `V`,
      reason   TYPE string VALUE `ZRSN`,
      pm_class TYPE string VALUE `ZPMC`,
      btc_map  TYPE string VALUE `ZBTM`,
      btc_role TYPE string VALUE `ZBTR`,
      "! ZRSN (keys / results up to 4 characters, 2 results) and ZPMC (up to 10, 3 results) fit TFK033D
      source_reason    TYPE string VALUE `P`,
      source_pm_class  TYPE string VALUE `P`,
      "! ZBTM: 7 results, keys of 35 / 15; ZBTR: keys of 35, role of 15 - longer than CHAR 12
      source_btc_map   TYPE string VALUE `T`,
      source_btc_role  TYPE string VALUE `T`,
      version_reason   TYPE string VALUE `1`,
      version_pm_class TYPE string VALUE `1`,
      version_btc_map  TYPE string VALUE `1`,
      version_btc_role TYPE string VALUE `1`,
    END OF gc_param_default.

  "! Names of the key and result fields of the four posting areas (FQC0 columns of the setup
  "! guide, Implementation_Order.md; named in the messages of the configuration check)
  CONSTANTS:
    BEGIN OF gc_field,
      reason         TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'REASON',
      fica_reason    TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'FICA_REASON',
      is_noc         TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'IS_NOC',
      flow           TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'FLOW',
      pay_method     TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'PAY_METHOD',
      house_bank     TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'HOUSE_BANK',
      method_class   TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'METHOD_CLASS',
      age_basis      TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'AGE_BASIS',
      calendar       TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'CALENDAR',
      scheme         TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'SCHEME',
      code           TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'CODE',
      family         TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'FAMILY',
      sub_family     TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'SUB_FAMILY',
      bank_key       TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'BANK_KEY',
      category       TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'CATEGORY',
      rule_group     TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'RULE_GROUP',
      exp_cdi        TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'EXP_CDI',
      posting_rule   TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'POSTING_RULE',
      action         TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ACTION',
      disposition    TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'DISPOSITION',
      usage          TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'USAGE',
      scope          TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'SCOPE',
      role           TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ROLE',
      compare_amount TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'COMPARE_AMOUNT',
    END OF gc_field.

  "! Separator of the allowed values the configuration check names (comma list)
  CONSTANTS gc_list_sep TYPE c LENGTH 1 VALUE ','.
  "! Form of a ZBTR scope of usage LIFECYCLE: flow D / C + method class (PCRE, whole value)
  CONSTANTS gc_scope_form TYPE string VALUE `[DC][A-Z0-9_]{1,3}`.

  "! A key or result field of a layout (keys first, then results, in FQC0 / column order)
  TYPES:
    BEGIN OF ty_field,
      name     TYPE zif_ca_ops_cfg_types=>ty_name,
      "! Characters the reader takes (0 = no limit)
      length   TYPE i,
      "! '*' allowed - the reader applies it as FQC0 does
      generic  TYPE abap_bool,
      "! A key that must hold a value or '*'
      required TYPE abap_bool,
    END OF ty_field.
  TYPES tt_field TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.

  "! Layout of a purpose (FICA_Posting_Areas.md section 2; lengths from the readers' own types)
  TYPES:
    BEGIN OF ty_layout,
      purpose TYPE ty_purpose,
      area    TYPE ty_area,
      keys    TYPE tt_field,
      results TYPE tt_field,
    END OF ty_layout.

  "! Status of an entry in the copy from a posting area into a typed table (ZCD_OPS_POSTAREA_COPY)
  TYPES ty_copy_status TYPE c LENGTH 12.
  CONSTANTS:
    BEGIN OF gc_copy,
      "! Copied (update mode) / to be copied (test mode)
      copy         TYPE ty_copy_status VALUE 'COPY',
      "! Written to the typed table (update mode)
      written      TYPE ty_copy_status VALUE 'WRITTEN',
      "! A value is longer than the typed column (layout length): left out, enter it in the app
      too_long     TYPE ty_copy_status VALUE 'TOO_LONG',
      "! The target version already has rows: nothing is copied (choose an unused version)
      version_used TYPE ty_copy_status VALUE 'VERSION_USED',
    END OF gc_copy.

  "! One posting area entry of the copy and its status
  TYPES BEGIN OF ty_copy_row.
  TYPES status TYPE ty_copy_status.
  INCLUDE TYPE ty_entry.
  TYPES END OF ty_copy_row.
  TYPES tt_copy_row TYPE STANDARD TABLE OF ty_copy_row WITH EMPTY KEY.

  "! Finding of the configuration check of the posting areas (one per invalid entry)
  TYPES:
    BEGIN OF ty_check_message,
      purpose  TYPE ty_purpose,
      area     TYPE ty_area,
      "! Key values of the entry, separated by GC_KEY_SEPARATOR (blank: the whole area)
      entry    TYPE string,
      severity TYPE zif_ca_ops_types=>ty_severity,
      number   TYPE zif_ca_ops_cfg_types=>ty_msg_number,
      v1       TYPE zif_ca_ops_cfg_types=>ty_msg_var,
      v2       TYPE zif_ca_ops_cfg_types=>ty_msg_var,
      v3       TYPE zif_ca_ops_cfg_types=>ty_msg_var,
    END OF ty_check_message.
  TYPES tt_check_message TYPE STANDARD TABLE OF ty_check_message WITH EMPTY KEY.

ENDINTERFACE.
