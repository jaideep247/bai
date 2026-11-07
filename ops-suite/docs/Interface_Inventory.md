# Interface inventory — file and API transmissions to and from SAP

> **First principle:** a transmission is monitored only when it has an interface row, an SAP evidence source for each stage, and an owner; anything else is invisible, and invisible is not the same as healthy.
> **Analogy:** a post room logbook — a parcel that never got a line in the book can go missing without anyone noticing it is gone.

Status 2026-11-06. Sources: `config/fmon_seed.md` (example rows), the payment engine reference (landscape facts) and `REQUIREMENTS_FSCD_OPERATIONS_SUITE.md` (FMON section). **No row below has been confirmed against PS4.** The requirements baseline puts this inventory first in the delivery order.

## 1. Coverage

Legend: **Seeded** = example row in `fmon_seed.md` (pattern, owner and SE11 fields still to confirm) · **Partial** = seeded for one bank or one stage only · **Gap** = no interface row; FMON cannot see it · **Out of FMON** = not a file; evidence lives elsewhere.

### Outbound (SAP → PRISM / bank / other)

| Flow | Evidence source today | PRISM evidence | Coverage | Gap to close |
|---|---|---|---|---|
| ACH disbursements (NACHA) | `ZCDT_REGUT` (generated), `ZCD_ACH_ACK` (per payment) | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to bank, failed | **Partial** — PNC only (`ACH_PNC_DISB_OUT`) | Rows for every bank/cycle that receives ACH (PUB, BOA, JPMC if used); file pattern; ACK status values |
| ACH collections (debits) | `ZCDT_REGUT`, `ZCD_ACH_ACK` (per file) | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to bank, failed | **Partial** — PNC only (`ACH_COLL_OUT`) | As above |
| Wires | `ZCD_WIRE_ACK` | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to bank, failed | **Partial** — JPMC only (`WIRE_JPMC_OUT`) | Other wire banks; ACK value domain |
| Positive pay | `ZCD_CHECK_HIST` (status) | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to bank, failed | **Partial** — one row, bank `‹bank›` (`CHECK_POSPAY_OUT`) | One row per bank (JPMC, BOA, PNC); ACK expected? |
| Stop pay | — | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to bank, failed | **Gap** | Interface row, evidence table, ACK |
| Cheque print file → IRIS (via PRISM) | `ZCDT_REGUT`? | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to IRIS, failed | **Gap** | Interface row and its own SLA, separate from positive pay |
| Payment status updates → sources (hourly, from `ZCD_SPE_EXCP_LOG`) | `ZCD_SPE_EXCP_LOG` | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to source, failed | **Gap** | Decide file vs API; failures without an SPE row are already an HCK check |
| BlackLine extracts (collections, disbursements) | job output only | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to BlackLine, failed | **Partial** — one row (`BLACKLINE_OUT`), no ACK by design | Two rows (`ZCD_FI_BLACKLINE_EXTRACT_COLL`, `ZCD_BLACKLINE_RECON`), expected on the 2nd business day |
| G/L OFSAA file | — | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to OFSAA, failed | **Gap** (no ACK by design) | Interface row, generation evidence |
| Cost centre file | — | PRISM status API (built, switched off until CAB approval) — received from SAP, delivered to target, failed | **Gap** (no ACK by design) | Interface row, generation evidence |
| Kestrel / HAL out-of-band reconciliation | — | PRISM status API (built, switched off until CAB approval) — received, delivered, failed | **Gap** | Confirm direction and evidence |
| AML screening (Bridger) | SLG1 | PRISM status API (built, switched off until CAB approval) — request received from SAP, screening response delivered to SAP, failed | **Out of FMON** (API) | HCK check on SLG1 if required |

### Inbound (bank / PRISM / other → SAP)

