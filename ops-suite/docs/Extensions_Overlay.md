# Customer extensions - the plug-in pack of the ops suite

Release: 2026-11-15 (build H). Product: `ops-framework/docs/EXTENDING_WITH_CUSTOMER_DATA.md` (the one extension
contract of the framework, its inventory `ops-framework/config/extension_points.json`). This document holds only what
is this landscape's own: which payment engine data it puts next to the product's screens, through which overlay
objects and links, what waits for which VERIFY item, and the decision to take. **Nothing is active**; no code of the
suite and no object of the framework changes.

> **First principle:** the product shows what SAP standard data says; this landscape adds what only its payment
> engine knows - which source system a payment came from, what its worklist says - next to it, on the same row,
> without touching the product.
>
> **Analogy:** the product is the airport's departure board; the pack adds this airline's own column - the gate
> agent's note - to the airline's rows, on the airline's own sheet clipped to the board.

## 1. The pack

| Piece | Where |
|---|---|
| Pack settings (prefix `CD`, registry layer `CD`, folders) | `config/extensions/pack.json` |
| Declarations | `config/extensions/breaks.json`, `config/extensions/account_flow.json` |
| Joins | the overlay of the link registry `config/links/overlay.json` (object `CD_PAY_WORK_STATE` gained its fields `SourceSystem`, `Outcome`, `Finding`, `IsLate` - elements of `ZI_CD_PayWorkState`, confirmed in the repository) |
| Generated, waiting for VERIFY (never imported) | `config/extensions/pending/` |
| Generated, active (package `src/ext`) | none yet |
| Report | `docs/extensions/extensions.md` (generated) |
| Generator and check | `tools/extensions.py [--check]`; portable check `extensions` |

The pack is the place for the rest of the suite's own data as well: its overlay layer (`config/links`), payment
model (`config/payment_model`), catalogue layer (`config/catalogue`), break rules (`config/breaks`), flows
(`config/flows`), business processes (`config/processes`) and its check classes in `src/` - each through the
extension point the framework's matrix names.

## 2. What it adds

| Extension | Product view | Joins | Columns | Status |
|---|---|---|---|---|
| `CD_BRK_WORK_STATE` | break list `ZR_CA_OpsBrkGroup` -> `ZC_CA_OpsBrkGroup`, cube `ZI_CA_OpsBrkCube`, query copy `ZC_CD_BrkQry` | anchor `ASSIGNMENT`: the assignment of the break group = `ClearingDoc` of `ZI_CD_PayWorkState` (one row per payment document) | source system of the payment's requests, open outcome, open finding, late | **pending** V139 (the assignment carries the payment document: confirmed for ACH and card, open for cheque) |
| `CD_BRK_LINE_REQUEST` | break lines `ZR_CA_OpsBrkItem` | - | request number, source system of the request | **blocked** (D-H3) |
| `CD_FLOW_REQUEST` | account flow cube `ZI_CA_OpsFlowCube` | (`CD_ITEM_TO_REQUEST`, pending V82) | request number, source system of the request | **blocked** (D-H3) |

Why the two requests are blocked: a break line on a clearing account is a journal line - the G/L transfer of many
FI-CA items, or a bank posting - and the overlay has no "to one" link from a journal line to the request log; the
account flow has no line level at all (its rows are aggregated by stage, account, document type, origin and
transaction). A request number per row would repeat or split the product's rows. The request side stays where it is
"to many" by nature: the payment trace and the link walker (`CD_ITEM_TO_REQUEST`, `CD_REQ_TO_OPEN_ITEMS`).

The generated code of `CD_BRK_WORK_STATE` (`config/extensions/pending/zcd_x_brkgrp_r.ddls.asddls`):

```cds
extend view entity ZR_CA_OpsBrkGroup with
  association [0..1] to ZI_CD_PayWorkState as _ZZCDWorkState on _ZZCDWorkState.ClearingDoc = $projection.Assignment
{
  @EndUserText.label: 'Source system of the payment'
  _ZZCDWorkState.SourceSystem as ZZCD_SourceSystem,
  ...
}
```

plus the projection (`ZCD_X_BRKGRP_C`), the cube (`ZCD_X_BRKGRP_CUBE`) and the query copy `ZC_CD_BrkQry` with the
source system as a free dimension.

## 3. Decision for the user

| ID | Decision | Proposal |
|---|---|---|
| D-H3 | Request number and source system next to a break line or an account flow row cannot be a column (no "to one" path; flow rows are aggregated). Options: (a) accept - the break **group** shows the payment's source system and worklist state (`CD_BRK_WORK_STATE`, after V139); the request detail through the payment trace; (b) a product feature for aggregated extensions (e.g. the number of requests or the single source per payment document) - a new extension point, a framework change; (c) a link journal line -> FI-CA document per line, if the clearing lines carry it (they carry the assignment only) | (a) now; (b) only if operations ask for it after the pilot |

## 4. VERIFY

| ID | Kind | Item |
|---|---|---|
| V139 | VERIFY-SE11 / QA1 | (existing, `Break_Analysis_Overlay.md`) the assignment of a clearing-account line carries the payment document for ACH, card and cheque; closing it turns `CD_BRK_WORK_STATE` active |
| V158 | VERIFY-ADT / DV1 | After the framework's V153-V156: the generated objects of the pack activate from the suite's package `src/ext` (`ZCD_X_BRKGRP_R`, `_C`, `_CUBE`, `ZC_CD_BrkQry`) - the framework's root view extended with an association to the suite view `ZI_CD_PayWorkState` (CHAR 18 assignment compared with the CHAR 12 payment document), the binding `ZUI_CA_OPS_BRK_O4` republished, the columns in the break list and in *Multidimensional Reports*; PlanViz of the break list with the association on the busiest clearing account (the worklist view groups `ZCD_PAY_OUTCOME` by AUGBL - index `DOC`) |

## 5. Running it

1. `python3 tools/extensions.py` after a change of a declaration or of the overlay; `--check` in the portable checks.
2. When V139 and V158 are closed: drop `verify` from `CD_BRK_WORK_STATE`, regenerate - the files move from the
   pending folder to `src/ext`; add package `ZCD_OPS_EXT` (`src/ext`) to `config/repository.json`, run the
   serializer, pull after the framework (`Implementation_Order.md`).
