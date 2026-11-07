# Design - ZCA_PARAM parameter framework

> **First principle:** a parameter is configuration that changes behaviour without a code
> change, so it must be as trustworthy as code: one identity, one meaning, validated,
> audited and owned.
> **Analogy:** a labelled fuse box - every switch has exactly one label, a fixed rating,
> and a log of who flipped it; a missing fuse never silently becomes "on".

Scope: S/4HANA 2023, SAP_BASIS 7.58, classic ABAP (not ABAP Cloud). Prefix `ZCA_`,
packages `ZCA_PARAM` (runtime, DDIC, messages, authorization) and `ZCA_PARAM_UI`
(maintenance app). Decisions of 2026-11-07; deviations from the initial brief are in
section 12.

## 1. Object list

| Layer | Object | Role |
|---|---|---|
| DDIC | `ZCA_PARAM_AREA` | area master: description, owner team, `PROD_EDITABLE`, `ACTIVE`, last customizing request, admin fields |
| DDIC | `ZCA_PARAM_DEF` | definition per area + name: kind, value type, min / max, default, allowed PCRE, interface, mandatory, developer-owned, description, owner; FK `AREA` -> `ZCA_PARAM_AREA` |
| DDIC | `ZCA_PARAM_VAL` | value rows per area + name + `NUMB`: sign, option, low, high; FK (`AREA`, `NAME`) -> `ZCA_PARAM_DEF` |
| DDIC | domains / data elements `ZCA_PARAM_*` | fixed values for kind, value type, sign, option; flags on domain `XFELD` |
| DDIC | `ZCA_D_PARAREA`, `ZCA_D_PARDEF`, `ZCA_D_PARVAL` | draft tables of the app |
| Messages | `ZCA_PARAM` | 001-025 runtime and validation, 040-047 maintenance (`config/zca_param_messages.md`; authorization failures are reported by the RAP framework) |
| Authorization | `ZCA_PARAM` (class `ZCA`), field `ZCA_PARAR` | maintenance only |
| API | `ZIF_CA_PARAM`, `ZIF_CA_PARAM_TYPES`, `ZCX_CA_PARAM` | read API, types / constants, checked exception (T100) |
| Logic | `ZCL_CA_PARAM` | resolution, typed getters, validation on every read, per-area buffer |
| Rules | `ZCL_CA_PARAM_VALIDATOR` | pure validation rules, shared by runtime and app |
| Data access | `ZIF_CA_PARAM_DAO`, `ZCL_CA_PARAM_DAO`, `ZCL_CA_PARAM_DAO_MEM` | one read per area; in-memory variant for tests |
| Tests support | `ZCL_CA_PARAM_BUILDER`, `ZCL_CA_PARAM_INJECTOR` | fluent test data; factory seam (`FOR TESTING`) |
| Entry | `ZCL_CA_PARAM_FACTORY` | `get( )`: session instance |
| App | `ZR_CA_ParamArea` / `ZR_CA_ParamDef` / `ZR_CA_ParamVal`, `ZC_*`, `ZI_CA_Param*VH`, BDEF `ZR_CA_PARAMAREA` / `ZC_CA_PARAMAREA`, DCLs `ZC_*`, SRVD `ZUI_CA_PARAM` | RAP managed BO with draft |
| App logic | `ZBP_R_CA_PARAMAREA`, `ZCL_CA_PARAM_MAINT`, `ZCL_CA_PARAM_MAINT_POLICY`, `ZIF_CA_PARAM_SYSTEM`, `ZCL_CA_PARAM_SYSTEM` | thin handlers, gate, pure policy, SAP API boundary |

## 2. Data model

```
ZCA_PARAM_AREA (CLIENT, AREA)                      1
   |  FK [0..*,1]                                  |
ZCA_PARAM_DEF  (CLIENT, AREA, NAME)                n   kind P | S, value type, rules
   |  FK [0..*,1] on (CLIENT, AREA, NAME)          |
ZCA_PARAM_VAL  (CLIENT, AREA, NAME, NUMB)          n   SIGN, OPTI, LOW, HIGH
```

- **One identity:** `AREA` (CHAR 16) + `NAME` (CHAR 30), upper case, `^[A-Z][A-Z0-9_]*$`.
  There is no second key, number or alias.
- All three tables: client-dependent, delivery class **C**, table logging **on**,
  fully buffered, data maintenance *restricted* (no SM30 view; the RAP app is the only
  maintenance path), enhancement category *cannot be enhanced*.
- Foreign keys document the hierarchy and give SE11 / SE16 checks; the database does
  not enforce them. Enforcement is structural (the app is a composition: a definition
  can only be created under an existing area, a value under an existing definition) and
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

## 4. Validation

`ZCL_CA_PARAM_VALIDATOR` holds every rule; the runtime calls it on every read, the app
on every save. It returns messages, never raises, never reads tables. A blank value is
valid at value level; whether blank is acceptable is decided by `MANDATORY` and the
typed getters (section 3).

