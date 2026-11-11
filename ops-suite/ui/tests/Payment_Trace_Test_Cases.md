# Payment trace `ZCD_OPS_PAYMENT_TRACE` - manual / Tosca-ready test cases

Status 2026-11-11: written for QA1; not executed. SAP GUI report (selection screen, ALV / tree output, `docs/Payment_Trace.md`). Each case is one Tosca test case: *Steps* = modules (SAP GUI scan of the selection screen and the result), *Expected* = verification points. Test data are taken in QA1 (SE16H on DPAYH / DFKKOP / ZCD_PAYM_REQ_LOG) - no production data in the repository. Executable only in QA1 with the transaction (proposed) or SE38.

| ID | Precondition (QA1 data) | Steps | Expected |
|---|---|---|---|
| PT-01 | Payment request with a SUCCESS row and a later failed attempt | Enter the FIN number (`P_FIN`) and the source (`P_SRC`), execute | The request shows the SUCCESS row, never the higher failed COUNTER |
| PT-02 | Same as PT-01 | Enter the FIN without source | Partner resolved with SOURCE first, then without (legacy PCLM partner) |
| PT-03 | Paid disbursement (method E / G / H / I / J / K / L) cleared on a bank statement | Enter the payment document (`P_AUGBL`) | Chain request -> open item (DFKKOP-ZZ_FIN_TRANS_NUM) -> payment run (DPAYH, status) -> statement line (FEBEP-CHECT = AUGBL) -> G/L (FIKEY) |
| PT-04 | Cheque payment (method C) cashed | Enter the payment document | Cheque register (DFKKCR-DOC1R = AUGBL), statement line by the last 13 characters of ZTNUM, state cashed |
| PT-05 | ACH return | Enter the payment document | Return lot item (DFKKRP-SELW1 = AUGBL) with the return reason RLGRD |
| PT-06 | Reversed payment (clearing reason 05) | Enter the payment document | Reversal shown, the payment is not reported as cleared |
| PT-07 | Stopped cheque and reissue | Enter the stopped payment document | Status STOPPED; the reissue is a separate payment with its own document and cheque number |
| PT-08 | Payment with a worklist row (late) | Enter the payment document | Outcome and finding of the worklist version shown with its evidence reference |
| PT-09 | Member number of the partner | Any trace with a partner | Member number masked to the last four characters; no bank account number shown |
| PT-10 | User without ZCA_OPS display for the company code | Enter a payment of that company code | No data (authorisation message), nothing of the company code shown |
| PT-11 | Unknown FIN number | Enter a FIN that does not exist | Message "nothing found", no dump |
| PT-12 | 2 million payment day | Trace one payment of the peak day | Response < 5 s; ST05 shows key / index reads only (pre-check 0.8 index on ZZ_FIN_TRANS_NUM) |
| PT-13 | Navigation from the payment object page (persona pages, `Payment`) | Press *Payment trace* | The trace opens with the payment document filled (intent `ZCDPaymentTrace-display`, proposed transaction - V98) |