| Flow | Evidence source today | PRISM evidence | Coverage | Gap to close |
|---|---|---|---|---|
| Payment requests from PRISM (API) | `ZCD_PAYM_REQ_LOG` | PRISM is the sender: the API call itself (logged in `ZCD_PAYM_REQ_LOG`) is the evidence | **Seeded** (`PAYREQ_PRISM_IN`) | Request key and timestamp fields (SE11) |
| BAI2 statements | FEB tables after import — since 2026-11-07 read by the FEB adapter (`ZCL_CD_FMON_ADAPTER_FEB`, EBS statement evidence): received / imported (FEBKO per payment engine account) / fully processed (every in-scope FEBEP line posted); deadline "processed by 10:00" (`ZCD_FMON_DEADL`) | PRISM status API (built, switched off until CAB approval) — received from bank, delivered to SAP, failed | **Partial** — JPMC, BOA (`BAI_JPMC_IN`, `BAI_BOA_IN`) with 10:00 deadline | PNC statement; holiday calendar; VERIFY statement date = previous business day |
| CAMT.053 / CAMT.054 | FEB tables | PRISM status API (built, switched off until CAB approval) — received from bank, delivered to SAP, failed | **Gap** in FMON (EBS can validate them) | Interface rows if any bank sends CAMT |
| ACH returns | `ZCD_ACH_RTRV_LOG`, returns lots (DFKKRP) | PRISM status API (built, switched off until CAB approval) — received from bank, delivered to SAP, failed | **Partial** — PNC only (`ACH_RET_PNC_IN`) | Other banks; returns lot header table (SE11) |
| NOC | DFKKNRK / DFKKNRP | PRISM status API (built, switched off until CAB approval) — received from bank, delivered to SAP, failed | **Partial** — PNC only (`NOC_PNC_IN`) | Other banks; item status field (SE11) |
| ACH / wire acknowledgements | `ZCD_ACH_ACK`, `ZCD_WIRE_ACK` | Bank response relayed by PRISM (implicit); planned: PRISM status API — ACK received from bank, delivered to SAP | Modelled as the response stage of the outbound file | Status values (SE11) |
| Positive pay / stop pay acknowledgements | — | PRISM status API (built, switched off until CAB approval) (if the banks send them) | **Gap** | Confirm whether the banks send them |
| Cheque status from IRIS (via PRISM) | `ZCD_CHECK_HIST` | PRISM status API (built, switched off until CAB approval) — received from IRIS, delivered to SAP, failed | Only as the response of positive pay | Own inbound row with SLA (status may only move forward; 10 → 9 allowed) |
| Bank paid-items / encashment, positive pay exceptions | — | PRISM status API (built, switched off until CAB approval) (if sent as files) | **Gap** | Confirm whether these come as files or only as BAI codes on the statement |
| Stripe payouts | `ZCD_STRP_POUT_LOG` | PRISM status API (built, switched off until CAB approval) — received from Stripe, delivered to SAP, failed | **Seeded** (`STRIPE_PAYOUT_IN`) | Fields (SE11) |
| DRM file (decrypt / split chain) | — | PRISM status API (built, switched off until CAB approval) — received, delivered to SAP, failed | **Gap** | Content, direction, owner |
| Source-system files (ORCI, ALPA, ALPL, HAL, BASE, DIS, Collections, Life & Annuity, Single Bill Payment) | — | PRISM status API (built, switched off until CAB approval) — received from source, delivered to SAP, failed | **Gap** | Confirm which sources send files rather than API calls |

## 1a. PRISM evidence

**Every flow to and from SAP is routed through PRISM** (confirmed 2026-11-06), so every row above gets PRISM evidence once the API is live. Today no PRISM milestone reaches SAP: "sent to PRISM" is SAP's own record (`ZCDT_REGUT`) and "forwarded to bank" has no source.

**Built, switched off (2026-11-06): the PRISM status API** — `POST /sap/zcd_ops/prism_status`, plain REST JSON over HTTPS, one event per call (`docs/PRISM_Status_API.md`). PRISM calls it for every flow when it has received a file / message (`RECEIVED`), delivered it (`DELIVERED`) or given up (`FAILED`); SAP stores the call in `ZCD_FMON_PRISM` and applies it **at once** (bgPF unit, seconds) as the FMON stage `PRISM_RECEIVED` / `PRISM_DELIVERED` / `PRISM_FAILED` with PRISM's own timestamp; the 5-minute FMON job applies any event a unit could not (safety net). The API writes only to the suite's FMON store — no business data, no change to payment files, jobs or routing. `counterparty` accepts any system code (bank, IRIS, BLACKLINE, OFSAA, STRIPE, BRIDGER, source codes) and `fileReference` is the file name or, for API flows (Bridger screening, payment status updates, payment requests), the message / request reference the FMON interface is keyed by — as for `PAYREQ_PRISM_IN`. §8 of the API document lists, for every row above, the milestones, reference and interface PRISM uses; seed rows exist only for the seeded interfaces, the others are *to configure*.

