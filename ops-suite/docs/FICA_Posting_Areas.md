# Customer posting areas ZRSN, ZPMC, ZBTM, ZBTR — setup in DV1 and FQC0 maintenance

> **First principle:** a mapping the FI-CA team already maintains every day belongs in the FI-CA tool they use every day; the suite only reads it and checks it every morning.
> **Analogy:** a shared address book — one team keeps the entries, everybody else looks names up; the morning check is the colleague who flags an entry with a missing phone number.

User decisions 2026-11-08: four mapping tables of the suite move to **FI-CA customer posting areas**, maintained by the FI-CA team in **FQC0**. Customer posting areas are allowed in this landscape, their names start with `Z`, and the generic value `*` works in FQC0 (confirmed by the user). The posting area names are delivered as `ZRSN`, `ZPMC`, `ZBTM`, `ZBTR` and are parameters (`POSTAREA_*`, area `CD_OPS`), so a posting area can be renamed without code.

| Posting area | Replaces | Read by | Purpose constant |
|---|---|---|---|
| `ZRSN` | `ZCD_EBS_RSN_MAP` | `ZCL_CD_EBS_CFG_DAO=>GET_REASON_MAP` / `GET_REASON` (EBS rule R05) | `GC_PURPOSE-REASON` |
| `ZPMC` | `ZCD_HCK_PMCLASS` | `ZCL_CD_HCK_RUNTIME_DAO=>GET_PM_CLASSES` (`A_INFLIGHT`, payment outcome) | `GC_PURPOSE-PM_CLASS` |
| `ZBTM` | `ZCD_BTC_MAP` | `ZCL_CD_EBS_CFG_DAO=>GET_BTC_MAP` (BTC resolver, R01, S09, statement evidence) | `GC_PURPOSE-BTC_MAP` |
| `ZBTR` | `ZCD_HCK_BTCROLE` | `ZCL_CD_HCK_RUNTIME_DAO=>GET_BTC_ROLES` (usage LIFECYCLE), `ZCL_CD_HCK_RECON_DAO=>GET_BTC_ROLES` (usage RECON) | `GC_PURPOSE-BTC_ROLE` |

The consumers are unchanged: each DAO method keeps its interface and returns the same rows, built from the posting area entries. One consumer changed on purpose: rule R05 asks `GET_REASON` for the entry that applies to one bank reason, so a `*` entry of ZRSN is honoured.

## 1. How the suite reads the entries

**One generic reader.** `ZIF_CD_OPS_POSTAREA` / `ZCL_CD_OPS_POSTAREA` (factory `ZCL_CD_OPS_POSTAREA_FACTORY=>GET_READER`, injector `ZCL_CD_OPS_POSTAREA_INJECTOR`, in-memory test double `ZCL_CD_OPS_POSTAREA_MEM`):

- `ENTRIES( purpose )` — every entry of the posting area, **one set-based read per posting area and run** (the factory keeps one reader per internal session = one batch run; the reader caches per purpose), ordered by the key values.
- `FIND( purpose, keys )` — the entry that applies to one key (FQC0 rule below).
- `AREA( purpose )` — the configured posting area name (parameter).

**Source: the stored entries (TFK033D), read-only.** `ZCL_CD_OPS_POSTAREA_DAO` selects `KEY01..KEY08`, `FUN01..FUN08` of `TFK033D` by `APPLK` (parameter `POSTAREA_APPLK`, delivered `V`), `BUBER` (the posting area) and `KTOPL` (parameter `POSTAREA_KTOPL`, delivered blank). Values are read into strings: nothing is truncated; the configuration check compares each value with the length its reader takes.

Why not the account determination API (`FKK_ACCOUNT_DETERMINE`): the suite needs **every** entry of an area — the set of mapped codes (R14 / S09 coverage), all roles of a scope, all payment methods of a class, and the configuration check — not one determination per key; one API call per statement line or payment would multiply calls in the batch runs, and the API's handling of a missing entry (message / exception per key) is not wanted in a read-only batch. The table is read only, in one place (`VERIFY-DDIC` marker in the DAO), and is already under drift control (`ZCD_OPS_TABWL` HCK / DRIFT row `TFK033D`, `config/hck_seed.md` §6).

