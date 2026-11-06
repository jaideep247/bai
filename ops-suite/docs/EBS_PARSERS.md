# EBS bank file parsers (BAI2, camt.053/054)

`ZCL_CD_EBS_PARSER_BAI2` and `ZCL_CD_EBS_PARSER_CAMT` implement `ZIF_CD_EBS_PARSER` and fill the format-neutral model `ZIF_CD_EBS_TYPES` (`ty_file` → `ty_statement` / `ty_line` / `ty_balance` / findings). They are pure: no database access, no `SY-DATUM`, and no engine-derived fields (flow_type, category, rule_group, exp_cdi, pay_method, map_posting and blocked stay initial).

Both parsers follow the same conventions:
- **Statement keys:** `S0001`, `S0002` … in file order. `source = 'FILE'`. Lines are numbered 1..n within each statement and carry `stmt_key`.
- **Amounts and balances:** `line-amount` is always positive and the direction is in `cdi` (C/D). Balances, `opening_bal` and `closing_bal` are signed (credit positive, debit negative).
- **Declared count:** `declared_count = -1` when the file declares no entry count.
- **Empty content** is not an exception. It returns finding `S11 EMPTY_FILE` with severity B. A readable file that has no statement gives the same finding.

Samples (fictitious data, internally consistent) are in `config/samples/`. The tests use the same structures inline.

## Messages (class ZCD_OPS, EBS range)

| No. | Text | Raised when |
|---|---|---|
| 150 | `Content is not a BAI2 file: first record &1 (expected type 01)` | first non-blank record is not `01` |
| 151 | `XML content could not be parsed: &1` | sXML raises `CX_SXML_ERROR` (malformed XML) |
| 152 | `Unsupported XML message &1/&2; expected camt.053 or camt.054` | root is not `Document`, its first child is not `BkToCstmrStmt` / `BkToCstmrDbtCdtNtfctn`, or the document has no child |

## BAI2 → model

| BAI2 | Model |
|---|---|
| 01 sender / receiver / creation date YYMMDD / time HHMM / file id | `sender_id`, `receiver_id`, `created_date`, `created_time`, `file_id` (date century 20; time 2400/9999 → 23:59:59) |
| 99 file control total | `control_total`; `record_count` = physical non-blank records |
| 02 originator id / as-of date / currency | `bank_id`, `stmt_date`, the line `booking_date` and the default currency |
| 03 account number / currency | one statement each: `account_no`, `currency` (falls back to the 02 currency), `stmt_id` = `<file id>-<group no>-<account>`, `stmt_no` = file id |
| 03 010 / 015 / 040 / 045 | `balances` OPBD / CLBD / OPAV / CLAV (signed), `opening_bal` / `closing_bal` |
| 03 other 0xx status codes | `balances` with `bal_type` = BAI2 code; other summary codes are ignored |
| 03 100 / 400 amount + item count | `total_credits` / `credit_count`, `total_debits` / `debit_count`, `has_totals`; `declared_count` = sum when both counts are given |
| 16 type code | `scheme` BAI2, `btc_code`; `cdi` C for 100–399, D for 400–699; 7xx–9xx produce no line, only an I finding |
| 16 amount | `amount` (2 implied decimals) |
| 16 funds type | blank/Z/0/1/2: no extras; V: value date + time → `value_date`; S: 3 amounts; D: n + n×(days, amount) |
| 16 bank ref / customer ref | `bank_ref`, `cust_ref`; `reference` = cust ref, else bank ref |
| 16 customer ref for 475 / 255 / 555 when numeric | `check_no` |
| 16 text (remainder, may contain commas, 88 continuation joined by a blank) | `addtl_info` (≤ 255) |
| `value_date` without V / `booking_date` | 02 as-of date |

## CAMT element path → model

The parser matches local names only, so it accepts any namespace or version. Paths below are relative to `Document/<message>/`.

