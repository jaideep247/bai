# Account flow reconciliation - customer overlay of the ops suite

Release: 2026-11-15 (build G). Product: `ops-framework/docs/ACCOUNT_FLOW.md`. This document holds only what is this
landscape's own: the accounts of the payment engine's flows by role, the values of the stage rules, the checks that
control each stage, the decisions to take. **Everything is configuration only and delivered inactive** until its
VERIFY item is closed; no code of the suite changes.

> **First principle:** the product knows how to lay a money flow out by stage and account and how to subtract what
> the checks hold open; only this landscape knows which accounts carry its ACH, wire, cheque and card money, which
> document type its payment engine posts the requests with, and which morning-report check watches each hand-over.
>
> **Analogy:** the product is the relay race's camera and score sheet; the overlay is this stadium's lanes and the
> names of its referees.

## 1. Facts the overlay rests on (repository, confirmed 2026)

- Clearing accounts by set (`ZCD_HCK_RCSET`, `config/hck_seed.md` §10a): ACH disbursement transit (`DISB_ACH`), wire
  transit (`DISB_WIRE`), cheque clearing (`DISB_CHQ`), ACH collection clearing (`COLL_ACH`), Stripe clearing
  (`STRIPE_US`, card collections - the repository models the card settlement, so the collections flow has a
  SETTLEMENT column). G/L accounts and company codes are placeholders there and here until Finance confirms them.
- The payment engine posts its requests in FI-CA; the payment run is FPY1; bank statements post through EBS; returns
  through returns lots (FP09); FI-CA reaches the G/L summarised per reconciliation key (G/L transfer FPG1, reference
  transaction `FKKSU` - the `A_GL_TRANSFER` PARAM4 default).
- The morning report's checks write their findings through the framework store (`ZCA_OPS_FINDING`, GROUP2 = check
  ID): `A_PRQ_NOT_PAID`, `A_INFLIGHT`, `A_RECON_3WAY`, `A_GL_TRANSFER`; the break analysis check `GL_BREAKS` is in the
  framework registry of area `CD_HCK`; the collections checks `COLL_R1_PENDING` ... `COLL_R4_SRCPOSTED` in area
  `CD_COLL`.

## 2. What the overlay delivers (`config/flows`, area `CD_HCK`, all inactive)

| Piece | Rows |
|---|---|
| Flows | `DISB` (payable to the house banks), `COLL` (receivable to the house banks) - the product templates copied to the area |
| Accounts (`zca_ops_flwacc.csv`) | DISB: payable (FI-CA reconciliation account, F, open FI-CA items), claim expense (OUTSIDE, F), ACH / wire / cheque clearing (F, explained breaks - one column per `ZCD_HCK_RCSET` set), cash (house bank, G, **no source**), returns clearing (CLARIFICATION, F, open exceptions of the returns-lot stage's check). COLL: receivable, revenue (OUTSIDE), Stripe clearing (SETTLEMENT), ACH collection clearing, cash, clarification. Company code, accounts: placeholders (V150) |
| Stages, tiles | as the product templates, texts of this landscape (payment engine request, FPY1, EBS, FP09, FPG1; card settlement = Stripe payout) |
| Stage controls (`zca_ops_flwctl.csv`) | DISB: request - `A_PRQ_NOT_PAID`; payment run - `A_INFLIGHT`; bank paid - `A_RECON_3WAY`, `GL_BREAKS`; bank return and returns lot - `A_INFLIGHT`; G/L transfer - `A_GL_TRANSFER`. COLL: receivable - `COLL_R1_PENDING`; payment lot - `COLL_R4_SRCPOSTED`; settlement and bank credit - `A_RECON_3WAY` (+ `GL_BREAKS` on the bank credit); G/L transfer - `A_GL_TRANSFER` |
| Stage rules (`zca_ops_flwrul.csv`, prefix `CD_`) | `CD_GL_TRANSFER` (AWTYP `FKKSU`) first; one rule per other stage **without value** - the payment engine's document type of the request / collection posting, the origin keys of FPY1, FP09, payment lots and clarification, the document types of the EBS postings and of the Stripe payout (V151) |

The offline check `flow_config` of `tools/portable_checks.py` validates the overlay with the product templates
(roles, sources, stages, rules, one payable / receivable per company code and currency, every row inactive).

## 3. Decisions for the user

| ID | Decision | Proposal |
|---|---|---|
| D-G11 | Cash (house bank) has no source: the bank statement balance per account and day is not stored by any check (A_RECON_3WAY compares day movements, EBS R18 the balance per statement in its own result) - the cash column stays *not evaluated* | accept now; later a suite source class over the EBS statement closing balance |
| D-G12 | The morning report's checks are not in the framework registry: their stage tags read *pending* unless they have open exceptions (framework D-G5) | accept, or register `A_*` rows in `ZCA_OPS_CHECK` of `CD_HCK` (no run of their own - documentation rows) |
| D-G13 | Returns clearing is accounted for by the open exceptions of `A_INFLIGHT` on the returns-lot stage - a return reported only after its age limit is unexplained until then | accept; a direct source over the open returns lot items (`DFKKRP`, fields V151) if the gap matters |
| D-G14 | One flow per direction with one column per clearing set (ACH, wire, cheque; ACH, card) - not one flow per payment method | accept |
| D-G15 | Area `CD_HCK` (the reconciliation area: its findings, its job user, its pilot) | accept |

## 4. VERIFY

| ID | Kind | Item |
|---|---|---|
| V150 | Configuration / Finance | Company code and G/L accounts of every account row (one per active `ZCD_HCK_RCSET` set for the clearing columns; the FI-CA payable / receivable reconciliation accounts; the claim expense / revenue accounts; the house bank G/L accounts of the disbursement and collection accounts); line source F for every account FI-CA posts to, G for the house bank accounts |
| V151 | VERIFY-SE11 / business | The values of the stage rules: FI-CA document type of the payment engine's request and collection postings, origin keys (`DFKKKO-HERKF`) of FPY1 payment documents, FP09 returns lots, payment lots and clarification postings, document types (BLART) of the EBS postings of paid items, returns and credits and of the Stripe payout posting; a returns lot item open = no posting yet (`DFKKRP` fields, if D-G13 asks for a direct source); a rule is activated only with its value |
| V152 | Configuration / PlanViz | The findings area of the morning report's checks (`CD_HCK`, GROUP2 = check ID) and that `A_INFLIGHT` reports returns without a returns lot with amount and company code; `COLL_R1_PENDING` / `COLL_R4_SRCPOSTED` of `CD_COLL` with company code; PlanViz FLOW-PV1 on the busiest disbursement clearing account over a month window and FLOW-PV3 (`DFKKOP` clearing branch) on a 2-million-payment day; the sample (V148) reproduced with this landscape's ACH return |

## 5. Running it

1. Framework first (`ops-framework/docs/INSTALL.md` §6f); then the overlay rows in DV1 on a customizing request.
2. Rows activated per flow only together: flow, accounts (V150), stages, tiles, controls (V152), rules with their
   values (V151).
3. Job `ZCA_OPS_FLOW_RUN` (area `CD_HCK`) after `ZCA_OPS_BRK_RUN` and the morning report; the query
   `ZC_CA_OpsFlowQry` in the *Multidimensional Reports* app with "to" = today; the tiles and the stage card of
   `ZUI_CA_OPS_FLOW` on the suite's overview page.
