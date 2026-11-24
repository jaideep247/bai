# Design - ZCA_PARAM parameter framework

> **First principle:** a parameter is configuration that changes behaviour without a code
> change, so it must be as trustworthy as code: one identity, one meaning, validated,
> audited and owned.
> **Analogy:** a labelled fuse box - every switch has exactly one label, a fixed rating,
> and a log of who flipped it; a missing fuse never silently becomes "on".

Scope: S/4HANA 2023, SAP_BASIS 7.58, classic ABAP (not ABAP Cloud). Prefix `ZCA_`,
package `ZCA_PARAM` (runtime, DDIC, messages, authorization). Maintenance in SM30 / SPRO
(table maintenance generator and view cluster, built in the system, `docs/OPERATIONS.md`).
Decisions of 2026-11-07, revised 2026-11-24 (RAP maintenance app removed); deviations from
the initial brief are in section 12.

## 1. Object list

| Layer | Object | Role |
|---|---|---|
| DDIC | `ZCA_PARAM_AREA` | area master: description, owner team, `ACTIVE` |
| DDIC | `ZCA_PARAM_DEF` | definition per area + name: kind, value type, min / max, default, allowed PCRE, interface, mandatory, context dimensions `DIM1`-`DIM4`, description; FK `AREA` -> `ZCA_PARAM_AREA` |
| DDIC | `ZCA_PARAM_VAL` | value rows per area + name + context `CTX1`-`CTX4` (blank = any) + `NUMB`: sign, option, low, high; FK (`AREA`, `NAME`) -> `ZCA_PARAM_DEF` |
| DDIC | domains / data elements `ZCA_PARAM_*` | fixed values for kind, value type, sign, option; flags on domain `XFELD` |
| Messages | `ZCA_PARAM` | 001-029 runtime and validation (`config/zca_param_messages.md`) |
| Authorization | `ZCA_PARAM` (class `ZCA`), field `ZCA_PARAR` | optional check per area; standard maintenance uses `S_TABU_DIS` |
| API | `ZIF_CA_PARAM`, `ZIF_CA_PARAM_TYPES`, `ZCX_CA_PARAM` | read API, types / constants, checked exception (T100) |
| Logic | `ZCL_CA_PARAM` | resolution, typed getters, validation on every read, per-area buffer |
| Rules | `ZCL_CA_PARAM_VALIDATOR` | pure validation rules, shared by runtime and the SM30 save events |
| Data access | `ZIF_CA_PARAM_DAO`, `ZCL_CA_PARAM_DAO`, `ZCL_CA_PARAM_DAO_MEM` | one read per area; in-memory variant for tests |
| Tests support | `ZCL_CA_PARAM_BUILDER`, `ZCL_CA_PARAM_INJECTOR` | fluent test data; factory seam (`FOR TESTING`) |
| Entry | `ZCL_CA_PARAM_FACTORY` | `get( )`: session instance |
| Maintenance | function group `ZCA_PARAM_MAINT` (generated), event include `sm30/lzca_param_maintf01.abap`, view cluster `ZCA_PARAM_VC`, transaction `ZCA_PARAM` | SM30 / SM34 / SPRO; save events call the validator |

## 2. Data model

```
ZCA_PARAM_AREA (CLIENT, AREA)                      1
   |  FK [0..*,1]                                  |
ZCA_PARAM_DEF  (CLIENT, AREA, NAME)                n   kind P | S, value type, rules
   |  FK [0..*,1] on (CLIENT, AREA, NAME)          |
ZCA_PARAM_VAL  (CLIENT, AREA, NAME,                n   SIGN, OPTI, LOW, HIGH
                CTX1, CTX2, CTX3, CTX4, NUMB)          CTXn = value of DIMn of the definition, blank = any
```

- **One identity:** `AREA` (CHAR 16) + `NAME` (CHAR 30), upper case, `^[A-Z][A-Z0-9_]*$`.
  There is no second key, number or alias.
- All three tables: client-dependent, delivery class **C**, table logging **on**,
  fully buffered, data maintenance *allowed* (SM30 / SM34 view cluster `ZCA_PARAM_VC`),
  enhancement category *cannot be enhanced*.
- Foreign keys document the hierarchy and give SE11 / SE16 checks; the database does
  not enforce them. Enforcement is by the maintenance dialog (foreign key screen check:
  a definition needs an existing area, a value an existing definition) and
  semantic (the runtime raises 001 / 003 for a row without master).
