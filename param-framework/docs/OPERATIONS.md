# Operations - ZCA_PARAM parameter framework

> **First principle:** every change to a parameter is a production change; it must be
> attributable, reversible and explainable from the logs alone.
> **Analogy:** a flight log - who changed which setting, when, from what to what.

## 1. Maintenance in SM30 / SPRO

The three tables are customizing tables (delivery class C) maintained with the table
maintenance generator in one function group, `ZCA_PARAM_MAINT`, and one view cluster,
`ZCA_PARAM_VC` (Area -> Definition -> Value), reached by transaction `ZCA_PARAM` (SM34)
or the SPRO activity of the consuming system.

| Client | Maintenance | Request |
|---|---|---|
| Development, customizing client (automatic recording) | areas, definitions, value rows, deletions | customizing request, asked by SM34 on save |
| QA, production | none (client setting SCC4: no changes) | changes come by transport |

Save checks: event 01 of each table (`sm30/lzca_param_maintf01.abap`) applies
`ZCL_CA_PARAM_VALIDATOR`, the rules the runtime applies on every read. The first error
stops the save. A definition change re-checks the stored value rows of that parameter.

### One-time setup (per system landscape)

1. SE11: the three tables are *Display/Maintenance Allowed* (abapGit sets it).
2. Table maintenance generator for each table, all in function group `ZCA_PARAM_MAINT`,
   authorization group of the owning team (or `&NC&`); `ZCA_PARAM_AREA` one step,
   `ZCA_PARAM_DEF` two step, `ZCA_PARAM_VAL` one step; propose new screen numbers each time.
3. Create include `LZCA_PARAM_MAINTF01` in the function group from
   `sm30/lzca_param_maintf01.abap`; assign event 01 of each table
   (*Environment -> Modification -> Events*): `ZCA_AREA_BEFORE_SAVE`,
   `ZCA_DEF_BEFORE_SAVE`, `ZCA_VAL_BEFORE_SAVE`.
4. SE54 view cluster `ZCA_PARAM_VC`: `ZCA_PARAM_AREA` (root) -> `ZCA_PARAM_DEF`
   (key `AREA`) -> `ZCA_PARAM_VAL` (keys `AREA`, `NAME`); generate the field dependencies.
5. SE93 transaction `ZCA_PARAM`: parameter transaction of `SM34`,
   `VIEWCLUSTERNAME = ZCA_PARAM_VC`, `UPDATE = X`.
6. SOBJ customizing object `ZCA_PARAM_VC` (type C), then an IMG activity
   (`S_IMG_EXTENSION`, enhancement of `SIMG_SPRO`) on that object.
7. VERIFY in development: an invalid row (wrong pattern, second row of a single value)
   is refused from SM34 as well as from SM30. If event 01 does not run inside the
   cluster, assign the same forms to the cluster's before-save event in SE54.

Effect of a change: a reader that already buffered the area keeps the old value until
`refresh` or the end of its session; other application servers see the change after table
buffer synchronization (`rdisp/bufreftime`). Long-running jobs refresh at run start.

## 2. Audit

- **Table logging** is on for `ZCA_PARAM_AREA`, `ZCA_PARAM_DEF`, `ZCA_PARAM_VAL`
  (technical setting *log data changes*). It records only where Basis has enabled
  profile parameter `rec/client` for the client (check in RZ11; VERIFY with Basis).
  Evaluate with transaction **SCU3** (table history: table name, time frame) - old and
  new values, user and time of every change.
- **Transports:** every change in the development client is recorded on a customizing
  request (SE01 / SE10, object list `TABU` entries of the three tables, or SM30
  *Utilities -> Change logs*).

## 3. Authorizations

SM30 / SM34 check `S_TABU_DIS` (authorization group of the table maintenance) or
`S_TABU_NAM` (table name), plus `S_TCODE` for `ZCA_PARAM` and SPRO.

| Role (suggestion) | Authorization | Clients |
|---|---|---|
| Team maintainer | `S_TABU_DIS` ACTVT 02 for the team's authorization group | development customizing client |
| Display / support | `S_TABU_DIS` ACTVT 03 | all |

The authorization object `ZCA_PARAM` (field `ZCA_PARAR`, area) stays available for a
check per area; it is not used by the standard maintenance.

Runtime reads need no authorization - parameters must not hold secrets (passwords,
tokens); use SSF / secure store for those.

## 4. Troubleshooting by message (class ZCA_PARAM)

| No | Meaning | Typical cause | Fix |
|---|---|---|---|
| 001 | area does not exist | typo in the constant, area not transported | create the area / import the request |
| 002 | area not active | area retired or not yet released | set Active (by transport) or remove the reader |
| 003 | parameter not defined | definition not transported, typo | define it (by transport) |
| 004 | mandatory parameter without value | no row and no default, or blank row | maintain a value |
| 005 | single value with several rows | rows loaded outside SM30 (e.g. direct table load) | delete the extra rows (development, by transport) |
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
| 026 | context value for a dimension the definition does not declare | row maintained for a context the definition does not have (or the dimension was removed) | declare the dimension on the definition or clear the context value |
| 027 | context value not in upper case | row loaded outside SM30 | correct the context value (upper case) |
| 028-029 | context dimension invalid, gap or repeat | definition maintained outside SM30 | declare dimensions from Context 1 on, each once |
| 019-025 | definition rules (name, kind, type, field not allowed, min > max, interface, LIST with S) | save in SM30 / SM34 | correct the definition |

Which row drives a context: `get_effective_context( iv_area iv_name it_context )` returns the
context a read uses and its number of rows (0 = default) - e.g. from a test report or the
debugger, without running the process. Checking a value: SE16 display of `ZCA_PARAM_VAL` (area, name) and
`ZCA_PARAM_DEF`; the effective value includes the default and the rules of
`docs/DESIGN.md` section 3.
