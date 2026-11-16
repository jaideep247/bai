# Exception contract

> **First principle:** an exception is only actionable when it says how much is at stake, by when it must be answered,
> who answers it, where the process stopped and which records prove it.
> **Analogy:** a delivery note on a damaged parcel - number of items, value, the date the customer was promised, the
> depot responsible, the last scan, and the scans themselves stapled to it.

Introduced 2026-11-15 (build K) with the payment file lifecycle, its first adopter; generic, so that every module can
adopt it (a module of FI-CA cash checks will). Status: not activated (`docs/VERIFY.md` V170).

## 1. The contract in one type

`ZIF_CA_OPS_EXC_CONTRACT=>TY_CONTRACT` is included in `ZIF_CA_OPS_TYPES=>TY_FINDING` and stored by the store in
`ZCA_OPS_FINDING`; the evidence rows `ZIF_CA_OPS_EXC_CONTRACT=>TY_EVIDENCE` are returned by a check in
`ZIF_CA_OPS_CHK_TYPES=>TY_RESULT-EVIDENCE` and stored by the runner in `ZCA_OPS_FNDEVI` (`ZIF_CA_OPS_EVIDENCE`).

| Contract item | Finding field (`TY_FINDING` / `ZCA_OPS_FINDING`) | Rule |
|---|---|---|
| Count | `ITEM_COUNT` / `ITEM_COUNT` | the items (payments) the finding stands for |
| Items without known amount | `UNKNOWN_COUNT` | the gross `AMOUNT` is then a lower bound - never 0 for "not known" |
| Gross amount and currency | `AMOUNT`, `CURRENCY` | one currency per finding; a module with several currencies raises one finding per currency; never summed across currencies |
| Duplicate exposure | `DUP_AMOUNT` (in `CURRENCY`) | kept apart from the gross; totals over related findings (a correlation group) count the gross once |
| Deadline | `DEADLINE_AT` (UTC), `CALENDAR_ID` | the deadline the finding is about and the business calendar it was computed in |
| Stage | `STAGE` | where the process stopped, in the module's vocabulary |
| Owner | `RESP_USER`, `RESP_TEAM`, `RESP_SOURCE` | from the existing configuration (`ZIF_CA_OPS_OWNER`): **C** the active control that covers the check code, else the check ID, else the rule (`ZCA_OPS_CTLCHK` -> `ZCA_OPS_CONTROL` owner and team); **P** the owner of the check's business process (`ZCA_OPS_PROC`); **N** none configured (said, never guessed). The assigned owner of the exceptions app (`OWNER`) stays separate |
| Evidence | `EVID_KEY` + rows of `ZCA_OPS_FNDEVI` | `ZCL_CA_OPS_EXC_CONTRACT=>EVIDENCE_KEY` (SHA-1 of area, check, object key, company code - stable over the carry-forward); rows replaced at every run that raises the finding |

Evidence row: kind (`SAP`, `MW` middleware / transfer, `BANK`, `OPS` the product's own record), type (`RUN`, `JOB`,
`PAYDOC`, `FILE`, `MSG`, `ACK`, `STMT`, `EVENT`), label, the record's own key, the **link registry object and key
values** ("FIELD=value;...") - `ZIF_CA_OPS_EVIDENCE=>WALKER_REQUEST` turns a row into the start of the link walker
(`docs/LINK_REGISTRY.md`) - occurrence and observation time, quality (`C` confirmed, `P` probable, `U` unmatched),
source.

The contract fields are not inherited by the carry-forward: each row keeps its own run's view (as the configuration
version).

## 2. How a module adopts it

1. Fill the contract fields of every finding (`ZCL_CA_OPS_EXC_CONTRACT=>MISSING` lists the gaps: `COUNT`, `CURRENCY`,
   `DEADLINE`, `OWNER`, `STAGE`, `EVIDENCE` - assert it empty in the module's unit test).
2. Resolve the owner with `ZCL_CA_OPS_FACTORY=>GET_OWNER( )->RESOLVE( )`.
3. Return the evidence rows with the findings (`RS_RESULT-EVIDENCE`, key = the finding's `EVID_KEY`); the runner stores
   them in the run's unit of work, never in test mode.
4. Nothing else: the exceptions app shows the facet *Payments, deadline and owner* and the facet *Evidence*
   (`ZC_CA_OpsFindEvidence`, DCL area and the finding's company code) for every adopting module.

## 3. Mapping for a module of FI-CA cash checks

| What the check knows | Contract field |
|---|---|
| Open items / payments / documents counted | `ITEM_COUNT` (and of them without amount `UNKNOWN_COUNT`) |
| Their amount per currency | `AMOUNT` / `CURRENCY` - one finding per currency |
| Amount at risk twice (a document on two lots, a payment in two files) | `DUP_AMOUNT` |
| Clearing / posting deadline on the business calendar | `DEADLINE_AT` / `CALENDAR_ID` |
| Process step reached (e.g. lot posted, clearing open) | `STAGE` |
| Documents, lots, statement lines, jobs | evidence rows with their link registry objects (`FICA_DOC_HEADER`, `FICA_PAYMENT_RUN`, `S4_BANK_STMT_LINE`, `S4_BACKGROUND_JOB`, ...) |

## 4. Limits

- The owner is the configuration at finding time; a reassignment in the exceptions app is the separate `OWNER`.
- The evidence of a finding is its latest run's; older evidence is not kept (the history keeps the dispositions).
- A finding of a module that does not adopt the contract has blank contract fields; the facets then stay empty.
