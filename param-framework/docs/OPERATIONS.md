# Operations - ZCA_PARAM parameter framework

> **First principle:** every change to a parameter is a production change; it must be
> attributable, reversible and explainable from the logs alone.
> **Analogy:** a flight log - who changed which setting, when, from what to what.

## 1. Maintenance

| Client | What can be done in the app | Request |
|---|---|---|
| Development, customizing client (automatic recording) | everything: areas, definitions, value rows, deletions | mandatory, entered on the area |
| QA, production, clients without recording | change existing value rows of parameters that are **not** developer-owned in areas that are **production-editable** | none |

Anything else is read-only in the app (feature control) and rejected on save (044 / 045).
New values or new parameters always come by transport from development.

Effect of a change: a reader that already buffered the area keeps the old value until
`refresh` or the end of its session; other application servers see the change after table
buffer synchronization (`rdisp/bufreftime`). Long-running jobs refresh at run start.

## 2. Audit

- **Table logging** is on for `ZCA_PARAM_AREA`, `ZCA_PARAM_DEF`, `ZCA_PARAM_VAL`
  (technical setting *log data changes*). It records only where Basis has enabled
  profile parameter `rec/client` for the client (check in RZ11; VERIFY with Basis).
  Evaluate with transaction **SCU3** (table history: table name, time frame) - shows old
  and new values, user, time, also for changes made through the app in production.
- **Transports:** every change in the development client is recorded on the customizing
  request entered on the area (SE01 / SE10, object list `TABU` entries of the three
  tables). The area shows the request of its last maintenance session.
- **Admin fields:** created / last changed by and at on every row (app and SE16 display).

## 3. Authorizations

Object `ZCA_PARAM`, fields `ZCA_PARAR` (area, patterns like `CD_*` allowed in roles) and
`ACTVT`:

| Role (suggestion) | ACTVT | Areas | Clients |
|---|---|---|---|
| Team maintainer | 01, 02, 03, 06 | own areas | development customizing client |
| Production key user | 02, 03 | production-editable areas of the team | QA, production |
| Display / support | 03 | `*` | all |

Runtime reads need no authorization - parameters must not hold secrets (passwords,
tokens); use SSF / secure store for those.

## 4. Troubleshooting by message (class ZCA_PARAM)

| No | Meaning | Typical cause | Fix |
|---|---|---|---|
| 001 | area does not exist | typo in the constant, area not transported | create the area / import the request |
| 002 | area not active | area retired or not yet released | set Active (by transport) or remove the reader |
| 003 | parameter not defined | definition not transported, typo | define it (by transport) |
| 004 | mandatory parameter without value | no row and no default, or blank row | maintain a value |
| 005 | single value with several rows | rows created outside the app (e.g. direct table load) | delete the extra rows (development, by transport) |
| 006 | value not valid for the type | e.g. `abc` for INT, `20260230` for DATE, PCRE does not compile, decimal comma | correct the value |
| 007 / 008 | below minimum / above maximum | value outside the defined range | correct the value or the definition |
| 009 | value does not match the allowed pattern | pattern is matched to the whole value | correct the value or the pattern |
| 010 | allowed pattern is not valid PCRE | definition error | correct the definition |
| 011 | DDIC type does not exist | table / structure not in this system | transport the object or correct the value |
| 012 / 013 | class missing / does not implement the interface | class not transported, wrong class | correct the value or transport the class |
| 014 / 015 | wrong getter for type / kind | code reads e.g. `get_int` on CHAR, `get_range` on P | align code and definition |
| 016 | select-option row not I EQ read as list | NE / BT / E row in a list parameter | use `get_range` or only I EQ rows |
| 017 | invalid sign / option / high in a row | BT without high, high on EQ, sign other than I / E | correct the row |
| 018 | typed read without value and default | not maintained, no default | maintain a value or a default |
| 019-025 | definition rules (name, kind, type, field not allowed, min > max, interface, LIST with S) | app save | correct the definition |
| 040-043 | customizing request missing / unknown / not customizing / not modifiable | app save in development | enter an open customizing request or task |
| 044 | definitions / areas only by transport | change attempted in QA / production | change in development |
| 045 | value not changeable in this client | area not production-editable or parameter developer-owned | change in development, or release the parameter (by transport) |
| 047 | recording on the request failed | request locked or released meanwhile, CTS problem | the save is rolled back (short dump); check the request (SE01) and save again |
| 048 | client check failed: customizing not editable, reason in the message | the business configuration API raised (VERIFY-ADT name, missing authorisation, client settings) | the app stays read-only for areas and definitions (fail closed); fix the reason shown and reopen the app |

Checking a value without the app: SE16 display of `ZCA_PARAM_VAL` (area, name) and
`ZCA_PARAM_DEF`; the effective value includes the default and the rules of
`docs/DESIGN.md` section 3.
