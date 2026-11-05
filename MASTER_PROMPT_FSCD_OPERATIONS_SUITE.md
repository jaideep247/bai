# Consolidated Master Prompt — SAP FS-CD / FI-CA Production Health Check, File Monitoring, EBS Validation & Job Cycle Frameworks (Enterprise Edition)

**Added**: 2026-11-05  
**Status**: Design brief (not yet implemented)  
**Seed data**: `btc-validation-matrix.xlsx` (not in this repository yet; attach it whenever you use the prompt)

This is the single, end-to-end master prompt consolidating the complete enterprise operations suite: the Health Check Framework, Custom-Table File Monitoring, CAMT/BAI BTC-Code EBS Validation, and the In-SAP Fallback Job Cycle Tool.

Copy the prompt block below (from "ROLE" to "ACCEPTANCE TESTS") into your AI assistant or development team brief. Attach `btc-validation-matrix.xlsx` as seed data.

---

> ### ROLE
> You are a Principal SAP Enterprise Solutions Architect with 20+ years in SAP for Insurance, specializing in FS-CD (built on FI-CA), high-throughput payment architectures, treasury/EBS processing, and production reliability engineering. You build fault-tolerant frameworks capable of processing tens of millions of financial documents (DFKKOP/DFKKOPK scale) per cycle.
>
> ### MISSION
> Design and build a modular, decoupled, **configuration-driven framework suite** for an enterprise SAP FS-CD/FI-CA landscape. The suite shares one execution engine, an auditable exception store, an alert router, an authorization model, and a real-time operational dashboard across four core pillars:
> 1. **Health Check Framework** — Configurable operational, financial, and technical health checks with statistical baselines and anomaly detection.
> 2. **File Monitoring Framework** — Custom-table based tracking through the SAP → PRISM (middleware) → Bank → SAP processing lifecycle.
> 3. **EBS Validation Framework** — Bank statement validation for CAMT (053/054) and BAI2 formats driven by a Bank Transaction Code (BTC) rule engine.
> 4. **Job Cycle Monitoring & Retrigger Tool** — Configurable SAP background job chains providing real-time tracking and emergency fallback retriggers for Control-M.
>
> ---
>
> ### TECHNICAL ARCHITECTURE & CODING STANDARDS
> 1. **Language Level:** Pure **ABAP 7.50+ syntax**. Leverage inline declarations (`DATA(...)`, `FINAL(...)`), table expressions (`VALUE`, `CORRESPONDING`, `FILTER`, `COND`, `SWITCH`), host variables (`@`), SQL aggregations, and CDS views for DB pushdown.
> 2. **Software Design Patterns:**
>    - **Factory Pattern:** Dynamically resolve and instantiate check/rule classes via customizing tables (`ZCD_*`).
>    - **Strategy Pattern:** Decouple validation routines, BTC evaluation algorithms, and alert dispatchers into interchangeable runtime strategies.
>    - **Chain of Responsibility:** Orchestrate statement line checks sequentially (Statement Level -> BTC Rule Engine -> Posting Pre-checks).
>    - **Observer Pattern:** Decouple metric and event producers from downstream sinks (persisted alerts, dashboard caches, email/webhook triggers).
>    - **Singleton Pattern:** Manage framework runtime configurations, authorization caches, and shared run-context metadata.
> 3. **Dependency Injection & Testability:** Decouple database operations, SAP background job function modules, and file APIs behind explicit interfaces (`IF_ZCD_*`).
> 4. **ABAP Unit Testing (AUnit):**
>    - Mandatory test classes (`FOR TESTING RISK LEVEL HARMLESS DURATION SHORT`) on all engines and strategies.
>    - Full dependency isolation via mock implementations (injecting mock DB/Customizing providers; zero dependency on persistent database state).
>    - Minimum **85% code coverage** across branch, statement, and condition paths.
>    - Boundary, negative, and data-mismatch scenarios must be explicitly asserted (`cl_abap_unit_assert=>assert_equals`, `assert_differs`, `assert_subrc`).
>
> ---
>
> ### CONFLUENCE WIKI-STYLE DOCUMENTATION REQUIREMENT
> Every deliverable must provide production-ready Confluence markdown documentation split into two distinct target audiences:
> 1. **Business & Operations Review:** Executive process summaries, process flow diagrams (Mermaid.js), business impact matrices, SLA/compliance commitments (SOX, NACHA), and operational RAG triage playbooks.
> 2. **Technical & Architecture Review:** Class diagrams, customizing schemas (SE11/SM30 tables and maintenance views), CDS view definitions, BAdI implementation points (e.g., `FIEB_CHANGE_BS_DATA`), and extension guidelines (adding checks/BTC rules purely through customizing).
>
> ---
>
> ### OUR LANDSCAPE (GROUND TRUTH)
> - **SAP Role:** Central payment engine. Receives payment requests from source systems, creates business partner master data, executes **VYSPA** to generate FS-CD documents, and triggers **FPY1** (Payment Run).
> - **Inbound Sources:** PCLM, BASE, ALPA, ALPL, HAL, ORCI, DIS.
> - **Payment Methods:** Wire, Check, EFT (ACH); domestic and international cross-border.
> - **Outbound Flow:** SAP → **PRISM (middleware)** → Bank. Every outbound file must track handoffs: PRISM pickup, forwarding, and downstream bank acknowledgment (ACK/NACK).
> - **Inbound Flow:** BAI2 and CAMT.053/054 statements; bank returns (ACH returns and NACHA NOC — Notification of Change) executing automated master data updates and returns lots (**FP09**).
> - **Target Processes:** VYSPA, FPY1, F.13, Write-offs (FP45), FP09, FPCRL, FPCPL (Clarifications), FEBP, FPB7, FPB17.
> - **Existing Custom Footprint:** Unify and extend existing logs without dropping historic tables: `ZCDT_REGUT`, `ZCD_CHECK_HIST`, `ZCD_ACH_RTRV_LOG`, `ZCD_ACH_ACK`, `ZCD_WIRE_ACK`, `ZCD_STRP_POUT_LOG`.
> - **Scheduling:** Control-M is primary; the suite provides an in-SAP native fallback to define, track, and retrigger job chains during Control-M outages or communication failures.
>
> ---
>
> ### DETAILED FRAMEWORK SPECIFICATIONS
>
> #### 1. HEALTH CHECK FRAMEWORK
> - **Runner Engine:** Configurable orchestrator executing check strategies implementing `IF_ZCD_HEALTH_CHECK`. Reads check definitions from `ZCD_HCK_DEF` and thresholds from `ZCD_HCK_THRESH`.
> - **Execution Model:** Package-size DB streaming, parallel RFC processing (`SPBT_*` or `CALL FUNCTION ... STARTING NEW TASK`) with auto-throttling against worker limits, run-state persistence in `ZCD_HCK_RUN`, and automatic circuit breaking on timeouts.
> - **Catalog (Minimum Deliverables):**
>   - *A. Financial Integrity:* Subledger (DFKKOP) to General Ledger (FAGLFLEXA/ACDOCA) reconciliation; posting interface error identification; open-item aging buckets; clearing differences; cash suspense balances.
>   - *B. Mass-Run Health:* FPY1, dunning, and correspondence runs: item throughput, interval completion, deviations against a rolling baseline (mean/median over prior 4–8 runs), and SLG1 message class log error rates.
>   - *C. Exception Queues:* Post Processing Office (PPO) backlog aging; clarification worklist backlog (FPCPL/FPCRL); payment dispute aging.
>   - *D. Master Data & Config Drift:* Missing payment parameters, bank key inconsistencies, frozen accounts, and baseline customizing hash verification.
>   - *E. Technical Health:* Cancelled/hung batch jobs (TBTCO), update terminations (VBHDR), short dumps (SNAP), lock entry backlogs (SM12), and staging table bloat.
>
> #### 2. FILE MONITORING FRAMEWORK (CUSTOM TABLES, ZERO-AIF DEPENDENCY)
> - **Unified Registry Layer:** Build a normalized facade over `ZCDT_REGUT` and legacy `ZCD_*` logs.
> - **Event Chain State Machine:**
>   - *Outbound:* `GENERATED_IN_SAP` → `SENT_TO_PRISM` → `FORWARDED_TO_BANK` → `ACK_RECEIVED` / `NACK_REJECTED`.
>   - *Inbound:* `FILE_RECEIVED` → `FILE_LOADED` → `FULLY_PROCESSED` / `PARTIALLY_PROCESSED` / `FAILED`.
> - **Validation & SLA Monitoring:** Cross-check against interface calendars, SLA delivery windows (e.g., Wire ACK within 30 min), file checksum validation, zero-byte detection, and expected record/amount control totals.
> - **NOC & Returns Lifecycle:** Guarantee 100% reconciliation on incoming return files. Every line must tie to an executed FP09 returns lot, an applied BP master data update (NACHA NOC C01–C07 within the 6-day SLA window), or an open, assigned operational exception. Files with unaccounted items remain `PARTIALLY_PROCESSED`.
>
> #### 3. EBS VALIDATION FRAMEWORK (BAI2 + CAMT, BTC RULE ENGINE)
> - **Pre-Posting File & Statement Checks:** Validate via `FIEB_CHANGE_BS_DATA` BAdI before posting begins.
>   - Opening balance = prior statement closing balance (statement continuity via FEBKO).
>   - Calculation check: Opening + Credits − Debits = Closing (CAMT OPBD/CLBD and BAI2 record 02/03).
>   - Statement numbering continuity, file hash verification, account currency matching.
> - **BTC Rule Engine (ZCD_BTC_MAP & ZCD_BTC_RULE):**
>   - Map CAMT (Domain/Family/Sub-Family) and BAI2 codes to semantic business flows (ACH settlements, returns, wires, checks, lockbox, fees, sweeps).
>   - Execute rules R01–R18 (Amount signs, currency consistency, mandatory trace numbers, NACHA return reason cross-checks, outbound ACK cross-referencing, SLA aging, and debit reconciliation against PRISM).
>   - **Strict Zero-Suspense Guarantee:** Unmapped BTC codes (`X01`) trigger a hard `BLOCK` and log an auditable exception. No line posts to unallocated suspense without explicit rule validation.
>
> #### 4. JOB CYCLE MONITORING & RETRIGGER (CONTROL-M FALLBACK)
> - **Cycle Definition Engine (`ZCD_JOB_CYCLE`):** Sequence job chains, predecessor dependencies, parameters, maximum SLA runtimes, and critical paths (VYSPA → FPY1 → DME/PRISM → FEBP → FP09 → FPCPL → F.13).
> - **Active Monitoring:** Inspect `TBTCO`/`TBTCP` runtime data, evaluate divergence between Control-M plans and SAP actual execution, and compute dynamic cycle health.
> - **SAP-Native Retriggering:** Secure, role-gated UI/report allowing step retriggers, cycle restarts from failure points, or manual chain executions using event-driven background job scheduling (`BP_EVENT_RAISE`). Ensure idempotent checks to prevent accidental duplicate execution.
>
> ---
>
> ### DELIVERABLES EXPECTED
> For every framework component, deliver:
> 1. **Complete ABAP 7.5 Code Artifacts:** Fully typed interfaces (`IF_*`), factory classes, strategy implementations, exception classes (`CX_*`), and dictionary structures using modern syntax.
> 2. **Comprehensive ABAP Unit Test Classes:** Isolated unit tests leveraging mock test doubles, covering positive, boundary, and error conditions.
> 3. **Confluence Wiki Page Documentation:** Structured production runbook in clean markdown, with dedicated tabs/sections for Business Operations and Technical Support.
>
> ---
>
> ### ACCEPTANCE TESTS
> 1. **Zero-Code Extensibility:** Add a new health check, source system, or BTC validation rule strictly via table customizing entries (`SM30`), requiring zero ABAP modifications.
> 2. **Suspense Protection:** Provide unit test proof that an unmapped or invalid transaction code triggers a hard block and logs an exception without generating an unassigned GL posting.
> 3. **Incomplete Returns Handling:** Demonstrate that an ACH return file containing unprocessed transactions flags the file status as `PARTIALLY_PROCESSED` and emits a high-priority alert.
> 4. **Mocked Unit Verification:** All business logic passes isolated ABAP Unit test suites with zero database dependencies and >85% code coverage.
