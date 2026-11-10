# Onboarding - using ZCA_PARAM in your team

> **First principle:** the developer who reads a parameter defines it; operations only
> changes values that development explicitly released.
> **Analogy:** a thermostat - the installer fixes the allowed range and wiring, the
> occupant turns the dial within it.

Five steps. Steps 1-3 happen in the customizing client of the development system (the
client that records customizing changes); everything travels by customizing request.

## 1. Register an area

Open the app *Parameter areas* (service binding `ZUI_CA_PARAM_O4`), choose *Create*:

| Field | Rule |
|---|---|
| Area | upper case, `A-Z 0-9 _`, starts with a letter, at most 16 characters, e.g. `CD_EBS`, `MM_INBOUND` |
| Description, Owner team | mandatory in practice: who answers questions about this area |
| Editable in production | X only if operations may change released values in QA / production without a transport |
| Active | X (blank = every read raises 002) |
| Customizing request | an open customizing request or task (checked on save) |

You need authorization object `ZCA_PARAM` with activity 01 (and 02 for your area).

## 2. Define parameters (by transport)

In the area, section *Parameters*, create one definition per parameter:

| Field | Meaning |
|---|---|
| Name | upper case identifier, at most 30 characters, unique in the area |
| Kind | P = single value; S = select-option (list or range) |
| Value type | INT, DEC, CHAR, BOOL, DATE (YYYYMMDD), TIME (HHMMSS), LIST (P only: comma / semicolon list), PCRE, DDIC (type name), CLASS (class name) |
| Min / Max | INT, DEC, DATE, TIME only |
| Default | used when no value row exists; validated like a value |
| Allowed PCRE | optional; must match the **whole** value, case ignored (LIST: each element) |
| Interface | CLASS only: the class must implement it |
| Mandatory | a value or a default must exist (a blank single value is rejected, except BOOL) |
| Developer-owned | X (default for new definitions) = values change only by transport; clear it to let production change existing values of a production-editable area |

The app refuses inconsistent definitions with the same rules the runtime applies
(messages 006-025).

## 3. Maintain values

Under a parameter, section *Values*. Row numbers are assigned automatically.

- Kind P: at most **one** row (005 otherwise); sign / option are I / EQ.
- Kind S: any number of rows with sign I / E and option EQ NE GT GE LT LE BT NB (BT / NB
  need *High*). No CP / NP: use value type PCRE for patterns.
- BOOL: `X` = on, **blank row = off**, no row = default. If production should be able to
  switch the flag, deliver a row (rows cannot be created in production).
- In QA / production only existing values of production-editable, non developer-owned
  parameters can be changed (no request; table logging audits the change).

## 4. Read in code

Declare area and names as constants of your types interface, read through the factory
and handle the exception where it matters for your process:

```abap
CONSTANTS:
  BEGIN OF gc_param,
    area        TYPE zif_ca_param_types=>ty_area VALUE 'MM_INBOUND',
    max_items   TYPE zif_ca_param_types=>ty_name VALUE 'MAX_ITEMS',
    send_mail   TYPE zif_ca_param_types=>ty_name VALUE 'SEND_MAIL',
    plants      TYPE zif_ca_param_types=>ty_name VALUE 'PLANTS',
    parser_cls  TYPE zif_ca_param_types=>ty_name VALUE 'PARSER_CLASS',
  END OF gc_param.

TRY.
    DATA(lo_param) = zcl_ca_param_factory=>get( ).
    lo_param->refresh( gc_param-area ).                       " batch: once per run
    DATA(lv_max)    = lo_param->get_int( iv_area = gc_param-area iv_name = gc_param-max_items ).
    DATA(lv_mail)   = lo_param->get_bool( iv_area = gc_param-area iv_name = gc_param-send_mail ).
    DATA(lt_plants) = lo_param->get_range( iv_area = gc_param-area iv_name = gc_param-plants ).
    IF lt_plants IS INITIAL.
      " nothing configured - do not select "all plants" by accident
    ENDIF.
    DATA(lv_class)  = lo_param->get_value( iv_area = gc_param-area iv_name = gc_param-parser_cls ).
    " CLASS value: existing class implementing the definition's interface (validated)
  CATCH zcx_ca_param INTO DATA(lx_error).
    " report lx_error->get_text( ) / lx_error->get_message( ); stop or degrade explicitly
ENDTRY.
```

| Need | Method | Value type / kind |
|---|---|---|
| any single value as text | `get_value` | any, P |
| integer / decimal | `get_int` / `get_dec` | INT / DEC or INT, P |
| flag | `get_bool` | BOOL, P |
| date / time | `get_date` / `get_time` | DATE / TIME, P |
| list of texts | `get_list` | LIST (P) or rows I EQ (S) |
| select-option | `get_range` | S |
| maintained at all? | `is_set` | any |
| rules of a parameter | `get_definition` | any |

