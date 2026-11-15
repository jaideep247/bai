# Account flow reconciliation

Release: 2026-11-15 (build G). Component: operations framework `ZCA_OPS`. Product positioning: SAP-native subledger
operations and reconciliation evidence - **read-only, no postings, no matching; the view compares nothing of its own**.

> **First principle:** money moves through a fixed chain of postings - a request, a payment run, a bank statement, a
> return, a G/L transfer - and every link of the chain already has a check that watches it. Lay the postings of one
> period out as a matrix (stages as rows, accounts as columns), add the position before and after, and subtract what
> the checks already hold open: whatever is left is the only part nobody has explained yet.
>
> **Analogy:** a relay race filmed from above. Each runner (stage) hands the baton (money) to the next lane (account);
> the referees at each hand-over (checks) note a dropped baton. At the end you count the batons: all are either at the
> finish, in a runner's hand that a referee has noted, or missing - and only "missing" needs a search.

## 1. What it shows

For one **flow** (e.g. disbursements `DISB`, collections `COLL`), one company code, one currency and a **posting date
window** "from" - "to":

| Rows | Columns | Cell |
|---|---|---|
| the configured **stages** in their order (payment request posted, payment run, bank statement paid, bank statement return, returns lot, G/L transfer, ...), then **OTHER** (lines no stage rule matches - never hidden), then **Movement**, **Opening position**, **Closing position**, **Unexplained** | the **accounts by role** (payable / receivable, outside the chain, settlement, clearing, cash, clarification) | debit and credit; **expected but not posted** amounts in their own columns (the brackets of the sample); for a subledger-posted account the journal lines as *reached G/L* |

Each stage row carries its **control tag** - the latest result of the checks that control it: *reconciled*, *n open*,
*pending* (no current result), *no control*. An account outside the control chain (expense, revenue: role `OUTSIDE`)
is shown and marked *no control point*. Above the matrix, the **tiles**: requested, paid / settled by the bank, matched
and cleared, still in transit, in clarification (amount and items), the exposure behind it, accounts not evaluated.

**Worked example (the sample, disbursements):** four payments of 2,100 leave through the house bank; one ACH return of
300 arrives on the bank statement and sits in the returns clearing account until the returns lot posts.

| Stage | Payable (FI-CA) | Claim expense (outside) | Disbursement clearing | Cash (house bank) | Returns clearing |
|---|---|---|---|---|---|
| Payment request posted | Cr 2,100 | Dr 2,100 | | | |
| Payment run | Dr 2,100 | | Cr 2,100 | | |
| Bank statement paid | | | Dr 2,100 | Cr 2,100 | |
| Bank statement return | | | | Dr 300 | Cr 300 |
| Returns lot | (Cr 300) expected | | | | (Dr 300) expected |
| G/L transfer | reached G/L | | | | |
| Movement | 0 | Dr 2,100 | 0 | Cr 1,800 | Cr 300 |
| Unexplained | 0 | no control point | 0 | per the bank source | 0 (the open returns lot item explains the 300) |

## 2. How to read it

1. **Movement** is the sum of the stage rows of the account's own lines (§4). It equals closing - opening for a
   journal account; for a subledger-posted account (FI-CA lines + direct G/L postings) movement - (closing - opening)
   = FI-CA lines - reached G/L = the transfer gap of the window, which the G/L transfer check controls.
   Every account FI-CA posts to is line source F (the payable, the expense of the request, the clearing account of
   the payment run, the clarification account) - only then are its FI-CA postings in their stages.
2. **Closing position** is the books at "to": opening + every journal line of the window.
3. **Unexplained** = closing - what existing checks account for at "to" (§5). Zero = every unit of the balance is a
   known open item of a check. Not evaluated = grey (`EvalStatus` N, `NotEvaluatedCount` 1, no amount) - never a zero
   by mistake. `OUTSIDE` = no control point (X).
4. **Expected** (brackets): a stage that will post what a check holds open - e.g. the returns lot clears the returns
   clearing account and reopens the payable. Nothing is posted; the amount is the open item of the check.
5. **Control tag**: O open - drill into the exceptions app (`ZUI_CA_OPS_EXC`) with the check ID; P pending - the check
   has no current result (stale run, or a check the framework cannot see run, §6); N - nobody watches this stage.

## 3. Configuration (entities of `ZUI_CA_OPS_CFG`, drafts, customizing request)

