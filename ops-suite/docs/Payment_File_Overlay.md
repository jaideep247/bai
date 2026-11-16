# Payment file lifecycle - the ops suite's overlay

> **First principle:** the framework decides what a payment file must go through and what is missing; the suite only
> tells it where this landscape records each step - the file monitoring already does.
> **Analogy:** a universal parcel tracker plugged into one courier's own scanner feed: the tracker's rules stay the same,
> only the translation of the courier's scan codes is the courier's.

Build K, 2026-11-15. Framework module CASHOPS: `ops-framework/docs/PAYMENT_FILE_LIFECYCLE.md`. Nothing activated; every
overlay row delivered **inactive** (`config/payfile/`).

## 1. Setup 1 of the framework's two setups

| Role | Adapter | Source of truth |
|---|---|---|
| FILE | `ZCL_CD_PF_FMON_FILES` (new) | the outbound files FMON registered (`ZCD_FMON_FILE` through `ZIF_CD_FMON_DAO=>GET_EVAL_FILES`): native key = FMON file reference, business date, generation time; the payment run from the generation group (`ZCL_CD_FMON_ACK_ALERT=>RUN_KEY` with the source's `GROUP_FIELDS`, V182); the payments of the run and house bank from `DPAYH` (one grouped read); a regenerated file names the earlier generation of its group (FMON rule 9) |
| SCHED | framework `ZCL_CA_OPS_PF_SRC_TBTCO` | SAP jobs of the payment medium program (`PROGRAMS=`, framework V175) |
| TRANSFER (and receipt / acceptance) | `ZCL_CD_PF_FMON_EVENTS` (new; also an `ZIF_CA_OPS_PF_ACK_SRC`) | FMON's audit trail `ZCD_FMON_EVENT` through `GET_EVENTS`: one record per event, native status = FMON stage |
| TICKET | framework `ZCL_CA_OPS_PF_TICKET_LOG` | log only |

Both new classes read FMON through its data access - no SQL of their own on FMON's tables, no change to FMON. FMON keeps
its status model (§A2), PRISM throttle (§A3a) and stage deadlines (§A3b); the framework's milestones are configured from
them below.

## 2. Status mapping (`config/payfile/zca_ops_pfmap.csv`, source `CDFMON` / `CDSAPJOB`)

| FMON stage / job status | Milestone | Outcome | Note |
|---|---|---|---|
| `F` / `A` (SAP job) | `GENERATED` | OK / FAILED | payment medium job |
| `GENERATED_IN_SAP` | `GENERATED` | OK | |
| `SENT_TO_PRISM`, `PRISM_RECEIVED` | `PICKUP` | OK | the middleware hop |
| `FORWARDED_TO_BANK` | `DELIVERED` | OK | |
| `PRISM_FAILED` | `DELIVERED` | FAILED | regeneration follows (reissue: §4) |
| `PRISM_DELIVERED` | `RECEIPT` | OK | delivered to the bank's endpoint = transport receipt (V183) |
| `ACK_RECEIVED` / `NACK_REJECTED` | `ACCEPTED` | OK / REJECTED | the bank's ACK file is its acceptance (V183) - never the same milestone as the receipt |

## 3. File types and deadlines (`config/payfile/zca_ops_pftyp.csv`, `zca_ops_pfstg.csv`)

`CD_ACH` and `CD_WIRE` (area `CD_FMON`, time zone `CST` as `FMON_TIME_ZONE`, factory calendar and cut-off to fill):
generated 60 minutes after the payment run, delivered 60 minutes after generation, receipt 30 minutes after delivery,
**acceptance by 10:00 of the next business day** (the flagship: `PF_ACK_MISSING`), settlement - the BAI statement
processed by 10:00 two business days later - optional until a statement adapter exists (V186). The FMON SLA rows stay
in FMON; the two are configured side by side, not merged (D-K4).

## 4. What it gives the first customer

- The worklist `ZUI_CA_OPS_PAYFILE` shows each ACH / wire file with its payments (from DPAYH, masked payee), amount per
  currency, the stage reached, deadline, owner and every FMON event as evidence; the missing-ACK case of FMON §A3c in
  the framework's form.
- FMON's regenerated files become reissues: `PF_DUP_EXPOSURE` when the earlier file reached the bank, and a late ACK
  for the earlier file after the regeneration is `PF_ORIG_ACK_AFTER_REISSUE` - FMON's `FILE_REGENERATED_NOT_FAILED`
  stays in FMON.
- The send step of this landscape is one OS-command wrapper program (`ZICD_CALL_SM69_COMMAND_NEW`, user-confirmed);
  its variant decides encrypt or transfer and the variant names are not confirmed (V184). It is not wired: one scheduler
  source per file type (the payment medium job); once the variants are known its jobs can evidence `PICKUP` through a
  second file type role (decision D-K5).

## 5. Proof

- `tools/tests/test_payfile_overlay.py`: the framework's fixtures through this setup give the expected results,
  identical to the framework's example XX (no middleware); rows inactive; product vocabulary only; every adapter class
  implements its role; the overlay names only `ZIF_CA_OPS_PF_*`, `ZIF_CA_OPS_TYPES`, `ZCX_CA_OPS_ERROR`,
  `ZCL_CA_OPS_UTIL`, `ZCL_CA_OPS_EXC_CONTRACT` of the framework.
- ABAP Unit `ZCL_CD_PF_FMON_FILES`, `ZCL_CD_PF_FMON_EVENTS` (FMON data access doubled).
- No framework object was changed for this overlay.

## 6. VERIFY

| ID | Item |
|---|---|
| V182 | The generation group of the ACH / wire sources (`ZCD_FMON_SRC-GROUP_FIELDS` = LAUFD, LAUFI, HBKID, HKTID in this order) so that a file's payments are those of its run and house bank; a group shortened to a digest gives no payments (amounts unknown, counted) |
| V183 | Per bank: `PRISM_DELIVERED` is the bank endpoint's receipt and the ACK file (`ACK_RECEIVED`) its acceptance; a bank whose ACK is only a receipt maps `ACK_RECEIVED` to `RECEIPT` instead and has no acceptance milestone |
| V184 | Variants of `ZICD_CALL_SM69_COMMAND_NEW` (encrypt / transfer) and whether its job evidences the hand-off to PRISM |
| V185 | Overlay link objects `CD_BANK_ACK` / `CD_PAYMENT_TO_ACK` (V121 placeholder) as link objects of the ACK evidence rows |
| V186 | A statement source for `SETTLED` (the BAI statement lines carrying the file's reference) |
