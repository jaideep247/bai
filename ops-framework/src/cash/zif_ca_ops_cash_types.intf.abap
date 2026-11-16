*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cash_types.intf.abap
*& Purpose:
*& Types and constants of the FI-CA cash operations checks (package
*& ZCA_OPS_CASH, docs/FICA_CASH_OPERATIONS.md): stages of the cash cycle,
*& evaluation states (observed, valid zero volume, not expected on a
*& non-working day, not evaluated), object types and check codes of the
*& findings, parameters CASH_* with their code defaults, messages 500-549,
*& the aggregated rows the data access returns (ZIF_CA_OPS_CASH_DAO) and
*& the typed exception of the builder ZCL_CA_OPS_CASH_EXC - count, amount
*& per currency, oldest item, next cutoff, owner, stage and evidence keys
*& at source grain. No logic.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | Exception contract (build K merge): TY_CUTOFF-CALENDAR_ID.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - types and constants</p>
"! Status VALUES of SAP tables are never constants here: they are parameters with a blank (pending) default, and a
"! rule whose value is pending reports "not evaluated" (docs/FICA_CASH_OPERATIONS.md section 4, VERIFY V220 ff.).
"! Indicator fields (X / blank) are compared as set / not set; their meaning is a VERIFY item.
INTERFACE zif_ca_ops_cash_types
  PUBLIC.

  TYPES ty_stage      TYPE zif_ca_ops_types=>ty_rule_id.
  TYPES ty_evaluation TYPE c LENGTH 14.
  TYPES ty_key_name   TYPE c LENGTH 20.
  TYPES ty_key_value  TYPE c LENGTH 40.
  TYPES ty_amount     TYPE zif_ca_ops_types=>ty_amount.
  TYPES ty_bank_id    TYPE c LENGTH 5.

  "! Stage of the cash cycle where the cycle stopped (RULE_ID of the finding)
  CONSTANTS:
    BEGIN OF gc_stage,
      "! The run / statement expected by the business calendar did not happen
      schedule TYPE ty_stage VALUE 'SCHEDULE',
      "! The job of the run ended without success
      job      TYPE ty_stage VALUE 'JOB',
      "! The job finished successfully, the business output is incomplete (failure injection)
      job_ok   TYPE ty_stage VALUE 'JOB_OK',
      proposal TYPE ty_stage VALUE 'PROPOSAL',
      payment  TYPE ty_stage VALUE 'PAYMENT',
      posting  TYPE ty_stage VALUE 'POSTING',
      clarify  TYPE ty_stage VALUE 'CLARIFY',
      returns  TYPE ty_stage VALUE 'RETURNS',
      reversal TYPE ty_stage VALUE 'REVERSAL',
      arrival  TYPE ty_stage VALUE 'ARRIVAL',
      transfer TYPE ty_stage VALUE 'TRANSFER',
      reset    TYPE ty_stage VALUE 'RESET',
      close    TYPE ty_stage VALUE 'CLOSE',
      gl       TYPE ty_stage VALUE 'GL',
    END OF gc_stage.

  "! Expected, observed and unknown (docs/FICA_CASH_OPERATIONS.md section 3): what an evaluation concluded
  CONSTANTS:
    BEGIN OF gc_evaluation,
      "! The source was read and shows the business output (or the exception)
      observed      TYPE ty_evaluation VALUE 'OBSERVED',
      "! The job ran and finished, the source shows no output: a valid zero-volume day
      zero_volume   TYPE ty_evaluation VALUE 'ZERO_VOLUME',
      "! Not a working day of the business calendar: nothing expected
      not_expected  TYPE ty_evaluation VALUE 'NOT_EXPECTED',
      "! Nothing at all arrived from the source for an expected day (stale source)
      stale         TYPE ty_evaluation VALUE 'STALE',
      "! The rule could not be evaluated (value pending, read failed, calendar unknown): never green
      not_evaluated TYPE ty_evaluation VALUE 'NOT_EVALUATED',
    END OF gc_evaluation.

  "! Object types of the findings (OBJECT_TYPE)
  CONSTANTS:
    BEGIN OF gc_object_type,
      run          TYPE zif_ca_ops_types=>ty_object_type VALUE 'PAYRUN',
      lot          TYPE zif_ca_ops_types=>ty_object_type VALUE 'PAYLOT',
      returns_lot  TYPE zif_ca_ops_types=>ty_object_type VALUE 'RETLOT',
      statement    TYPE zif_ca_ops_types=>ty_object_type VALUE 'STATEMENT',
      bank_account TYPE zif_ca_ops_types=>ty_object_type VALUE 'BANKACCT',
      document     TYPE zif_ca_ops_types=>ty_object_type VALUE 'DOCUMENT',
      recon_key    TYPE zif_ca_ops_types=>ty_object_type VALUE 'RECONKEY',
      day          TYPE zif_ca_ops_types=>ty_object_type VALUE 'DAY',
      "! A rule of a check (not evaluated, result capped)
      rule         TYPE zif_ca_ops_types=>ty_object_type VALUE 'CASHRULE',
    END OF gc_object_type.

  "! Check codes of the findings
  CONSTANTS:
    BEGIN OF gc_code,
      payrun_missing    TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAYRUN_MISSING',
      payrun_job_failed TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAYRUN_JOB_FAILED',
      payrun_gap        TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAYRUN_PROPOSAL_GAP',
      payrun_no_doc     TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAYRUN_NO_DOCUMENT',
      lot_not_posted    TYPE zif_ca_ops_types=>ty_check_code VALUE 'LOT_NOT_POSTED',
      lot_clarif        TYPE zif_ca_ops_types=>ty_check_code VALUE 'LOT_CLARIFICATION_AGED',
      retlot_open       TYPE zif_ca_ops_types=>ty_check_code VALUE 'RETURNS_LOT_NOT_CLOSED',
      return_clarif     TYPE zif_ca_ops_types=>ty_check_code VALUE 'RETURNS_CLARIFICATION_AGED',
      return_no_doc     TYPE zif_ca_ops_types=>ty_check_code VALUE 'RETURNS_REVERSAL_PENDING',
      ebs_missing       TYPE zif_ca_ops_types=>ty_check_code VALUE 'EBS_STATEMENT_MISSING',
      ebs_stale         TYPE zif_ca_ops_types=>ty_check_code VALUE 'EBS_SOURCE_STALE',
      ebs_unposted      TYPE zif_ca_ops_types=>ty_check_code VALUE 'EBS_LINES_NOT_POSTED',
      ebs_not_fica      TYPE zif_ca_ops_types=>ty_check_code VALUE 'EBS_NOT_TRANSFERRED_FICA',
      clr_reset         TYPE zif_ca_ops_types=>ty_check_code VALUE 'CLEARING_RESET_AFTER_PAYOUT',
      pay_reversed      TYPE zif_ca_ops_types=>ty_check_code VALUE 'PAYMENT_REVERSED_AFTER_PAYOUT',
      glkey_open        TYPE zif_ca_ops_types=>ty_check_code VALUE 'GLKEY_OPEN_PAST_CUTOFF',
      glkey_error       TYPE zif_ca_ops_types=>ty_check_code VALUE 'GLKEY_TRANSFER_ERROR',
      glkey_not_gl      TYPE zif_ca_ops_types=>ty_check_code VALUE 'GLKEY_NOT_IN_GL',
      "! Information: a valid zero-volume day / a day the calendar does not expect output
      zero_volume       TYPE zif_ca_ops_types=>ty_check_code VALUE 'CASH_ZERO_VOLUME',
      not_expected      TYPE zif_ca_ops_types=>ty_check_code VALUE 'CASH_NOT_EXPECTED',
      "! A rule that could not be evaluated (never green; the check is partial)
      not_evaluated     TYPE zif_ca_ops_types=>ty_check_code VALUE 'CASH_NOT_EVALUATED',
      "! More objects than CASH_MAX_ROWS: the first are reported, the check is partial
      capped            TYPE zif_ca_ops_types=>ty_check_code VALUE 'CASH_RESULT_CAPPED',
    END OF gc_code.

  "! Source tables (REFERENCE of a finding, reason of a failed read)
  CONSTANTS:
    BEGIN OF gc_source,
      payments  TYPE zif_ca_ops_types=>ty_reference VALUE 'DPAYH',
      jobs      TYPE zif_ca_ops_types=>ty_reference VALUE 'TBTCO',
      lots      TYPE zif_ca_ops_types=>ty_reference VALUE 'DFKKZK/DFKKZP',
      returns   TYPE zif_ca_ops_types=>ty_reference VALUE 'DFKKRK/DFKKRP',
      statement TYPE zif_ca_ops_types=>ty_reference VALUE 'FEBKO/FEBEP',
      to_fica   TYPE zif_ca_ops_types=>ty_reference VALUE 'FEBEP/DFKKZK',
      resets    TYPE zif_ca_ops_types=>ty_reference VALUE 'DFKKRAPT/DPAYH',
      reversals TYPE zif_ca_ops_types=>ty_reference VALUE 'DFKKKO/DPAYH',
      keys      TYPE zif_ca_ops_types=>ty_reference VALUE 'DFKKSUMC/DFKKSUM',
      journal   TYPE zif_ca_ops_types=>ty_reference VALUE 'DFKKSUM/I_JOURNALENTRY',
      calendar  TYPE zif_ca_ops_types=>ty_reference VALUE 'FACTORY CALENDAR',
      control   TYPE zif_ca_ops_types=>ty_reference VALUE 'ZCA_OPS_CONTROL',
    END OF gc_source.

  "! Names of the evidence keys at source grain (docs/FICA_CASH_OPERATIONS.md section 5)
  CONSTANTS:
    BEGIN OF gc_key,
      run       TYPE ty_key_name VALUE 'LAUFD/LAUFI',
      lot       TYPE ty_key_name VALUE 'KEYZ1',
      returns   TYPE ty_key_name VALUE 'KEYR1',
      statement TYPE ty_key_name VALUE 'KUKEY',
      account   TYPE ty_key_name VALUE 'HBKID/HKTID',
      document  TYPE ty_key_name VALUE 'OPBEL',
      payment   TYPE ty_key_name VALUE 'DOC1R',
      clearing  TYPE ty_key_name VALUE 'AUGBL',
      recon_key TYPE ty_key_name VALUE 'FIKEY',
      journal   TYPE ty_key_name VALUE 'AWTYP/AWKEY',
      job       TYPE ty_key_name VALUE 'JOBNAME/JOBCOUNT',
      day       TYPE ty_key_name VALUE 'DATE',
    END OF gc_key.

  "! Debit / credit indicator of DFKKSUM-SHKZG: H = credit (the debit side is the key's gross volume)
  CONSTANTS gc_shkzg_credit TYPE c LENGTH 1 VALUE 'H'.
  "! Mask of a job name parameter (*) and the escape character of the LIKE pattern built from it
  CONSTANTS gc_job_mask TYPE c LENGTH 1 VALUE '*'.
  CONSTANTS gc_like_escape TYPE c LENGTH 1 VALUE '#'.
  "! Working days searched for the next cutoff before it is reported unknown
  CONSTANTS gc_cutoff_search_days TYPE i VALUE 14.

  "! Parameters (area CA_OPS, prefix CASH_; config/param_definitions.csv, docs/PARAMETERS.md)
  CONSTANTS:
    BEGIN OF gc_param,
      calendar          TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_CALENDAR',
      lookback_days     TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_LOOKBACK_DAYS',
      max_rows          TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_MAX_ROWS',
      payrun_lag_days   TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_PAYRUN_LAG_DAYS',
      payrun_bukrs      TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_PAYRUN_BUKRS',
      payrun_jobname    TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_PAYRUN_JOBNAME',
      payrun_min_age    TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_PAYRUN_MIN_AGE_DAYS',
      payrun_gap_active TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_PAYRUN_GAP_ACTIVE',
      payrun_order_meth TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_PAYRUN_ORDER_METHODS',
      lot_done_status   TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_LOT_DONE_STATUS',
      lot_days          TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_LOT_DAYS',
      lot_clarif_days   TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_LOT_CLARIF_DAYS',
      ret_done_status   TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_RET_DONE_STATUS',
      ret_days          TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_RET_DAYS',
      ret_clarif_days   TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_RET_CLARIF_DAYS',
      ebs_lag_days      TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_EBS_LAG_DAYS',
      ebs_account_days  TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_EBS_ACCOUNT_DAYS',
      ebs_post_days     TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_EBS_POST_DAYS',
      ebs_fica_banks    TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_EBS_FICA_BANKS',
      clr_days          TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_CLR_DAYS',
      clr_augrd         TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_CLR_AUGRD',
      glkey_open_days   TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_GLKEY_OPEN_DAYS',
      glkey_gl_days     TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_GLKEY_GL_DAYS',
      gl_awtyp          TYPE zif_ca_ops_types=>ty_param_name VALUE 'CASH_GL_AWTYP',
    END OF gc_param.

  "! Code defaults (equal to the definition defaults; status values have none - pending)
  CONSTANTS:
    BEGIN OF gc_param_default,
      lookback_days   TYPE i VALUE 7,
      max_rows        TYPE i VALUE 500,
      payrun_lag_days TYPE i VALUE 1,
      payrun_min_age  TYPE i VALUE 1,
      lot_days        TYPE i VALUE 1,
      lot_clarif_days TYPE i VALUE 3,
      ret_days        TYPE i VALUE 1,
      ret_clarif_days TYPE i VALUE 3,
      ebs_lag_days    TYPE i VALUE 1,
      ebs_account_days TYPE i VALUE 30,
      ebs_post_days   TYPE i VALUE 1,
      clr_days        TYPE i VALUE 1,
      glkey_open_days TYPE i VALUE 1,
      glkey_gl_days   TYPE i VALUE 1,
    END OF gc_param_default.

  "! Messages of the cash checks (message class ZCA_OPS, 500-549)
  CONSTANTS:
    BEGIN OF gc_msg,
      payrun_missing    TYPE zif_ca_ops_types=>ty_msgno VALUE '500',
      payrun_job_failed TYPE zif_ca_ops_types=>ty_msgno VALUE '501',
      payrun_gap        TYPE zif_ca_ops_types=>ty_msgno VALUE '502',
      payrun_no_doc     TYPE zif_ca_ops_types=>ty_msgno VALUE '503',
      payrun_job_ok     TYPE zif_ca_ops_types=>ty_msgno VALUE '504',
      lot_not_posted    TYPE zif_ca_ops_types=>ty_msgno VALUE '505',
      lot_clarif        TYPE zif_ca_ops_types=>ty_msgno VALUE '506',
      retlot_open       TYPE zif_ca_ops_types=>ty_msgno VALUE '507',
      return_clarif     TYPE zif_ca_ops_types=>ty_msgno VALUE '508',
      return_no_doc     TYPE zif_ca_ops_types=>ty_msgno VALUE '509',
      ebs_missing       TYPE zif_ca_ops_types=>ty_msgno VALUE '510',
      ebs_stale         TYPE zif_ca_ops_types=>ty_msgno VALUE '511',
      ebs_unposted      TYPE zif_ca_ops_types=>ty_msgno VALUE '512',
      ebs_not_fica      TYPE zif_ca_ops_types=>ty_msgno VALUE '513',
      clr_reset         TYPE zif_ca_ops_types=>ty_msgno VALUE '514',
      pay_reversed      TYPE zif_ca_ops_types=>ty_msgno VALUE '515',
      glkey_open        TYPE zif_ca_ops_types=>ty_msgno VALUE '516',
      glkey_error       TYPE zif_ca_ops_types=>ty_msgno VALUE '517',
      glkey_not_gl      TYPE zif_ca_ops_types=>ty_msgno VALUE '518',
      not_evaluated     TYPE zif_ca_ops_types=>ty_msgno VALUE '519',
      reason_param      TYPE zif_ca_ops_types=>ty_msgno VALUE '520',
      reason_read       TYPE zif_ca_ops_types=>ty_msgno VALUE '521',
      reason_calendar   TYPE zif_ca_ops_types=>ty_msgno VALUE '522',
      reason_no_cal     TYPE zif_ca_ops_types=>ty_msgno VALUE '523',
      capped            TYPE zif_ca_ops_types=>ty_msgno VALUE '524',
      zero_volume       TYPE zif_ca_ops_types=>ty_msgno VALUE '525',
      not_expected      TYPE zif_ca_ops_types=>ty_msgno VALUE '526',
      no_accounts       TYPE zif_ca_ops_types=>ty_msgno VALUE '527',
      det_stage         TYPE zif_ca_ops_types=>ty_msgno VALUE '530',
      det_amount        TYPE zif_ca_ops_types=>ty_msgno VALUE '531',
      det_oldest        TYPE zif_ca_ops_types=>ty_msgno VALUE '532',
      det_cutoff        TYPE zif_ca_ops_types=>ty_msgno VALUE '533',
      det_owner         TYPE zif_ca_ops_types=>ty_msgno VALUE '534',
      det_evidence      TYPE zif_ca_ops_types=>ty_msgno VALUE '535',
      det_source        TYPE zif_ca_ops_types=>ty_msgno VALUE '536',
      det_job           TYPE zif_ca_ops_types=>ty_msgno VALUE '537',
      det_no_owner      TYPE zif_ca_ops_types=>ty_msgno VALUE '538',
      det_cutoff_open   TYPE zif_ca_ops_types=>ty_msgno VALUE '539',
    END OF gc_msg.

  "! ---- Exception content (the builder ZCL_CA_OPS_CASH_EXC; build K's exception contract plugs in there) ----
  "! An evidence key at source grain (name = gc_key-*, value = the key, e.g. 20261112/PAY01)
  TYPES:
    BEGIN OF ty_evidence,
      name  TYPE ty_key_name,
      value TYPE ty_key_value,
    END OF ty_evidence.
  TYPES tt_evidence TYPE STANDARD TABLE OF ty_evidence WITH EMPTY KEY.

  "! Owner of a check from the existing configuration: the active control that covers the check
  "! (ZCA_OPS_CTLCHK GROUP2 = check ID, as ZI_CA_OpsCheckTeam) - owner, backup, team, cutoff time - else the
  "! business process owner (ZCA_OPS_PROC); blank = not assigned
  TYPES:
    BEGIN OF ty_owner,
      control_id  TYPE c LENGTH 20,
      owner       TYPE syuname,
      backup      TYPE syuname,
      team        TYPE c LENGTH 10,
      cutoff_time TYPE t,
    END OF ty_owner.

  "! Next cutoff of a check: the next working day of the business calendar at the control's cutoff time, in the
  "! time zone of the control review (CONTROL_TIME_ZONE); KNOWN blank = not determinable (no calendar / no cutoff)
  TYPES:
    BEGIN OF ty_cutoff,
      known     TYPE abap_bool,
      "! Business calendar the cutoff was computed in (CASH_CALENDAR; exception contract CALENDAR_ID, 2026-11-16)
      calendar_id TYPE zif_ca_ops_exc_contract=>ty_calendar_id,
      date      TYPE d,
      time      TYPE t,
      time_zone TYPE tznzone,
    END OF ty_cutoff.

  "! One exception of the cash checks before it becomes a finding (ZCL_CA_OPS_CASH_EXC=>TO_FINDING). Count and
  "! amount are per company code and currency - never summed across currencies; the oldest item date gives the
  "! age; cutoff and owner come from the configuration; the evidence keys identify the source records
  TYPES:
    BEGIN OF ty_exception,
      check_code    TYPE zif_ca_ops_types=>ty_check_code,
      severity      TYPE zif_ca_ops_types=>ty_severity,
      stage         TYPE ty_stage,
      evaluation    TYPE ty_evaluation,
      object_type   TYPE zif_ca_ops_types=>ty_object_type,
      "! Source-grain key of the object (run, lot, statement, document, key) + company code + currency
      object_key    TYPE zif_ca_ops_types=>ty_object_key,
      source        TYPE zif_ca_ops_types=>ty_reference,
      company_code  TYPE bukrs,
      currency      TYPE zif_ca_ops_types=>ty_currency,
      item_count    TYPE i,
      amount        TYPE ty_amount,
      oldest        TYPE d,
      age_days      TYPE i,
      cutoff        TYPE ty_cutoff,
      owner         TYPE ty_owner,
      "! House bank / account ID (a label, never an account number) and payment method where known
      account       TYPE c LENGTH 40,
      pay_method    TYPE c LENGTH 10,
      "! Parameter that drives the rule (CFG_RULE of the finding)
      rule_param    TYPE zif_ca_ops_types=>ty_param_name,
      evidence      TYPE tt_evidence,
      "! Main message of the finding (ZCA_OPS / msgno with up to four variables)
      msgno         TYPE zif_ca_ops_types=>ty_msgno,
      msgv1         TYPE string,
      msgv2         TYPE string,
      msgv3         TYPE string,
      msgv4         TYPE string,
      "! Free text appended to the details (a caught exception trace)
      note          TYPE string,
    END OF ty_exception.

  "! ---- Aggregated rows of the data access (ZIF_CA_OPS_CASH_DAO): every sum is computed on the database ----
  "! Payments of a run per paying company code and currency (DPAYH: proposal and payment run rows)
  TYPES:
    BEGIN OF ty_run_sum,
      run_date     TYPE d,
      run_id       TYPE c LENGTH 6,
      proposal     TYPE abap_bool,
      company_code TYPE bukrs,
      currency     TYPE zif_ca_ops_types=>ty_currency,
      "! Payment method (DPAYH-RZAWE): a payment-order method posts no payment document by design
      pay_method   TYPE c LENGTH 1,
      item_count   TYPE i,
      amount       TYPE ty_amount,
      "! Payments without payment document (DOC1R initial)
      nodoc_count  TYPE i,
      nodoc_amount TYPE ty_amount,
    END OF ty_run_sum.
  TYPES tt_run_sum TYPE STANDARD TABLE OF ty_run_sum WITH EMPTY KEY.

  "! A source object with its count, amount per currency and oldest date (lot, returns lot, statement, clearing
  "! document, payment document, reconciliation key)
  TYPES:
    BEGIN OF ty_sum,
      object_id    TYPE c LENGTH 24,
      "! Second part of the key where the object has one (run ID, statement date, closing date)
      object_sub   TYPE c LENGTH 24,
      company_code TYPE bukrs,
      currency     TYPE zif_ca_ops_types=>ty_currency,
      house_bank   TYPE ty_bank_id,
      account_id   TYPE ty_bank_id,
      item_count   TYPE i,
      amount       TYPE ty_amount,
      oldest       TYPE d,
    END OF ty_sum.
  TYPES tt_sum TYPE STANDARD TABLE OF ty_sum WITH EMPTY KEY.

  "! Bank statements of an account and statement date (FEBKO)
  TYPES:
    BEGIN OF ty_statement_day,
      company_code    TYPE bukrs,
      house_bank      TYPE ty_bank_id,
      account_id      TYPE ty_bank_id,
      statement_date  TYPE d,
      statement_count TYPE i,
    END OF ty_statement_day.
  TYPES tt_statement_day TYPE STANDARD TABLE OF ty_statement_day WITH EMPTY KEY.

  "! A day of the evaluation window and whether the business calendar expects output on it
  TYPES:
    BEGIN OF ty_day,
      date    TYPE d,
      working TYPE abap_bool,
    END OF ty_day.
  TYPES tt_day TYPE STANDARD TABLE OF ty_day WITH EMPTY KEY.

ENDINTERFACE.
