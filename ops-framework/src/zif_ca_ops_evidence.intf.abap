*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_evidence.intf.abap
*& Purpose:
*& Evidence of findings (exception contract, docs/EXCEPTION_CONTRACT.md):
*& the typed rows that prove a finding - SAP records (run, job, payment
*& documents), middleware records (message / file IDs) and bank records
*& (acknowledgement, statement line) - stored per evidence key
*& (ZCA_OPS_FNDEVI) and turned into a start of the link registry walker.
*& The runner saves the rows a check returns; apps read them in CDS.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - evidence of findings</p>
INTERFACE zif_ca_ops_evidence
  PUBLIC.

  "! Save the evidence rows: the rows of every evidence key named are replaced (one unit of work with the run)
  "! @parameter iv_area     | Area of the run
  "! @parameter iv_run_id   | Run that produced the findings
  "! @parameter it_evidence | Rows (key EVID_KEY + SEQ; SEQ 0 = numbered in the order given)
  "! @raising zcx_ca_ops_error | 010 the rows could not be written
  METHODS save
    IMPORTING
      iv_area     TYPE zif_ca_ops_types=>ty_area
      iv_run_id   TYPE zif_ca_ops_types=>ty_run_id
      it_evidence TYPE zif_ca_ops_exc_contract=>tt_evidence
    RAISING
      zcx_ca_ops_error.

  "! The evidence rows of a finding
  METHODS read
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      iv_evid_key        TYPE zif_ca_ops_exc_contract=>ty_evid_key
    RETURNING
      VALUE(rt_evidence) TYPE zif_ca_ops_exc_contract=>tt_evidence.

  "! The walker request that starts at the record of an evidence row (its link object and key values)
  "! @raising zcx_ca_ops_error | 377 the row names no link object or no key value
  METHODS walker_request
    IMPORTING
      iv_area           TYPE zif_ca_ops_types=>ty_area
      is_evidence       TYPE zif_ca_ops_exc_contract=>ty_evidence
    RETURNING
      VALUE(rs_request) TYPE zif_ca_ops_link_types=>ty_request
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
