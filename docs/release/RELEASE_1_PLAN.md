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
| P0 | Clean install and release baseline | **M** - versioned pack manifest `ops-framework/release/manifest.json` (releases, components with their version constants, prerequisites, packs PARAM / CORE / FICA_CASH / DEMO with objects by rule, catalogue processes, checks, licence modules, seed rows by key, source contracts, activation steps, fixtures; `tools/release_manifest.py --check`); blank-slate check (product rules in the manifest check, the first customer's deny list in the root test `tools/tests/test_blank_slate.py`; 74 log lines, example area, test data cleaned); collisions offline and name clash test against the target system before any write (R1-D1: stay in Z, namespace report as preparation); import order PARAM -> CORE -> FICA_CASH; upgrade notes `tools/release_diff.py` and rollback procedure; install harness `tools/qualify` (activation, ABAP Unit, ATC, CDS / OData, licensing proof without a licence) - `ops-framework/docs/RELEASE_AND_INSTALL.md`, VERIFY V200-V212 | offline done; SAP run open (V200) |
| P0 | FI-CA cash coverage and trace | **N** - runnable checks for payment run, incoming lot, returns lot, bank statement, clearing reset and G/L transfer on the exception contract of build K; fixtures where finding, source record, amount, owner and age agree across worklist, dashboard and export; failure injection (successful job, incomplete business output) | offline done 2026-11-15: six checks in `ZCA_OPS_CASH` (module `CASH_OPS`, inactive), exception builder mapped into today's finding (one mapping to change for K's contract), 30 fixtures + root spec test (`ops-framework/docs/FICA_CASH_OPERATIONS.md`); open: status values and system proof V220-V237 |
| P0 / P1 | Expected, observed and unknown on every control; alert delivery confirmed separately from submission; monitor coverage; catalogue milestones (finding 3, P1 "Reconcile monitor coverage and alert delivery") | **O** - one evaluation record per registered check and run (`ZCA_OPS_EVAL`: expected scope, source freshness, watermark, completeness, result class OK / ZERO_OK / HOLIDAY / PER_CLOSED / STALE / NOT_EVAL / FINDINGS, reason, last valid result; optional `TY_RESULT-EVAL`, existing checks default from their result; K's day results and N's evaluations mapped onto it); never green when unknown on the area dashboard and in the daily review (healthy sign-off with unknown checks needs an observation); alert delivery state per channel (application log on write, e-mail through a send status reader, custom channels through `CONFIRM`), confirmation job, delivery check and reconciliation view; monitor coverage per area and licence module (refused / warned through the existing licence service); catalogue milestones entry / runnable / platform-validated / activated | offline done 2026-11-16 (`ops-framework/docs/EVALUATION_AND_COVERAGE.md`; fixtures `config/evaluation/fixtures.json` + root test); open: SAP proof V270-V285, the e-mail send status reader (V271 / V272, D-O2) |
| P0 / P1 | External expected-run and dependency evidence when the scheduler never starts SAP; FI-CA mass-activity intervals and their document output (review row "SAP batch monitoring", scorecard 1) | **P** - expected-run plug-in `ZIF_CA_OPS_EXPECTED_RUN_SRC` (plan, predecessor, scheduler state, freshness) with the delivered source on `ZCA_OPS_JOBSCH` plus a calendar and a worked example for a scheduler export; check `ZCL_CA_OPS_CHK_XRUN` against TBTCO (never started / failed before SAP / SAP queue, predecessor not finished, held, late; stale plan `STALE`, unreadable `NOT_EVAL`); mass activity check `ZCL_CA_OPS_CHK_MA_INTERVAL` in `ZCA_OPS_CASH` (parent ended while intervals failed, overrun, output short - payment documents, dunning notices; scorecard 1 fixture MA-01) | offline done 2026-11-16 (`ops-framework/docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md`; fixtures `config/expected_runs/fixtures.json` + root test); open: SAP proof V290-V306, the mass activity framework's own interval records (V300), decisions D-P1 ... D-P5 |
| P0 | Configuration and release gates | **M / N** - customer B installs without customer A records, appends or product edits; preview and rollback of configuration; missing DDIC objects and ambiguous joins; two-user company-code isolation across Fiori, exports, alerts and ticket links; volume test | after K |
| P1 | Case and alert delivery | one customer-selected ITSM channel; one external record per correlated incident with audit trail through retries, outages, reassignment and closure; alert delivery confirmed separately from submission (done in **O**: delivery state and reconciliation; a ticket channel confirms through `CONFIRM`) | later |
| P1 | FI-CA collections and standard FS-CD pack | dunning / clarification and two standard FS-CD flows; one insurance overlay through the extension points | later |
| P2 | Utilities, telecom and PS-CD pilots | one industry at a time on a representative landscape | later |