| Value type | Valid value | Min / max | Allowed PCRE |
|---|---|---|---|
| INT | `^[+-]?[0-9]+$`, within type `i` | numeric | whole value |
| DEC | `^[+-]?([0-9]+([.][0-9]*)?\|[.][0-9]+)$` (decimal point) | numeric (decfloat34) | whole value |
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
  start of each run, dialog and RAP requests start with a fresh session anyway.
- The tables are also fully buffered by the kernel: a change made on another application
  server becomes visible after table buffer synchronization (profile parameter
  `rdisp/bufreftime`, typically 1-2 minutes).
- Order is deterministic everywhere: SQL `ORDER BY` the full key, SORTED tables, no
  `INDEX 1`, no `SELECT *`.

## 6. Errors

One checked exception `ZCX_CA_PARAM` (`CX_STATIC_CHECK`, `IF_T100_MESSAGE`, message class
`ZCA_PARAM`, variables &1 area, &2 name, &3 value / row / field, &4 type / limit /
interface). `ZCX_CA_PARAM=>CREATE( is_message )` builds it from the message structure the
validator and the app share; `get_message( )` returns it. Message texts:
`config/zca_param_messages.md` (troubleshooting per number: `docs/OPERATIONS.md`).
Because the exception is checked, every caller must decide what a configuration error
means for its process.

## 7. Authorization

| Activity on `ZCA_PARAM` (`ZCA_PARAR` = area) | Where checked | Grants |
|---|---|---|
| 01 create | global authorization of the app (any area, `DUMMY`) | create an area |
| 02 change | instance authorization per area (update, Edit) | change area, definitions, values |
| 03 display | DCL roles `ZC_CA_PARAMAREA` / `ZC_CA_PARAMDEF` / `ZC_CA_PARAMVAL` (`pfcg_auth`) | see the area in the app |
| 06 delete | instance feature control of definitions and values | delete definitions / value rows |

Runtime reads (`ZIF_CA_PARAM`) check no authorization: batch users of every team read
parameters; parameters must therefore never hold secrets. Suggested roles: team
maintainer (01/02/03/06 for its areas, customizing client), production key user
(02/03 for production-editable areas), display (03, any area).

## 8. Transport and client rules

The app decides a **mode** per client (`ZCL_CA_PARAM_MAINT_POLICY`):

- **TRANSPORT** - role (T000-CCCATEGORY) not production **and** change option
  (T000-CCCORACTIV) "automatic recording of changes" **and** the business configuration
  API reports the customizing table editable
  (`CL_BCFG_CD_REUSE_API_FACTORY=>GET_CUST_OBJ_SERVICE_INSTANCE( )->IS_EDITABLE( )`).
- **LOCAL** - every other client (QA, production, sandboxes without recording).

| Change | TRANSPORT | LOCAL |
|---|---|---|
| Create area, change area fields | yes (01 / 02) | no |
| Create / change / delete definitions (developer-owned configuration) | yes | no (044) |
| Create value rows, delete value rows | yes (06 for delete) | no |
| Change existing value rows | yes | only if area `PROD_EDITABLE` = X and definition `DEVELOPER_OWNED` blank (045 otherwise) |
| Customizing request | mandatory on the area (`TransportRequest`), checked on save (040-043), every saved row recorded with `MBC_CP_API` | none; change audited by table logging |

New definitions start `DEVELOPER_OWNED` = X; a team releases a parameter for production
maintenance by clearing the flag (by transport). A BOOL that production may switch needs
a delivered value row (a row cannot be created in LOCAL mode).

Feature control hides what is not allowed; the validations on save repeat the decisive
rules (044, 045, 005, request) so that EML callers cannot bypass them. The saver records
the rows of a save on the request of the area; a recording failure aborts the save
(`RAISE SHORTDUMP`, rollback) - the request was validated before, so this indicates a
system problem.

## 9. Testing

| Level | Test class | Proves |
|---|---|---|
| Rules | `ZCL_CA_PARAM_VALIDATOR` `ltc_validator` (40 tests) | types, limits, whole-value case-insensitive PCRE, list elements, DDIC / class / interface via RTTI (T000, CL_ABAP_TYPEDESCR, CX_SY_ZERODIVIDE, IF_MESSAGE), rows per kind, definition rules |
| Logic | `ZCL_CA_PARAM` `ltc_param` (36 tests, over `ZCL_CA_PARAM_BUILDER`) | default, mandatory, BOOL on / off / default, P with two rows, S list and range in NUMB order, conversions with min / max, invalid values, type and kind mismatch, unknown / inactive area, unknown name, case, `is_set`, definition, one read per area, refresh |
| SQL | `ZCL_CA_PARAM_DAO` `ltc_dao` (5 tests, `cl_osql_test_environment` doubling all three tables) | found flag, area filter, key order of definitions and values |
| Seam | `ZCL_CA_PARAM_FACTORY` `ltc_factory` (4 tests) | singleton, injected reader, injected DAO with real logic, reset |
| App policy | `ZCL_CA_PARAM_MAINT_POLICY` `ltc_policy` (10 tests) | mode per client, configuration by transport, local value rules, request rules |
| App gate | `ZCL_CA_PARAM_MAINT` `ltc_maint` (9 tests, local double `ltd_system`) | client read once, request read / recording only in TRANSPORT, failure propagated, 044 / 045, authorization |