- Value rows reuse no TVARVC data element; own domains restrict `SIGN` to I / E and
  `OPTI` to EQ NE GT GE LT LE BT NB - pattern options (CP / NP) are excluded, patterns
  are value type PCRE.

## 3. Read semantics

Every getter resolves the parameter afresh from the buffered area snapshot, validates
every row and the default against the definition, then applies the rules below. Every
failure is `ZCX_CA_PARAM` with the message number shown - never a silent default, never
a dump.

| Situation | Kind P (single value) | Kind S (select-option) |
|---|---|---|
| Area not in `ZCA_PARAM_AREA` | 001 | 001 |
| Area `ACTIVE` blank | 002 | 002 |
| Name not defined in the area | 003 | 003 |
| No value row, default set | the default (validated like a value) | `get_range`: one row I EQ default; `get_list`: [default] |
| No value row, no default, not mandatory | `get_value` = blank; `get_bool` = false; `get_int` / `get_dec` / `get_date` / `get_time` raise 018 | empty range / empty list |
| No value row, no default, `MANDATORY` = X | 004 | 004 |
| One row | `LOW` | the row |
| Row with blank `LOW` | BOOL: **false (explicit off)**; mandatory non-BOOL: 004; typed getters: 018; `get_value`: blank | valid (range "equals blank") |
| More than one row | **005** (configuration error) | all rows, ordered by `NUMB` |
| A row or the default invalid for the definition | 006-013, 017 | 006-013, 017 |
| `get_list` with a row that is not I EQ | - | 016 |
| Getter does not fit the value type | 014 (e.g. `get_int` on CHAR) | - |
| Getter does not fit the kind | 015 (`get_range`) | 015 (`get_value`, typed getters) |

Getter / value type matrix (kind P): `get_value` any type; `get_int` INT; `get_dec` DEC or
INT; `get_bool` BOOL; `get_date` DATE; `get_time` TIME; `get_list` LIST (split at comma or
semicolon, elements condensed, blank elements dropped). Kind S: `get_range` any type,
`get_list` (rows must be I EQ). `is_set` = at least one value row (default does not
count; no validation). `get_definition` returns the definition. Area and name are
converted to upper case.

**BOOL:** a row with `LOW` = X is true, a row with blank `LOW` is false, no row is the
default (X or blank). A flag with default X can therefore be switched off - the defect
of the old framework, where blank meant "use the default", cannot occur.

**Empty range:** an empty `get_range` result means "nothing maintained". `WHERE f IN
@lt_range` with an empty range selects everything - consumers must test `IS INITIAL`
first or define the parameter `MANDATORY`.

## 3a. Context: values per source, type, company code, ...

> **First principle:** a value that differs by a business fact (source, transaction type,
> company code, payment method) is still one parameter; the fact selects the row, the
> code does not.
> **Analogy:** an access sequence in SAP pricing - the most specific condition record
> that exists wins (customer + material before material alone), and the search stops
> at the first hit.

**Definition.** `DIM1`-`DIM4` name up to four context dimensions of a parameter, e.g.
`DIM1 = SOURCE`, `DIM2 = TRANS_TYPE`. `DIM1` is the most significant. Dimensions are
identifiers (at most 20 characters), declared from `DIM1` on without gap or repeat
(028 / 029). A parameter without dimensions behaves exactly as in section 3.

**Value rows.** `CTX1`-`CTX4` hold the value of the dimension in the same position;
blank = any. A context value needs its dimension on the definition (026) and is upper
case (027). Kind P has at most one row **per context** (005).

**Read.** Every getter, `is_set` and `get_effective_context` take an optional
`it_context`: the caller's facts by dimension name (`dim = 'SOURCE' value = 'SRC_A'`).
A caller passes every fact it knows; each definition uses only its own dimensions and
ignores the rest. So a dimension can be added to a definition later by configuration
alone - the callers already pass the fact. Names and values are compared in upper case.

**Access sequence.** With n dimensions the read tries 2**n contexts, most specific
first, `DIM1` deciding before `DIM2`. Example for SOURCE / TRANS_TYPE, read SRC_A / CANC:

