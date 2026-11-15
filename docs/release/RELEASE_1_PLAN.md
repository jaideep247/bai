# Release 1 plan: FI-CA Cash Operations pack

> **First principle:** for each expected business cycle, support must see what should have happened, where it stopped,
> how many items and how much money are affected, who owns the response, and which SAP, middleware or bank records prove it.
> **Analogy:** a parcel tracker for money - not "the van left the depot", but "these 1,240 parcels worth 3.1 million
> left the depot, the courier never signed for them, the deadline was 10:00, and this is the person on call".

Source: the product review of 2026-11-15 (`docs/review/2026-11-15_FICA_Production_Support_Product_Review.md`).
The release claim is limited to the SAP releases, connectors and process variants proven in the pilot (review, last
section).

## 1. Scope of Release 1

One installable **FI-CA Cash Operations** pack on S/4HANA 2023 on-premise / private edition (classic ABAP, RAP, OData V4),
proven on a clean system and with a second customer configuration that uses a different middleware or bank integration.

| In Release 1 | Later |
|---|---|
| Payment run expected / completed, proposal-to-payment gaps | FI-CA revenue and collections (invoicing, dunning, correspondence, instalments, write-off) - P1 |
| Payment file lifecycle: generation, middleware pickup, onward delivery, bank receipt, bank acceptance, posting / settlement (flagship) | Standard FS-CD pack (premium / debit entry, broker report, claims disbursement) - P1 |
| Payment lots and clarification ageing; returns lots and reversal | ITSM ticket synchronisation (one channel) and one SAP monitoring route - P1 |
| Bank statement arrival and posting; clearing and reset exceptions | Utilities (IS-U), telecommunications (BRIM / CI), public sector (PS-CD) pilots - P2 |
| Reconciliation key transfer to G/L; three-way cash reconciliation | Public Edition / side-by-side variant - separate engineering path |

Every exception of the pack carries: count, amount and currency (per currency, never summed across currencies), deadline
(business calendar), owner, the stage where the cycle stopped, and evidence at source grain. Every evaluation tells
expected, observed and unknown apart: a stale source, a valid zero-volume day, a holiday and a failed query give
different results; a failed query is "not evaluated", never "OK".

## 2. Backlog and builds

| Priority | Deliverable (review section 5) | Build | State |
|---|---|---|---|
| P0 | Portable file and ACK adapter (flagship) | **K** - payment file lifecycle module in the framework; adapters for scheduler, middleware, acknowledgement and ticketing; exception contract; worklist; first customer's adapters and example customer XX with a different setup | running |
| P0 | V161 before the posting-area mapping becomes a portable default | **L** - mapping source per purpose (posting area or typed table) behind the existing reader; ZBTM on the typed table; rollback, precedence and duplicate tests | running |
| P0 | Clean install and release baseline | **M** - versioned pack manifest (releases, components, prerequisites, checks, seed data, source contracts, activation steps, fixtures); blank-slate install check (framework and parameter framework with no customer table, field, scheduler name, source code or recipient); object collision and import order; upgrade replay and rollback; activation proven separately from licensing | next |
| P0 | FI-CA cash coverage and trace | **N** - runnable checks for payment run, incoming lot, returns lot, bank statement, clearing reset and G/L transfer on the exception contract of build K; fixtures where finding, source record, amount, owner and age agree across worklist, dashboard and export; failure injection (successful job, incomplete business output) | after K |
| P0 | Configuration and release gates | **M / N** - customer B installs without customer A records, appends or product edits; preview and rollback of configuration; missing DDIC objects and ambiguous joins; two-user company-code isolation across Fiori, exports, alerts and ticket links; volume test | after K |
| P1 | Case and alert delivery | one customer-selected ITSM channel; one external record per correlated incident with audit trail through retries, outages, reassignment and closure; alert delivery confirmed separately from submission | later |
| P1 | FI-CA collections and standard FS-CD pack | dunning / clarification and two standard FS-CD flows; one insurance overlay through the extension points | later |
| P2 | Utilities, telecom and PS-CD pilots | one industry at a time on a representative landscape | later |

## 2a. Review coverage (every point of the review, where it is handled)

