# Process flow card - specification (custom OVP card)

> **First principle:** a flow diagram is a picture of the same numbers the list card already shows - the card computes nothing.
> **Analogy:** a metro map over the timetable - same stations, drawn as a line.

Status 2026-11-11: specification and an unexecuted card source under `ui/cards/processflow` (**VERIFY V97**): the app manifests are not in the repository, the card was never run.

## 1. Why a custom card

Fiori elements overview pages (OData V4) offer list, table, analytical, KPI, link-list and stack cards - no flow card. The delivered annotations give a **criticality list card** (*Process flow*, presentation variant `Flow`) and a **bar card** (`FlowBars`) that work without custom code. A flow diagram (nodes per stage, state colour, counts) needs a custom card with `sap.suite.ui.commons.ProcessFlow`.

## 2. Data

Entity set `PaymentFlow` of `ZUI_CD_OPS_OVERVIEW` (binding `ZUI_CD_OPS_OVERVIEW_O4`), filtered like the other control center cards: `IsCurrentDay eq true` (or the global filter `BusinessDate`), optional `CompanyCode`. Request: `PaymentFlow?$apply=filter(IsCurrentDay eq true)/groupby((Stage,StageLabel,StageSequence,StageSource,FlowCriticality),aggregate(PaymentCount with sum as PaymentCount,StuckCount with sum as StuckCount,DropCount with sum as DropCount))&$orderby=StageSequence` - the DCL limits the rows to the user's company codes before the sum.

## 3. Mapping to ProcessFlow

| ProcessFlow | From |
|---|---|
| Lane | `StageSource` (PAYRUN payments, REQUEST requests) - one lane each, ordered by the smallest `StageSequence` |
| Node | one per stage: title `StageLabel`, texts "n in stage", "s stuck", "d dropped" |
| Node state | `FlowCriticality`: 3 Positive, 2 Critical, 1 Negative, 0 Neutral |
| Children | the next stage of the same lane (by `StageSequence`) |
| Press on a node | navigation to the payments of the stage: intent `ZCDTransaction-analyze` (payments) or `PaymentOfDay` list with the status filter |

## 4. Card settings (manifest of the overview app)

```json
"processflow": {
  "model": "mainService",
  "template": "zcd.ops.cards.processflow",
  "settings": { "title": "Process flow", "entitySet": "PaymentFlow" }
}
```

The card component is registered as a library or a module of the app (`ui/cards/processflow/Component.js`). Tests: OPA5 journey `ui/tests/integration/OverviewJourney.js` checks the list card variant; the custom card itself has no automated test until it is run in DV1.