| Try | CTX1 (SOURCE) | CTX2 (TRANS_TYPE) |
|---|---|---|
| 1 | SRC_A | CANC |
| 2 | SRC_A | any |
| 3 | any | CANC |
| 4 | any | any (general rows) |
| - | default of the definition (section 3) | |

A context that needs a fact the read did not pass is skipped. The **first context with
value rows wins, and all rows come from that one context** - a range or list is never a
mix of a specific and a general context (as with an exclusive access in SAP pricing).

**Validation.** Every row of every context is validated on every read (section 4), so
a wrong row for one source fails the reads of every source of that parameter - a
configuration error is found by the first read, not by the source it belongs to.

**Explain.** `get_effective_context( area, name, context )` returns the context a read
uses and its number of rows (0 = default) - the support answer to "which row drives
SRC_A?" without running the process.

## 4. Validation

`ZCL_CA_PARAM_VALIDATOR` holds every rule; the runtime calls it on every read, the SM30
save events on every save. It returns messages, never raises, never reads tables. A blank value is
valid at value level; whether blank is acceptable is decided by `MANDATORY` and the
typed getters (section 3).

| Value type | Valid value | Min / max | Allowed PCRE |
|---|---|---|---|
| INT | `^[+-]?[0-9]+$`, within type `i` | numeric | whole value |
| DEC | `^[+-]?[0-9]+([.][0-9]+)?$` (decimal point) and convertible to decfloat34 | numeric (decfloat34) | whole value |
| CHAR | anything (CHAR 255) | not allowed | whole value |
| BOOL | X (or blank) | not allowed | not allowed |
| DATE | 8 digits and a real date (YYYYMMDD) | text compare | whole value |
| TIME | HHMMSS, 00:00:00-23:59:59 | text compare | whole value |
| LIST | anything; kind P only | not allowed | each element |
| PCRE | compiles with `CL_ABAP_REGEX=>CREATE_PCRE` | not allowed | whole value |
| DDIC | name `^(/[A-Z0-9_]+/)?[A-Z0-9_]+$` and an existing DDIC type (RTTI, `IS_DDIC_TYPE`) | not allowed | whole value |
| CLASS | same name pattern, an existing class (RTTI kind class); with `INTERFACE_NAME` the class implements it | not allowed | whole value |

- **Allowed PCRE** is matched to the **whole value, ignoring case** (`matches( ... case =
  abap_false )`); an invalid pattern is 010, never "no match".
- **Rows:** kind P - `SIGN` blank or I, `OPTI` blank or EQ, `HIGH` blank; kind S - `SIGN`
  I / E, `OPTI` one of the eight options, `HIGH` required for BT / NB and blank otherwise
  (017). `LOW` and `HIGH` are validated as values.
- **Definitions:** name (019), kind (020), value type (021), LIST only for kind P (025),
  min / max only for INT DEC DATE TIME and valid for the type (022 / 006), min <= max
  (023), interface only for CLASS (022) and existing (024), allowed PCRE not for BOOL
  (022) and compiling (010), default valid as a value. Area name (019).
- **Dynamic code:** DDIC and CLASS values are never fragments of code: only a repository
  name that exists passes. Consumers still use the value only as a name (e.g.
  `SELECT ... FROM (lv_table)` after `get_value`, or `CREATE OBJECT TYPE (lv_class)` and
  a cast to `INTERFACE_NAME`).

## 5. Buffering

- `ZCL_CA_PARAM_FACTORY=>GET( )` returns one instance per internal session.
- `ZCL_CA_PARAM` keeps a HASHED buffer by area; the first read of an area costs one DAO
  call (three SELECTs: master row, definitions ORDER BY key, values ORDER BY key into
  SORTED tables). Later reads of the same area use the buffer. Unknown areas are not
  buffered (an area created later is seen at once); inactive areas are.
- `refresh( iv_area )` drops one area, `refresh( )` all. Long-running jobs call it at the
  start of each run, dialog and OData requests start with a fresh session anyway.
- The tables are also fully buffered by the kernel: a change made on another application
  server becomes visible after table buffer synchronization (profile parameter
  `rdisp/bufreftime`, typically 1-2 minutes).
- Order is deterministic everywhere: SQL `ORDER BY` the full key, SORTED tables, no
  `INDEX 1`, no `SELECT *`.

## 6. Errors

