# Adding a customer payment model (product layer of ZCA_OPS)

> **First principle:** the screens, totals and drill-downs are the same at every customer; only the bottom layer - which table holds a payment, which field is the source, how a payment finds its request - differs, so only that layer is written per customer, and it is written as data (a mapping spec), not code.
> **Analogy:** a universal power adapter - the appliance (cards, object pages, tests) never changes; each country (customer) gets a plug (adapter view) cut from a drawing (mapping spec).

Status 2026-11-11: product templates, generator and the first customer mapping written and checked offline (abaplint 0 issues, generator unit tests); **not activated**. VERIFY items V94-V99; ledger and document-change model (§5) V110-V114 (`VERIFY.md`).

## 1. What is product and what is mapped

| Layer | Who | Objects (prefix `<P>` of the customer) |
|---|---|---|
| **Contract** | product | Fields every customer delivers - section `payment` (required): business date, payment run, payment document, company code (+ its currency), flow C / D, source (= feeder system), transaction, request status, payment status, payment method, method class, house bank + account ID, open outcome, open finding, late flag, currency, amount; `payment_request` (n:m link payment - request); `request` (request reference, received date / time, company code, source, transaction, feeder reference, request status, processing status, currency, amount); `request_attempt` (attempt number, processing status, received at, accepted); `request_event` (timeline hops FEEDER, MIDDLEWARE, REQUEST, PAYMENT, STATUS_BACK). Defined once in `tools/abaptools/payment_model.py` (`CONTRACT`) |
| **Texts, feeder systems** | product (framework tables, customer rows) | `ZCA_OPS_PMDIM` - text and display order of every dimension value (business users see "Claims system", not `CLM`); `ZCA_OPS_FEEDER` - feeder system name, deep-link URL template (`https://...{REF}`, opened by the browser - the system never calls a feeder), whether its reference may be shown in full (default: masked to the last four characters). App: `ZUI_CA_OPS_CFG` entities *Payment model dimension texts*, *Feeder systems* |
| **Adapter views** | **customer (generated from the mapping spec)** | `ZI_<P>_PaymFact`, `ZI_<P>_PaymReqLink`, `ZI_<P>_PaymReqFact`, `ZI_<P>_PaymAttempt`, `ZI_<P>_PaymEvent`; ledger and document-change model (§5): `ZI_<P>_LedgItem`, `_LedgBatch`, `_LedgAcct`, `_LedgRcRes`, `_LedgBankLn`, `_DocEvent` |
| **Everything above** | product templates (`ops-framework/templates/payment_model`), generated per customer | cube `ZR/ZC_<P>_PaymCube` (+ persona card annotations), trend `ZI_<P>_PaymTrendB`, `ZI_<P>_PaymDay`, `ZR/ZC_<P>_PaymTrend`, payment `ZR/ZC_<P>_Payment` (list + object page), link `ZR/ZC_<P>_PaymReqLink`, request `ZR/ZC_<P>_PaymRequest`, attempts, timeline, exceptions per day `ZI_<P>_PaymExcRow` / `_PaymExcDay`, `ZR/ZC_<P>_PaymExcTrend`, DCL `ZC_<P>_PAYM` (framework company-code rule), service `ZUI_<P>_PAYM`, test holder `ZCL_<P>_PAYM_CDS_TEST` |
| **Plug-ins (ABAP)** | product contract, customer class | Only where a join cannot express the value (a status derived by rules, a feeder read through an API log): the customer builds a consumer view (or a CDS table function) that delivers the contract field and names it in the spec - no ABAP interface is needed for the delivered cases. A rule engine as source is a later extension (contract: one value per payment key, read-only, set-based) |

Rules of the product: read-only; amounts always with their currency (currency is a grouping key - never summed across currencies, no conversion); absolute amounts, the sign is the flow dimension; aggregation in the database (no payment row reaches a card); the payment list needs a business date (mandatory filter, paged); company-code DCL on every entity; nothing stored that can be read live.

## 2. Steps for a new customer (effort for a consultant who knows the landscape)