| Review point | Handled by | Gap still open |
|---|---|---|
| Blank-slate install, versioned delivery, collisions, import order, upgrade, rollback (finding 1, P0) | build M | SAP run of the install harness on A4H, then DV1 |
| V161 posting-area mapping (finding 2) | build L (ZBTM on a typed table, user decision) | - |
| Expected / observed / unknown on **every** control; alert delivery confirmed separately from submission (finding 3) | builds K and N for their own controls | **O**: framework-wide evaluation state (expected scope, freshness, watermark, completeness, last valid result, reason) for all existing checks; delivery confirmation of alerts; monitor-coverage state when a licensed module is impaired or disabled |
| Customer extensions proven before more screens; identity beyond a shared document number (system, client, company code, fiscal year); ambiguous matches shown (finding 4, P0 gates) | build H (contract), build K (second setup) | **Q**: intake flow and payment reference added by configuration for customer XX; ambiguous-match view in the walker; authorisation and cardinality tests |
| Reference insurance implementation gaps: ECT pending, BlackLine extract monitoring, base-rejected and missing-check-ID controls, returns source notification (finding 5) | - | **R**: first customer's pilot acceptance items (suite only) |
| Batch: expected runs when the scheduler never starts SAP; FI-CA mass-activity intervals and their document output (scorecard 1) | - | **P**: expected-run evidence from the scheduler adapter; mass-activity interval check (FKKMAKO / FKKMAZE) with partial-output detection |
| Payment file lifecycle, acknowledgement granularity, reissue and duplicate exposure (P0) | build K | SAP proof |
| Cash controls: payment run, lots, returns, statement, clearing reset, G/L transfer (P0) | build N | three-way reconciliation and account flow already exist; SAP proof |
| Configuration preview and rollback, missing DDIC objects, two-user isolation across Fiori, exports, alerts and ticket links, volume (P0 gates) | builds M / N in part | **Q** (preview / rollback, missing DDIC, isolation across exports and ticket links); volume in QA1 |
| Responder acknowledgement separate from assignment; ticket synchronisation; repeat incidents (daily operations, P1) | - | R1-D5, then P1 |
| Bank statement parser qualified by message version and bank profile | - | P1 (bank profile matrix) |
| Request, attempt, payment, file and journal line kept as distinct objects; one-to-many navigation (payment trace) | payment trace, build K evidence rows | check during build K merge |
| Catalogue milestones tracked apart: catalogue entry, runnable check, platform-validated, customer-activated | - | part of **O** (a status column per catalogue process) |
| FI-CA collections, FS-CD pack (P1); IS-U, BRIM, PS-CD (P2) | - | after Release 1 |
| Redistribution review of the shipped set (finding 1) | build M blank-slate check (technical part) | R1-D3 (legal part) |

## 3. Acceptance: the demo scorecard (review section 5)

The same fixtures run against this product and any shortlisted alternative.

1. SAP job finished, a child interval failed, and the batch produced only part of the expected financial output.
2. Payment file generated and picked up, bank acknowledgement missing, replacement file issued, late acknowledgement
   received for the original.
3. Bank statement posted, a residual remains in the clearing account, a return or reversal is pending, and the next
   G/L close depends on it.
4. A source goes silent on a business day, reports a valid zero on another day, and is intentionally inactive on a holiday.
5. The same workflow deployed for a second company and a different middleware, with a custom check and separate operator
   permissions.

Measured: time to detect; time to identify business impact and owner; false and missed findings; count and amount
verifiable end to end; time to onboard the second configuration; collector performance at representative peak volume.

## 4. SAP proof (cannot be done offline)

- **Reference system A4H** (S/4HANA 2025 with FI-CA): the test tool's qualification harness already syncs, activates and
  runs ABAP Unit and ATC there through ADT. Reuse that route for a clean install of the parameter framework and the
  framework (no suite), then the pack, as the first install proof - noting that the target release is 2023.
- **Target landscape DV1 / QA1**: activation, ABAP Unit, ATC, CDS / OData activation, PlanViz pre-checks, two-user
  isolation, pilot volume.
- Open VERIFY items of each component (`ops-framework/docs/VERIFY.md`, `ops-suite/docs/VERIFY_Suite.md`).

## 5. Decisions for the product owner

| ID | Decision | Why it matters |
|---|---|---|
| R1-D1 | **Decided 2026-11-15: stay in the Z namespace (`ZCA_` prefix) for now.** A registered vendor namespace (for example `/XYZ/`) stays an option for commercial delivery | Customer objects also use Z / Y, so the install checks the target for a same-named object outside the product packages and stops before writing; the namespace report of build M shows what a later move would change |
| R1-D2 | **Decided 2026-11-15: abapGit for pilots, SAP Add-On Assembly Kit (AAK) later for commercial delivery.** Before AAK: register a vendor namespace and rename (AAK does not package Z objects - see R1-D1 and the namespace report of build M), get AAK access through the SAP partner programme, set up a development and an assembly system for the target release | AAK gives installation with SAINT, updates with SPAM / SAINT, a versioned software component, upgrade safety, vendor-object protection and optional uninstall |
| R1-D3 | Redistribution rights and a review of the distributable set for customer-specific data, artefacts and identifiers | The suite and the review documents stay out of the product delivery |
| R1-D4 | Pilot landscape and the second-customer configuration used for the proof | The release claim covers only what the pilot shows |
| R1-D5 | Responder acknowledgement separate from assignment, if a distinct response SLA is needed (review, daily operations) | Today escalation stops at assignment |
