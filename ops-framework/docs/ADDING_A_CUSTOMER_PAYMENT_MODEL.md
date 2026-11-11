# Adding a customer payment model (product layer of ZCA_OPS)

> **First principle:** the screens, totals and drill-downs are the same at every customer; only the bottom layer - which table holds a payment, which field is the source, how a payment finds its request - differs, so only that layer is written per customer, and it is written as data (a mapping spec), not code.
> **Analogy:** a universal power adapter - the appliance (cards, object pages, tests) never changes; each country (customer) gets a plug (adapter view) cut from a drawing (mapping spec).

Status 2026-11-11: product templates, generator and the first customer mapping (the ops suite) written and checked offline (abaplint 0 issues, generator unit tests); **not activated**. VERIFY items V94-V99 (`VERIFY.md`).

## 1. What is product and what is mapped

| Layer | Who | Objects (prefix `<P>` of the customer) |
|---|---|---|
| **Contract** | product | Fields every customer delivers - section `payment` (required): business date, payment run, payment document, company code (+ its currency), flow C / D, source (= feeder system), transaction, request status, payment status, payment method, method class, house bank + account ID, open outcome, open finding, late flag, currency, amount; `payment_request` (n:m link payment - request); `request` (request reference, received date / time, company code, source, transaction, feeder reference, request status, processing status, currency, amount); `request_attempt` (attempt number, processing status, received at, accepted); `request_event` (timeline hops FEEDER, MIDDLEWARE, REQUEST, PAYMENT, STATUS_BACK). Defined once in `tools/abaptools/payment_model.py` (`CONTRACT`) |
| **Texts, feeder systems** | product (framework tables, customer rows) | `ZCA_OPS_PMDIM` - text and display order of every dimension value (business users see "Claims system", not `PCLM`); `ZCA_OPS_FEEDER` - feeder system name, deep-link URL template (`https://...{REF}`, opened by the browser - the system never calls a feeder), whether its reference may be shown in full (default: masked to the last four characters). App: `ZUI_CA_OPS_CFG` entities *Payment model dimension texts*, *Feeder systems* |
| **Adapter views** | **customer (generated from the mapping spec)** | `ZI_<P>_PaymFact`, `ZI_<P>_PaymReqLink`, `ZI_<P>_PaymReqFact`, `ZI_<P>_PaymAttempt`, `ZI_<P>_PaymEvent` |
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

## 5. Not in the product yet (2026-11-11)

Ledger and reconciliation down to the universal journal (subledger document -> G/L document -> journal lines, account / date totals, variance buckets as rows), document-change events (reversal, clearing reset, re-clearing) and their risk findings: designed in the first customer's documents (the first customer's dashboard document, section 9), not built.