All test classes: `RISK LEVEL HARMLESS DURATION SHORT`, a message on every assertion.
Not unit-tested, by design: `ZCL_CA_PARAM_SYSTEM` (one-line wrappers of T000 / E070 /
AUTHORITY-CHECK / business configuration API / `MBC_CP_API`; its callers are tested with
a double) and the behaviour pool (thin; covered by the gate and policy tests and the
manual app test in `docs/VERIFY.md`). Consumers test with the real logic over
`ZCL_CA_PARAM_DAO_MEM` - there is no second implementation of the semantics.

## 10. Quality gates

`abaplint.json` (v758, house naming and modern-syntax rules, `errorNamespace`
`^(ZCL_CA_|ZIF_CA_|ZCX_CA_|LCL_|LTC_|LTD_|LIF_)`, SAP stubs from `abaplint/deps`),
`tools/checks.py` (name lengths, artifact headers, PCRE only, no CP / NP, no inline user
texts, no `SELECT *`, FINAL, test class risk / duration, message constants vs. message
class, neutral wording), `tools/abapgit_serialize.py --check`, tool tests; CI in
`ci/abaplint.yml`.

## 11. Review findings and how each is prevented

| # | Finding in the old framework | Prevention here |
|---|---|---|
| 1 | Two identities (code + name) -> duplicates | One key AREA + NAME; no code field; unique primary keys; names validated as identifiers |
| 2 | Non-deterministic reads (`SELECT *`, no ORDER BY, STANDARD table, `INDEX 1`) | Explicit field lists, `ORDER BY` full key, SORTED / HASHED tables; kind P with two rows is error 005, never "row 1"; checks `no_select_star` |
| 3 | Failures swallowed into defaults or dumps on conversion | Checked `ZCX_CA_PARAM` for every failure (001-025); values validated by PCRE before any conversion; typed getters on blank raise 018 |
| 4 | No audit trail (no table logging, delivery class A) | Delivery class C, table logging on (SCU3), customizing requests recorded with `MBC_CP_API`, admin fields, request on the area |
| 5 | Area master not enforced | Foreign keys; composition Area -> Definition -> Value in the app; runtime 001 / 002 / 003 |
| 6 | No API for value-by-name / typed / range | `ZIF_CA_PARAM`: `get_value`, `get_int`, `get_dec`, `get_bool`, `get_date`, `get_time`, `get_list`, `get_range`, `is_set`, `get_definition`, `refresh` |
| 7 | Untyped values, no validation | Value type, min / max, allowed PCRE, interface per definition; validated on save and on every read |
| 8 | Static buffer without refresh | Per-area instance buffer with `refresh( [area] )`; injector `reset( )` for tests |
| 9 | DDIC / class names used unvalidated in dynamic SQL | Value types DDIC / CLASS: name pattern + RTTI existence (+ interface); anything else is 006 / 011 / 012 / 013 |
| 10 | Test double duplicating production logic | `ZCL_CA_PARAM_DAO_MEM` holds data only; tests run `ZCL_CA_PARAM` itself (builder / `inject_dao`) |
| 11 | Docs not matching code | Semantics in one class, documented in section 3 with a test per row; message texts generated from one source and checked against the constants (`tools/checks.py messages`) |
| 12 | No maintenance authorization model | Object `ZCA_PARAM` per area and activity; DCL for display; client mode rules (section 8) |
| - | Blank meant "default", flags could not be switched off | BOOL: row with blank LOW = false; only a missing row means default |

## 12. Deviations from the initial brief (and why)

- **`TRANSPORT_REQUEST` on `ZCA_PARAM_AREA`** (persisted): a managed RAP BO cannot keep a
  transient root field; the request must be on the root for the validations and the
  saver. It also documents the request of the last maintenance session.
- **No delete of areas in the app:** the request of a deleted root cannot be read in the
  save. Areas are retired with `ACTIVE` = blank (runtime 002).
- **Range options without CP / NP:** patterns are PCRE only (house rule); a select-option
  can still be used in SQL `IN`.
- **Flags on standard domain `XFELD`** instead of own domains.
- **`get_time`** added (value type TIME exists).
- **`MANDATORY`** also rejects a blank single value row (except BOOL), not only a missing
  row without default.
- **One app, three levels** (Area -> Definition -> Value) instead of separate apps: one
  draft, one lock, one request per area.
- **Types in `ZIF_CA_PARAM_TYPES`** (also the app's constants), the system boundary
  (`ZIF_CA_PARAM_SYSTEM`) in `ZCA_PARAM_UI`.
- **Client field named `CLIENT`** in the customizing tables (draft tables: `MANDT`).
- **Client mode** uses T000 (role, change option) and the business configuration API
  together: T000 alone would allow a client the API refuses, the API alone does not tell a
  production client.