**FQC0 precedence, as implemented (`ZCL_CD_OPS_POSTAREA=>FIND`).** A candidate entry matches when every key is equal to the value or `*`. Among the candidates the entry with an **exact value in the first key, counted from KEY01, where the candidates differ** wins. So an exact key beats `*`, and when several keys are generic the most specific entry *from the left* wins (the key order of the posting area is its priority order). Example (ZBTM, ISO `PMNT-ICDT-ARET` at bank JPMC): `ISO/PMNT/ICDT/ARET/*/*` beats `ISO/PMNT/ICDT/*/JPMC/*` — sub-family (KEY04) comes before bank (KEY05). This is the order the EBS resolver always used (exact code before the family row; bank row before the every-bank row; flow row before the `*` row), so the move keeps the behaviour. **VERIFY in DV1** (`Release_Readiness.md`): FI-CA may rank by the number of generic keys instead; the test in §5 decides. Only `RANK` of `ZCL_CD_OPS_POSTAREA` changes if it does.

Where a reader cannot apply `*` (a code list, a role list, a payment method list), `*` is refused by the configuration check (message 427) and ignored by the reader — see the layouts.

## 2. Layouts (keys and results)

Key and result fields in FQC0 column order. *Generic* = `*` allowed. *Length* = the characters the reader takes (from the reader's own types). **VERIFY-SE11:** TFK033D-`KEYnn` / `FUNnn` must hold at least these lengths (§4).

### ZRSN — bank return / NOC reason (was ZCD_EBS_RSN_MAP)

| Field | Kind | Length | Generic | Meaning |
|---|---|---|---|---|
| REASON | key 1 | 4 | yes (`*` = every other reason) | NACHA return reason R01–R85 / NOC code C01–C07 |
| FICA_REASON | result 1 | 3 | — | Payment engine return reason (returns lot, DFKKRP-RLGRD) |
| IS_NOC | result 2 | 1 | — | `X` = notification of change, blank = return |

Everything fitted.

### ZPMC — payment method classes (was ZCD_HCK_PMCLASS)

| Field | Kind | Length | Generic | Meaning |
|---|---|---|---|---|
| FLOW | key 1 | 1 | no | `D` disbursement / `C` collection (TFK042Z-XEINZ of the method) |
| PAY_METHOD | key 2 | 1 | no | SAP payment method — **one entry per payment method** (was the comma list PAY_METHODS) |
| HOUSE_BANK | key 3 | 5 | yes | `*` = the class of the payment method (every house bank); a house bank (DPAYH-HBKID) = only the factory calendar of that bank |
| METHOD_CLASS | result 1 | 3 | — | Open list (WIR, ACH, CHQ, CRD, ACI …); flow + class = the 4-character threshold key |
| AGE_BASIS | result 2 | 10 | — | `*` entries: VALUE_DATE / ISSUE_DATE; house-bank entries: blank |
| CALENDAR | result 3 | 2 | — | Factory calendar; `*` entry blank = PARAM1 of `A_INFLIGHT`; house-bank entry: required |

House-bank override (unchanged semantics): an entry with a house bank only overrides the calendar of its class for the payments of that bank. In FQC0 terms the house-bank entry wins for those payments, so it repeats the class of the payment method (the check refuses another class, message 385) and leaves the ageing basis blank (423). A payment method maps to exactly one class per flow: the key FLOW + PAY_METHOD + `*` is unique, and a house-bank entry must name the same class (385) and needs the `*` entry of its payment method (431). The payment methods of one class share ageing basis and calendar, the entries of one class and house bank share the calendar (433). Reader result (unchanged structure): one class row per flow + class (HBKID blank, PAY_METHODS = the comma list of its payment methods) and one house-bank row per flow + class + house bank.

Not mapped: DESCRIPTION, ACTIVE (FQC0 has neither — an entry that exists applies; a class not yet confirmed is not entered), CHANGED_BY / _AT and the RAP admin fields (FQC0 change documents and the customizing request).

### ZBTM — bank transaction codes (was ZCD_BTC_MAP)

| Field | Kind | Length | Generic | Meaning |
|---|---|---|---|---|
| SCHEME | key 1 | 5 | no | BAI2 / ISO / PRTRY |
| CODE | key 2 | 35 | no | BAI2 type code; ISO **domain** (e.g. PMNT); PRTRY code |
| FAMILY | key 3 | 35 | no | ISO family (e.g. ICDT); blank for BAI2 / PRTRY |
| SUB_FAMILY | key 4 | 35 | yes (ISO `*` = the family row, was the code `PMNT-ICDT`) | ISO sub-family (e.g. ARET); blank for BAI2 / PRTRY |
| BANK_KEY | key 5 | 15 | yes (`*` = every bank, was blank) | Bank identifier as in the statement (= ZCD_EBS_ACCT-BANK_KEY) |
| FLOW | key 6 | 1 | yes (`*` = any flow) | D / C |
| CATEGORY | result 1 | 4 | — | Requirements baseline category (C01 … X01) |
| RULE_GROUP | result 2 | 10 | — | Rule group in ZCD_BTC_RULE (blank = category) |
| EXP_CDI | result 3 | 1 | — | Expected direction C / D / `*` / blank |
| PAY_METHOD | result 4 | 10 | — | Payment method family (ACH, WIRE, CHECK …) |
| POSTING_RULE | result 5 | 4 | — | Expected posting rule |
| ACTION | result 6 | 10 | — | AUTO_POST / EXCEPTION / BLOCK / NOTIFY / ON_ACCOUNT / blank |
| DISPOSITION | result 7 | 10 | — | blank = posted as usual, NOT_POSTED = never posted (sweeps, A26) |

The ISO code is split into its three ISO parts so that it fits key fields and so that the family row is the FQC0 generic `*` of the sub-family. The reader joins them again (`PMNT-ICDT-ARET`, family row `PMNT-ICDT`; `ZIF_CD_EBS_TYPES=>GC_ISO_SEPARATOR`) and maps bank `*` to the blank bank key the resolver always used for "every bank", so the resolver, R01, S09 and the statement evidence are unchanged.

**Did not fit:** ZCD_BTC_MAP had 10 result fields (8 allowed). Dropped: **RET_REASON** (read by no rule — no redundant data), **ACTIVE** (an entry that exists applies; switching a code off = removing the entry by transport, which leaves the code unmapped and blocked by R14 exactly as an inactive row did), **DESCRIPTION** (FQC0 has no entry text; the text stays in `config/postarea_zbtm.csv`). 7 results remain, 6 keys.

### ZBTR — bank code roles (was ZCD_HCK_BTCROLE)

| Field | Kind | Length | Generic | Meaning |
|---|---|---|---|---|
| USAGE | key 1 | 10 | no | LIFECYCLE (`A_INFLIGHT`, payment outcome) / RECON (`A_RECON_3WAY`) |
| SCOPE | key 2 | 10 | no | LIFECYCLE: flow + method class (e.g. `DACH`, form `[DC][A-Z0-9_]{1,3}`, class in ZPMC); RECON: set id (ZCD_HCK_RCSET) |
| SCHEME | key 3 | 5 | no | BAI2 / ISO / PRTRY (RECON: BAI2 only) |
| CODE | key 4 | 35 | no | BAI2 type code / ISO domain / PRTRY code |
| FAMILY | key 5 | 35 | no | ISO family; blank otherwise |
| SUB_FAMILY | key 6 | 35 | no | ISO sub-family; blank otherwise |
| ROLE | result 1 | 15 | — | LIFECYCLE: open list (ORIGINAL, RETURNED, COLLECTED …), never a RECON role; RECON: LEG / DEPOSIT / CUTOFF / REDEPOSIT / CHEQUE / OTHER / IGNORE |
| COMPARE_AMOUNT | result 2 | 1 | — | LIFECYCLE: X returns lot / R payment amount / C correction / blank; RECON: blank |

`*` is not used in ZBTR: a code without a role is a control (`BTC_ROLE_MISSING`, unmapped reconciliation variance) that a `*` entry would silence. Not mapped: DESCRIPTION, ACTIVE, admin fields (as ZPMC).

## 3. Configuration check (FQC0 checks only domains)

`ZCL_CD_OPS_CFG_CHECKS=>CHECK_POSTING_AREAS`, reported every morning by the check **`D_POSTAREA_INVALID`** (`ZCL_CD_HCK_C_POSTAREA`, check code `POSTAREA_INVALID`, metric `POSTAREA_INVALID`; object key = posting area / key values). What the configuration apps checked before, plus what a posting area adds:

| Posting area | Validation | Message | Severity |
|---|---|---|---|
| all | `*` in a key the reader cannot apply | 427 | E |
| all | Value longer than the reader takes (never truncated) | 428 | E |
| all | Required key blank (enter a value or `*`) | 429 | E |
| all | Posting area without entries | 432 | W |
| ZRSN | NOC flag `X` or blank | 413 | E |
| ZPMC | Flow D / C; ageing basis VALUE_DATE / ISSUE_DATE (`*` entry); method class present | 413, 422 | E |
| ZPMC | House-bank entry: calendar present, no ageing basis, `*` entry of the payment method exists | 422, 423, 431 | E |
| ZPMC | One class per payment method (house-bank entry names the class of the `*` entry) | 385 | E |
| ZPMC | One ageing basis / calendar per class, one calendar per class and house bank | 433 | E |
| ZBTM | Scheme, flow, expected direction, action, disposition values | 413 | E |
| ZBTM | ISO: family and sub-family present; BAI2 / PRTRY: both blank | 422, 423 | E |
| ZBTM | Entry not BLOCK: rule group (blank = category) with an active rule in ZCD_BTC_RULE | 416 | E |
| ZBTR | Usage, scheme values; ISO parts as ZBTM | 413, 422, 423 | E |
| ZBTR | LIFECYCLE: scope form `[DC][A-Z0-9_]{1,3}`; method class of the scope in ZPMC; role present and not a RECON role; compare amount X / R / C / blank | 425, 430, 422, 424, 413 | E |
| ZBTR | RECON: one of the seven roles; scheme BAI2; no compare amount | 413, 423 | E |

## 4. Setup in DV1 (once, before the entries)

1. **Confirm the dictionary (VERIFY-SE11).** SE11 `TFK033D`: field names `APPLK`, `BUBER`, `KTOPL`, `KEY01`–`KEY08`, `FUN01`–`FUN08` and their lengths. The layouts need key fields of at least 35 characters (ZBTM / ZBTR CODE, FAMILY, SUB_FAMILY as data element length; real values are ≤ 4 for ISO parts and ≤ 3 for BAI2), 15 for BANK_KEY and results of at least 15 (ROLE). If the key fields are shorter, the smallest workable alternative is to define CODE / FAMILY / SUB_FAMILY / BANK_KEY with data elements of that length (the suite's values are short: ISO parts 4, BAI2 3, PRTRY `NOC`; BANK_KEY is the statement's bank identifier - ABA routing number 9, BIC 11 characters, `config/fmon_seed.md` - and no bank-specific ZBTM entry exists today, all are `*`; a key shorter than 11 would only stop a future bank-specific entry of a BIC-identified bank) and, if FUN is shorter than 15, to shorten the lifecycle role names in ZBTR **and** in the patterns of ZCD_HCK_SEQOUT together (e.g. `PAYOUT_RECEIVED` → `PAYOUT_RCVD`; roles are configuration values, no code names them). The configuration check reports every value longer than its reader takes (428). Also confirm the application area of FS-CD (domain `APPLK_KK`, delivered parameter `POSTAREA_APPLK` = `V`).
2. **Define the four customer posting areas** — SPRO, *Financial Accounting → Contract Accounts Receivable and Payable → Program Enhancements → Define Customer-Specific Posting Areas* (**VERIFY**: exact path and activity name in DV1; the posting area definition tables are TFK033B / TFK033BT with the key and result field definitions, VERIFY-SE11). Per posting area: name `ZRSN` / `ZPMC` / `ZBTM` / `ZBTR`, application area of FS-CD, text (*Ops suite: return reasons*, *… payment method classes*, *… bank transaction codes*, *… bank code roles*), **no chart-of-accounts dependency** (the entries are stored with KTOPL blank = `POSTAREA_KTOPL` blank; if DV1 forces a chart of accounts, set the parameter to it), generic entries (`*`) allowed where the definition offers the switch (VERIFY), and the key / result fields of §2 in that order with a data element each. Data elements: SAP ones where the meaning matches (house bank `HBKID`, factory calendar `WFCID`, payment method of FI-CA, VERIFY-SE11), otherwise new `ZCD_PA_*` CHAR data elements of the §2 length with fixed values only where the suite's check does not already check them (FQC0 checks domains only).
3. **Request.** The posting area definitions on their own request (VERIFY whether DV1 records them as workbench or customizing objects), released and imported to QA1 / PS4 **before** the request with the entries — FQC0 cannot store an entry of an undefined posting area. Implementation_Order step 3.3a.
4. **Parameters.** The six `POSTAREA_*` definitions of `config/param_definitions.csv` (step 3.0); change a value only together with the posting area it names.
5. **Precedence test (VERIFY).** In ZBTM enter the test entries `ISO/PMNT/ICDT/ARET/*/*` (category T91) and `ISO/PMNT/ICDT/*/JPMC/*` (category T92), ask FQC0 / `FKK_ACCOUNT_DETERMINE` (SE37, posting area ZBTM, keys ISO / PMNT / ICDT / ARET / JPMC / D) which entry applies: T91 = the implemented rule (first key from the left); T92 = FI-CA ranks by the number of generic keys — then change `ZCL_CD_OPS_POSTAREA=>RANK` and review the EBS resolver order. Delete the test entries.

## 5. FQC0 maintenance guide (FI-CA team)

**Where.** Transaction **FQC0** (*Maintain FI-CA account determination*), application area of FS-CD, posting area `ZRSN` / `ZPMC` / `ZBTM` / `ZBTR` (the names in the parameters `POSTAREA_*`), in the **customizing client of DV1**, on a **customizing request**. QA1 and PS4 receive the entries only by transport (D-3: new configuration only from DV1; the production client is not changeable).

**What `*` means.** `*` = any value of that key; an entry with the exact value always wins over an entry with `*`; when several keys are `*` the entry that is exact in the left-most differing key wins (§1). Use `*` only where §2 says *generic: yes*:

| Posting area | `*` allowed in | Example |
|---|---|---|
| ZRSN | REASON | `*` → reason `RZZ`: every reason without its own entry (R05 then never reports REASON_UNMAPPED) |
| ZPMC | HOUSE_BANK | `D / E / *` → WIR: the class of method E at every house bank |
| ZBTM | SUB_FAMILY (ISO), BANK_KEY, FLOW | `ISO / PMNT / ICDT / * / * / *`: the family row; `BAI2 / 495 / / / * / *`: every bank, any flow |
| ZBTR | — | every code of a scope is its own entry |

**Typical changes.**

| Change | Posting area | Entry |
|---|---|---|
| New bank transaction code | ZBTM | SCHEME / CODE (ISO: domain, family, sub-family) / BANK_KEY `*` / FLOW → CATEGORY, RULE_GROUP (needs an active rule group in ZCD_BTC_RULE, EBS configuration app), EXP_CDI, PAY_METHOD, ACTION |
| Code of one bank that deviates | ZBTM | Same code with BANK_KEY = the bank (wins over `*`) |
| New return / NOC reason | ZRSN | REASON → FICA_REASON, IS_NOC |
| New payment method of a class | ZPMC | FLOW / PAY_METHOD / `*` → METHOD_CLASS, AGE_BASIS (CALENDAR optional) |
| Own calendar of a house bank | ZPMC | FLOW / PAY_METHOD / HOUSE_BANK → the same METHOD_CLASS, AGE_BASIS blank, CALENDAR (one entry per payment method of the class) |
| New method class | ZPMC + ZBTR + HCK app | ZPMC entries of its payment methods; ZBTR LIFECYCLE roles with SCOPE = flow + class; ZCD_HCK_CLRRULE / ZCD_HCK_SEQOUT rows and ZCD_HCK_THRESH limits in the HCK configuration app |
| New lifecycle role of a code | ZBTR | LIFECYCLE / flow + class / scheme / code → ROLE, COMPARE_AMOUNT |
| Reconciliation role of a code | ZBTR | RECON / set id / BAI2 / code → one of the seven roles |
| Switch a code off | ZBTM | Remove the entry by transport (the code is then unmapped and blocked by R14) |

**Afterwards.** Release the request; after the import the next morning report lists every entry the suite cannot use (`D_POSTAREA_INVALID`, `Operations_Runbook.md` §5o). Seed entries: `config/postarea_zbtm.csv`, `config/postarea_zrsn.csv`, `config/hck_seed.md` §8a / §8b (ZPMC) and §8e / §10b (ZBTR).
