*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pilot_types.intf.abap
*& Purpose:
*& Types and constants of the pilot pack (proof of value in shadow mode,
*& docs/PILOT_PACK.md): the metrics per day, area, business process and
*& check (CDS ZI_CA_OpsPilotDay), the share of breaks explained (CDS
*& ZR_CA_OpsPilotBrk), the baselines (ZCA_OPS_PILOTBL), the CSV layout of
*& the export, parameters (prefix PILOT_, area CA_OPS) and the messages
*& 300-305 of ZCA_OPS. Read-only metrics of existing data. No logic.
*& Modification log:
*& 2026-11-11 | Initial version (build F: pilot pack).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - pilot pack types</p>
INTERFACE zif_ca_ops_pilot_types
  PUBLIC.

  "! Parameters of the pilot pack (area CA_OPS, prefix PILOT_)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Reason code that marks a resolved exception as a false positive (read in CDS) [NOT_AN_ISSUE]
      fp_reason   TYPE zif_ca_ops_types=>ty_param_name VALUE 'PILOT_FP_REASON',
      "! Days the export covers when no date is entered [30]
      window_days TYPE zif_ca_ops_types=>ty_param_name VALUE 'PILOT_WINDOW_DAYS',
      "! Logical path and logical file name (transaction FILE) of the export [blank]
      export_path TYPE zif_ca_ops_types=>ty_param_name VALUE 'PILOT_EXPORT_PATH',
      export_file TYPE zif_ca_ops_types=>ty_param_name VALUE 'PILOT_EXPORT_FILE',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_default,
      fp_reason   TYPE zif_ca_ops_types=>ty_param_value VALUE 'NOT_AN_ISSUE',
      window_days TYPE i VALUE 30,
    END OF gc_default.

  "! Messages of ZCA_OPS (300-305)
  CONSTANTS:
    BEGIN OF gc_msg,
      exported   TYPE zif_ca_ops_types=>ty_msgno VALUE '300',
      nothing    TYPE zif_ca_ops_types=>ty_msgno VALUE '301',
      path_blank TYPE zif_ca_ops_types=>ty_msgno VALUE '302',
      write_fail TYPE zif_ca_ops_types=>ty_msgno VALUE '303',
    END OF gc_msg.

  "! Separator of the CSV fields and the record kinds of the export (first column)
  CONSTANTS gc_separator TYPE c LENGTH 1 VALUE ';'.
  CONSTANTS gc_quote TYPE c LENGTH 1 VALUE '"'.
  CONSTANTS:
    BEGIN OF gc_record,
      day      TYPE string VALUE `DAY`,
      break    TYPE string VALUE `BREAK`,
      baseline TYPE string VALUE `BASELINE`,
    END OF gc_record.
  "! Column names of the two record kinds (header lines of the export; identifiers, not texts)
  CONSTANTS gc_header_day TYPE string
    VALUE `RECORD;RAISED_DATE;AREA;PROCESS_ID;CHECK_ID;RAISED;ASSIGNED;RESOLVED;FALSE_POSITIVES;FP_RATE_PCT;`
        & `DETECT_KNOWN;AVG_MIN_TO_DETECT;BASELINE_KNOWN;AVG_BASELINE_MIN;DETECTED_EARLIER;AVG_MIN_TO_ASSIGN;`
        & `AVG_MIN_TO_RESOLVE`.
  CONSTANTS gc_header_break TYPE string
    VALUE `RECORD;KEY_DATE;AREA;ACCOUNT_ID;COMPANY_CODE;BREAKS;EXPLAINED;UNEXPLAINED;EXPLAINED_PCT`.
  CONSTANTS gc_header_baseline TYPE string VALUE `RECORD;AREA;CHECK_ID;BASELINE_MIN;SOURCE`.

  "! Metrics of one day, area, business process and check (CDS ZI_CA_OpsPilotDay)
  TYPES:
    BEGIN OF ty_day,
      raiseddate         TYPE d,
      area               TYPE zif_ca_ops_types=>ty_area,
      processid          TYPE c LENGTH 35,
      checkid            TYPE c LENGTH 35,
      raisedcount        TYPE i,
      assignedcount      TYPE i,
      resolvedcount      TYPE i,
      falsepositivecount TYPE i,
      detectknowncount   TYPE i,
      baselineknowncount TYPE i,
      earliercount       TYPE i,
      minutestodetect    TYPE p LENGTH 12 DECIMALS 1,
      baselineminutes    TYPE p LENGTH 12 DECIMALS 1,
      minutestoassign    TYPE p LENGTH 12 DECIMALS 1,
      minutestoresolve   TYPE p LENGTH 12 DECIMALS 1,
    END OF ty_day.
  TYPES tt_day TYPE STANDARD TABLE OF ty_day WITH EMPTY KEY.

  "! Breaks explained of one account and key date (CDS ZR_CA_OpsPilotBrk)
  TYPES:
    BEGIN OF ty_break,
      area             TYPE zif_ca_ops_types=>ty_area,
      accountid        TYPE c LENGTH 20,
      companycode      TYPE bukrs,
      keydate          TYPE d,
      groupcount       TYPE i,
      explainedcount   TYPE i,
      unexplainedcount TYPE i,
    END OF ty_break.
  TYPES tt_break TYPE STANDARD TABLE OF ty_break WITH EMPTY KEY.

  "! The previous detection time of a check (ZCA_OPS_PILOTBL)
  TYPES:
    BEGIN OF ty_baseline,
      area         TYPE zif_ca_ops_types=>ty_area,
      check_id     TYPE c LENGTH 20,
      baseline_min TYPE i,
      source       TYPE c LENGTH 60,
    END OF ty_baseline.
  TYPES tt_baseline TYPE STANDARD TABLE OF ty_baseline WITH EMPTY KEY.

ENDINTERFACE.
