# UI test pack - OPA5 journeys and manual / Tosca-ready cases

> **First principle:** a UI test proves what the user sees from the annotations and entity sets in the repository - it cannot prove an app that has not been generated yet.
> **Analogy:** a pre-flight checklist written before the aircraft is delivered: every line names a real instrument, and it is flown once the aircraft exists.

Status 2026-11-11: **written, never executed.** The Fiori apps (manifests, `webapp/` folders) are not in the repository; they are generated in DV1 (`docs/Implementation_Order.md` step 1f). Every journey below runs only after its app exists. Nothing here can be executed offline.

## 1. What is here

| File | App (generated in DV1) | Service / entity set | Proves |
|---|---|---|---|
| `integration/OverviewJourney.js` | Production support overview `ZCD_OPS_OVW` (OVP V4) | `ZUI_CD_OPS_OVERVIEW`: `MonitorFreshness`, `CriticalException`, `ControlDay`, `PaymentLifecycle`, `ServiceHealth`, `ServiceContributor`, `PaymentFlow` | Cards render with titles from the annotations; *Current business date* filter set by default; card header navigation |
| `integration/PersonaJourney.js` | Persona pages `ZCD_PAYM_BIZ`, `ZCD_PAYM_MGR`, `ZCD_PAYM_IT` (OVP V4) | `ZUI_CD_PAYM`: `PaymentCategory`, `PaymentTrend`, `Payment`, `ExceptionTrend` | Business card has no technical code column; amount card groups by currency; drill-down list needs a business date; payment object page shows *Requests* |
| `integration/ControlReviewJourney.js` | Daily control review `ZCAControlReview-manage` (list report V4) | `ZUI_CA_OPS_REV`: `ControlReview`, action `markReviewed` | *Mark reviewed* with result *Action required* without observation / next action is refused (message 076 of class ZCA_OPS); with both it is saved |
| `integration/ExceptionJourney.js` | Owned exceptions `ZCDOpsException-manage` (list report + object page V4) | `ZUI_CA_OPS_EXC`: `Exception`, action `classifyException` | *Classify* with reason TIMING sets the reason code |
| `integration/AreaDashboardJourney.js` | Area dashboard `ZCAOpsDashboard-display` (list report V4) | `ZUI_CA_OPS_DASH`: `CheckStatus` | Attention variant lists flagged / stale checks |
| `integration/TransactionsJourney.js` | Transactions dashboard `ZCDTransaction-analyze` (ALP / list report V4) | `ZUI_CD_TRX_DASH`: `Transaction`, `TransactionKpi` | List filters by worklist date; a problem row opens |
| `integration/pages/*.js` | page objects (sap.fe.test `ListReport` / `ObjectPage` templates; OVP pages with plain OPA5 matchers - sap.fe.test has no OVP template) | | |
| `integration/opaTests.qunit.js` | QUnit / OPA5 runner that loads the journeys | | |
| `Payment_Trace_Test_Cases.md` | SAP GUI report `ZCD_OPS_PAYMENT_TRACE` (manual / Tosca-ready) | | |

## 2. How to run (once the apps exist in DV1)

1. Generate each app in DV1 (SAP Business Application Studio, template "Overview Page" / "List Report Page", OData V4, the binding of the table above) - or download it from the ABAP repository (BSP) into a local project.
2. Download `$metadata` of the binding in DV1 (`/sap/opu/odata4/sap/<binding>/srvd/sap/<service>/0001/$metadata`) into the app's `webapp/localService/mainService/metadata.xml`; the annotations come from the CDS metadata extensions of this repository, so the mock server shows the same cards.
3. Copy `ui/tests/integration` into the app's `webapp/test/integration`; set the app ID and the entity set names in `opaTests.qunit.js` (`APPS`) to the generated app IDs.
4. `npm install`, then `npx fiori run --open test/integration/opaTests.qunit.html` (mock server from the downloaded metadata, `@sap-ux/ui5-middleware-fe-mockserver`); in DV1 against the live backend with the same journeys (no mock) for gate 2.
5. Record the result per journey in `docs/Test_and_Validation_Document.md` (UI cases UI-01 ... UI-12).

## 3. Honest limits

- The journeys use the entity sets, field names, labels and qualifiers of the CDS views and metadata extensions in the repository. A generated app may need its control IDs adapted (the page objects keep them in one place).
- Mock data from metadata proves the UI wiring, never the numbers; the numbers are proved by the CDS tests (`ZCL_CD_OPS_SVC_CDS_TEST`, `ZCL_CD_PAYM_CDS_TEST`, `ZCL_CD_OPS_OVW_CDS_TEST`) and the QA1 cases.
- The validation of *Mark reviewed* is the framework's behaviour pool (message 076); against the mock server it is not executed - that journey is meaningful only against DV1 / QA1.
- The custom process-flow card (`ui/cards/processflow`) has no automated test until it runs once in DV1.
