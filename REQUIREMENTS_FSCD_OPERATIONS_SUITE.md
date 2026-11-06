# Requirements — SAP FS-CD Production Support Operations Suite

## Role and objective

Act as a principal SAP technical architect, FI-CA / FS-CD insurance functional consultant, and production support lead. Design and improve `ops-suite` as an on-premises SAP operations layer for the existing payment engine, with no SAP BTP dependency. Help L1/L2 teams answer what was expected, what happened, which transactions are affected, what evidence supports the conclusion, and who owns the next action.

Use the actual target SAP release, active objects, job variants, interface contracts, and approved operational procedures as the baseline. Treat repository documentation and configuration seeds as evidence to verify. Identify capabilities as implemented, requiring target SAP verification, or proposed.

## Technical environment and delivery constraints

- Target SAP S/4HANA 2023 on-premise or private cloud with SAP_BASIS 7.58. Confirm the installed release and support package in the target system. Use ABAP 7.58-compatible syntax and Clean Core extension principles.
- Maintain the abapGit root package `ZCD_OPS` and subpackages `ZCD_OPS_CORE`, `ZCD_OPS_EBS`, `ZCD_OPS_FMON`, and `ZCD_OPS_HCK`. Keep operational persistence and alerting in Core, statement validation in EBS, file lifecycle tracking in FMON, and health checks and analytical views in HCK.
- Keep the suite native to S/4HANA with no SAP BTP dependency. Prefer existing reports and jobs. Use CDS, RAP, Fiori elements, or ALV with IDA where appropriate for a verified support need. Any new UI may modify only authorized operational records. Use native background processing for monitoring or alerting where needed. Observe existing FI-CA mass activities through their available evidence.
- Require the repository's abaplint checks and target-system activation, ATC and Code Vulnerability Analyzer checks under the approved security variant before promotion. Record the effective check versions and approved exemptions. Validate authorization, SQL access paths and runtime under representative support load.

## Repository baseline and implementation status

Start from the existing entry points and extend their normal execution paths.

| Area | Repository entry point | Implementation work |
|---|---|---|
| FMON | [ZCD_FMON_MONITOR](ops-suite/src/fmon/zcd_fmon_monitor.prog.abap) | Extend the registry, evidence correlation and SLA findings for the approved pilot interfaces. Prove the identity, acknowledgement and concurrency cases below. |
| HCK | [ZCD_MORNING_REPORT](ops-suite/src/hck/zcd_morning_report.prog.abap) | Extend job-cycle observation, expected-volume coverage, stale-run detection and alert evidence. Control-M retains scheduling and recovery ownership. |
| EBS | [ZCD_EBS_VALIDATE](ops-suite/src/ebs/zcd_ebs_validate.prog.abap) | Extend report-based shadow validation and reconciliation. Posting enforcement and release of blocked lines are outside this initiative. |
| Core | [Shared ABAP services](ops-suite/src/core/) | Reuse operational run, finding and alert services. Add read-only tracing and handover where evidence and organizational authorization permit. |

The entry points are present in source. Treat each enhancement as pending until it is wired through its report or approved job variant, exercised by a representative QA case and documented in the [operations runbook](ops-suite/docs/Operations_Runbook.md). A standalone helper, seed row or planned feature does not satisfy delivery.

## Operating boundary

Existing source systems, SAP jobs, interfaces, and standard processing retain ownership of payment intake, bank-file transfer and processing, payment runs, posting, clearing, returns, reversals, and GL transfer. Observe those processes through approved, bounded reads. The suite may write to its own operational stores for observations, findings, run history, support dispositions, and alert tracking. A support acknowledgement or resolution must affect only the finding.

Exclude business-data updates, posting hooks or enforcement, new payment APIs or callbacks, changes to source-system contracts, automated business-job starts or reruns, lock removal, file movement or retransmission, reconciliation-key closure, GL transfer, and posting or clearing corrections. Recovery instructions may point an authorized operator to the existing runbook and transaction. Escalate any request requiring a business-process change for separate review.

## FMON — File and interface monitoring

- Inventory each in-scope interface with its direction, expected schedule, business date, calendar, time zone, cutoff, evidence source, and owner. Monitor both inbound and outbound flows through the existing handoffs and SAP jobs. Verify candidate evidence sources such as `ZCDT_REGUT`, `ZCD_CHECK_HIST`, `ZCD_ACH_ACK`, `ZCD_WIRE_ACK` and returns logs in the target client before relying on them.
- Track generation or receipt, delivery, processing, acknowledgement, and reconciliation as separate dimensions. Record the evidence source and time for each transition. SAP generation or archive presence establishes generation only. PRISM evidence establishes the milestone it explicitly confirms. Record manual B2B portal verification with the operator, timestamp, and evidence reference. Claim bank receipt only with evidence that confirms it.
- Match file generations by interface, direction, and stable generation identity. Distinguish reused references and preserve the full key. Compare counts and amounts where the interface contract supplies them. Match collection acknowledgements at file level and disbursement acknowledgements at payment level where applicable. Account for partial, repeated, late, and cumulated acknowledgements.
- Detect missing, late, failed, and partially processed files. Protect monitor state under overlapping runs and replay. Distinguish an incomplete read or unavailable source from a verified missing file. Track potential duplicates as findings for investigation.