One checked exception `ZCX_CA_PARAM` (`CX_STATIC_CHECK`, `IF_T100_MESSAGE`, message class
`ZCA_PARAM`, variables &1 area, &2 name, &3 value / row / field, &4 type / limit /
interface). `ZCX_CA_PARAM=>CREATE( is_message )` builds it from the message structure the
validator and the save events share; `get_message( )` returns it. Message texts:
`config/zca_param_messages.md` (troubleshooting per number: `docs/OPERATIONS.md`).
Because the exception is checked, every caller must decide what a configuration error
means for its process.

## 7. Authorization

SM30 / SM34 check `S_TABU_DIS` (authorization group of the table maintenance) or
`S_TABU_NAM`, plus `S_TCODE`. The object `ZCA_PARAM` (`ZCA_PARAR` = area, `ACTVT`)
stays available for a check per area in a maintenance event; it is not used by default.

Runtime reads (`ZIF_CA_PARAM`) check no authorization: batch users of every team read
parameters; parameters must therefore never hold secrets.

## 8. Transport and client rules

Standard customizing rules apply (delivery class C, SCC4):

- Development customizing client with automatic recording: areas, definitions and values
  are maintained in SM30 / SM34; every change is recorded on a customizing request.
- QA and production: no changes (client setting); values come by transport.
- Save events (event 01 of each table) apply `ZCL_CA_PARAM_VALIDATOR`; a definition
  change re-checks its stored value rows; a single value (kind P) keeps at most one row.
- Audit: table logging (SCU3) and the customizing requests.

## 9. Testing

| Level | Test class | Proves |
|---|---|---|
| Rules | `ZCL_CA_PARAM_VALIDATOR` `ltc_validator` (40 tests) | types, limits, whole-value case-insensitive PCRE, list elements, DDIC / class / interface via RTTI (T000, CL_ABAP_TYPEDESCR, CX_SY_ZERODIVIDE, IF_MESSAGE), rows per kind, definition rules |
| Logic | `ZCL_CA_PARAM` `ltc_param` (36 tests, over `ZCL_CA_PARAM_BUILDER`) | default, mandatory, BOOL on / off / default, P with two rows, S list and range in NUMB order, conversions with min / max, invalid values, type and kind mismatch, unknown / inactive area, unknown name, case, `is_set`, definition, one read per area, refresh |
| SQL | `ZCL_CA_PARAM_DAO` `ltc_dao` (5 tests, `cl_osql_test_environment` doubling all three tables) | found flag, area filter, key order of definitions and values |
| Seam | `ZCL_CA_PARAM_FACTORY` `ltc_factory` (4 tests) | singleton, injected reader, injected DAO with real logic, reset |

All test classes: `RISK LEVEL HARMLESS DURATION SHORT`, a message on every assertion.
Not unit-tested, by design: the SM30 save events (generated function group; manual test in
`docs/VERIFY.md`). Consumers test with the real logic over
`ZCL_CA_PARAM_DAO_MEM` - there is no second implementation of the semantics.

## 10. Quality gates

`abaplint.json` (v758, house naming and modern-syntax rules, `errorNamespace`
`^(ZCL_CA_|ZIF_CA_|ZCX_CA_|LCL_|LTC_|LTD_|LIF_)`, SAP stubs from `abaplint/deps`),
`tools/checks.py` (name lengths, artifact headers, PCRE only, no CP / NP, no inline user
texts, no `SELECT *`, FINAL, test class risk / duration, message constants vs. message
class), `tools/abapgit_serialize.py --check`, tool tests; CI in
`ci/abaplint.yml`.

## 11. Review findings and how each is prevented

