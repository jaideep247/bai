*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_recon_types.intf.abap
*& Purpose:
*& Types and constants of the three-way reconciliation check A_RECON_3WAY
*& (bank <-> G/L transit / clearing account <-> payment engine per company
*& code, clearing account, currency and day; Stripe descriptor groups; ACH
*& assignment pairs): configuration rows (ZCD_HCK_RCSET, ZCD_HCK_RCBTC),
*& the grouped reads of ZIF_CD_HCK_RECON_DAO, the evaluated group days,
*& check codes, buckets, metrics, messages and parameters.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - three-way reconciliation types</p>
"! Shared by ZCL_CD_HCK_C_RECON3 (check), ZCL_CD_HCK_RECON_EVAL (pure rules) and
"! ZCL_CD_HCK_RECON_DAO (grouped reads). Amounts are never summed across currencies.
INTERFACE zif_cd_hck_recon_types
  PUBLIC.

  TYPES ty_set_id  TYPE c LENGTH 10.
  TYPES ty_kind    TYPE c LENGTH 10.
  TYPES ty_side    TYPE c LENGTH 1.
  TYPES ty_role    TYPE c LENGTH 10.
  TYPES ty_bucket  TYPE c LENGTH 10.
  TYPES ty_status  TYPE c LENGTH 10.
  "! BAI2 type code of a bank line (FEBEP-VORGC, VERIFY-SE11 length)
  TYPES ty_btc     TYPE c LENGTH 10.
  TYPES ty_bukrs   TYPE c LENGTH 4.
  TYPES ty_hkont   TYPE c LENGTH 10.
  TYPES ty_waers   TYPE c LENGTH 5.
  TYPES ty_hbkid   TYPE c LENGTH 5.
  TYPES ty_hktid   TYPE c LENGTH 5.
  "! Payment engine bank account as derived from FEBEP-XBLNR (ZCD_EBS_ACCT-ACCOUNT_NO)
  TYPES ty_account TYPE c LENGTH 35.
  TYPES ty_zuonr   TYPE c LENGTH 18.
  TYPES ty_belnr   TYPE c LENGTH 10.
  TYPES ty_gjahr   TYPE n LENGTH 4.
  TYPES ty_ledger  TYPE c LENGTH 2.
  TYPES ty_awtyp   TYPE c LENGTH 5.
  "! Debit / credit indicator of a bank line (FEBEP-EPVOZ) or a G/L line (ACDOCA-DRCRK)
  TYPES ty_cdi     TYPE c LENGTH 1.
  TYPES ty_amount  TYPE zif_cd_ops_types=>ty_amount.
  "! Group key of the result (DIM1 of the metrics): BUKRS/HKONT/WAERS
  TYPES ty_group   TYPE c LENGTH 35.

  TYPES tt_account TYPE STANDARD TABLE OF ty_account WITH EMPTY KEY.
  TYPES tt_btc     TYPE STANDARD TABLE OF ty_btc WITH EMPTY KEY.
  TYPES tt_zuonr   TYPE STANDARD TABLE OF ty_zuonr WITH EMPTY KEY.
  TYPES tt_bucket  TYPE STANDARD TABLE OF ty_bucket WITH EMPTY KEY.

  " ------------------------------------------------------------ configuration
  "! ZCD_HCK_RCSET: one transit / clearing account in one currency
  TYPES:
    BEGIN OF ty_set,
      set_id      TYPE ty_set_id,
      kind        TYPE ty_kind,
      side        TYPE ty_side,
      bukrs       TYPE ty_bukrs,
      hkont       TYPE ty_hkont,
      waers       TYPE ty_waers,
      hbkid       TYPE ty_hbkid,
      hktid       TYPE ty_hktid,
      invert_bank TYPE abap_bool,
      leg_bank    TYPE abap_bool,
      leg_fica    TYPE abap_bool,
      tolerance   TYPE ty_amount,
      description TYPE zif_cd_hck_types=>ty_text,
    END OF ty_set.
  TYPES tt_set TYPE STANDARD TABLE OF ty_set WITH EMPTY KEY.

  "! ZCD_HCK_RCBTC: role of a bank code in a set
  TYPES:
    BEGIN OF ty_btc_role,
      set_id TYPE ty_set_id,
      btc    TYPE ty_btc,
      role   TYPE ty_role,
    END OF ty_btc_role.
  TYPES tt_btc_role TYPE STANDARD TABLE OF ty_btc_role WITH EMPTY KEY
                    WITH NON-UNIQUE SORTED KEY by_set COMPONENTS set_id btc.

  " ------------------------------------------------------------ grouped reads (DAO)
  "! Bank lines of a payment engine account grouped per currency, day (FEBEP-BUDAT), code and
  "! debit / credit; amounts as on the statement (unsigned, direction in CDI)
  TYPES:
    BEGIN OF ty_bank_day,
      account    TYPE ty_account,
      currency   TYPE ty_waers,
      day        TYPE d,
      btc        TYPE ty_btc,
      cdi        TYPE ty_cdi,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_bank_day.
  TYPES tt_bank_day TYPE STANDARD TABLE OF ty_bank_day WITH EMPTY KEY.

  "! Last booking day of the statements loaded for an account (up to the report date)
  TYPES:
    BEGIN OF ty_bank_last,
      account  TYPE ty_account,
      last_day TYPE d,
    END OF ty_bank_last.
  TYPES tt_bank_last TYPE STANDARD TABLE OF ty_bank_last WITH EMPTY KEY.

  "! Company code + clearing account + currency of a set (G/L and subledger reads)
  TYPES:
    BEGIN OF ty_gl_key,
      bukrs    TYPE ty_bukrs,
      hkont    TYPE ty_hkont,
      currency TYPE ty_waers,
    END OF ty_gl_key.
  TYPES tt_gl_key TYPE STANDARD TABLE OF ty_gl_key WITH EMPTY KEY.

  "! G/L lines of a clearing account per posting day and reference procedure (ACDOCA, signed)
  TYPES:
    BEGIN OF ty_gl_day,
      bukrs      TYPE ty_bukrs,
      hkont      TYPE ty_hkont,
      currency   TYPE ty_waers,
      day        TYPE d,
      awtyp      TYPE ty_awtyp,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_gl_day.
  TYPES tt_gl_day TYPE STANDARD TABLE OF ty_gl_day WITH EMPTY KEY.

  "! Payment engine G/L transfer totals (DFKKSUMC) of a clearing account per posting day
  TYPES:
    BEGIN OF ty_fica_day,
      bukrs      TYPE ty_bukrs,
      hkont      TYPE ty_hkont,
      currency   TYPE ty_waers,
      day        TYPE d,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_fica_day.
  TYPES tt_fica_day TYPE STANDARD TABLE OF ty_fica_day WITH EMPTY KEY.

  "! House bank account of a set (payment documents DPAYH)
  TYPES:
    BEGIN OF ty_bank_key,
      bukrs    TYPE ty_bukrs,
      hbkid    TYPE ty_hbkid,
      hktid    TYPE ty_hktid,
      currency TYPE ty_waers,
    END OF ty_bank_key.
  TYPES tt_bank_key TYPE STANDARD TABLE OF ty_bank_key WITH EMPTY KEY.

  "! Payment documents of payment runs (DPAYH) per house bank account, currency and run date
  TYPES:
    BEGIN OF ty_pay_day,
      bukrs      TYPE ty_bukrs,
      hbkid      TYPE ty_hbkid,
      hktid      TYPE ty_hktid,
      currency   TYPE ty_waers,
      day        TYPE d,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_pay_day.
  TYPES tt_pay_day TYPE STANDARD TABLE OF ty_pay_day WITH EMPTY KEY.

  "! Stripe payout deposits (bank lines of the deposit codes) per posting document
  TYPES:
    BEGIN OF ty_deposit,
      account    TYPE ty_account,
      currency   TYPE ty_waers,
      bukrs      TYPE ty_bukrs,
      belnr      TYPE ty_belnr,
      gjahr      TYPE ty_gjahr,
      day        TYPE d,
      cdi        TYPE ty_cdi,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_deposit.
  TYPES tt_deposit TYPE STANDARD TABLE OF ty_deposit WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_doc_key,
      bukrs TYPE ty_bukrs,
      belnr TYPE ty_belnr,
      gjahr TYPE ty_gjahr,
    END OF ty_doc_key.
  TYPES tt_doc_key TYPE STANDARD TABLE OF ty_doc_key WITH EMPTY KEY.

  "! Clearing-account lines of a G/L document per assignment and debit / credit (signed)
  TYPES:
    BEGIN OF ty_doc_assign,
      bukrs      TYPE ty_bukrs,
      belnr      TYPE ty_belnr,
      gjahr      TYPE ty_gjahr,
      zuonr      TYPE ty_zuonr,
      cdi        TYPE ty_cdi,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_doc_assign.
  TYPES tt_doc_assign TYPE STANDARD TABLE OF ty_doc_assign WITH EMPTY KEY.

  "! Clearing-account lines of an assignment group per debit / credit (signed)
  TYPES:
    BEGIN OF ty_assign_sum,
      zuonr      TYPE ty_zuonr,
      cdi        TYPE ty_cdi,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_assign_sum.
  TYPES tt_assign_sum TYPE STANDARD TABLE OF ty_assign_sum WITH EMPTY KEY.

  "! Assignment group of the clearing account whose lines do not net to zero
  TYPES:
    BEGIN OF ty_open_assign,
      zuonr      TYPE ty_zuonr,
      first_day  TYPE d,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_open_assign.
  TYPES tt_open_assign TYPE STANDARD TABLE OF ty_open_assign WITH EMPTY KEY.

  " ------------------------------------------------------------ evaluation
  "! Everything the pure rules need for one set and window (no SQL)
  TYPES:
    BEGIN OF ty_eval_input,
      set            TYPE ty_set,
      from           TYPE d,
      to             TYPE d,
      report_date    TYPE d,
      tolerance      TYPE ty_amount,
      timing_days    TYPE i,
      redeposit_days TYPE i,
      "! FEBEP-EPVOZ value of a credit / debit (EBS parameters EBS_FEB_CREDIT_IND / _DEBIT_IND)
      credit_ind     TYPE ty_cdi,
      debit_ind      TYPE ty_cdi,
      "! Reference procedure of the payment engine G/L transfer (TRACE_GL_AWTYP)
      fica_awtyp     TYPE ty_awtyp,
      "! Last day the account's statements cover (initial = no statement)
      last_bank_day  TYPE d,
      roles          TYPE tt_btc_role,
      bank_days      TYPE tt_bank_day,
      "! Lines of REDEPOSIT codes without a returns lot (DFKKRP-SELW1 = FEBEP-CHECT)
      bank_no_lot    TYPE tt_bank_day,
      gl_days        TYPE tt_gl_day,
      fica_days      TYPE tt_fica_day,
      pay_days       TYPE tt_pay_day,
    END OF ty_eval_input.

  "! Result of one group day (set + posting day)
  TYPES:
    BEGIN OF ty_group_day,
      day          TYPE d,
      bank         TYPE ty_amount,
      gl_fica      TYPE ty_amount,
      gl_other     TYPE ty_amount,
      fica         TYPE ty_amount,
      payments     TYPE ty_amount,
      diff_bank_gl TYPE ty_amount,
      diff_gl_fica TYPE ty_amount,
      "! Bank <-> G/L difference left after timing and buckets
      residual     TYPE ty_amount,
      status       TYPE ty_status,
      sub_status   TYPE ty_status,
      "! Buckets that explained the bank <-> G/L difference (in allocation order)
      buckets      TYPE tt_bucket,
      bank_lines   TYPE i,
      gl_lines     TYPE i,
      fica_lines   TYPE i,
    END OF ty_group_day.
  TYPES tt_group_day TYPE STANDARD TABLE OF ty_group_day WITH EMPTY KEY.

  "! Lines of bank codes without a role in the set (new or unmapped codes)
  TYPES:
    BEGIN OF ty_unmapped,
      btc        TYPE ty_btc,
      amount     TYPE ty_amount,
      line_count TYPE i,
    END OF ty_unmapped.
  TYPES tt_unmapped TYPE STANDARD TABLE OF ty_unmapped WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_eval_result,
      days     TYPE tt_group_day,
      unmapped TYPE tt_unmapped,
    END OF ty_eval_result.

  "! Stripe descriptor group: charges + fees (signed) against the deposit
  TYPES:
    BEGIN OF ty_stripe_group,
      zuonr      TYPE ty_zuonr,
      "! Deposit document when no descriptor was found (deposit not on the clearing account)
      belnr      TYPE ty_belnr,
      day        TYPE d,
      charges    TYPE ty_amount,
      fees       TYPE ty_amount,
      deposit    TYPE ty_amount,
      difference TYPE ty_amount,
      status     TYPE ty_status,
    END OF ty_stripe_group.
  TYPES tt_stripe_group TYPE STANDARD TABLE OF ty_stripe_group WITH EMPTY KEY.

  "! Unmatched ACH assignment groups of one first day
  TYPES:
    BEGIN OF ty_ach_day,
      day         TYPE d,
      group_count TYPE i,
      amount      TYPE ty_amount,
      first_zuonr TYPE ty_zuonr,
      status      TYPE ty_status,
    END OF ty_ach_day.
  TYPES tt_ach_day TYPE STANDARD TABLE OF ty_ach_day WITH EMPTY KEY.

  " ------------------------------------------------------------ constants
  CONSTANTS gc_check_id TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_RECON_3WAY'.
  "! Separator of the group key BUKRS/HKONT/WAERS (DIM1) and of finding object keys
  CONSTANTS gc_key_sep TYPE c LENGTH 1 VALUE '/'.
  "! Separator of the bucket list in a finding text
  CONSTANTS gc_list_sep TYPE string VALUE `,`.
  "! Last part of a finding object key <group>/<day or descriptor>/<leg>
  CONSTANTS:
    BEGIN OF gc_leg,
      bank     TYPE c LENGTH 4 VALUE 'BANK',
      fica     TYPE c LENGTH 4 VALUE 'FICA',
      ach      TYPE c LENGTH 4 VALUE 'ACH',
      stripe   TYPE c LENGTH 4 VALUE 'STRP',
      unmapped TYPE c LENGTH 4 VALUE 'BTC',
    END OF gc_leg.
  "! Group key widths: company code / G/L account (internal, ALPHA) / currency at fixed positions,
  "! so ZI_CD_HckRecon splits DIM1 by position (cds_abap_parity)
  CONSTANTS:
    BEGIN OF gc_group_width,
      bukrs TYPE i VALUE 4,
      hkont TYPE i VALUE 10,
      waers TYPE i VALUE 5,
    END OF gc_group_width.

  CONSTANTS:
    BEGIN OF gc_kind,
      threeway  TYPE ty_kind VALUE 'THREEWAY',
      ach_zuonr TYPE ty_kind VALUE 'ACH_ZUONR',
      stripe    TYPE ty_kind VALUE 'STRIPE',
    END OF gc_kind.

  CONSTANTS:
    BEGIN OF gc_role,
      leg       TYPE ty_role VALUE 'LEG',
      deposit   TYPE ty_role VALUE 'DEPOSIT',
      cutoff    TYPE ty_role VALUE 'CUTOFF',
      redeposit TYPE ty_role VALUE 'REDEPOSIT',
      cheque    TYPE ty_role VALUE 'CHEQUE',
      other     TYPE ty_role VALUE 'OTHER',
      ignore    TYPE ty_role VALUE 'IGNORE',
    END OF gc_role.

  "! Variance buckets: shown apart from true breaks (timing, cut-off and a pending redeposit
  "! are listed as information; cheque, unmapped and other are a warning)
  CONSTANTS:
    BEGIN OF gc_bucket,
      timing    TYPE ty_bucket VALUE 'TIMING',
      cutoff    TYPE ty_bucket VALUE 'CUTOFF',
      redeposit TYPE ty_bucket VALUE 'REDEPOSIT',
      cheque    TYPE ty_bucket VALUE 'CHEQUE',
      unmapped  TYPE ty_bucket VALUE 'UNMAPPED',
      other     TYPE ty_bucket VALUE 'OTHER',
    END OF gc_bucket.

  "! Status of a group day (bank <-> G/L, G/L <-> payment engine, Stripe group, ACH day)
  CONSTANTS:
    BEGIN OF gc_status,
      balanced TYPE ty_status VALUE 'BALANCED',
      break    TYPE ty_status VALUE 'BREAK',
      timing   TYPE ty_status VALUE 'TIMING',
      variance TYPE ty_status VALUE 'VARIANCE',
      "! No bank, G/L or payment engine evidence: grey, never green
      empty    TYPE ty_status VALUE 'EMPTY',
      "! Leg not compared (leg mapping of the set)
      none     TYPE ty_status VALUE 'NONE',
    END OF gc_status.

  "! Why a set was not evaluated (RECON_CONFIG)
  CONSTANTS:
    BEGIN OF gc_config_reason,
      no_account TYPE ty_status VALUE 'NO_ACCOUNT',
      duplicate  TYPE ty_status VALUE 'DUPLICATE',
      no_deposit TYPE ty_status VALUE 'NO_DEPOSIT',
    END OF gc_config_reason.

  CONSTANTS:
    BEGIN OF gc_code,
      "! Bank <> G/L beyond the tolerance, not explained by a bucket (also unmatched ACH groups)
      recon_break      TYPE zif_cd_ops_types=>ty_check_code VALUE 'RECON_BREAK',
      "! G/L <> payment engine control total beyond the tolerance
      subledger_break  TYPE zif_cd_ops_types=>ty_check_code VALUE 'RECON_SUBLEDGER_BREAK',
      "! Stripe descriptor group <> BAI deposit + fees
      stripe_break     TYPE zif_cd_ops_types=>ty_check_code VALUE 'STRIPE_GROUP_BREAK',
      "! Difference explained by timing, cut-off or a pending redeposit (information)
      recon_timing     TYPE zif_cd_ops_types=>ty_check_code VALUE 'RECON_TIMING',
      "! Difference explained by a cheque, unmapped-code or other bucket (warning)
      recon_variance   TYPE zif_cd_ops_types=>ty_check_code VALUE 'RECON_VARIANCE',
      "! A set without any evidence in the window (information; check grey when no set has any)
      recon_no_data    TYPE zif_cd_ops_types=>ty_check_code VALUE 'RECON_NO_DATA',
      "! A set that cannot be evaluated (house bank account, duplicate group, deposit codes)
      recon_config     TYPE zif_cd_ops_types=>ty_check_code VALUE 'RECON_CONFIG',
    END OF gc_code.

  "! Metrics (ZCD_HCK_METRIC; DIM1 = BUKRS/HKONT/WAERS): differences per day (DIM2 ISO day),
  "! bucket and status counts (DIM2 bucket / status), Stripe group differences (DIM2 descriptor)
  CONSTANTS:
    BEGIN OF gc_metric,
      diff_bank_gl TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_DIFF_BANK_GL',
      diff_gl_fica TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_DIFF_GL_FICA',
      unexplained  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_UNEXPLAINED',
      bucket       TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_BUCKET',
      days         TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_DAYS',
      stripe_diff  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_STRIPE_DIFF',
      ach_open     TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_ACH_OPEN',
      breaks       TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RC_BREAKS',
    END OF gc_metric.
  "! Prefix of every metric of the check (ZI_CD_HckRecon selects by it; cds_abap_parity)
  CONSTANTS gc_metric_prefix TYPE string VALUE `RC_`.

  " ------------------------------------------------------------ parameters (ZCA_PARAM)
  "! Hard ceiling of HCK_RECON_MAX_ROWS (assignment groups of one read)
  CONSTANTS gc_max_rows TYPE i VALUE 50000.

  CONSTANTS:
    BEGIN OF gc_param,
      "! Days before the report date that are reconciled
      lookback_days  TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_RECON_LOOKBACK_DAYS',
      "! Days a difference may stay open as timing (statement next day / month)
      timing_days    TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_RECON_TIMING_DAYS',
      "! Days a failed collection (468) may wait for its delayed redeposit without a returns lot
      redeposit_days TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_RECON_REDEPOSIT_DAYS',
      "! Absolute tolerance per group day when the set has none
      tolerance      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_RECON_TOLERANCE',
      "! Assignment groups of one read (ACH pairs, Stripe groups)
      max_rows       TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_RECON_MAX_ROWS',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      lookback_days  TYPE i VALUE 7,
      timing_days    TYPE i VALUE 3,
      redeposit_days TYPE i VALUE 10,
      tolerance      TYPE string VALUE `0.00`,
      max_rows       TYPE i VALUE 5000,
    END OF gc_param_default.

  "! Message numbers (class ZCD_OPS)
  CONSTANTS:
    BEGIN OF gc_msg,
      recon_break      TYPE zif_cd_ops_types=>ty_msgno VALUE '690',
      subledger_break  TYPE zif_cd_ops_types=>ty_msgno VALUE '691',
      stripe_break     TYPE zif_cd_ops_types=>ty_msgno VALUE '692',
      recon_timing     TYPE zif_cd_ops_types=>ty_msgno VALUE '693',
      recon_variance   TYPE zif_cd_ops_types=>ty_msgno VALUE '694',
      ach_unmatched    TYPE zif_cd_ops_types=>ty_msgno VALUE '695',
      no_data          TYPE zif_cd_ops_types=>ty_msgno VALUE '696',
      unmapped_codes   TYPE zif_cd_ops_types=>ty_msgno VALUE '697',
      summary          TYPE zif_cd_ops_types=>ty_msgno VALUE '698',
      set_not_used     TYPE zif_cd_ops_types=>ty_msgno VALUE '699',
    END OF gc_msg.

ENDINTERFACE.