## HCK — Daily health checks and diagnostics

- Monitor existing payment-file and clearing jobs, rejected items, check-print and acknowledgement queues, outbound interfaces, BlackLine delivery, bank-statement exceptions, SOST, and other controls in the approved checklist.
- Match the scheduled job by business date, program, variant, and relevant step. Distinguish attempts from the effective outcome. Detect stale running jobs independently of recent completions. Flag expected companies or interfaces with no observations, even when others are active.
- Present failed, late, incomplete, unknown, and passed checks distinctly. Require positive evidence for a pass. Show the source, last verified time, owner, and existing runbook reference. Isolate or bound slow checks so one check cannot prevent the morning report.
- Add read-only dump, queue, lock, or number-range diagnostics where they help resolve a documented support issue. Route findings through existing approved channels and escalation rules. Keep alert submission and confirmed delivery distinct and retain critical findings when a digest is capped.

## EBS — Shadow validation and reconciliation

- Validate supported BAI2, CAMT.053 and CAMT.054 inputs or existing SAP statement data in an observational run. Report malformed or incomplete input, balance and control-total discrepancies, unmapped bank codes, suspected duplicates, and ambiguous payment, check, or lot matches. Record what was evaluated and which evidence was unavailable.
- Compare bank statement totals with existing FI-CA activity and applicable GL clearing and transfer evidence by company code, bank account, currency, and business cutoff. Separate timing differences, genuine breaks, and items awaiting evidence. Support drilldown to the statement, document, lot, or reconciliation key where the evidence permits.
- Confirm expected outcomes for returns, retrievals, NOC, sweeps, and check encashment with the process owner. Treat discrepancies as operational findings. Observe posting outcomes independently of SAP's posting execution.

## Shared support controls

- Provide read-only transaction and file trace where reliable keys exist. Accept source and financial transaction ID, SAP document, check or trace number, or file reference as search inputs as applicable. Surface multiple matches and evidence gaps explicitly.
- Keep queries bounded and use approved tables, fields, and access paths. Enforce organizational access for scheduled and interactive users. Mask sensitive values in reports and alerts. Version operational configuration, preserve an audit trail, and retain evidence under the approved retention policy.
- Keep findings actionable. Include severity, business impact, affected scope, supporting references, owner, and the next step in the existing runbook. Support shift handover with unresolved critical findings and their latest verified status.

## Read-only payment and reconciliation controls

- **360° payment trace.** Follow the existing source request through SAP intake and posting, payment run or check issuance, file generation, PRISM handoff, bank acknowledgement, settlement, encashment or return, FI-CA clearing, and G/L reconciliation. Show source record, timestamp and evidence status at each stage. Support partial, split, reversed and reissued payments and surface ambiguous links. Read from existing integrations and approved SAP sources only.
- **Outbound payment reconciliation.** Compare existing payment requests and payment runs with ACH or wire references, check register entries, acknowledgements and bank statement items. Verify authoritative keys and sources in the target system before using `PAYRQ`, `PAYR`, or FS-CD registers. Flag potential duplicate clearing, unmatched encashments and wire fee differences as findings.
- **Three-way cash reconciliation.** Show separate checks for statement integrity, bank movement versus G/L transit, and G/L transit versus FI-CA payments, open items or clarification. Use the applicable company code, bank account, currency, cutoff and reconciliation key. Show matched amounts, timing differences, unexplained variances and missing evidence. Display the observed posting and clarification disposition.
- **Operational controls.** Report unclosed reconciliation keys with a configurable initial 24-hour threshold, subject to Finance approval and cutoff rules. Flag stranded `ZCD_OPS_RUN` records and retain their evidence for triage. Mask sensitive banking and personal data in logs, views and alerts. Record operational configuration changes with actor, time and before/after values using an approved audit mechanism. Verify control evidence before making any compliance claim.
- **Execution boundary.** These controls observe, correlate and report. Posting, reversing, clearing, routing items into clarification, changing job or business state, deleting or resetting stranded runs, and modifying interfaces, message contracts or integration routing are outside scope. Existing approved operational stores may hold findings and audit evidence. Use native CDS and support views where appropriate. Read existing queue and mass-activity status through approved access paths.

## Incident triage capabilities

New production support functionality is encouraged when it improves investigation using existing evidence. The normal triage path is search → correlate → inspect → hand off. Build it into the existing reports or a shared support view.