Rules of thumb: never catch `ZCX_CA_PARAM` to substitute a hard-coded value (define a
default instead); never pass a DDIC / CLASS value anywhere but as a name.

## 5. Test with the in-memory DAO

Your unit tests run the real framework logic over in-memory data - no database, no
second implementation of the semantics:

```abap
METHOD setup.
  DATA(lo_dao) = NEW zcl_ca_param_builder( )->area( zif_mm_types=>gc_param-area
    )->param( iv_name = zif_mm_types=>gc_param-max_items iv_value_type = zif_ca_param_types=>gc_value_type-int
              iv_default = '10' )->row( '25'
    )->param( iv_name = zif_mm_types=>gc_param-send_mail iv_value_type = zif_ca_param_types=>gc_value_type-bool
              iv_default = zif_ca_param_types=>gc_true )->row( space )      " switched off
    )->dao( ).
  zcl_ca_param_injector=>inject_dao( lo_dao ).   " code under test calls zcl_ca_param_factory=>get( )
ENDMETHOD.

METHOD teardown.
  zcl_ca_param_injector=>reset( ).
ENDMETHOD.
```

- `->build( )` returns a `ZIF_CA_PARAM` directly when the class under test takes the
  reader as a constructor parameter.
- `zcl_ca_param_injector=>inject( lo_double )` replaces the reader completely (for
  example a `cl_abap_testdouble` of `zif_ca_param` to force an exception).
- `ZCL_CA_PARAM_DAO_MEM->read_count( )` proves buffering / refresh in your own tests.

## 6. Moving an existing parameter interface onto ZCA_PARAM

A consumer with its own parameter interface (first consumer: the payment engine
operations suite, `ZIF_CD_OPS_PARAMS`) keeps its callers and adds one adapter class:

1. One area per functional area of the consumer (e.g. `CD_OPS`, `CD_EBS`, `CD_FMON`,
   `CD_HCK`); the adapter derives the area from the parameter name with a constant
   prefix table, names stay unchanged (at most 30 characters).
2. A definition for **every** name the code reads, including names completed at run time
   (`ALERT_<route>`, `RETENTION_DAYS_<target>`, ...): enumerate them - an undefined name
   raises 003. Value type from the reading code (integer helpers -> INT, flags -> BOOL,
   comma lists -> LIST, select-options -> kind S), the delivered default constant as
   DEFAULT_VALUE.
3. The adapter maps `get_param` to `get_value` (BOOL: `get_bool` as `X` or blank - the
   operations suite's callers compare with `X`, so an off flag reaches them as blank and the
   caller's default never overrides a resolved value or a definition default), `get_range` to
   `get_range` (kind S) or to `get_list` turned into I EQ rows (LIST), `refresh_params`
   to `refresh( )`.
4. An interface without `RAISING` cannot pass `ZCX_CA_PARAM` on: the adapter records the
   message (finding / application log) and returns the caller's default - a documented
   transition rule, to be removed when callers move to the typed getters.
5. Tests: the consumer's in-memory parameter fake is replaced by `ZCL_CA_PARAM_DAO_MEM`
   behind the adapter, so the consumer's tests exercise the real semantics.

### 6a. Seed files (delivered areas, definitions and example values)

The framework itself delivers no data; a consumer delivers its areas and definitions as
seed files next to its code (e.g. `config/param_areas.csv`, `config/param_definitions.csv`,
`config/param_values.csv` of the consumer's component) and enters them in the app in the customizing
client on a customizing request (no SM30, no direct table load). Format - UTF-8 CSV, header
row exactly as below, one row per table row, flags `X` or blank, a field with a comma in
double quotes:

| File | Columns (= fields of the table) |
|---|---|
| `param_areas.csv` (`ZCA_PARAM_AREA`) | `AREA,DESCRIPTION,OWNER_TEAM,PROD_EDITABLE,ACTIVE` |
| `param_definitions.csv` (`ZCA_PARAM_DEF`) | `AREA,NAME,KIND,VALUE_TYPE,MIN_VALUE,MAX_VALUE,DEFAULT_VALUE,ALLOWED_PCRE,INTERFACE_NAME,MANDATORY,DEVELOPER_OWNED,DESCRIPTION,OWNER` |
| `param_values.csv` (`ZCA_PARAM_VAL`, optional) | `AREA,NAME,NUMB,SIGN,OPTI,LOW,HIGH` |

Rules a consumer's check should apply before a row is entered (the app applies them again
on save): area and name are identifiers (16 / 30 characters), description at most 60, owner
at most 30 characters; the section 2 rules per value type; rows sorted by area and name;
value rows only for defined names, kind P with one row `NUMB` 1, `I` / `EQ`. Values in
`param_values.csv` are examples to confirm per landscape - production values are maintained
in the app, never transported from a seed. The operations suite generates its in-memory test
data (`ZCL_CD_OPS_PARAM_SEED`) from these files and checks them against its code
(`tools/param_definitions.py`).
