*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_rules.clas.abap
*& Purpose:
*& Pure rules of the clearing-account break analysis: which bucket rules
*& apply to an account (area or *, active, account pattern; validated -
*& an invalid rule is left out with a configuration problem), the values
*& of the groups (lines, debits, credits, net, age, lines after the key
*& date that clear the group), and the classification: every journal line
*& open at the key date gets the bucket of the first rule (by sequence)
*& whose conditions all hold - FIELD of the line, GROUP of its group, DAYS
*& window, LINK to an object of the link registry (rows read beforehand);
*& a line no rule explains is OTHER. A group gets the bucket and rule of its
*& oldest open line (the line open longest is the break), with the reason
*& "rule ID: reason"; OTHER when that line is unexplained. A value list given as @PARAMETER that is
*& blank never matches. No database, no state: tests prove every rule.
*& Modification log:
*& 2026-11-11 | Initial version (build F: clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - break analysis rules (pure)</p>
"! First match wins, explainable: the rule ID and reason go with every classified line and group. Read-only:
"! the analysis explains open lines, it never matches, clears or posts them.
CLASS zcl_ca_ops_brk_rules DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Separator of the rule ID and its reason in the reason text of a group
    CONSTANTS gc_reason_separator TYPE string VALUE `: `.

    "! The rules that apply to an account, in order (sequence, rule ID), and their conditions; a rule with an
    "! invalid bucket, pattern, condition kind, field, operator or link is left out (problem)
    "! @parameter it_links | Links of the registry effective from the line's object (S4_JOURNAL_ITEM)
    CLASS-METHODS effective_rules
      IMPORTING
        it_rules    TYPE zif_ca_ops_brk_types=>tt_rule
        it_conds    TYPE zif_ca_ops_brk_types=>tt_cond
        it_buckets  TYPE zif_ca_ops_brk_types=>tt_bucket
        it_links    TYPE zif_ca_ops_link_types=>tt_link_id
        it_params   TYPE zif_ca_ops_brk_types=>tt_param_list
        iv_area     TYPE zif_ca_ops_types=>ty_area
        iv_acct_id  TYPE zif_ca_ops_brk_types=>ty_acct_id
      EXPORTING
        et_rules    TYPE zif_ca_ops_brk_types=>tt_rule
        et_conds    TYPE zif_ca_ops_brk_types=>tt_cond
        et_problems TYPE zif_ca_ops_brk_types=>tt_problem.

    "! Parameter names of the @ values of the conditions (to be read once)
    CLASS-METHODS param_names
      IMPORTING
        it_conds        TYPE zif_ca_ops_brk_types=>tt_cond
      RETURNING
        VALUE(rt_names) TYPE string_table.

    "! Link IDs the LINK conditions read
    CLASS-METHODS link_ids
      IMPORTING
        it_conds        TYPE zif_ca_ops_brk_types=>tt_cond
      RETURNING
        VALUE(rt_links) TYPE zif_ca_ops_link_types=>tt_link_id.

    "! Classify the groups of one package and their lines
    "! @parameter it_sums     | Groups of the grouped read (order kept, numbered from iv_group_no + 1)
    "! @parameter it_items    | Their lines up to the key date and after it (LATER)
    "! @parameter it_rules    | Effective rules in order (EFFECTIVE_RULES)
    "! @parameter it_hits     | Rows of the linked objects per line and link
    CLASS-METHODS classify
      IMPORTING
        is_context  TYPE zif_ca_ops_brk_types=>ty_context
        it_sums     TYPE zif_ca_ops_brk_types=>tt_group_sum
        it_items    TYPE zif_ca_ops_brk_types=>tt_item
        it_rules    TYPE zif_ca_ops_brk_types=>tt_rule
        it_conds    TYPE zif_ca_ops_brk_types=>tt_cond
        it_hits     TYPE zif_ca_ops_brk_types=>tt_hit
        it_params   TYPE zif_ca_ops_brk_types=>tt_param_list
        it_buckets  TYPE zif_ca_ops_brk_types=>tt_bucket
        iv_group_no TYPE i DEFAULT 0
      EXPORTING
        et_groups   TYPE zif_ca_ops_brk_types=>tt_group
        et_items    TYPE zif_ca_ops_brk_types=>tt_item_result.

    "! Key of a journal line inside an analysis (ledger / company code / year / document / line)
    CLASS-METHODS line_key
      IMPORTING
        is_item       TYPE zif_ca_ops_brk_types=>ty_item
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_brk_types=>ty_line_key.

    "! Values of a condition: a comma list, a single value, or the list of the @ parameter it names
    CLASS-METHODS values_of
      IMPORTING
        iv_value         TYPE zif_ca_ops_brk_types=>ty_value
        iv_operator      TYPE zif_ca_ops_brk_types=>ty_operator
        it_params        TYPE zif_ca_ops_brk_types=>tt_param_list
      RETURNING
        VALUE(rt_values) TYPE string_table.

    "! Compare a value with the condition's operator and values; numbers compared as numbers when both are
    "! numbers. An operator that needs values never holds without them (a blank list explains nothing)
    CLASS-METHODS compare
      IMPORTING
        iv_actual       TYPE clike
        iv_operator     TYPE zif_ca_ops_brk_types=>ty_operator
        it_values       TYPE string_table
      RETURNING
        VALUE(rv_holds) TYPE abap_bool.

  PRIVATE SECTION.
    "! Values of a group a GROUP condition compares
    TYPES:
      BEGIN OF ty_group_values,
        lines          TYPE i,
        debits         TYPE i,
        credits        TYPE i,
        net_amount     TYPE zif_ca_ops_types=>ty_amount,
        age_days       TYPE i,
        clears_later   TYPE abap_bool,
        later_doc_type TYPE c LENGTH 2,
        days_to_clear  TYPE i,
      END OF ty_group_values.

    "! Evidence of a LINK condition that held: the linked row
    TYPES:
      BEGIN OF ty_evidence,
        object_id TYPE zif_ca_ops_link_types=>ty_object_id,
        row_key   TYPE zif_ca_ops_brk_types=>ty_link_key,
        value     TYPE zif_ca_ops_brk_types=>ty_link_value,
      END OF ty_evidence.

    CLASS-METHODS validate_rule
      IMPORTING
        is_rule     TYPE zif_ca_ops_brk_types=>ty_rule
        it_conds    TYPE zif_ca_ops_brk_types=>tt_cond
        it_buckets  TYPE zif_ca_ops_brk_types=>tt_bucket
        it_links    TYPE zif_ca_ops_link_types=>tt_link_id
        it_params   TYPE zif_ca_ops_brk_types=>tt_param_list
      CHANGING
        ct_problems TYPE zif_ca_ops_brk_types=>tt_problem
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    CLASS-METHODS field_known
      IMPORTING
        is_cond         TYPE zif_ca_ops_brk_types=>ty_cond
      RETURNING
        VALUE(rv_known) TYPE abap_bool.

    CLASS-METHODS group_values
      IMPORTING
        is_sum           TYPE zif_ca_ops_brk_types=>ty_group_sum
        it_lines         TYPE zif_ca_ops_brk_types=>tt_item
        iv_key_date      TYPE d
      RETURNING
        VALUE(rs_values) TYPE ty_group_values.

    CLASS-METHODS holds
      IMPORTING
        is_cond         TYPE zif_ca_ops_brk_types=>ty_cond
        is_item         TYPE zif_ca_ops_brk_types=>ty_item
        is_group        TYPE ty_group_values
        iv_key_date     TYPE d
        it_hits         TYPE zif_ca_ops_brk_types=>tt_hit
        it_params       TYPE zif_ca_ops_brk_types=>tt_param_list
      CHANGING
        cs_evidence     TYPE ty_evidence
      RETURNING
        VALUE(rv_holds) TYPE abap_bool.

    CLASS-METHODS link_holds
      IMPORTING
        is_cond         TYPE zif_ca_ops_brk_types=>ty_cond
        is_item         TYPE zif_ca_ops_brk_types=>ty_item
        it_hits         TYPE zif_ca_ops_brk_types=>tt_hit
        it_values       TYPE string_table
      CHANGING
        cs_evidence     TYPE ty_evidence
      RETURNING
        VALUE(rv_holds) TYPE abap_bool.

    CLASS-METHODS item_value
      IMPORTING
        is_item         TYPE zif_ca_ops_brk_types=>ty_item
        iv_field        TYPE zif_ca_ops_brk_types=>ty_field
      RETURNING
        VALUE(rv_value) TYPE string.

    CLASS-METHODS group_value
      IMPORTING
        is_group        TYPE ty_group_values
        iv_field        TYPE zif_ca_ops_brk_types=>ty_field
      RETURNING
        VALUE(rv_value) TYPE string.

    CLASS-METHODS days_value
      IMPORTING
        is_item        TYPE zif_ca_ops_brk_types=>ty_item
        iv_field       TYPE zif_ca_ops_brk_types=>ty_field
        iv_key_date    TYPE d
      RETURNING
        VALUE(rv_days) TYPE i.

    CLASS-METHODS as_number
      IMPORTING
        iv_value         TYPE clike
      EXPORTING
        ev_number        TYPE decfloat34
      RETURNING
        VALUE(rv_number) TYPE abap_bool.

    "! Parameter name of an @ value (upper case); blank when the value is not a parameter reference
    CLASS-METHODS param_of
      IMPORTING
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_name) TYPE string.

    CLASS-METHODS problem
      IMPORTING
        iv_rule_id  TYPE zif_ca_ops_brk_types=>ty_rule_id
        iv_msgno    TYPE zif_ca_ops_types=>ty_msgno
        iv_v1       TYPE clike OPTIONAL
        iv_v2       TYPE clike OPTIONAL
        iv_v3       TYPE clike OPTIONAL
        iv_v4       TYPE clike OPTIONAL
      CHANGING
        ct_problems TYPE zif_ca_ops_brk_types=>tt_problem.

