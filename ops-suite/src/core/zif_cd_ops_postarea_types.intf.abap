*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_postarea_types.intf.abap
*& Purpose:
*& Named types and constants of the FI-CA customer posting areas the suite
*& reads its mapping tables from (user decision 2026-11-08: ZRSN return
*& reasons, ZPMC payment method classes, ZBTM bank transaction codes, ZBTR
*& bank code roles - maintained by the FI-CA team in FQC0). An entry is
*& the key values KEY01..KEY08 and the result values FUN01..FUN08 of
*& TFK033D (VERIFY-SE11: field names and lengths); values are strings, so
*& nothing is truncated on read - the configuration check compares each
*& value with the length its reader needs. No logic.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas replace ZCD_EBS_RSN_MAP, ZCD_HCK_PMCLASS,
*&            | ZCD_BTC_MAP and ZCD_HCK_BTCROLE).
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
      fun07 TYPE ty_value,
      fun08 TYPE ty_value,
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
      applk    TYPE zif_cd_ops_types=>ty_param_name VALUE 'POSTAREA_APPLK',
      "! TFK033D-KTOPL of the entries; blank = posting areas defined without chart of accounts
      ktopl    TYPE zif_cd_ops_types=>ty_param_name VALUE 'POSTAREA_KTOPL',
      reason   TYPE zif_cd_ops_types=>ty_param_name VALUE 'POSTAREA_RSN',
      pm_class TYPE zif_cd_ops_types=>ty_param_name VALUE 'POSTAREA_PMC',
      btc_map  TYPE zif_cd_ops_types=>ty_param_name VALUE 'POSTAREA_BTM',
      btc_role TYPE zif_cd_ops_types=>ty_param_name VALUE 'POSTAREA_BTR',
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
    END OF gc_param_default.

  "! Names of the key and result fields of the four posting areas (FQC0 columns of the setup
  "! guide, Implementation_Order.md; named in the messages of the configuration check)
  CONSTANTS:
    BEGIN OF gc_field,
      reason         TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'REASON',
      fica_reason    TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'FICA_REASON',
      is_noc         TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'IS_NOC',
      flow           TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'FLOW',
      pay_method     TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'PAY_METHOD',
      house_bank     TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'HOUSE_BANK',
      method_class   TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'METHOD_CLASS',
      age_basis      TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'AGE_BASIS',
      calendar       TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'CALENDAR',
      scheme         TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'SCHEME',
      code           TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'CODE',
      family         TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'FAMILY',
      sub_family     TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'SUB_FAMILY',
      bank_key       TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'BANK_KEY',
      category       TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'CATEGORY',
      rule_group     TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'RULE_GROUP',
      exp_cdi        TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'EXP_CDI',
      posting_rule   TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'POSTING_RULE',
      action         TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ACTION',
      disposition    TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'DISPOSITION',
      usage          TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'USAGE',
      scope          TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'SCOPE',
      role           TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'ROLE',
      compare_amount TYPE zif_cd_ops_cfg_types=>ty_name VALUE 'COMPARE_AMOUNT',
    END OF gc_field.

  "! Separator of the allowed values the configuration check names (comma list)
  CONSTANTS gc_list_sep TYPE c LENGTH 1 VALUE ','.
  "! Form of a ZBTR scope of usage LIFECYCLE: flow D / C + method class (PCRE, whole value)
  CONSTANTS gc_scope_form TYPE string VALUE `[DC][A-Z0-9_]{1,3}`.

  "! Finding of the configuration check of the posting areas (one per invalid entry)
  TYPES:
    BEGIN OF ty_check_message,
      purpose  TYPE ty_purpose,
      area     TYPE ty_area,
      "! Key values of the entry, separated by GC_KEY_SEPARATOR (blank: the whole area)
      entry    TYPE string,
      severity TYPE zif_cd_ops_types=>ty_severity,
      number   TYPE zif_cd_ops_cfg_types=>ty_msg_number,
      v1       TYPE zif_cd_ops_cfg_types=>ty_msg_var,
      v2       TYPE zif_cd_ops_cfg_types=>ty_msg_var,
      v3       TYPE zif_cd_ops_cfg_types=>ty_msg_var,
    END OF ty_check_message.
  TYPES tt_check_message TYPE STANDARD TABLE OF ty_check_message WITH EMPTY KEY.

ENDINTERFACE.
