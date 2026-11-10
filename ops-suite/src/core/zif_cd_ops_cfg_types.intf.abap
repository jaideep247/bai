*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_cfg_types.intf.abap
*& Purpose:
*& Field check messages (class ZCD_OPS) of the suite's configuration apps
*& (EBS, FMON, HCK, approved tables) and of the configuration check of the
*& customer posting areas. Types, client and request constants and the
*& gate's messages are the framework's (ZIF_CA_OPS_CFG_TYPES). No logic.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-06 | Message 418: a pattern field is not valid PCRE.
*& 2026-11-07 | Messages 420 / 421: register state tokens and outcome finding codes of ZCD_HCK_SEQOUT.
*& 2026-11-08 | Message 423: table consolidation, a field that must be blank for the row's kind / usage.
*& 2026-11-08 | Messages 422 / 424 / 425: required for the kind, value of the other usage, form (PCRE).
*& 2026-11-08 | Message 426: expected group list of ZCD_HCK_AGG (ZCD_HCK_AGGGRP merged).
*& 2026-11-08 | Messages 427-433 (and 385 shared): configuration check of the customer posting areas.
*& 2026-11-10 | Message 812 (shared with R21): lookup key / status field not approved in ZCD_OPS_TABWL.
*& 2026-11-10 | Types, constants and the gate's messages moved to the reusable framework ZCA_OPS
*&            | (ZIF_CA_OPS_CFG_TYPES); this interface keeps the suite's field check messages.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - configuration apps: field check messages</p>
INTERFACE zif_cd_ops_cfg_types
  PUBLIC.

  "! Thresholds of the health check (ZCD_HCK_THRESH, ZCL_CD_OPS_CFG_CHECKS=>THRESHOLDS_ORDERED)
  TYPES ty_amount TYPE p LENGTH 12 DECIMALS 4.

  "! Message class ZCD_OPS, range 400-449 (configuration apps of the suite)
  CONSTANTS:
    BEGIN OF gc_msg,
      class_invalid       TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '410',
      table_invalid       TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '411',
      field_invalid       TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '412',
      value_invalid       TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '413',
      window_incomplete   TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '414',
      thresholds_order    TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '415',
      rule_group_empty    TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '416',
      not_positive        TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '417',
      pattern_invalid     TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '418',
      "! ZCD_HCK_SEQOUT-REG_STATE / FINDING (code review of the cheque lifecycle, 2026-11-07)
      reg_state_invalid   TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '420',
      finding_invalid     TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '421',
      "! Table consolidation 2026-11-08: checks per kind / usage of a row ('when' of the generator)
      required            TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '422',
      must_be_blank       TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '423',
      value_reserved      TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '424',
      form_invalid        TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '425',
      "! ZCD_HCK_AGG-EXPECTED_GROUPS (expected groups of a grouped aggregate, audit A103)
      group_list_invalid  TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '426',
      "! Customer posting areas ZRSN / ZPMC / ZBTM / ZBTR (configuration check POSTAREA_INVALID, 2026-11-08)
      generic_key         TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '427',
      value_too_long      TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '428',
      key_blank           TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '429',
      class_unknown       TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '430',
      class_entry_none    TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '431',
      area_empty          TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '432',
      entries_differ      TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '433',
      "! Shared with the in-flight check (HCK): one payment method in two method classes
      method_two_classes  TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '385',
      "! Shared with the EBS lookup rule R21 at runtime: field not approved in ZCD_OPS_TABWL (EBS / LOOKUP)
      lookup_not_approved TYPE zif_ca_ops_cfg_types=>ty_msg_number VALUE '812',
    END OF gc_msg.

ENDINTERFACE.