| Path | Model |
|---|---|
| `GrpHdr/MsgId`, `GrpHdr/CreDtTm` | `file_id`, `created_date` / `created_time` (time zone suffix ignored) |
| `GrpHdr/MsgRcpt/Id/**` (first leaf), else `MsgRcpt/Nm` | `receiver_id` |
| `GrpHdr/CtrlSum` | `control_total` (stored, not validated) |
| `Stmt|Ntfctn/Id`, `ElctrncSeqNb`, `LglSeqNb` | `stmt_id`, `stmt_no`, `legal_seq_no` |
| `…/CreDtTm`; `…/FrToDt/ToDtTm` | `created_date` / `created_time`; `stmt_date` = date part of ToDtTm, else the CreDtTm date |
| `…/Acct/Id/IBAN` or `Acct/Id/Othr/Id`; `Acct/Ccy` | `account_no`; `currency` (falls back to the first balance's currency, then the first line's) |
| `…/Acct/Svcr/FinInstnId/BICFI` or `BIC`, else `Othr/Id` | `bank_id` |
| `Bal/Tp/CdOrPrtry/Cd` (or `Prtry`), `Amt@Ccy`, `CdtDbtInd`, `Dt/Dt` or `Dt/DtTm` | `balances` (DBIT → negative); `opening_bal` from OPBD, else PRCD; `closing_bal` from CLBD |
| `TxsSummry/TtlNtries/NbOfNtries` | `declared_count` (else TtlCdt + TtlDbt counts when both are given, else -1) |
| `TxsSummry/TtlCdtNtries/NbOfNtries + Sum`, `TtlDbtNtries/…` | `credit_count` / `total_credits`, `debit_count` / `total_debits`, `has_totals` |
| `Ntry/Amt@Ccy`, `CdtDbtInd`, `RvslInd`, `BookgDt`, `ValDt` | `amount`, `currency`, `cdi`, `reversal`, `booking_date`, `value_date` |
| `Ntry/AcctSvcrRef` (overridden by `TxDtls/Refs/AcctSvcrRef`) | `bank_ref` |
| `BkTxCd/Domn/Cd`, `Fmly/Cd`, `Fmly/SubFmlyCd` | `scheme` ISO, `domain`, `family`, `subfamily`, `btc_code` = `DOMN-FMLY-SUBF` |
| `BkTxCd/Prtry/Cd`, `Prtry/Issr` | `prtry_code`, `prtry_issuer`; when there is no Domn: `scheme` PRTRY and `btc_code` = Prtry/Cd |
| `TxDtls/BkTxCd` | overrides the entry-level code for that line |
| `TxDtls/Refs/EndToEndId` (`NOTPROVIDED` ignored), `InstrId`, `ChqNb`, `MsgId` | `end_to_end_id`, `instr_id`, `check_no`, `cust_ref` |
| `TxDtls/RtrInf/Rsn/Cd` | `return_reason` |
| `TxDtls/AddtlTxInf`, else `Ntry/AddtlNtryInf` | `addtl_info` |
| reference | `check_no` → `end_to_end_id` → `instr_id` → `bank_ref` |

**Lines per entry.** An `Ntry` with two or more `TxDtls` gives one line per TxDtls when every TxDtls has an amount (`TxDtls/Amt`, else `AmtDtls/TxAmt/Amt`). Otherwise the entry gives one line with the entry amount and the references of the first TxDtls.

**Counts.** `record_count` and the count checks use the number of `Ntry` elements, not TxDtls.

## Findings

| Rule | Check code | Severity | Object |
|---|---|---|---|
| S06 | `BAI2_ACCT_CTRL_TOTAL` (49 vs Σ 03 + 16 amounts), `BAI2_GROUP_CTRL_TOTAL` (98 vs Σ 49), `BAI2_FILE_CTRL_TOTAL` (99 vs Σ 98), `BAI2_CDT_SUM_MISMATCH` / `BAI2_DBT_SUM_MISMATCH` (100/400 vs Σ 16) | B | STMT / FILE |
| S06 | `CAMT_SUM_MISMATCH` (TtlNtries/Sum vs Σ \|entries\|), `CAMT_NET_MISMATCH` (TtlNetNtry, signed), `CAMT_CDT_SUM_MISMATCH`, `CAMT_DBT_SUM_MISMATCH` | B | STMT |
| S11 | `EMPTY_FILE` (no content or no statement) | B | FILE |
| S11 | `NO_ENTRIES` (statement without 16 / Ntry) | W | STMT |
| S12 | `BAI2_RECORD_COUNT` (49/98/99), `BAI2_ACCOUNT_COUNT` (98), `BAI2_GROUP_COUNT` (99), `BAI2_ITEM_COUNT` (100/400 item count vs 16 records) | E | STMT / FILE |
| S12 | `CAMT_ENTRY_COUNT`, `CAMT_CDT_ENTRY_COUNT`, `CAMT_DBT_ENTRY_COUNT` | E | STMT |
| S00 | `MISSING_TRAILER`, `UNEXPECTED_RECORD_ORDER`, `UNKNOWN_RECORD`, `INVALID_AMOUNT`, `INVALID_DATE`, `INVALID_TYPE_CODE` | E | STMT / FILE |
| S00 | `INFO_CODE_SKIPPED` (BAI2 7xx–9xx detail) | I | STMT |

For an S06 finding, `amount` = found − expected, and `currency` is the statement or group currency. Messages always state the expected and the found value.

Each BAI2 trailer checks its direct children. For example, 98 is compared with the sum of the **declared** 49 totals, and the computed total is used only when a 49 is missing. A wrong 49 therefore raises both the account finding and the group finding.

## Known limits

- **BAI2 amounts and dates.** BAI2 amounts always use 2 implied decimals, even for 0-decimal currencies such as JPY. Two-digit years are read as 20YY.
- **BAI2 record layout.** One record per physical line is assumed. Fixed-block files without line breaks are not supported. A 03 record that is cut short by `/` in the middle of a summary group before an 88 continuation is not re-aligned.
- **BAI2 16 text.** A trailing `/` at the end of the 16 text is treated as a terminator and removed.
- **BAI2 control totals.** The control total sums only the main amount fields. Funds-type distribution amounts (S/D) are excluded.
- **CAMT file attributes.** `sender_id` stays initial because camt has no sender in GrpHdr. The `encoding` named in the XML declaration is ignored, because the string is converted to UTF-8 before parsing. Time zone offsets are not applied.
- **CAMT checks not made.** `GrpHdr/CtrlSum` and the sum of the TxDtls amounts against the entry amount are not validated. Entries with Sts other than BOOK are parsed like booked entries.
- **Not verified on a system.** The parsers are verified with abaplint and an offline re-implementation only. They have not been activated in SAP and ABAP Unit has not been run. The sXML classes are not in the abaplint stubs, so their signatures are not type-checked.