## 2a. Review coverage (every point of the review, where it is handled)

| Review point | Handled by | Gap still open |
|---|---|---|
| Blank-slate install, versioned delivery, collisions, import order, upgrade, rollback (finding 1, P0) | build M | SAP run of the install harness on A4H, then DV1 |
| V161 posting-area mapping (finding 2) | build L (ZBTM on a typed table, user decision) | - |
| Expected / observed / unknown on **every** control; alert delivery confirmed separately from submission (finding 3) | builds K and N for their own controls; **O** (2026-11-16, framework-wide): an evaluation record for every registered check and run (expected scope, source freshness, watermark, completeness, result class, reason, last valid result; K's and N's states mapped; closed period `PER_CLOSED`), unknown shown apart from OK on the dashboard and the daily review (sign-off as healthy needs a reason), alert delivery state per channel with a confirmation job, a delivery check and a reconciliation view, monitor coverage per area and licence module (disabled, refused, warned, impaired, not run, ran) - `ops-framework/docs/EVALUATION_AND_COVERAGE.md` | SAP proof V270-V285; the e-mail channel cannot confirm until a send status reader is verified (V271 / V272, D-O2) |
| Customer extensions proven before more screens; identity beyond a shared document number (system, client, company code, fiscal year); ambiguous matches shown (finding 4, P0 gates) | build H (contract), build K (second setup) | **Q**: intake flow and payment reference added by configuration for customer XX; ambiguous-match view in the walker; authorisation and cardinality tests |
| Reference insurance implementation gaps: ECT pending, BlackLine extract monitoring, base-rejected and missing-check-ID controls, returns source notification (finding 5) | build R (2026-11-16, suite only): every check built and delivered inactive - `C_ECT_PENDING`, `C_CHQ_NO_ID`, FMON due-file check `F_BLKLINE` / `F_RETNOTIF`, collections R2 / R3 complete; `ops-suite/docs/Pilot_Acceptance.md` | business answers V240-V255 (pending ECT values, BlackLine file evidence and due time, request status and refund log, cheque methods, how PCLM is told about returns - do the PSU runs report returns?), then one activation request per control and its QA1 test |
| Batch: expected runs when the scheduler never starts SAP; FI-CA mass-activity intervals and their document output (scorecard 1) | **P** (2026-11-16): the scheduler's plan through `ZIF_CA_OPS_EXPECTED_RUN_SRC` (configured plan on `ZCA_OPS_JOBSCH` plus a calendar; worked example of a scheduler export) compared with TBTCO - never started, failed before SAP, SAP queue, predecessor not finished, held, late, with the exception contract and evidence of the scheduler record and the SAP job; a stale plan is `STALE`, an unreadable one `NOT_EVAL`; mass activity check `ZCL_CA_OPS_CHK_MA_INTERVAL` (parent ended while intervals failed, overrun, output short against the payment run's documents or dunning notices; scorecard 1 = fixture MA-01: 1 document, 250.00 EUR, stage `JOB_OK`) - `ops-framework/docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md` | `FKKMAKO` / `FKKMAZE` are the dunning history, not the mass activity run / interval records: those are not in the reference system's export (V298, V300) - the delivered run source sees parallel jobs; SAP proof V290-V306; D-P1 ... D-P5 |
| Payment file lifecycle, acknowledgement granularity, reissue and duplicate exposure (P0) | build K | SAP proof |
| Cash controls: payment run, lots, returns, statement, clearing reset, G/L transfer (P0) | build N | three-way reconciliation and account flow already exist; SAP proof |
| Configuration preview and rollback, missing DDIC objects, two-user isolation across Fiori, exports, alerts and ticket links, volume (P0 gates) | builds M / N in part | **Q** (preview / rollback, missing DDIC, isolation across exports and ticket links); volume in QA1 |
| Responder acknowledgement separate from assignment; ticket synchronisation; repeat incidents (daily operations, P1) | - | R1-D5, then P1 |
| Bank statement parser qualified by message version and bank profile | - | P1 (bank profile matrix) |
| Request, attempt, payment, file and journal line kept as distinct objects; one-to-many navigation (payment trace) | payment trace, build K evidence rows | check during build K merge |
| Catalogue milestones tracked apart: catalogue entry, runnable check, platform-validated, customer-activated | **O** (2026-11-16): four columns per catalogue process (`ZC_CA_OpsCatalogue`, generated `docs/catalogue/milestones.md`); platform validation recorded on a system (`ZCA_OPS_CAT_VALIDATE`), never seeded | the install harness records its validation (V283) |
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
| D-O1 | Which result classes count as healthy on a card: today `OK`, `ZERO_OK`, `HOLIDAY` are green, `PER_CLOSED` neutral, `FINDINGS` / `PARTIAL` amber, `NOT_EVAL` / `STALE` red (build O) | Support reads one colour per control; a closed period that should count as healthy changes the criticality of `ZI_CA_OpsEvalNow` only |
| D-O2 | E-mail delivery: build and verify a SOST send status reader (`ZIF_CA_OPS_DLV_READER`) after V271 / V272 and decide which SAPconnect status is "delivered" (transmitted to the mail server, or a delivery receipt) - until then the e-mail channel answers "cannot confirm" | The reconciliation shows e-mail alerts as unconfirmed, never as delivered; payment-critical routes may add the application log channel, which confirms on write |
| D-O3 | Period close: keep the parameter list `EVAL_PERIOD_CLOSED` per area, or plug a site calendar on SAP's posting periods (OB52) after V275 | Without either, a check of a closed period shows `OK` instead of `PER_CLOSED` |
| D-O4 | Severity of the coverage gaps (`MONITOR_NOT_RUN` / `MONITOR_REFUSED` = E, `MONITOR_IMPAIRED` / `MONITOR_LIC_WARNED` = W) and of "cannot confirm" (`EVAL_DLV_UNCONFIRMABLE` I) - and whether the delivered registry rows `COVERAGE` / `ALERT_DELIVERY` stay active by default | A monitor gap is an owned exception routed by the existing alert rules; the rows of area `CA_OPS` run only where the customer schedules them |
| D-P1 | Mass activity intervals: accept for Release 1 that the delivered run source sees a run's parallel jobs (SAP job tables), or first confirm the mass activity framework's run / interval tables and status values (V300) and add a source with true interval numbers. `FKKMAKO` / `FKKMAZE` named in the plan are the dunning history (V298) | Interval numbers and states of the framework would make the evidence confirmed instead of probable; the parallel-job view already proves scorecard 1 (job finished, a child failed, output short) |
| D-P2 | A payment without document after a successful payment run: report it by the mass activity check (`MA_OUTPUT_SHORT`, with the failed interval) or by the payment run check (`PAYRUN_NO_DOCUMENT`, build N) - activate one rule per area, or route one to information | Both see the same 250.00 EUR of scorecard 1; two exceptions for one cause double the work |
| D-P3 | Business calendar of the configured plan: the core has none (weekdays only); holidays come from the FI-CA Cash Operations pack (`ZCL_CA_OPS_MA_CALENDAR` on the cash checks' factory calendar) or a site class. Alternative: move one factory calendar reader into the core for every module | Without a calendar, a holiday of a configured job is a "never started" unless its row has no run on that weekday |
| D-P4 | Severity of the expected-run verdicts (never started / predecessor not finished = E, held / late = W) and whether a scheduler row of criticality L lowers them | The alert rules route by severity; a low-criticality job may not justify a call-out |
| D-P5 | `ZCA_OPS_MAACT` is a core table (the generated configuration app is core, as the payment file configuration of build K) while its rows and the check are of the FI-CA Cash Operations pack | A core install carries an empty table it does not read; the alternative is a pack-own configuration app |