**PRISM throttle (confirmed by the user 2026-11-06):** PRISM sends **ACH and wire** files to the bank one at a time, **2 minutes apart**; positive pay and stop pay files are not throttled (nor IRIS, BlackLine, OFSAA, cost centre or source files). **One queue per bank** (JPMC, BOA, PNC … each wait 2 minutes between their own files; files to different banks do not wait for each other — confirmed by the user 2026-11-06, scope `C`); the gap is **1–2 minutes per file** (parameter default 2) and is measured from the PRISM status API timestamps (PRISM_RECEIVED → PRISM_DELIVERED) after go-live, then `FMON_PRISM_THROTTLE_MIN` is tuned. When several ACH / wire files are handed over together (the evening ACH cycle), `DELIVERED` for the n-th file trails its `RECEIVED` by about 2 × (n − 1) minutes. FMON allows exactly that wait on the delivery SLA of a throttled file and reports a jammed queue as `PRISM_QUEUE_LONG` (`FMON_FILE_MONITORING.md` §A3a). Throttled = outbound interface whose `PAY_METHOD` is in `FMON_PRISM_THROTTLE_METHODS` (default `ACH,WIRE`): ACH disbursements, ACH collections and wires above; positive pay (`CHECK`) and stop pay are not. To confirm with the PRISM team: one queue for all banks or one per bank (`FMON_PRISM_THROTTLE_SCOPE`).

New callbacks are outside the read-only rollout (requirements baseline, operating boundary): the API ships as **its own approved change** — the ICF node is created inactive and switched on after CAB approval (`Implementation_Order.md`, switch S-PRISM). Until then, the manual-status app records a milestone an operator verified in the PRISM console or B2B portal (operator, time, evidence reference).

## 2. Structural limits (true even for seeded rows)

1. **FMON reads SAP evidence tables, not the transport.** A file that lands in an inbound directory but is never loaded leaves no table row, so FMON cannot see it. `UNMAPPED_FILE` only catches rows in configured source tables that match no interface.
2. **Operating-system steps are not observed.** Encrypt, decrypt, archive and transfer run through `ZICD_CALL_SM69_COMMAND_NEW`. HCK can see that the job ran; nothing confirms that the file moved.
3. **Generation is not delivery.** `ZCDT_REGUT` proves that SAP generated the file. Only PRISM or bank evidence proves the next milestone (requirements baseline FMON §2).
4. **The calendar defines "missing".** A flow without a `ZCD_FMON_CAL` row can be late or failed, but never *missing*.

## 3. How to close the inventory (read-only, no change to any interface)

| Step | Source | Output |
|---|---|---|
| 1 | Control-M export: every job whose SAP step is a file program, `RFKK_MA_SCHEDULER` with an output variant, or `ZICD_CALL_SM69_COMMAND_NEW` | Candidate list: job, program and variant, direction, entity |
| 2 | AL11 / logical file paths (FILE) used by those variants and SM69 commands | Directory and name pattern per flow |
| 3 | PRISM interface catalogue | Which milestones PRISM confirms per flow (receipt, forward, bank ACK) |
| 4 | SE11 on each evidence table | The `‹SE11›` fields in `fmon_seed.md` |
| 5 | One `ZCD_FMON_IFACE` + `ZCD_FMON_CAL` + `ZCD_FMON_SLA` row per flow, by transport | Monitored flow with an owner |

**Proposed, not built:** a read-only inbound directory check (directory listing against the expected pattern and window) that flags *file present, not loaded* and *file expected, not present*. It only lists directories: no file is moved, opened or deleted. It closes limit 1 and needs approval of the directory list and S_DATASET read authorisation for the batch user.