| # | Step | Effort |
|---|---|---|
| 1 | Name the tables: where a payment lives (one row per payment and run), how its flow / method class / source are found, where the request and its attempts live, the link payment - request. Mark every field you have not seen in SE11 as `verify` | 0.5-1 day workshop |
| 2 | Write `config/payment_model/mapping.json` in the customer folder: `model` (prefix, area, consumer areas, service name, package folder, window / trend days, peak-day volume, intents of the trace / exceptions / job apps), one section per contract part with `from`, `joins`, `where`, `group_by` and one expression per contract field (CDS fragment, or `null` + `verify`). A section that waits for a field is `"status": "pending"` with its reason - it is generated into the pending folder for review and left out of the service | 0.5 day |
| 3 | Helper views for linkages a single select cannot express (e.g. method class from a customizing table, the worklist state of a payment) in the customer package, named in `joins` | 0-1 day |
| 4 | Wrapper `tools/payment_model.py` (copy of the ops suite's, three lines of settings); run it, then the serializer; `--check` in the customer's check list | 1 hour |
| 5 | Rows of `ZCA_OPS_PMDIM` (texts) and `ZCA_OPS_FEEDER` (feeder systems, URL templates, visibility) in DV1, by transport | 0.5 day |
| 6 | Activate in DV1 (framework -> helper views -> adapters -> generated views -> DCL -> service), publish the binding, run `ZCL_<P>_PAYM_CDS_TEST`, PlanViz of the adapter on the largest day | 1-2 days |
| 7 | Three overview page app descriptors (business, managers, IT support) from the card list of the customer's dashboard document; launchpad pages and roles | 1-2 days |

New sources / feeder systems later: a row in `ZCA_OPS_FEEDER` and texts in `ZCA_OPS_PMDIM` - no code. A new feeder with its own request table: a new linkage in the spec (join or helper view) and regenerate.

## 3. Worked example - a fictitious second customer

Customer "example insurer", prefix `PE`, area `ZPE_OPS`. Payments in `ZPE_PAYMENT` (one row per payment), requests from two feeder systems - a claims system (`CLM`) and a billing system (`BIL`) - in `ZPE_REQUEST`, link in `ZPE_PAY_REQ`. The unit test `tools/tests/test_payment_model.py` uses exactly this shape.

```json
{
  "model": {"prefix": "PE", "area": "ZPE_OPS", "areas": ["ZPE_OPS"], "consumer": "example insurer",
            "service": "ZUI_PE_PAYM", "package_folder": "src/paym", "pending_folder": "config/payment_model/pending",
            "since": "2026-11-11", "window_days": 40, "trend_days": 30, "peak_day_min": 500000,
            "intents": {"trace": ["ZPETrace", "display"], "exceptions": ["ZPEExc", "manage"], "job": ["ZPEJob", "display"]}},
  "payment": {"from": "zpe_payment as Pay",
              "joins": ["left outer join zpe_method as Mth on Mth.method = Pay.method"],
              "fields": {"BusinessDate": {"expr": "Pay.pay_date"}, "PaymentRun": {"expr": "Pay.run_id"},
                         "PaymentDocument": {"expr": "Pay.pay_doc"}, "MethodClass": {"expr": "Mth.class"},
                         "TransactionType": {"expr": null, "verify": "not delivered by the payment table"}, "...": {}}},
  "payment_request": {"from": "zpe_pay_req as Lnk", "fields": {"PaymentDocument": {"expr": "Lnk.pay_doc"}, "...": {}}},
  "request": {"from": "zpe_request as Req", "where": ["Req.accepted = 'X'"], "fields": {"Source": {"expr": "Req.feeder"}, "...": {}}},
  "request_attempt": {"status": "pending", "reason": "attempt table not yet named", "from": "‹attempt table› as Att", "fields": {}}
}
```

Rows: `ZCA_OPS_FEEDER` `CLM` "Claims system", URL `https://claims.example/claim/{REF}`, reference visible; `BIL` "Billing", no URL, masked. Result: the same three overview pages and object pages as the first customer; the attempts table appears on the request page once the section is active.

## 4. Generated files and checks

`python3 tools/payment_model.py` writes the package folder (and the pending folder); `--check` lists every file that differs from what the spec and templates produce, and every superfluous one - generated files are never edited by hand. The spec is refused (message per field) when a contract field is missing, a key or required field is null, a null has no `verify` note, an active section contains a placeholder (`‹...›`), or a text contains `;`, a comment or braces. Templates use `{{KEY}}` values, `#if LINK|REQUEST|ATTEMPT|EVENT` blocks and `#for` loops (DCL grants, service entities).

## 5. Ledger and document-change model (2026-11-11)

Optional sections of the same spec; generated only when active (flags `LEDGER`, `RECON`, `RESULT`, `BANK`, `CHANGES` of the templates). VERIFY V110-V114 (`VERIFY.md`).

| Section (adapter) | Role | Contract fields |
|---|---|---|
| `ledger_item` (`ZI_<P>_LedgItem`) | Subledger items a payment cleared, with the **subledger batch key** under which the clearing reached the G/L | PaymentDocument, SubledgerDocument, SubledgerItem (keys), CompanyCode, BatchKey, GlAccount, Currency, Amount (signed), PostingDate, MainTransaction / SubTransaction (+ texts), ContractAccount, BusinessPartner (masked by the product to the last four), ClearingDocument / Date / Reason, RequestReference |
| `ledger_batch` (`ZI_<P>_LedgBatch`) | Subledger summary records per batch key, company code, account, currency, with the **G/L reference key** of the batch | BatchKey, CompanyCode, GlAccount, Currency (keys), GlReferenceKey, PostingDate, BatchStatus, Amount, LineCount |
| `recon_account` (`ZI_<P>_LedgAcct`) | Clearing / transit accounts of the group reconciliation | CompanyCode, GlAccount, Currency (keys), AccountKind, Description |
| `recon_result` (`ZI_<P>_LedgRcRes`) | Stored results of the consumer's own reconciliation check per business date and account - **reused, never recomputed** | BusinessDate, CompanyCode, GlAccount, Currency (keys), Bank / Gl / Subledger amounts, the two differences, Tolerance, ResultStatus (BALANCED, TIMING, VARIANCE, BREAK, SUBLEDGER_BREAK), Bucket, MeasuredAt |
| `recon_bank_line` (`ZI_<P>_LedgBankLn`) | Bank statement lines of the reconciled accounts; how a line finds its subledger clearing document and its G/L clearing line is the consumer's rule | StatementKey, StatementLine (keys), CompanyCode, GlAccount, Currency, BookingDate, Amount, DebitCredit, house bank / account ID, statement number / date, transaction code, bank reference, reference text, value date, posted flags, ClearingDocument, ClearingChanged, G/L fiscal year / document / line item |
| `document_event` (`ZI_<P>_DocEvent`) | Document changes of a payment: REVERSAL, CLEARING_RESET, RECLEARING, VOID, REISSUE | PaymentDocument, EventType, EventDocument (keys), CompanyCode, Original / New / Reversal document, EventDate, EventTime, EventUser, Reason, EventSource |

Model keys: `ledger` {`area`, `parameter`, `default`} - the ledger parameter of the parameter framework (`ZI_<P>_LedgCfg`: value, else definition default, else the delivered default, the leading ledger `0L`); `gl_reference_type` - the reference type (BKPF-AWTYP) of the G/L documents of a batch key. The product adds the **standard** part: G/L documents of a batch key (BKPF by reference type + key + company code), journal lines (ACDOCA in the model's ledger, read by key, with every accounting attribute), G/L reversals (BKPF-STBLG) as GL_REVERSAL events, the payment's **share** of the summary (payment amount / batch total, pro-rata G/L amount - never a 1:1 G/L line), the batch key level (transferred / not transferred / difference), the group reconciliation per business date x company code x account x currency (journal aggregated by company code, account and posting date for the configured accounts only; analytical cube + query), the changes timeline of a payment and of a request, change volumes per type, source, payment type, company code, house bank and day. Rules: amounts per currency, company-code DCL on every entity, read-only, nothing stored.

**Worked example (fictitious customer `PE`).** `ledger_item` from `zpe_item as Itm` (items with `Itm.cleared_by` = payment document, batch key `Itm.batch_id`); `ledger_batch` from `zpe_batch_total as Tot` grouped per batch / company code / account / currency, `GlReferenceKey` = `Tot.batch_id`; model `ledger` = {`area`: `ZPE_OPS`, `parameter`: `ZPE_LEDGER`, `default`: `0L`}, `gl_reference_type` = `ZPEGL`; `recon_account` from `zpe_clearing_account`; `recon_result` absent (the customer has no reconciliation check yet: the reconciliation shows the live legs only); `recon_bank_line` pending until the statement fields are confirmed; `document_event` from `zpe_doc_change`. The unit tests `tools/tests/test_payment_model.py` use this shape.