ENDCLASS.



CLASS zcl_ca_ops_brk_rules IMPLEMENTATION.

  METHOD effective_rules.
    CLEAR: et_rules, et_conds, et_problems.
    LOOP AT it_rules ASSIGNING FIELD-SYMBOL(<ls_rule>)
         WHERE active = abap_true AND ( area = iv_area OR area = zif_ca_ops_brk_types=>gc_area_any ).
      IF <ls_rule>-acct_pattern IS NOT INITIAL
         AND zcl_ca_ops_util=>pcre_valid( <ls_rule>-acct_pattern ) = abap_true
         AND zcl_ca_ops_util=>pcre_match( iv_value = iv_acct_id iv_pattern = <ls_rule>-acct_pattern ) = abap_false.
        " the rule is for other accounts
        CONTINUE.
      ENDIF.
      DATA(lt_own) = VALUE zif_ca_ops_brk_types=>tt_cond( FOR ls_cond IN it_conds
                                                          WHERE ( area = <ls_rule>-area AND rule_id = <ls_rule>-rule_id )
                                                          ( ls_cond ) ).
      IF validate_rule( EXPORTING is_rule     = <ls_rule>
                                  it_conds    = lt_own
                                  it_buckets  = it_buckets
                                  it_links    = it_links
                                  it_params   = it_params
                        CHANGING  ct_problems = et_problems ) = abap_false.
        CONTINUE.
      ENDIF.
      INSERT <ls_rule> INTO TABLE et_rules.
      INSERT LINES OF lt_own INTO TABLE et_conds.
    ENDLOOP.
    SORT et_rules BY seq rule_id.
    SORT et_conds BY rule_id cond_no.
  ENDMETHOD.


  METHOD validate_rule.
    rv_valid = abap_true.
    READ TABLE it_buckets ASSIGNING FIELD-SYMBOL(<ls_bucket>) WITH TABLE KEY bucket = is_rule-bucket.
    IF sy-subrc <> 0 OR <ls_bucket>-active = abap_false.
      problem( EXPORTING iv_rule_id = is_rule-rule_id iv_msgno = zif_ca_ops_brk_types=>gc_msg-bucket_unknown
                         iv_v1 = is_rule-rule_id iv_v2 = is_rule-bucket
               CHANGING  ct_problems = ct_problems ).
      rv_valid = abap_false.
    ENDIF.
    IF zcl_ca_ops_util=>pcre_valid( is_rule-acct_pattern ) = abap_false.
      problem( EXPORTING iv_rule_id = is_rule-rule_id iv_msgno = zif_ca_ops_brk_types=>gc_msg-pattern
                         iv_v1 = is_rule-rule_id iv_v2 = is_rule-acct_pattern
               CHANGING  ct_problems = ct_problems ).
      rv_valid = abap_false.
    ENDIF.
    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>).
      DATA(lv_kind) = to_upper( condense( <ls_cond>-cond_kind ) ).
      DATA(lv_op) = to_upper( condense( <ls_cond>-operator ) ).
      IF field_known( <ls_cond> ) = abap_false.
        problem( EXPORTING iv_rule_id = is_rule-rule_id iv_msgno = zif_ca_ops_brk_types=>gc_msg-field_unknown
                           iv_v1 = is_rule-rule_id iv_v2 = <ls_cond>-cond_no iv_v3 = <ls_cond>-field iv_v4 = lv_kind
                 CHANGING  ct_problems = ct_problems ).
        rv_valid = abap_false.
      ENDIF.
      DATA(lv_link_op) = xsdbool( lv_op = zif_ca_ops_brk_types=>gc_op-ex OR lv_op = zif_ca_ops_brk_types=>gc_op-nx ).
      IF NOT ( lv_op = zif_ca_ops_brk_types=>gc_op-eq OR lv_op = zif_ca_ops_brk_types=>gc_op-ne
            OR lv_op = zif_ca_ops_brk_types=>gc_op-in OR lv_op = zif_ca_ops_brk_types=>gc_op-ni
            OR lv_op = zif_ca_ops_brk_types=>gc_op-ge OR lv_op = zif_ca_ops_brk_types=>gc_op-le
            OR lv_op = zif_ca_ops_brk_types=>gc_op-gt OR lv_op = zif_ca_ops_brk_types=>gc_op-lt
            OR lv_op = zif_ca_ops_brk_types=>gc_op-rx OR lv_op = zif_ca_ops_brk_types=>gc_op-bl
            OR lv_op = zif_ca_ops_brk_types=>gc_op-nb OR lv_link_op = abap_true )
         OR ( lv_link_op = abap_true AND lv_kind <> zif_ca_ops_brk_types=>gc_kind-link ).
        problem( EXPORTING iv_rule_id = is_rule-rule_id iv_msgno = zif_ca_ops_brk_types=>gc_msg-op_invalid
                           iv_v1 = is_rule-rule_id iv_v2 = <ls_cond>-cond_no iv_v3 = lv_op iv_v4 = lv_kind
                 CHANGING  ct_problems = ct_problems ).
        rv_valid = abap_false.
      ENDIF.
      IF lv_kind = zif_ca_ops_brk_types=>gc_kind-link AND NOT line_exists( it_links[ table_line = <ls_cond>-link_id ] ).
        problem( EXPORTING iv_rule_id = is_rule-rule_id iv_msgno = zif_ca_ops_brk_types=>gc_msg-link_unknown
                           iv_v1 = is_rule-rule_id iv_v2 = <ls_cond>-cond_no iv_v3 = <ls_cond>-link_id
                           iv_v4 = zif_ca_ops_brk_types=>gc_item_object
                 CHANGING  ct_problems = ct_problems ).
        rv_valid = abap_false.
      ENDIF.
      IF lv_op = zif_ca_ops_brk_types=>gc_op-rx AND zcl_ca_ops_util=>pcre_valid( <ls_cond>-cond_value ) = abap_false.
        problem( EXPORTING iv_rule_id = is_rule-rule_id iv_msgno = zif_ca_ops_brk_types=>gc_msg-pattern
                           iv_v1 = is_rule-rule_id iv_v2 = <ls_cond>-cond_value
                 CHANGING  ct_problems = ct_problems ).
        rv_valid = abap_false.
      ENDIF.
      " a blank list parameter keeps the rule, but it explains nothing until the parameter has a value
      DATA(lv_name) = param_of( <ls_cond>-cond_value ).
      IF lv_name IS NOT INITIAL.
        IF values_of( iv_value = <ls_cond>-cond_value iv_operator = zif_ca_ops_brk_types=>gc_op-in it_params = it_params )
           IS INITIAL.
          problem( EXPORTING iv_rule_id = is_rule-rule_id iv_msgno = zif_ca_ops_brk_types=>gc_msg-param_blank
                             iv_v1 = is_rule-rule_id iv_v2 = <ls_cond>-cond_no iv_v3 = lv_name
                   CHANGING  ct_problems = ct_problems ).
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD field_known.
    DATA(lv_field) = to_upper( condense( is_cond-field ) ).
    CASE to_upper( condense( is_cond-cond_kind ) ).
      WHEN zif_ca_ops_brk_types=>gc_kind-field.
        rv_known = xsdbool( lv_field = zif_ca_ops_brk_types=>gc_field-posting_date
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-document_date
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-doc_type
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-debit_credit
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-assignment
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-ref_type
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-recon_key
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-amount
                         OR lv_field = zif_ca_ops_brk_types=>gc_field-currency ).
      WHEN zif_ca_ops_brk_types=>gc_kind-group.
        rv_known = xsdbool( lv_field = zif_ca_ops_brk_types=>gc_group-lines
                         OR lv_field = zif_ca_ops_brk_types=>gc_group-debits
                         OR lv_field = zif_ca_ops_brk_types=>gc_group-credits
                         OR lv_field = zif_ca_ops_brk_types=>gc_group-net_amount
                         OR lv_field = zif_ca_ops_brk_types=>gc_group-age_days
                         OR lv_field = zif_ca_ops_brk_types=>gc_group-clears_later
                         OR lv_field = zif_ca_ops_brk_types=>gc_group-later_doc_type
                         OR lv_field = zif_ca_ops_brk_types=>gc_group-days_to_clear ).
      WHEN zif_ca_ops_brk_types=>gc_kind-days.
        rv_known = xsdbool( lv_field = zif_ca_ops_brk_types=>gc_days-period_end
                         OR lv_field = zif_ca_ops_brk_types=>gc_days-key_date ).
      WHEN zif_ca_ops_brk_types=>gc_kind-link.
        " any field of the linked object (checked against its runtime DDIC when it is read); blank = existence
        rv_known = abap_true.
      WHEN OTHERS.
        rv_known = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD param_names.
    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>).
      DATA(lv_name) = param_of( <ls_cond>-cond_value ).
      IF lv_name IS NOT INITIAL AND NOT line_exists( rt_names[ table_line = lv_name ] ).
        INSERT lv_name INTO TABLE rt_names.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD link_ids.
    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>)
         WHERE cond_kind = zif_ca_ops_brk_types=>gc_kind-link AND link_id IS NOT INITIAL.
      IF NOT line_exists( rt_links[ table_line = <ls_cond>-link_id ] ).
        INSERT <ls_cond>-link_id INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD line_key.
    rv_key = |{ is_item-ledger }{ zif_ca_ops_brk_types=>gc_key_separator }{ is_item-bukrs }|
          && |{ zif_ca_ops_brk_types=>gc_key_separator }{ is_item-gjahr }|
          && |{ zif_ca_ops_brk_types=>gc_key_separator }{ is_item-belnr }|
          && |{ zif_ca_ops_brk_types=>gc_key_separator }{ is_item-docln }|.
  ENDMETHOD.


  METHOD values_of.
    DATA lt_parts TYPE string_table.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    IF lv_value IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_name) = param_of( iv_value ).
    IF lv_name IS NOT INITIAL.
      READ TABLE it_params ASSIGNING FIELD-SYMBOL(<ls_param>) WITH TABLE KEY name = CONV #( lv_name ).
      IF sy-subrc = 0.
        rt_values = <ls_param>-values.
      ENDIF.
      RETURN.
    ENDIF.
    IF iv_operator = zif_ca_ops_brk_types=>gc_op-in OR iv_operator = zif_ca_ops_brk_types=>gc_op-ni
       OR iv_operator = zif_ca_ops_brk_types=>gc_op-ex OR iv_operator = zif_ca_ops_brk_types=>gc_op-nx.
      SPLIT lv_value AT zif_ca_ops_brk_types=>gc_list_separator INTO TABLE lt_parts.
      LOOP AT lt_parts INTO DATA(lv_part).
        lv_part = condense( lv_part ).
        IF lv_part IS NOT INITIAL.
          INSERT lv_part INTO TABLE rt_values.
        ENDIF.
      ENDLOOP.
    ELSE.
      INSERT lv_value INTO TABLE rt_values.
    ENDIF.
  ENDMETHOD.


  METHOD compare.
    DATA lv_actual_num TYPE decfloat34.
    DATA lv_value_num TYPE decfloat34.
    DATA(lv_actual) = condense( CONV string( iv_actual ) ).
    CASE iv_operator.
      WHEN zif_ca_ops_brk_types=>gc_op-bl.
        rv_holds = xsdbool( lv_actual IS INITIAL ).
        RETURN.
      WHEN zif_ca_ops_brk_types=>gc_op-nb.
        rv_holds = xsdbool( lv_actual IS NOT INITIAL ).
        RETURN.
    ENDCASE.
    IF it_values IS INITIAL.
      " a blank value list explains nothing
      RETURN.
    ENDIF.
    DATA(lv_value) = condense( it_values[ 1 ] ).
    CASE iv_operator.
      WHEN zif_ca_ops_brk_types=>gc_op-in OR zif_ca_ops_brk_types=>gc_op-ex.
        rv_holds = xsdbool( line_exists( it_values[ table_line = lv_actual ] ) ).
      WHEN zif_ca_ops_brk_types=>gc_op-ni OR zif_ca_ops_brk_types=>gc_op-nx.
        rv_holds = xsdbool( NOT line_exists( it_values[ table_line = lv_actual ] ) ).
      WHEN zif_ca_ops_brk_types=>gc_op-rx.
        rv_holds = zcl_ca_ops_util=>pcre_match( iv_value = lv_actual iv_pattern = lv_value ).
      WHEN OTHERS.
        IF as_number( EXPORTING iv_value = lv_actual IMPORTING ev_number = lv_actual_num ) = abap_true
           AND as_number( EXPORTING iv_value = lv_value IMPORTING ev_number = lv_value_num ) = abap_true.
          rv_holds = SWITCH #( iv_operator
                               WHEN zif_ca_ops_brk_types=>gc_op-eq THEN xsdbool( lv_actual_num = lv_value_num )
                               WHEN zif_ca_ops_brk_types=>gc_op-ne THEN xsdbool( lv_actual_num <> lv_value_num )
                               WHEN zif_ca_ops_brk_types=>gc_op-ge THEN xsdbool( lv_actual_num >= lv_value_num )
                               WHEN zif_ca_ops_brk_types=>gc_op-le THEN xsdbool( lv_actual_num <= lv_value_num )
                               WHEN zif_ca_ops_brk_types=>gc_op-gt THEN xsdbool( lv_actual_num > lv_value_num )
                               WHEN zif_ca_ops_brk_types=>gc_op-lt THEN xsdbool( lv_actual_num < lv_value_num ) ).
        ELSE.
          rv_holds = SWITCH #( iv_operator
                               WHEN zif_ca_ops_brk_types=>gc_op-eq THEN xsdbool( lv_actual = lv_value )
                               WHEN zif_ca_ops_brk_types=>gc_op-ne THEN xsdbool( lv_actual <> lv_value )
                               WHEN zif_ca_ops_brk_types=>gc_op-ge THEN xsdbool( lv_actual >= lv_value )
                               WHEN zif_ca_ops_brk_types=>gc_op-le THEN xsdbool( lv_actual <= lv_value )
                               WHEN zif_ca_ops_brk_types=>gc_op-gt THEN xsdbool( lv_actual > lv_value )
                               WHEN zif_ca_ops_brk_types=>gc_op-lt THEN xsdbool( lv_actual < lv_value ) ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD classify.
    DATA lt_lines TYPE zif_ca_ops_brk_types=>tt_item.
    DATA ls_evidence TYPE ty_evidence.
    CLEAR: et_groups, et_items.
    DATA(lv_group_no) = iv_group_no.
    DATA(lt_items) = it_items.
    SORT lt_items BY assignment currency posting_date belnr docln.

    LOOP AT it_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      lv_group_no += 1.
      CLEAR lt_lines.
      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_line>)
           WHERE assignment = <ls_sum>-assignment AND currency = <ls_sum>-currency.
        INSERT <ls_line> INTO TABLE lt_lines.
      ENDLOOP.
      DATA(ls_values) = group_values( is_sum = <ls_sum> it_lines = lt_lines iv_key_date = is_context-key_date ).
      DATA(ls_group) = VALUE zif_ca_ops_brk_types=>ty_group( group_no     = lv_group_no
                                                              assignment   = <ls_sum>-assignment
                                                              currency     = <ls_sum>-currency
                                                              amount       = <ls_sum>-amount
                                                              line_count   = <ls_sum>-line_count
                                                              first_date   = <ls_sum>-first_date
                                                              last_date    = <ls_sum>-last_date
                                                              age_days     = ls_values-age_days
                                                              clears_later = ls_values-clears_later ).
      " the group takes the explanation of its oldest open line (the line open longest is the break)
      DATA(lv_oldest_done) = abap_false.
      DATA(lv_best_rule) = VALUE zif_ca_ops_brk_types=>ty_rule( ).
      DATA(lv_item_no) = 0.
      LOOP AT lt_lines ASSIGNING <ls_line>.
        lv_item_no += 1.
        DATA(ls_result) = VALUE zif_ca_ops_brk_types=>ty_item_result( group_no = lv_group_no
                                                                      item_no  = lv_item_no
                                                                      item     = <ls_line> ).
        IF <ls_line>-later = abap_true.
          ls_group-later_amount += <ls_line>-amount.
          IF ls_group-later_date IS INITIAL OR <ls_line>-posting_date < ls_group-later_date.
            ls_group-later_date = <ls_line>-posting_date.
          ENDIF.
          INSERT ls_result INTO TABLE et_items.
          CONTINUE.
        ENDIF.
        IF ls_group-recon_key IS INITIAL.
          ls_group-recon_key = <ls_line>-recon_key.
        ENDIF.
        ls_result-bucket = zif_ca_ops_brk_types=>gc_bucket_other.
        LOOP AT it_rules ASSIGNING FIELD-SYMBOL(<ls_rule>).
          CLEAR ls_evidence.
          DATA(lv_all) = abap_true.
          LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>)
               WHERE area = <ls_rule>-area AND rule_id = <ls_rule>-rule_id.
            IF holds( EXPORTING is_cond     = <ls_cond>
                                is_item     = <ls_line>
                                is_group    = ls_values
                                iv_key_date = is_context-key_date
                                it_hits     = it_hits
                                it_params   = it_params
                      CHANGING  cs_evidence = ls_evidence ) = abap_false.
              lv_all = abap_false.
              EXIT.
            ENDIF.
          ENDLOOP.
          IF lv_all = abap_true.
            " first match wins
            ls_result-bucket      = <ls_rule>-bucket.
            ls_result-rule_id     = <ls_rule>-rule_id.
            ls_result-link_object = ls_evidence-object_id.
            ls_result-link_key    = ls_evidence-row_key.
            ls_result-link_value  = ls_evidence-value.
            IF lv_oldest_done = abap_false.
              lv_best_rule = <ls_rule>.
            ENDIF.
            EXIT.
          ENDIF.
        ENDLOOP.
        lv_oldest_done = abap_true.
        INSERT ls_result INTO TABLE et_items.
      ENDLOOP.

      IF lv_best_rule IS INITIAL.
        ls_group-bucket = zif_ca_ops_brk_types=>gc_bucket_other.
      ELSE.
        ls_group-bucket  = lv_best_rule-bucket.
        ls_group-rule_id = lv_best_rule-rule_id.
        ls_group-reason  = condense( |{ lv_best_rule-rule_id }{ gc_reason_separator }{ lv_best_rule-reason }| ).
        READ TABLE it_buckets ASSIGNING FIELD-SYMBOL(<ls_bucket>) WITH TABLE KEY bucket = lv_best_rule-bucket.
        ls_group-explained = xsdbool( sy-subrc = 0 AND <ls_bucket>-explained = abap_true
                                      AND lv_best_rule-bucket <> zif_ca_ops_brk_types=>gc_bucket_other ).
      ENDIF.
      INSERT ls_group INTO TABLE et_groups.
    ENDLOOP.
  ENDMETHOD.


  METHOD group_values.
    DATA lv_later_net TYPE zif_ca_ops_types=>ty_amount.
    DATA lv_later_date TYPE d.
    rs_values-net_amount = is_sum-amount.
    rs_values-age_days = COND #( WHEN is_sum-first_date IS INITIAL THEN 0 ELSE iv_key_date - is_sum-first_date ).
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF <ls_line>-later = abap_false.
        rs_values-lines += 1.
        IF <ls_line>-debit_credit = zif_ca_ops_brk_types=>gc_debit.
          rs_values-debits += 1.
        ELSE.
          rs_values-credits += 1.
        ENDIF.
        CONTINUE.
      ENDIF.
      lv_later_net += <ls_line>-amount.
      IF lv_later_date IS INITIAL OR <ls_line>-posting_date < lv_later_date.
        lv_later_date = <ls_line>-posting_date.
        rs_values-later_doc_type = <ls_line>-doc_type.
      ENDIF.
    ENDLOOP.
    IF lv_later_date IS NOT INITIAL.
      rs_values-days_to_clear = lv_later_date - iv_key_date.
      rs_values-clears_later = xsdbool( is_sum-amount + lv_later_net = 0 ).
    ENDIF.
  ENDMETHOD.


  METHOD holds.
    DATA(lv_op) = CONV zif_ca_ops_brk_types=>ty_operator( to_upper( condense( is_cond-operator ) ) ).
    DATA(lv_field) = CONV zif_ca_ops_brk_types=>ty_field( to_upper( condense( is_cond-field ) ) ).
    DATA(lt_values) = values_of( iv_value = is_cond-cond_value iv_operator = lv_op it_params = it_params ).
    CASE to_upper( condense( is_cond-cond_kind ) ).
      WHEN zif_ca_ops_brk_types=>gc_kind-field.
        rv_holds = compare( iv_actual = item_value( is_item = is_item iv_field = lv_field )
                            iv_operator = lv_op it_values = lt_values ).
      WHEN zif_ca_ops_brk_types=>gc_kind-group.
        rv_holds = compare( iv_actual = group_value( is_group = is_group iv_field = lv_field )
                            iv_operator = lv_op it_values = lt_values ).
      WHEN zif_ca_ops_brk_types=>gc_kind-days.
        rv_holds = compare( iv_actual   = |{ days_value( is_item = is_item iv_field = lv_field iv_key_date = iv_key_date ) }|
                            iv_operator = lv_op it_values = lt_values ).
      WHEN zif_ca_ops_brk_types=>gc_kind-link.
        IF is_cond-cond_value IS NOT INITIAL AND lt_values IS INITIAL.
          " a named list without values explains nothing
          RETURN.
        ENDIF.
        rv_holds = link_holds( EXPORTING is_cond     = is_cond
                                         is_item     = is_item
                                         it_hits     = it_hits
                                         it_values   = lt_values
                               CHANGING  cs_evidence = cs_evidence ).
    ENDCASE.
  ENDMETHOD.


  METHOD link_holds.
    DATA lv_count TYPE i.
    DATA ls_first TYPE ty_evidence.
    DATA(lv_op) = CONV zif_ca_ops_brk_types=>ty_operator( to_upper( condense( is_cond-operator ) ) ).
    DATA(lv_field) = to_upper( condense( is_cond-field ) ).
    DATA(lv_key) = line_key( is_item ).
    LOOP AT it_hits USING KEY line ASSIGNING FIELD-SYMBOL(<ls_hit>)
         WHERE link_id = is_cond-link_id AND line_key = lv_key.
      DATA(lv_value) = condense( CONV string( zcl_ca_ops_link_query=>value_of( it_pairs = <ls_hit>-pairs
                                                                               iv_field = lv_field ) ) ).
      DATA(lv_match) = COND abap_bool(
        WHEN lv_field IS INITIAL OR ( ( lv_op = zif_ca_ops_brk_types=>gc_op-ex OR lv_op = zif_ca_ops_brk_types=>gc_op-nx )
                                      AND it_values IS INITIAL )
          THEN abap_true
        WHEN lv_op = zif_ca_ops_brk_types=>gc_op-ex OR lv_op = zif_ca_ops_brk_types=>gc_op-nx
          THEN xsdbool( line_exists( it_values[ table_line = lv_value ] ) )
        ELSE compare( iv_actual = lv_value iv_operator = lv_op it_values = it_values ) ).
      IF lv_match = abap_true.
        lv_count += 1.
        IF ls_first IS INITIAL.
          ls_first = VALUE #( object_id = <ls_hit>-object_id row_key = <ls_hit>-row_key value = lv_value ).
        ENDIF.
      ENDIF.
    ENDLOOP.
    DATA(lv_needed) = nmax( val1 = is_cond-min_count val2 = 1 ).
    IF lv_op = zif_ca_ops_brk_types=>gc_op-nx.
      rv_holds = xsdbool( lv_count = 0 ).
      RETURN.
    ENDIF.
    rv_holds = xsdbool( lv_count >= lv_needed ).
    IF rv_holds = abap_true AND cs_evidence IS INITIAL.
      cs_evidence = ls_first.
    ENDIF.
  ENDMETHOD.


  METHOD item_value.
    rv_value = SWITCH #( iv_field
                         WHEN zif_ca_ops_brk_types=>gc_field-posting_date  THEN CONV string( is_item-posting_date )
                         WHEN zif_ca_ops_brk_types=>gc_field-document_date THEN CONV string( is_item-document_date )
                         WHEN zif_ca_ops_brk_types=>gc_field-doc_type      THEN CONV string( is_item-doc_type )
                         WHEN zif_ca_ops_brk_types=>gc_field-debit_credit  THEN CONV string( is_item-debit_credit )
                         WHEN zif_ca_ops_brk_types=>gc_field-assignment    THEN CONV string( is_item-assignment )
                         WHEN zif_ca_ops_brk_types=>gc_field-ref_type      THEN CONV string( is_item-ref_type )
                         WHEN zif_ca_ops_brk_types=>gc_field-recon_key     THEN CONV string( is_item-recon_key )
                         WHEN zif_ca_ops_brk_types=>gc_field-amount        THEN |{ is_item-amount }|
                         WHEN zif_ca_ops_brk_types=>gc_field-currency      THEN CONV string( is_item-currency ) ).
  ENDMETHOD.


  METHOD group_value.
    rv_value = SWITCH #( iv_field
                         WHEN zif_ca_ops_brk_types=>gc_group-lines          THEN |{ is_group-lines }|
                         WHEN zif_ca_ops_brk_types=>gc_group-debits         THEN |{ is_group-debits }|
                         WHEN zif_ca_ops_brk_types=>gc_group-credits        THEN |{ is_group-credits }|
                         WHEN zif_ca_ops_brk_types=>gc_group-net_amount     THEN |{ is_group-net_amount }|
                         WHEN zif_ca_ops_brk_types=>gc_group-age_days       THEN |{ is_group-age_days }|
                         WHEN zif_ca_ops_brk_types=>gc_group-clears_later   THEN CONV string( is_group-clears_later )
                         WHEN zif_ca_ops_brk_types=>gc_group-later_doc_type THEN CONV string( is_group-later_doc_type )
                         WHEN zif_ca_ops_brk_types=>gc_group-days_to_clear  THEN |{ is_group-days_to_clear }| ).
  ENDMETHOD.


  METHOD days_value.
    CASE iv_field.
      WHEN zif_ca_ops_brk_types=>gc_days-period_end.
        " last day of the posting month: first day of the next month minus one
        DATA(lv_next) = CONV d( |{ is_item-posting_date(6) }01| ).
        lv_next += 31.
        lv_next = |{ lv_next(6) }01|.
        rv_days = ( lv_next - 1 ) - is_item-posting_date.
      WHEN zif_ca_ops_brk_types=>gc_days-key_date.
        rv_days = iv_key_date - is_item-posting_date.
    ENDCASE.
  ENDMETHOD.


  METHOD as_number.
    CLEAR ev_number.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    IF lv_value IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        ev_number = CONV decfloat34( lv_value ).
        rv_number = abap_true.
      CATCH cx_sy_conversion_error.
        rv_number = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD param_of.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    IF strlen( lv_value ) > 1 AND lv_value(1) = zif_ca_ops_brk_types=>gc_param_marker.
      rv_name = to_upper( substring( val = lv_value off = 1 ) ).
    ENDIF.
  ENDMETHOD.


  METHOD problem.
    INSERT VALUE #( rule_id = iv_rule_id msgno = iv_msgno v1 = iv_v1 v2 = iv_v2 v3 = iv_v3 v4 = iv_v4 )
           INTO TABLE ct_problems.
  ENDMETHOD.

ENDCLASS.