- **Search and correlate.** Accept an incident's available identifier, such as a file reference, job and variant, source and financial transaction ID, SAP document, check or trace number, or reconciliation key. Show the matched business date, organizational scope and related identifiers. Present competing matches for review and preserve access checks on drilldowns.
- **Build an evidence timeline.** For each relevant stage show what was expected, what was observed, when it was last checked and where the evidence came from. Highlight the first missing or failed milestone and the affected population. Distinguish a confirmed failure from an unavailable source, stale evidence or an ambiguous match.
- **Guide investigation.** Show the likely failure category with the evidence behind it, the next diagnostic check, the responsible team and the existing runbook link. For a missing acknowledgement, distinguish SAP generation, PRISM receipt and bank acknowledgement. For a failed job, identify the affected interval, latest attempt and relevant log. For a reconciliation break, separate timing differences from unexplained amounts and show the underlying keys.
- **Prepare shift handover.** Provide a copyable, masked summary with business impact, evidence references, checks already performed, outstanding questions, owner and next action. Allow authorized support staff to record notes and dispositions in the suite's own findings. Keep refresh and notification actions scoped to the suite.

Accept each feature only after L1/L2 can reproduce the triage path on a representative incident and verify the evidence and access controls. Confirm that searching, refreshing, drilling down and handing off leave business data, job schedules, processing decisions and external interfaces unchanged. Operators carry out recovery under the existing runbook.

## Insurance production support roadmap

Add these capabilities through the existing reports and operational stores. Use existing evidence from policy, claims and reinsurance interfaces where it is available and approved. Treat missing cross-system evidence as unknown.

| Priority | Support capability | QA acceptance |
|---|---|---|
| P1 | **Failed batch interval and lock diagnostics (HCK).** Correlate job, variant, business date, interval, attempt, and available job log, dump, or enqueue evidence. Distinguish suspected contention from a confirmed failure cause. Point support to the existing recovery runbook. | A transient failure followed by a successful retry shows the effective outcome. A failed interval with incomplete evidence remains visible with the evidence gap. |
| P1 | **Runtime anomaly alerts (HCK).** Compare active jobs with completed runs for comparable variants and business cycles. Use a configured deadline when history is sparse and include throughput only when measured. | A stalled job breaches its configured threshold. Sparse history and month-end patterns do not generate a misleading baseline verdict. |
| P1 | **In-flight premium before dunning cutoff (EBS/HCK).** Flag accounts with a pending notice and an apparent payment in an existing statement or lot. Show the observation time, cutoff, matching evidence, and confidence for Collections review. | Pending, posted, reversed, and ambiguous payments are distinguished. The alert leaves dunning and policy status untouched. |
| P1 | **Reconciliation-key and GL transfer readiness (HCK).** Identify open keys, incomplete activity, missing or partial transfers, and unexplained differences at the applicable company, currency, and cutoff. | A partial transfer cannot pass the control. Support can trace the difference to the available activity, key, and GL evidence. |
| P2 | **Remittance and broker variance triage (EBS).** Present authorized candidate matches for clarification and explain the matching fields. Report broker settlement differences against approved references. Add coinsurance settlement discrepancy reporting only where an existing process and usable evidence are confirmed. | Similar names, identical amounts, and competing references remain review candidates. Findings explain variances without clearing, writing off, or creating payment requests. |
| P2 | **Claims disbursement exceptions (FMON/HCK).** Report outstanding check aging using approved thresholds. Surface existing wire-screening or payment-control exceptions to the designated owner through approved channels. | Paid, voided, reissued, outstanding, and unknown checks are distinguished. Alerts reflect recorded screening outcomes and preserve restricted access. |
| P2 | **Read-only payment trace and handover (Core).** Link approved policy, check, or trace references to existing SAP documents, clarification, file and acknowledgement evidence. | An analyst can follow one collection and one claims payment end to end, with ambiguous matches and evidence gaps shown explicitly. |

Automated matching or clearing, dunning deferral, batch replay, lock release, FIKEY closure or GL transfer, check stops, statutory reporting, and payment screening or blocking require separate process ownership and approval. Measure current triage time, manual touches, missed alerts, and false positives during the pilot. Set improvement targets from that baseline.

## Delivery and acceptance

Deliver in this order: establish the evidence inventory, pilot FMON, harden HCK, verify EBS in shadow mode, then extend tracing and shift handover. Start with one collections interface and one disbursement interface in QA. Compare against existing support reports, PRISM evidence, SAP jobs, and reconciliation records before operational reliance. Validate activation, authorizations, job variants, and peak-volume performance in the target SAP client.

Exercise missing, partial, duplicate, and late acknowledgements, overlapping monitor runs, reused references, missing company-level data, a stalled job after a recent success, source and alert failures, and holiday cutoffs. Demonstrate that incomplete evidence cannot produce a false pass. Verify that running the suite changes only authorized operational records and alert state, with no change to financial documents, business statuses, source interfaces, or processing jobs.

For each proposed change, identify the production support problem, evidence source and matching keys, expected output, failure behavior, support owner, and acceptance checks. Prioritize work that reduces missed incidents or shortens triage.