| Table / entity | Key | Content |
|---|---|---|
| `ZCA_OPS_FLOW` *Account flows* | area, flow | description, direction D / C, ledger (blank = `FLOW_LEDGER`), business process (catalogue activation), active |
| `ZCA_OPS_FLWACC` *Account flow accounts by role* | area, flow, account (column) | role (`RECEIVABLE`, `PAYABLE`, `OUTSIDE`, `SETTLEMENT`, `CLEARING`, `CASH`, `CLARIFICATION`), company code, currency (blank = each currency its own slice), G/L account or range (`HKONT_FROM` - `HKONT_TO`), **line source** G (journal) / F (FI-CA documents), display order, source class of what the checks account for (`ZIF_CA_OPS_FLOW_SOURCE`, blank = not evaluated) and its tile (`TRANSIT`, `CLARIFY`, `OPEN`, `BANK`) |
| `ZCA_OPS_FLWSTG` *Account flow stages* | area, flow, stage | order, text, expected postings: `EXPECT_FROM` (the role whose open items the stage will clear) / `EXPECT_TO` (the role of the counter-posting); reserved IDs `OTHER`, `MOVEMENT`, `OPENING`, `CLOSING`, `UNEXPLAINED` refused (340) |
| `ZCA_OPS_FLWTIL` *Account flow tiles from stages* | area, flow, tile, stage, role | `REQUESTED` / `PAID` / `CLEARED`: the debit (D) or credit (C) of the stage on the accounts of the role (one stage may feed two tiles on two roles) |
| `ZCA_OPS_FLWCTL` *Account flow stage controls* | area, flow, stage, check area, check ID | the checks whose latest result is the stage's control tag (findings `AREA` / `GROUP2`) |
| `ZCA_OPS_FLWRUL` *Account flow stage rules* | area, flow, **sequence** | rule ID, stage, line source G / F and its criteria - G: reference transaction (AWTYP), document type (BLART), debit / credit; F: FI-CA document type, origin key, main / sub-transaction, debit / credit; a blank criterion matches any value; **first match wins** (lowest sequence - the key, so unique); unmatched lines go to OTHER |

Why ranges and not account patterns: a range is a join condition HANA evaluates on the journal's column store; a PCRE
pattern would have to bring every line to ABAP. Cross-row rules (`ZCL_CA_OPS_FLOW_CONFIG=>VALIDATE`, messages 324-329,
and offline `tools/abaptools/flow_config.py`, check `flow_config`): a rule names an active stage (or OTHER) and only
criteria of its line source, an active rule has a criterion (else it would hide OTHER), one account per company code
and currency of a role that receives an expected counter-posting (`EXPECT_TO`; several clearing accounts - ACH, wire,
cheque - are columns of one flow), a role a stage or a tile names is held by an account.

## 4. How each figure is derived (CDS, set-based on HANA)

