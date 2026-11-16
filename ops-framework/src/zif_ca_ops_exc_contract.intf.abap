*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_exc_contract.intf.abap
*& Purpose:
*& The exception contract of the operations framework
*& (docs/EXCEPTION_CONTRACT.md): what every finding of a module that
*& adopts it carries besides the store's own fields - the number of items
*& it stands for (ZIF_CA_OPS_TYPES=>TY_FINDING-ITEM_COUNT) and of them
*& those without a known amount, the gross amount with its currency
*& (TY_FINDING-AMOUNT / CURRENCY, one currency per finding - never summed
*& across currencies), the possible duplicate exposure kept apart, the
*& deadline (UTC) with its business calendar, the stage where the
*& process stopped, the responsible user and team from the configuration
*& and the key of its typed evidence rows (ZCA_OPS_FNDEVI), each linkable
*& through the link registry walker. TY_CONTRACT is included in
*& TY_FINDING; TY_EVIDENCE rows are returned by a check
*& (ZIF_CA_OPS_CHK_TYPES=>TY_RESULT-EVIDENCE) and stored by the runner.
*& Validation: ZCL_CA_OPS_EXC_CONTRACT. No logic.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle, first module that adopts it).
*& 2026-11-16 | Evidence kind SCHD: the external scheduler's record (expected runs, build P).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - exception contract</p>
"! Built-in types only: ZIF_CA_OPS_TYPES includes TY_CONTRACT in its finding.
INTERFACE zif_ca_ops_exc_contract
  PUBLIC.

  TYPES ty_evid_key    TYPE c LENGTH 40.
  TYPES ty_stage       TYPE c LENGTH 12.
  TYPES ty_calendar_id TYPE c LENGTH 2.
  TYPES ty_team        TYPE c LENGTH 10.
  TYPES ty_resp_source TYPE c LENGTH 1.
  TYPES ty_evid_kind   TYPE c LENGTH 4.
  TYPES ty_evid_type   TYPE c LENGTH 10.
  TYPES ty_quality     TYPE c LENGTH 1.
  TYPES ty_link_object TYPE c LENGTH 30.
  TYPES ty_link_value  TYPE c LENGTH 200.
  TYPES ty_native_key  TYPE c LENGTH 120.
  TYPES ty_label       TYPE c LENGTH 60.
  TYPES ty_source_id   TYPE c LENGTH 10.
  TYPES ty_gap         TYPE c LENGTH 10.
  TYPES tt_gap         TYPE STANDARD TABLE OF ty_gap WITH EMPTY KEY.
  "! Amount of the contract (as ZCA_OPS_FINDING-AMOUNT: DEC 23,2)
  TYPES ty_amount      TYPE p LENGTH 12 DECIMALS 2.

  "! The contract fields of a finding (stored as ZCA_OPS_FINDING-UNKNOWN_COUNT ... EVID_KEY)
  TYPES:
    BEGIN OF ty_contract,
      "! Items of ITEM_COUNT whose amount is not known (the gross AMOUNT is then a lower bound)
      unknown_count TYPE i,
      "! Possible duplicate exposure in the finding's currency (e.g. the same payments in a reissued file) -
      "! never added to AMOUNT; totals over a correlation group count the gross once
      dup_amount    TYPE ty_amount,
      "! Deadline the finding is about (UTC; initial = none) and the business calendar it was computed in
      deadline_at   TYPE timestampl,
      calendar_id   TYPE ty_calendar_id,
      "! Stage where the process stopped (the module's vocabulary, e.g. a milestone of the payment file)
      stage         TYPE ty_stage,
      "! Responsible user and team from the configuration and their source (GC_RESP_SOURCE)
      resp_user     TYPE syuname,
      resp_team     TYPE ty_team,
      resp_source   TYPE ty_resp_source,
      "! Key of the evidence rows (ZCL_CA_OPS_EXC_CONTRACT=>EVIDENCE_KEY; blank = no evidence)
      evid_key      TYPE ty_evid_key,
    END OF ty_contract.

  "! One typed evidence row of a finding (ZCA_OPS_FNDEVI)
  TYPES:
    BEGIN OF ty_evidence,
      evid_key    TYPE ty_evid_key,
      seq         TYPE i,
      kind        TYPE ty_evid_kind,
      ev_type     TYPE ty_evid_type,
      label       TYPE ty_label,
      native_key  TYPE ty_native_key,
      link_object TYPE ty_link_object,
      link_value  TYPE ty_link_value,
      occurred_at TYPE timestampl,
      observed_at TYPE timestampl,
      quality     TYPE ty_quality,
      source_id   TYPE ty_source_id,
    END OF ty_evidence.
  TYPES tt_evidence TYPE STANDARD TABLE OF ty_evidence WITH EMPTY KEY.

  "! Where the responsible user / team came from: C a control that covers the check (owner, team),
  "! P the business process of the check (owner), N none configured (the finding says so)
  CONSTANTS:
    BEGIN OF gc_resp_source,
      control TYPE ty_resp_source VALUE 'C',
      process TYPE ty_resp_source VALUE 'P',
      none    TYPE ty_resp_source VALUE 'N',
    END OF gc_resp_source.

  "! Kind of an evidence row: the system that holds the record
  CONSTANTS:
    BEGIN OF gc_kind,
      sap        TYPE ty_evid_kind VALUE 'SAP',
      middleware TYPE ty_evid_kind VALUE 'MW',
      bank       TYPE ty_evid_kind VALUE 'BANK',
      ops        TYPE ty_evid_kind VALUE 'OPS',
      "! The external workload scheduler (its plan / run record; 2026-11-16, build P)
      scheduler  TYPE ty_evid_kind VALUE 'SCHD',
    END OF gc_kind.

  "! Type of an evidence row
  CONSTANTS:
    BEGIN OF gc_type,
      run       TYPE ty_evid_type VALUE 'RUN',
      job       TYPE ty_evid_type VALUE 'JOB',
      pay_doc   TYPE ty_evid_type VALUE 'PAYDOC',
      file      TYPE ty_evid_type VALUE 'FILE',
      message   TYPE ty_evid_type VALUE 'MSG',
      ack       TYPE ty_evid_type VALUE 'ACK',
      statement TYPE ty_evid_type VALUE 'STMT',
      event     TYPE ty_evid_type VALUE 'EVENT',
    END OF gc_type.

  "! Quality of an evidence row: C confirmed by a key, P probable (time window, heuristic), U unmatched
  CONSTANTS:
    BEGIN OF gc_quality,
      confirmed TYPE ty_quality VALUE 'C',
      probable  TYPE ty_quality VALUE 'P',
      unmatched TYPE ty_quality VALUE 'U',
    END OF gc_quality.

  "! Contract gaps of a finding (ZCL_CA_OPS_EXC_CONTRACT=>MISSING)
  CONSTANTS:
    BEGIN OF gc_gap,
      count    TYPE ty_gap VALUE 'COUNT',
      currency TYPE ty_gap VALUE 'CURRENCY',
      deadline TYPE ty_gap VALUE 'DEADLINE',
      owner    TYPE ty_gap VALUE 'OWNER',
      stage    TYPE ty_gap VALUE 'STAGE',
      evidence TYPE ty_gap VALUE 'EVIDENCE',
    END OF gc_gap.

  "! Separator of the key values of an evidence row ("FIELD=value;FIELD=value")
  CONSTANTS gc_value_separator TYPE c LENGTH 1 VALUE ';'.

ENDINTERFACE.
