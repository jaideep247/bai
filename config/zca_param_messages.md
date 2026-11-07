# Message class ZCA_PARAM

Source of the message class ZCA_PARAM. `tools/abapgit_serialize.py` writes
`src/zca_param.msag.xml` from the table below; `tools/checks.py` compares it
with the constants `ZIF_CA_PARAM_TYPES=>GC_MSG` (every constant has a row, every
text is at most 73 characters).

Placeholders: `&1` area, `&2` parameter name, `&3` value / row / field,
`&4` type / limit / interface (unless the text says otherwise).

## Runtime (001-039)

| No | Constant | Text |
|---|---|---|
| 001 | area_unknown | Parameter area &1 does not exist |
| 002 | area_inactive | Parameter area &1 is not active |
| 003 | name_unknown | Parameter &2 is not defined in area &1 |
| 004 | mandatory_missing | Mandatory parameter &1 / &2 has no value |
| 005 | single_multiple | Parameter &1 / &2 is a single value but has &3 value rows |
| 006 | type_invalid | Value '&3' of parameter &1 / &2 is not a valid &4 |
| 007 | below_min | Value &3 of parameter &1 / &2 is below the minimum &4 |
| 008 | above_max | Value &3 of parameter &1 / &2 is above the maximum &4 |
| 009 | pattern_mismatch | Value '&3' of parameter &1 / &2 does not match the allowed pattern |
| 010 | pattern_invalid | Allowed pattern '&3' of parameter &1 / &2 is not valid PCRE |
| 011 | ddic_unknown | DDIC type &3 of parameter &1 / &2 does not exist |
| 012 | class_unknown | Class &3 of parameter &1 / &2 does not exist |
| 013 | class_no_intf | Class &3 of parameter &1 / &2 does not implement &4 |
| 014 | type_mismatch | Parameter &1 / &2 has value type &3 and cannot be read as &4 |
| 015 | kind_mismatch | Parameter &1 / &2 has kind &3 and cannot be read as &4 |
| 016 | row_not_list | Row &3 of parameter &1 / &2 has sign/option &4; a list needs I EQ |
| 017 | row_invalid | Row &3 of parameter &1 / &2: sign/option/high '&4' not valid |
| 018 | no_value | Parameter &1 / &2 has no value and no default |
| 019 | name_invalid | Name '&3' is invalid: A-Z, 0-9, _; it must start with a letter |
| 020 | kind_invalid | Kind '&3' of parameter &1 / &2 is not valid (P or S) |
| 021 | vtype_invalid | Value type '&3' of parameter &1 / &2 is not valid |
| 022 | field_not_allowed | Field &3 is not allowed for value type &4 (parameter &1 / &2) |
| 023 | min_above_max | Minimum &3 is greater than maximum &4 (parameter &1 / &2) |
| 024 | intf_unknown | Interface &3 of parameter &1 / &2 does not exist |
| 025 | list_needs_single | Value type LIST needs kind P (parameter &1 / &2) |

## Maintenance app (040-059)

| No | Constant | Text |
|---|---|---|
| 040 | request_missing | Enter an open customizing request for the changes to area &1 |
| 041 | request_unknown | Request &1 does not exist |
| 042 | request_not_cust | Request &1 is not a customizing request or task |
| 043 | request_released | Request &1 is not modifiable (released or locked) |
| 044 | config_not_allowed | Area &1: areas and definitions are maintained only by transport |
| 045 | value_not_editable | Values of parameter &1 / &2 cannot be changed in this client |
| 046 | not_authorized | No authorization for activity &2 in parameter area &1 |
| 047 | record_failed | Changes could not be recorded on request &1 |
