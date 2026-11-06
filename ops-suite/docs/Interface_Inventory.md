# Interface inventory — file and API transmissions to and from SAP

> **First principle:** a transmission is monitored only when it has an interface row, an SAP evidence source for each stage, and an owner; anything else is invisible, and invisible is not the same as healthy.
> **Analogy:** a post room logbook — a parcel that never got a line in the book can go missing without anyone noticing it is gone.

Status 2026-11-06. Sources: `config/fmon_seed.md` (example rows), the payment engine reference (landscape facts) and `MASTER_PROMPT_FSCD_OPERATIONS_SUITE.md` (FMON section). **No row below has been confirmed against PS4.** The master prompt puts this inventory first in the delivery order.

## 1. Coverage

Legend: **Seeded** = example row in `fmon_seed.md` (pattern, owner and SE11 fields still to confirm) · **Partial** = seeded for one bank or one stage only · **Gap** = no interface row; FMON cannot see it · **Out of FMON** = not a file; evidence lives elsewhere.

### Outbound (SAP → PRISM / bank / other)

| Flow | Evidence source today | Coverage | Gap to close |
|---|---|---|---|
| ACH disbursements (NACHA) | `ZCDT_REGUT` (generated), `ZCD_ACH_ACK` (per payment) | **Partial** — PNC only (`ACH_PNC_DISB_OUT`) | Rows for every bank/cycle that receives ACH (PUB, BOA, JPMC if used); file pattern; ACK status values |
| ACH collections (debits) | `ZCDT_REGUT`, `ZCD_ACH_ACK` (per file) | **Partial** — PNC only (`ACH_COLL_OUT`) | As above |
| Wires | `ZCD_WIRE_ACK` | **Partial** — JPMC only (`WIRE_JPMC_OUT`) | Other wire banks; ACK value domain |
| Positive pay | `ZCD_CHECK_HIST` (status) | **Partial** — one row, bank `‹bank›` (`CHECK_POSPAY_OUT`) | One row per bank (JPMC, BOA, PNC); ACK expected? |
| Stop pay | — | **Gap** | Interface row, evidence table, ACK |
| Cheque print file → IRIS (via PRISM) | `ZCDT_REGUT`? | **Gap** | Interface row and its own SLA, separate from positive pay |
| Payment status updates → sources (hourly, from `ZCD_SPE_EXCP_LOG`) | `ZCD_SPE_EXCP_LOG` | **Gap** | Decide file vs API; failures without an SPE row are already an HCK check |
| BlackLine extracts (collections, disbursements) | job output only | **Partial** — one row (`BLACKLINE_OUT`), no ACK by design | Two rows (`ZCD_FI_BLACKLINE_EXTRACT_COLL`, `ZCD_BLACKLINE_RECON`), expected on the 2nd business day |
| G/L OFSAA file | — | **Gap** (no ACK by design) | Interface row, generation evidence |
| Cost centre file | — | **Gap** (no ACK by design) | Interface row, generation evidence |
| Kestrel / HAL out-of-band reconciliation | — | **Gap** | Confirm direction and evidence |
| AML screening (Bridger) | SLG1 | **Out of FMON** (API) | HCK check on SLG1 if required |

### Inbound (bank / PRISM / other → SAP)

| Flow | Evidence source today | Coverage | Gap to close |
|---|---|---|---|
| Payment requests from PRISM (API) | `ZCD_PAYM_REQ_LOG` | **Seeded** (`PAYREQ_PRISM_IN`) | Request key and timestamp fields (SE11) |
| BAI2 statements | FEB tables after import | **Partial** — JPMC, BOA (`BAI_JPMC_IN`, `BAI_BOA_IN`) | PNC statement; holiday calendar |
| CAMT.053 / CAMT.054 | FEB tables | **Gap** in FMON (EBS can validate them) | Interface rows if any bank sends CAMT |
| ACH returns | `ZCD_ACH_RTRV_LOG`, returns lots (DFKKRP) | **Partial** — PNC only (`ACH_RET_PNC_IN`) | Other banks; returns lot header table (SE11) |
| NOC | DFKKNRK / DFKKNRP | **Partial** — PNC only (`NOC_PNC_IN`) | Other banks; item status field (SE11) |
| ACH / wire acknowledgements | `ZCD_ACH_ACK`, `ZCD_WIRE_ACK` | Modelled as the response stage of the outbound file | Status values (SE11) |
| Positive pay / stop pay acknowledgements | — | **Gap** | Confirm whether the banks send them |
| Cheque status from IRIS (via PRISM) | `ZCD_CHECK_HIST` | Only as the response of positive pay | Own inbound row with SLA (status may only move forward; 10 → 9 allowed) |
| Bank paid-items / encashment, positive pay exceptions | — | **Gap** | Confirm whether these come as files or only as BAI codes on the statement |
| Stripe payouts | `ZCD_STRP_POUT_LOG` | **Seeded** (`STRIPE_PAYOUT_IN`) | Fields (SE11) |
| DRM file (decrypt / split chain) | — | **Gap** | Content, direction, owner |
| Source-system files (ORCI, ALPA, ALPL, HAL, BASE, DIS, Collections, Life & Annuity, Single Bill Payment) | — | **Gap** | Confirm which sources send files rather than API calls |

## 2. Structural limits (true even for seeded rows)

1. **FMON reads SAP evidence tables, not the transport.** A file that lands in an inbound directory but is never loaded leaves no table row, so FMON cannot see it. `UNMAPPED_FILE` only catches rows in configured source tables that match no interface.
2. **Operating-system steps are not observed.** Encrypt, decrypt, archive and transfer run through `ZICD_CALL_SM69_COMMAND_NEW`. HCK can see that the job ran; nothing confirms that the file moved.
3. **Generation is not delivery.** `ZCDT_REGUT` proves that SAP generated the file. Only PRISM or bank evidence proves the next milestone (master prompt FMON §2).
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
