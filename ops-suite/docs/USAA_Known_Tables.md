# Known landscape tables — what the suite uses (source: USAA payment engine reference)

> **First principle:** only confirmed names go into configuration; anything else is marked and fails loudly at runtime (DDIC validation), never silently.
> **Analogy:** a map with surveyed roads drawn solid and rumoured tracks dotted — you plan the route on the solid lines.

Facts below were confirmed in production work in 2026 (payment engine reference). Where a money-moving decision rests on one, re-check it in SE11 / SE16 in QA1 and record what was checked.

## 1. Confirmed tables, fields and joins

| Table | Confirmed fields / rule | Join |
|---|---|---|
| `ZCD_PAYM_REQ_LOG` (payment requests from PRISM, API) | `ZZ_STATUS` — **take the row with `SUCCESS`, never the highest `COUNTER`** (a failed attempt can be written after the success); `COUNTER`; FIN number; `ZZ_MEMBER_NO`; `SOURCE` | FIN number = `DFKKOP-ZZ_FIN_TRANS_NUM`; `ZZ_MEMBER_NO` = `BUT000-BPEXT`, read **with** `SOURCE` first, then without (legacy PCLM partners pre-date SOURCE) |
| `ZCD_SPE_EXCP_LOG` (SPE) | Status-update table the hourly payment-status job sends from | **Every failure needs an SPE row**, otherwise the job never reports it to the source |
| `ZCD_CHECK_HIST` (IRIS cheque status via PRISM) | Status domain `ZECT_STATUS`: terminal **3 failed, 4 rejected, 9 returned**; mailed **10 → 9** allowed; otherwise a higher status may overwrite a lower one, **never the reverse**. PRISM translates IRIS "confirmed" to mailed | — |
| `DPAYH` | `ZZ_PAYMENT_STATUS` (live payment status); `LAUFD` + `LAUFI` give the cumulation group where `DOC1R` is not initial | `DFKKCR-DOC1R = DFKKOP-AUGBL` |
| `DFKKOP` | `ZZ_FIN_TRANS_NUM`; `ZZ_BILLPLANID` directly on DFKKOP (no DFKKNRK join) | — |
| `DFKKNRK` / `DFKKNRP` (NOC lots) | `DFKKNRP` keys `MANDT`, `KEYN1` (lot), `POSNA` (item); `INFOF` CHAR 50. Not an AML source | — |
| `DFKKRP` / `DFKKRAPT` | Exist (returns / clearing) | `DFKKRP-SELW1 = DFKKOP-AUGBL` |
| `FEBEP` | `BUDAT` always populated; `XBLNR` never blank for BAI 452 | `FEBEP-CHECT = BSEG-XREF2 = DFKKOP-AUGBL` (methods E G H I J K L); `DFKKCR-ZTNUM = FEBEP-CHECT` (method C) |
| `DFKKSUMC` / `DFKKKO` / `BSEG` | — | `DFKKSUMC-FIKEY = DFKKKO-FIKEY = BSEG-AWKEY` |
| `TFK042Z` | `XEINZ` separates collections from disbursements | — |
| `TFK033D` | Wildcard `*` does **not** work — enumerate | — |
| `TVARVC` | Refuses two type-P rows with the same name | — |
| `EFKKCLEGPI` | FPY1 locks per partner **interval** (GPART_V..GPART_B, one RUNKEY + BUKRS, `_SCOPE 3`) | — |
| **Do not exist** | `DFKKRNIT`, `DFKKRAFT` — never configure | — |

Field names **not** in the reference (still `VERIFY-SE11`): the FIN-number and timestamp fields of `ZCD_PAYM_REQ_LOG`, every field of `ZCD_SPE_EXCP_LOG` and `ZCD_CHECK_HIST` other than the status domain, the ACK tables (`ZCD_ACH_ACK`, `ZCD_WIRE_ACK`), `ZCDT_REGUT`, `ZCD_STRP_POUT_LOG`, `ZCD_ACH_RTRV_LOG` status field (three candidate names, parity C4).

## 2. How the suite uses them (phase 3 of the RAP build) — **built 2026-11-06**

| Use | Module | Known facts applied | Still to confirm |
|---|---|---|---|
| PRISM payment-request monitoring (API interface `PAYREQ_PRISM_IN`) | FMON (generic adapter, configuration) | Status field `ZZ_STATUS`, processed = `SUCCESS`; a later failed row must not downgrade a request that has a SUCCESS row; partition by `SOURCE` | Request reference / FIN-number and timestamp field names |
| Payment request failed **without an SPE row** | HCK check (new check class) | Every failure needs a `ZCD_SPE_EXCP_LOG` row | SPE key field linking to the request |
| Cheque status went **backwards** (illegal transition) | HCK check (new check class) | `ZECT_STATUS` ordering, terminal 3 / 4 / 9, 10 → 9 allowed | `ZCD_CHECK_HIST` key and sequence fields |
| Paid payment request left **CANCELLED** (PCLM) | HCK check (new check class) | CANCELLED = money will not leave; a paid request must never be CANCELLED | Paid indicator (via FIN number → DFKKOP / DPAYH) |
| Handled-manually record for payment requests | FMON operations app (§6.5 of `RAP_Apps_Design.md`) | Request reference as delivered by PRISM | — |
| EBS: BAI 143 / 452 | EBS | Known unmapped codes in production | Treasury: category and posting rule before a `ZCD_BTC_MAP` row is added; until then **R14 blocks them** (never posted to the wrong clearing account) |
| EBS: BAI 452 has a non-blank XBLNR | EBS (rule R-level check once mapped) | `XBLNR` never blank for 452 | — |

Every field name above that is not confirmed goes into configuration (not code) and is validated against the DDIC at runtime, so a wrong name produces a PLUGIN_ERROR / configuration finding instead of a wrong result.