| # | Finding in the old framework | Prevention here |
|---|---|---|
| 1 | Two identities (code + name) -> duplicates | One key AREA + NAME; no code field; unique primary keys; names validated as identifiers |
| 2 | Non-deterministic reads (`SELECT *`, no ORDER BY, STANDARD table, `INDEX 1`) | Explicit field lists, `ORDER BY` full key, SORTED / HASHED tables; kind P with two rows is error 005, never "row 1"; checks `no_select_star` |
| 3 | Failures swallowed into defaults or dumps on conversion | Checked `ZCX_CA_PARAM` for every failure (001-025); values validated by PCRE before any conversion; typed getters on blank raise 018 |
| 4 | No audit trail (no table logging, delivery class A) | Delivery class C, table logging on (SCU3), customizing requests (SM30 / SM34) |
| 5 | Area master not enforced | Foreign keys with screen check in the view cluster Area -> Definition -> Value; runtime 001 / 002 / 003 |
| 6 | No API for value-by-name / typed / range | `ZIF_CA_PARAM`: `get_value`, `get_int`, `get_dec`, `get_bool`, `get_date`, `get_time`, `get_list`, `get_range`, `is_set`, `get_definition`, `refresh` |
| 7 | Untyped values, no validation | Value type, min / max, allowed PCRE, interface per definition; validated on save and on every read |
| 8 | Static buffer without refresh | Per-area instance buffer with `refresh( [area] )`; injector `reset( )` for tests |
| 9 | DDIC / class names used unvalidated in dynamic SQL | Value types DDIC / CLASS: name pattern + RTTI existence (+ interface); anything else is 006 / 011 / 012 / 013 |
| 10 | Test double duplicating production logic | `ZCL_CA_PARAM_DAO_MEM` holds data only; tests run `ZCL_CA_PARAM` itself (builder / `inject_dao`) |
| 11 | Docs not matching code | Semantics in one class, documented in section 3 with a test per row; message texts generated from one source and checked against the constants (`tools/checks.py messages`) |
| 12 | No maintenance authorization model | `S_TABU_DIS` / `S_TABU_NAM` per authorization group; customizing client rules (section 8) |
| - | Blank meant "default", flags could not be switched off | BOOL: row with blank LOW = false; only a missing row means default |

## 12. Deviations from the initial brief (and why)

- **Maintenance in SM30 / SPRO instead of a RAP app (2026-11-24):** the tables are
  customizing maintained by a few developers in the development client; the RAP BO
  (draft, projections, DCLs, service, behaviour pool, client / request policy) added about
  25 objects and its own activation issues for no gain over the standard dialog. Removed
  with it: `TRANSPORT_REQUEST`, the admin fields (history is in SCU3 and the requests),
  `PROD_EDITABLE`, `DEVELOPER_OWNED` and `OWNER` (only the app enforced them), messages
  040-048. `GC_VERSION` 2.0.0.
- **Range options without CP / NP:** patterns are PCRE only (house rule); a select-option
  can still be used in SQL `IN`.
- **Flags on standard domain `XFELD`** instead of own domains.
- **Context dimensions (2026-11-24):** the brief had one value per area + name. Values that
  differ by source, type or company code would have needed a parameter per combination or
  a table per process; four ranked dimensions with an exclusive access sequence cover
  them in the same three tables (section 3a and section 13).
- **`get_time`** added (value type TIME exists).
- **`MANDATORY`** also rejects a blank single value row (except BOOL), not only a missing
  row without default.
- **Client field named `CLIENT`** in the customizing tables.

## 13. Configuration instead of code: what belongs where

> **First principle:** a value goes into a parameter when it can change on its own; a set
> of values that only makes sense together, or that switches code paths, is a rule.
> **Analogy:** thermostat settings per room are parameters; the wiring diagram that says
> which switch drives which circuit is a rule.

| Configuration | Example | Where |
|---|---|---|
| A switch, limit, threshold, list or pattern | log level, retention days, allowed states | parameter |
| The same, different per source / type / company code | log level per source; void states per payment method | parameter with context dimensions (section 3a) |
| A value that selects a class | handler class of a source | parameter, value type `CLASS` with `INTERFACE_NAME` (the class is checked to exist and implement it) |
| A mapping of independent rows | response status per profile and outcome | parameter with context (profile, outcome) |
| A row whose fields must change together, or whose existence enables a process | flow of a source: status field + response profile + notification switches | rule table of the process (its own customizing table), or BRF+ for decision logic |
| More than four key dimensions, or keys that need their own check tables | rules by source x type x payment method x company code x currency | rule table of the process |

Effect on change and test: adding a source, a company code or a new value to an existing
parameter is a customizing change (SM30 / SPRO, customizing request, SCU3) with no
transport of code; the read logic is the one unit-tested class `ZCL_CA_PARAM`, so the test
of such a change is the business test of the new configuration, not a regression test of
code. A new parameter is a definition row plus the one line of code that reads it; a new
dimension on an existing parameter needs no code when the callers already pass the fact.