| Figure | View | Source and rule |
|---|---|---|
| Journal signatures | `ZI_CA_OpsFlowGlSig` | released view **`I_JournalEntryItem`** joined to the accounts (`ZI_CA_OpsFlowAcct`: ledger, company code, account range, currency range), posting date in the window; grouped per account, currency, AWTYP, BLART, debit / credit - only signatures leave HANA |
| FI-CA lines | `ZI_CA_OpsFlowFiLine` / `ZI_CA_OpsFlowFiSig` | **FI-CA posts to the G/L only summarised per reconciliation key** (G/L transfer, AWTYP `FKKSU`): the stage of an FI-CA posting is not visible in the journal. It is derived **from the FI-CA side**: business partner items posted (`DFKKOP` by posting date, own document), business partner items cleared (`DFKKOP` with clearing document, by clearing date, the clearing document's type and origin - payment run, returns lot, reversal - amount reversed), G/L items of the FI-CA documents (`DFKKOPK`); document type and origin from the header `DFKKKO` |
| First match | `ZI_CA_OpsFlowGlMin` / `ZI_CA_OpsFlowFiMin` | lowest sequence of an active rule of the flow and line source whose filled criteria hold - over the signatures, never per line |
| Movement by stage | `ZI_CA_OpsFlowMove` | signature + stage (or OTHER) + rule; debit / credit. For a line source F account the FI-CA lines **plus its direct G/L postings** (bank statement, manual - journal lines that are not the G/L transfer); its G/L transfer lines (AWTYP `FKKSU`) are **IsMemo** (reached G/L) - shown, never added (the subledger would count twice) |
| Opening | `ZI_CA_OpsFlowOpen` | balance up to the day before "from" **without summing years of lines**: fiscal year of "from" from the company code's variant (`I_CompanyCode` -> `I_FiscalCalendarDate`), then the carry-forward (period 000) + the lines of that year before "from" - all through `I_JournalEntryItem` |
| Closing, accounted for, Unexplained | `ZI_CA_OpsFlowPosU` -> `_PosSum` -> `ZI_CA_OpsFlowPos` | closing = opening + journal movement; accounted for = the last evaluation at "to" (`ZI_CA_OpsFlowEvlItm`; an unsigned finding amount takes the sign of the closing); Unexplained = closing - accounted for, status E / N / X |
| Expected | `ZI_CA_OpsFlowExp` | per stage with `EXPECT_FROM`: the accounted-for amount of that role's account, clearing side opposite its balance, counter side on the `EXPECT_TO` account(s) |
| Control tag | `ZI_CA_OpsFlowCtl` -> `ZI_CA_OpsFlowTag` | open exceptions of the checks (`ZI_CA_OpsChkOpen`, the company code and the area level) and the run freshness (`ZR_CA_OpsCheckStatus`) |
| Matrix, query | `ZI_CA_OpsFlowFact` -> cube `ZI_CA_OpsFlowCube` -> query `ZC_CA_OpsFlowQry` | union of the rows (stage, zero rows for every stage, expected, MOVEMENT, OPENING, CLOSING, UNEXPLAINED); stage order and texts, role and account columns, tag, status |
| Tiles, stage card | `ZI_CA_OpsFlowTileU` -> `_TileS` -> `ZC_CA_OpsFlowTile`; `ZI_CA_OpsFlowStgTag` -> `ZC_CA_OpsFlowStage` | service `ZUI_CA_OPS_FLOW` (binding `ZUI_CA_OPS_FLOW_O4`): overview KPI cards and list card |

The currency is a dimension everywhere: amounts are summed per currency, never across. The query: rows stage (order,
ID, tag), columns role and account x debit / credit / expected debit / expected credit; free: reached G/L, status, line
source, document type, origin, transactions, rule; prompts flow, company code, currency (mandatory, single) and the
parameters "from" / "to". Totals hidden (the Movement row is the total of the stages). Consumed in the SAP standard
*Multidimensional Reports* app / Analysis for Office; **no freestyle UI code**. Read access: DCLs on area and company code
(`ZCA_OPS` 03, `docs/auth_zca_ops.md` §3c).

### 4a. Data sources: standard view or table, and why

| Data | Read through | Why |
|---|---|---|
| Journal lines (movement, opening, reached G/L) | released **`I_JournalEntryItem`** (rule D-C8) | the G/L side reads released APIs; its DCL is not applied through the product views - the dashboard's own DCL is |
| Fiscal year of "from" | released **`I_CompanyCode`** (fiscal year variant) + **`I_FiscalCalendarDate`** | period balance approach; `I_FiscalCalendarDate` is VERIFY-ADT (V147) - fallback: lines of every year before "from" (PlanViz FLOW-PV2 decides) |
| Company code name, G/L account name of a column | released **`I_CompanyCode`** (CompanyCodeName, ChartOfAccounts) + **`I_GLAccountText`** (in `ZI_CA_OpsFlowAcct`) | standard texts; `CompanyCodeName` VERIFY-ADT (V147) |
| Texts of tags, statuses, rows, roles | `DDCDS_CUSTOMER_DOMAIN_VALUE_T` (as the repository's reopen texts); `I_Language` for one-row parameter views | standard text access of domain fixed values |
| FI-CA documents and items | tables **`DFKKOP`**, **`DFKKOPK`**, **`DFKKKO`** | no released FI-CA document / item view is confirmed in the repository for S/4HANA 2023 - the documented clean-core exception; VERIFY-ADT (V147): when ADT shows a C1 released FI-CA document view, the branches of `ZI_CA_OpsFlowFiLine` move to it; fields not confirmed in the repository are VERIFY-SE11 (V146) |
| Open FI-CA items (source) | table `DFKKOP` (`ZCL_CA_OPS_FLOW_DAO`) | as above |
| Break snapshots, findings, run status, parameters, configuration | framework tables / views (`ZCA_OPS_BRKRUN` / `_BRKGRP`, `ZCA_OPS_FINDING` through `ZI_CA_OpsChkOpen`, `ZR_CA_OpsCheckStatus`, `ZCA_PARAM_*`) | the framework's own data |
| Not read (not needed): business partner, house bank, bank statement | - | no partner or house bank dimension (the cash column is a G/L account); the bank statement is read by a consumer's CASH source (the framework delivers none, §5) - `I_BusinessPartner`, `I_HouseBank` / `I_HouseBankAccount` and released bank statement views would be added only with a dimension or source that needs them (VERIFY-ADT then; on 2023 the statement stays `FEBKO` / `FEBEP` where no released view is confirmed) |

## 5. What the checks account for (evaluation, report `ZCA_OPS_FLOW_RUN`)

Open items of checks are a property of *now*, and some are only known to ABAP plug-ins - so they are **stored**: the
report evaluates the flows of an area at a key date (blank = today - `FLOW_KEY_DATE_LAG`, default 0) and saves one
evaluation per flow (`ZCA_OPS_FLWEVL` / `_FLWEVI`, configuration version as `docs/EXPLAINABLE_RESULTS.md`, committed per
flow; test mode writes nothing; evaluations older than `FLOW_RETENTION_DAYS` removed). The dashboard compares the
closing at "to" with the **last evaluation whose key date is "to"**; a "to" without evaluation shows *not evaluated*.

| Role | Source class (`EVAL_CLASS`) | What it accounts for | Not evaluated when |
|---|---|---|---|
| `CLEARING`, `SETTLEMENT` | `ZCL_CA_OPS_FLOW_SRC_BREAK` | open break groups **in a named bucket** (not `OTHER`) of the latest break snapshot of each break account of the company code in the range, at most `FLOW_BREAK_MAX_AGE_DAYS` before the key date (`docs/BREAK_ANALYSIS.md`); `OTHER` groups stay unexplained - the break check raises them | no snapshot in the window; a partial snapshot |
| `PAYABLE`, `RECEIVABLE` | `ZCL_CA_OPS_FLOW_SRC_FICA` | open business partner items of the reconciliation account (`DFKKOP`, no clearing document, posted up to the key date); the rest of the closing is what the subledger does not hold open (e.g. the G/L transfer gap) | - (the split "not yet in a payment run / not yet paid" is not evaluated, D-G10) |
| `CLARIFICATION`, `CASH`, any role a check reports item by item | `ZCL_CA_OPS_FLOW_SRC_FINDING` | the open / assigned exceptions of the checks controlling the stages that clear the role (`EXPECT_FROM`), company code, per currency; unsigned, the sign of the balance | no stage clears the role, or no check controls it |
| `OUTSIDE` | - | no control point (no row) | - |
| any | blank | - | always (grey, reason 322) |

Not available in the product (documented gaps, never a silent zero): payments in transit as their own list, the bank
statement balance (three-way reconciliation / statement results of a consumer), returns lot / payment lot items in
clarification read directly - a consumer adds a source class or uses the finding source on its own checks. A check
that reports an item only after n days accounts for it only from then.

## 6. Control tags

| Tag | Rule |
|---|---|
| O *n open* | open or assigned exceptions (B / E / W) of the stage's checks for the company code or the area level |
| P *pending* | no open exception, but a check of the registry (`ZCA_OPS_CHECK`) has no current run (stale, `CHECK_STALE_MIN_<area>`), or the check is not in the registry (a consumer's own engine: the framework sees no run - D-G5) |
| R *reconciled* | every check has a current result and nothing is open |
| N *no control* | no check configured for the stage (also OTHER) |

## 7. Product delivery (`config/flows`, all inactive)

Templates of SAP standard processes in area `CA_FICA` (the catalogue's FI-CA monitoring area; a consumer copies them to
its area): `DISB` (request, payment run FPY1, bank statement paid / return, returns lot - expects CLARIFICATION ->
PAYABLE -, G/L transfer FPG1) and `COLL` (receivable, payment lot / payment run, settlement, bank statement credit,
clarification - expects CLARIFICATION -> RECEIVABLE -, G/L transfer); tiles; controls `FICA_GL_BREAKS` (bank stage)
and `FICA_GL_OPENKEY` (G/L transfer gap) of the catalogue's monitoring templates; rules `S4_GL_TRANSFER` (AWTYP `FKKSU`,
confirmed) and one rule per other stage **without values** - the document types and origin keys are the landscape's
(VERIFY V146). **No accounts, no customer codes.**

## 8. Performance (PlanViz pre-checks)

| ID | Read | Expectation |
|---|---|---|
| FLOW-PV1 | `ZI_CA_OpsFlowGlSig` for the busiest flow and a month window | ledger / company code / account / posting date predicates reach ACDOCA under `I_JournalEntryItem`; aggregation on HANA; rows scanned vs returned recorded; no DCL of the released view evaluated |
| FLOW-PV2 | `ZI_CA_OpsFlowOpen` | carry-forward (period 000) + year-to-date only - never the lines of earlier years; if the carry-forward is not exposed, the fallback (all earlier lines) is measured on the busiest account before it may run |
| FLOW-PV3 | `ZI_CA_OpsFlowFiLine` / `_FiSig` | `DFKKOP` / `DFKKOPK` by company code and account, the clearing branch by clearing date (an index on BUKRS / HKONT / AUGDT may be needed); `DFKKKO` by document key |
| FLOW-PV4 | `ZCL_CA_OPS_FLOW_DAO=>FICA_OPEN_ITEMS` | open items of a reconciliation account aggregated on HANA (company code + account range on `DFKKOP`) |
| FLOW-PV5 | `=>BREAK_SNAPSHOTS`, `=>OPEN_FINDINGS` | snapshot headers by company code / account (few rows), findings by index `OPN` |

## 9. Limits

- The opening relies on the balance carry-forward of the year of "from" (FAGLGVTR); before it has run the prior years
  are missing (V148). Closing and opening are the books in **transaction currency** of the account.
- Unexplained is as good as the sources: a role without a source is grey; a break snapshot covers its look-back
  window only (older open groups show as unexplained); findings of an age threshold appear late.
- Expected postings land on the account of the `EXPECT_TO` role (one per company code and currency: problem 326).
- No posting, no clearing, no matching, no update of SAP standard tables: the evaluation writes only its own tables.

## 10. Decisions for the user

| ID | Decision (proposal) |
|---|---|
| D-G1 | Stages of subledger-posted accounts from the FI-CA side (business partner items posted / cleared, G/L items of FI-CA documents); the journal lines shown as *reached G/L*, closing from the books |
| D-G2 | Opening = carry-forward of the fiscal year of "from" + that year's lines before "from" (no sum over years); fallback only after FLOW-PV2 |
| D-G3 | Expected (brackets) = the open items of the `EXPECT_FROM` role's checks; shown as own columns (the query cannot write brackets) |
| D-G4 | What checks account for is a stored evaluation per key date (`ZCA_OPS_FLOW_RUN`); a "to" without evaluation is *not evaluated* |
| D-G5 | A check outside the registry shows *pending* unless it has open exceptions (alternative: register the consumer's checks) |
| D-G6 | Exposure behind it = in transit + in clarification + unexplained (absolute); grey while an account is not evaluated |
| D-G7 | Accounts as G/L ranges, not patterns |
| D-G8 | Product flows as inactive templates in area `CA_FICA`, copied by a consumer to its area |
| D-G9 | Clearing accounted for = break groups in named buckets only; `OTHER` stays unexplained |
| D-G10 | Payable / receivable: open items only; the split "not in a payment run / not yet paid" not evaluated |

Parameters: `FLOW_LEDGER` (0L), `FLOW_KEY_DATE_LAG` (0), `FLOW_RETENTION_DAYS` (400), `FLOW_BREAK_MAX_AGE_DAYS` (2) -
`docs/PARAMETERS.md`. Messages 320-338, 340 (`config/zca_ops_messages.md`). VERIFY: V145-V149 (`docs/VERIFY.md`).

## Related: customer data on top (2026-11-15)

A customer adds columns from its own tables to the cube `ZI_CA_OpsFlowCube` (on request a copy of the query `ZC_CA_OpsFlowQry`) and the stage card `ZC_CA_OpsFlowStage`; anchors: company code, the stage (area, flow, stage) and the account column (area, flow, account) - extension points `FLOW` and `FLOW_STAGE` of `config/extension_points.json`. It declares them in its folder (`config/extensions/*.json`); `tools/extensions.py` checks them against the inventory and the link registry and generates the `extend view entity` sources into the customer package. No product object changes. `docs/EXTENDING_WITH_CUSTOMER_DATA.md`; VERIFY V153-V157.
