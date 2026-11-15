*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_flow_source.intf.abap
*& Purpose:
*& Plug-in of the account flow reconciliation (docs/ACCOUNT_FLOW.md
*& section 5): what an existing check or subledger list accounts for in
*& the closing position of one account of a flow at a key date - per
*& currency, signed as the journal (debit +) or unsigned with the sign of
*& the balance - or why it cannot say (status N with a reason: shown grey,
*& never as zero). Named per account in ZCA_OPS_FLWACC-EVAL_CLASS and
*& created through ZCL_CA_OPS_FACTORY=>GET_PLUGIN. An implementation only
*& reads: no posting, no update of business data.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - account flow source plug-in</p>
INTERFACE zif_ca_ops_flow_source
  PUBLIC.

  "! What the source accounts for in the closing position of an account at the key date
  "! @parameter is_config   | The flow's configuration (stages and the checks that control them)
  "! @parameter is_account  | The account (company code, G/L account range, currency or blank = every currency)
  "! @parameter iv_key_date | Key date of the evaluation
  "! @parameter rt_rows     | One row per currency: amount and items accounted for (status E), or status N and why
  "! @raising zcx_ca_ops_error | the source failed - the account is recorded as not evaluated with the message
  METHODS accounted_for
    IMPORTING
      is_config      TYPE zif_ca_ops_flow_types=>ty_config
      is_account     TYPE zif_ca_ops_flow_types=>ty_account
      iv_key_date    TYPE d
    RETURNING
      VALUE(rt_rows) TYPE zif_ca_ops_flow_types=>tt_source_row
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
