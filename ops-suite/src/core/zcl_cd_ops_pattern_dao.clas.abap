*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pattern_dao.clas.abap
*& Purpose:
*& All SQL of the pattern check and the pattern migration. Reads configured
*& patterns per pattern area and the distinct real values of the area's
*& source in a date window (DISTINCT, ORDER BY, UP TO the row cap): FEBEP-
*& XBLNR of the configured accounts, ZCD_FMON_FILE names, TBTCO job names,
*& object keys / rule IDs / check codes / groups of findings. Migration: the
*& suite's own configuration tables only (fixed list), static SQL: complete
*& rows read with the complete field list of the table (tools/tests checks the
*& lists against ddic/), changed in ABAP, written back once per table (the
*& ZCD_EBS_FLOW_PAT key field PATTERN: delete + insert). Commits nothing.
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: pattern check and migration).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - pattern check and migration DAO</p>
CLASS zcl_cd_ops_pattern_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pattern_dao.

  PRIVATE SECTION.
    "! Field names of the configuration tables (dictionary names, not text)
    CONSTANTS:
      BEGIN OF gc_column,
        priority      TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'PRIORITY',
        iface_id      TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'IFACE_ID',
        cycle_id      TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'CYCLE_ID',
        step_no       TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'STEP_NO',
        rule_id       TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'RULE_ID',
        check_id      TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'CHECK_ID',
        class_name    TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'CLASS_NAME',
        suppress_uuid TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'SUPPRESS_UUID',
        changed_by    TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'LAST_CHANGED_BY',
        changed_at    TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'LAST_CHANGED_AT',
        local_changed TYPE zif_cd_ops_pattern_types=>ty_name VALUE 'LOCAL_LAST_CHANGED_AT',
      END OF gc_column.
    "! Start and end of a day as time-stamp suffix (run start window of findings)
    CONSTANTS gc_day_start TYPE string VALUE `000000`.
    CONSTANTS gc_day_end TYPE string VALUE `235959.9999999`.
    CONSTANTS gc_key_separator TYPE string VALUE ` `.

    "! One pattern field of a configuration table in the migration scope
    TYPES:
      BEGIN OF ty_scope,
        table      TYPE zif_cd_ops_pattern_types=>ty_name,
        field      TYPE zif_cd_ops_pattern_types=>ty_name,
        key1       TYPE zif_cd_ops_pattern_types=>ty_name,
        key2       TYPE zif_cd_ops_pattern_types=>ty_name,
        "! Only rows of this check class (ZCD_HCK_DEF parameters holding pattern lists)
        class_name TYPE zif_cd_ops_types=>ty_class_name,
        is_list    TYPE abap_bool,
      END OF ty_scope.
    TYPES tt_scope TYPE STANDARD TABLE OF ty_scope WITH EMPTY KEY.
    TYPES tt_flow TYPE STANDARD TABLE OF zcd_ebs_flow_pat WITH EMPTY KEY.
    TYPES tt_iface TYPE STANDARD TABLE OF zcd_fmon_iface WITH EMPTY KEY.
    TYPES tt_step TYPE STANDARD TABLE OF zcd_job_step WITH EMPTY KEY.
    TYPES tt_rule TYPE STANDARD TABLE OF zcd_ops_alrule WITH EMPTY KEY.
    TYPES tt_def TYPE STANDARD TABLE OF zcd_hck_def WITH EMPTY KEY.
    TYPES tt_suppress TYPE STANDARD TABLE OF zcd_hck_suppress WITH EMPTY KEY.
    TYPES tt_area_range TYPE RANGE OF zif_cd_ops_types=>ty_pe_area.

    METHODS scope
      RETURNING
        VALUE(rt_scope) TYPE tt_scope.

    "! All rows of one configuration table, complete field list, by primary key
    METHODS read_table
      IMPORTING
        iv_table       TYPE zif_cd_ops_pattern_types=>ty_name
      RETURNING
        VALUE(rr_rows) TYPE REF TO data
      RAISING
        zcx_cd_ops_error.

    "! Key part of a row as text (the same text identifies the row when it is written)
    METHODS key_text
      IMPORTING
        is_row         TYPE any
        iv_field       TYPE zif_cd_ops_pattern_types=>ty_name
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Distinct values of a finding column of runs started in the window
    METHODS findings_column
      IMPORTING
        iv_area          TYPE zif_cd_ops_pattern_types=>ty_area
        iv_from          TYPE d
        iv_to            TYPE d
        iv_max_rows      TYPE i
      RETURNING
        VALUE(rt_values) TYPE zif_cd_ops_pattern_types=>tt_value.

    "! Write the converted rows of one table; key field changed = delete + insert
    METHODS write_table
      IMPORTING
        iv_table          TYPE zif_cd_ops_pattern_types=>ty_name
        it_rows           TYPE zif_cd_ops_pattern_types=>tt_migration
      RETURNING
        VALUE(rs_written) TYPE zif_cd_ops_pattern_types=>ty_written
      RAISING
        zcx_cd_ops_error.

    METHODS stamp
      CHANGING
        cs_row TYPE any.

    "! Static modifying statement of one table: update, or delete + insert (key change)
    METHODS save_table
      IMPORTING
        iv_table      TYPE zif_cd_ops_pattern_types=>ty_name
        it_old        TYPE ANY TABLE
        it_new        TYPE ANY TABLE
        iv_key_change TYPE abap_bool
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS zcl_cd_ops_pattern_dao IMPLEMENTATION.

  METHOD zif_cd_ops_pattern_dao~get_patterns.
    CASE iv_area.
      WHEN zif_cd_ops_pattern_types=>gc_area-ebs_flow.
        SELECT priority, pattern
          FROM zcd_ebs_flow_pat
          WHERE active = @abap_true
          ORDER BY priority, pattern
          INTO TABLE @DATA(lt_flow).
        LOOP AT lt_flow ASSIGNING FIELD-SYMBOL(<ls_flow>).
          INSERT VALUE #( source  = |{ zif_cd_ops_pattern_types=>gc_table-flow_pattern } { <ls_flow>-priority }|
                          pattern = <ls_flow>-pattern ) INTO TABLE rt_patterns.
        ENDLOOP.

      WHEN zif_cd_ops_pattern_types=>gc_area-fmon_file.
        SELECT iface_id, name_pattern
          FROM zcd_fmon_iface
          WHERE active       = @abap_true
            AND name_pattern <> @space
          ORDER BY iface_id
          INTO TABLE @DATA(lt_iface).
        LOOP AT lt_iface ASSIGNING FIELD-SYMBOL(<ls_iface>).
          INSERT VALUE #( source  = |{ zif_cd_ops_pattern_types=>gc_table-fmon_iface } { <ls_iface>-iface_id }|
                          pattern = <ls_iface>-name_pattern ) INTO TABLE rt_patterns.
        ENDLOOP.

      WHEN zif_cd_ops_pattern_types=>gc_area-hck_job.
        SELECT cycle_id, step_no, jobname
          FROM zcd_job_step
          WHERE jobname <> @space
          ORDER BY cycle_id, step_no
          INTO TABLE @DATA(lt_step).
        LOOP AT lt_step ASSIGNING FIELD-SYMBOL(<ls_step>).
          INSERT VALUE #( source  = |{ zif_cd_ops_pattern_types=>gc_table-job_step } { <ls_step>-cycle_id } {
                                      <ls_step>-step_no }|
                          pattern = <ls_step>-jobname ) INTO TABLE rt_patterns.
        ENDLOOP.
        " Job-name lists of the technical job checks (PARAM1)
        SELECT check_id, param1
          FROM zcd_hck_def
          WHERE active = @abap_true
            AND ( class_name = @zif_cd_ops_pattern_types=>gc_list_class-tech_jobs
               OR class_name = @zif_cd_ops_pattern_types=>gc_list_class-job_runtime )
          ORDER BY check_id
          INTO TABLE @DATA(lt_def).
        LOOP AT lt_def ASSIGNING FIELD-SYMBOL(<ls_def>).
          LOOP AT zcl_cd_ops_util=>split_list( <ls_def>-param1 ) INTO DATA(lv_item).
            INSERT VALUE #( source  = |{ zif_cd_ops_pattern_types=>gc_table-hck_def } { <ls_def>-check_id } {
                                        zif_cd_ops_pattern_types=>gc_field-param1 }|
                            pattern = lv_item ) INTO TABLE rt_patterns.
          ENDLOOP.
        ENDLOOP.

      WHEN zif_cd_ops_pattern_types=>gc_area-hck_suppr.
        SELECT check_id, key_pattern
          FROM zcd_hck_suppress
          WHERE key_pattern <> @space
            AND ( status = @zif_cd_hck_suppress_types=>gc_status-active
               OR status = @zif_cd_hck_suppress_types=>gc_status-requested )
          ORDER BY check_id, key_pattern
          INTO TABLE @DATA(lt_suppr).
        LOOP AT lt_suppr ASSIGNING FIELD-SYMBOL(<ls_suppr>).
          INSERT VALUE #( source  = |{ zif_cd_ops_pattern_types=>gc_table-suppression } { <ls_suppr>-check_id }|
                          pattern = <ls_suppr>-key_pattern ) INTO TABLE rt_patterns.
        ENDLOOP.

      WHEN zif_cd_ops_pattern_types=>gc_area-alert_rule
        OR zif_cd_ops_pattern_types=>gc_area-alert_check
        OR zif_cd_ops_pattern_types=>gc_area-alert_grp1
        OR zif_cd_ops_pattern_types=>gc_area-alert_grp2.
        SELECT rule_id, rule_pattern, check_pattern, group1_pattern, group2_pattern
          FROM zcd_ops_alrule
          WHERE active = @abap_true
          ORDER BY rule_id
          INTO TABLE @DATA(lt_rule).
        LOOP AT lt_rule ASSIGNING FIELD-SYMBOL(<ls_rule>).
          DATA(lv_pattern) = SWITCH zif_cd_ops_types=>ty_pattern(
            iv_area
            WHEN zif_cd_ops_pattern_types=>gc_area-alert_rule  THEN <ls_rule>-rule_pattern
            WHEN zif_cd_ops_pattern_types=>gc_area-alert_check THEN <ls_rule>-check_pattern
            WHEN zif_cd_ops_pattern_types=>gc_area-alert_grp1  THEN <ls_rule>-group1_pattern
            ELSE <ls_rule>-group2_pattern ).
          IF lv_pattern IS NOT INITIAL.
            INSERT VALUE #( source  = |{ zif_cd_ops_pattern_types=>gc_table-alert_rule } { <ls_rule>-rule_id }|
                            pattern = lv_pattern ) INTO TABLE rt_patterns.
          ENDIF.
        ENDLOOP.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_cd_ops_pattern_dao~get_values.
    CASE iv_area.
      WHEN zif_cd_ops_pattern_types=>gc_area-ebs_flow.
        " Statements of the configured accounts only (the EBS scope, ZCD_EBS_ACCT)
        SELECT DISTINCT p~xblnr
          FROM febep AS p
          INNER JOIN febko AS k
            ON k~kukey = p~kukey
          INNER JOIN zcd_ebs_acct AS a
            ON  a~bukrs = k~bukrs
            AND a~hbkid = k~hbkid
            AND a~hktid = k~hktid
          WHERE k~azdat BETWEEN @iv_from AND @iv_to
            AND a~active = @abap_true
            AND p~xblnr  <> @space
          ORDER BY p~xblnr
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.

      WHEN zif_cd_ops_pattern_types=>gc_area-fmon_file.
        SELECT DISTINCT file_name
          FROM zcd_fmon_file
          WHERE business_date BETWEEN @iv_from AND @iv_to
          ORDER BY file_name
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.

      WHEN zif_cd_ops_pattern_types=>gc_area-hck_job.
        "VERIFY-DDIC: TBTCO-JOBNAME, SDLSTRTDT, STRTDATE
        SELECT DISTINCT jobname
          FROM tbtco
          WHERE sdlstrtdt BETWEEN @iv_from AND @iv_to
             OR strtdate  BETWEEN @iv_from AND @iv_to
          ORDER BY jobname
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.

      WHEN zif_cd_ops_pattern_types=>gc_area-hck_suppr
        OR zif_cd_ops_pattern_types=>gc_area-alert_rule
        OR zif_cd_ops_pattern_types=>gc_area-alert_check
        OR zif_cd_ops_pattern_types=>gc_area-alert_grp1
        OR zif_cd_ops_pattern_types=>gc_area-alert_grp2.
        rt_values = findings_column( iv_area = iv_area iv_from = iv_from iv_to = iv_to iv_max_rows = iv_max_rows ).
    ENDCASE.
  ENDMETHOD.


  METHOD findings_column.
    DATA lt_area TYPE tt_area_range.
    DATA(lv_from) = CONV timestampl( |{ iv_from }{ gc_day_start }| ).
    DATA(lv_to) = CONV timestampl( |{ iv_to }{ gc_day_end }| ).
    " Suppression keys: HCK findings only; alert patterns: findings of every area (empty range)
    IF iv_area = zif_cd_ops_pattern_types=>gc_area-hck_suppr.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = zif_cd_ops_types=>gc_pe_area-health_check ) INTO TABLE lt_area.
    ENDIF.
    CASE iv_area.
      WHEN zif_cd_ops_pattern_types=>gc_area-hck_suppr.
        SELECT DISTINCT f~object_key
          FROM zcd_ops_finding AS f
          INNER JOIN zcd_ops_run AS r
            ON r~run_id = f~run_id
          WHERE r~started_at BETWEEN @lv_from AND @lv_to
            AND f~pe_area IN @lt_area
          ORDER BY f~object_key
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.
      WHEN zif_cd_ops_pattern_types=>gc_area-alert_rule.
        SELECT DISTINCT f~rule_id
          FROM zcd_ops_finding AS f
          INNER JOIN zcd_ops_run AS r
            ON r~run_id = f~run_id
          WHERE r~started_at BETWEEN @lv_from AND @lv_to
          ORDER BY f~rule_id
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.
      WHEN zif_cd_ops_pattern_types=>gc_area-alert_check.
        SELECT DISTINCT f~check_code
          FROM zcd_ops_finding AS f
          INNER JOIN zcd_ops_run AS r
            ON r~run_id = f~run_id
          WHERE r~started_at BETWEEN @lv_from AND @lv_to
          ORDER BY f~check_code
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.
      WHEN zif_cd_ops_pattern_types=>gc_area-alert_grp1.
        SELECT DISTINCT f~group1
          FROM zcd_ops_finding AS f
          INNER JOIN zcd_ops_run AS r
            ON r~run_id = f~run_id
          WHERE r~started_at BETWEEN @lv_from AND @lv_to
          ORDER BY f~group1
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.
      WHEN zif_cd_ops_pattern_types=>gc_area-alert_grp2.
        SELECT DISTINCT f~group2
          FROM zcd_ops_finding AS f
          INNER JOIN zcd_ops_run AS r
            ON r~run_id = f~run_id
          WHERE r~started_at BETWEEN @lv_from AND @lv_to
          ORDER BY f~group2
          INTO TABLE @rt_values
          UP TO @iv_max_rows ROWS.
    ENDCASE.
    DELETE rt_values WHERE table_line IS INITIAL.
  ENDMETHOD.


  METHOD zif_cd_ops_pattern_dao~get_migration_rows.
    DATA lr_rows TYPE REF TO data.
    DATA lv_table TYPE zif_cd_ops_pattern_types=>ty_name.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    LOOP AT scope( ) ASSIGNING FIELD-SYMBOL(<ls_scope>).
      IF <ls_scope>-table <> lv_table.
        lv_table = <ls_scope>-table.
        TRY.
            lr_rows = read_table( lv_table ).
          CATCH zcx_cd_ops_error.
            " Table not active yet (pull in progress): nothing to migrate in it
            CLEAR lr_rows.
        ENDTRY.
      ENDIF.
      IF lr_rows IS NOT BOUND.
        CONTINUE.
      ENDIF.
      ASSIGN lr_rows->* TO <lt_rows>.
      LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
        ASSIGN COMPONENT <ls_scope>-field OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc <> 0 OR <lv_value> IS INITIAL.
          CONTINUE.
        ENDIF.
        IF <ls_scope>-class_name IS NOT INITIAL
           AND key_text( is_row = <ls_row> iv_field = gc_column-class_name ) <> <ls_scope>-class_name.
          CONTINUE.
        ENDIF.
        DATA(lv_key1) = key_text( is_row = <ls_row> iv_field = <ls_scope>-key1 ).
        DATA(lv_key2) = key_text( is_row = <ls_row> iv_field = <ls_scope>-key2 ).
        INSERT VALUE #( table      = <ls_scope>-table
                        field      = <ls_scope>-field
                        key1       = lv_key1
                        key2       = lv_key2
                        row_key    = condense( |{ lv_key1 }{ gc_key_separator }{ lv_key2 }| )
                        is_list    = <ls_scope>-is_list
                        max_length = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_data( <lv_value> )
                                       )->output_length
                        old        = <lv_value> ) INTO TABLE rt_rows.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_pattern_dao~write_migration.
    DATA lt_rows TYPE zif_cd_ops_pattern_types=>tt_migration.
    lt_rows = VALUE #( FOR ls_row IN it_rows WHERE ( status = zif_cd_ops_pattern_types=>gc_migration-convert )
                       ( ls_row ) ).
    SORT lt_rows BY table.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_first>) GROUP BY <ls_first>-table INTO DATA(lv_table).
      DATA(lt_table_rows) = VALUE zif_cd_ops_pattern_types=>tt_migration( FOR ls_member IN GROUP lv_table
                                                                          ( ls_member ) ).
      DATA(ls_written) = write_table( iv_table = lv_table it_rows = lt_table_rows ).
      IF ls_written-table IS NOT INITIAL.
        INSERT ls_written INTO TABLE rt_written.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD write_table.
    DATA lr_new TYPE REF TO data.
    DATA lr_old TYPE REF TO data.
    DATA lv_key_change TYPE abap_bool.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_new> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_old> TYPE STANDARD TABLE.

    DATA(lt_scope) = scope( ).
    DATA(lr_rows) = read_table( iv_table ).
    ASSIGN lr_rows->* TO <lt_rows>.
    CREATE DATA lr_new LIKE <lt_rows>.
    CREATE DATA lr_old LIKE <lt_rows>.
    ASSIGN lr_new->* TO <lt_new>.
    ASSIGN lr_old->* TO <lt_old>.

    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_changed) = abap_false.
      LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_plan>).
        DATA(ls_scope) = VALUE #( lt_scope[ table = iv_table field = <ls_plan>-field ] OPTIONAL ).
        IF key_text( is_row = <ls_row> iv_field = ls_scope-key1 ) <> <ls_plan>-key1
           OR key_text( is_row = <ls_row> iv_field = ls_scope-key2 ) <> <ls_plan>-key2.
          CONTINUE.
        ENDIF.
        IF lv_changed = abap_false.
          INSERT <ls_row> INTO TABLE <lt_old>.
        ENDIF.
        ASSIGN COMPONENT <ls_plan>-field OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc = 0.
          <lv_value> = <ls_plan>-new.
          lv_changed = abap_true.
          " The pattern of ZCD_EBS_FLOW_PAT is part of the key
          IF <ls_plan>-field = ls_scope-key2.
            lv_key_change = abap_true.
          ENDIF.
        ENDIF.
      ENDLOOP.
      IF lv_changed = abap_true.
        stamp( CHANGING cs_row = <ls_row> ).
        INSERT <ls_row> INTO TABLE <lt_new>.
      ENDIF.
    ENDLOOP.
    IF <lt_new> IS INITIAL.
      RETURN.
    ENDIF.

    save_table( iv_table = iv_table it_old = <lt_old> it_new = <lt_new> iv_key_change = lv_key_change ).
    rs_written-table = iv_table.
    IF lv_key_change = abap_true.
      rs_written-deleted = lr_old.
      rs_written-created = lr_new.
    ELSE.
      rs_written-updated = lr_new.
    ENDIF.
  ENDMETHOD.


  METHOD save_table.
    DATA lt_flow_old TYPE tt_flow.
    DATA lt_flow TYPE tt_flow.
    DATA lt_iface TYPE tt_iface.
    DATA lt_step TYPE tt_step.
    DATA lt_rule TYPE tt_rule.
    DATA lt_def TYPE tt_def.
    DATA lt_suppress TYPE tt_suppress.
    DATA lv_failed TYPE abap_bool.

    CASE iv_table.
      WHEN zif_cd_ops_pattern_types=>gc_table-flow_pattern.
        lt_flow_old = it_old.
        lt_flow = it_new.
        IF iv_key_change = abap_true.
          DELETE zcd_ebs_flow_pat FROM TABLE @lt_flow_old.
          lv_failed = xsdbool( sy-subrc <> 0 ).
          IF lv_failed = abap_false.
            INSERT zcd_ebs_flow_pat FROM TABLE @lt_flow.
            lv_failed = xsdbool( sy-subrc <> 0 ).
          ENDIF.
        ELSE.
          UPDATE zcd_ebs_flow_pat FROM TABLE @lt_flow.
          lv_failed = xsdbool( sy-subrc <> 0 ).
        ENDIF.
      WHEN zif_cd_ops_pattern_types=>gc_table-fmon_iface.
        lt_iface = it_new.
        UPDATE zcd_fmon_iface FROM TABLE @lt_iface.
        lv_failed = xsdbool( sy-subrc <> 0 ).
      WHEN zif_cd_ops_pattern_types=>gc_table-job_step.
        lt_step = it_new.
        UPDATE zcd_job_step FROM TABLE @lt_step.
        lv_failed = xsdbool( sy-subrc <> 0 ).
      WHEN zif_cd_ops_pattern_types=>gc_table-alert_rule.
        lt_rule = it_new.
        UPDATE zcd_ops_alrule FROM TABLE @lt_rule.
        lv_failed = xsdbool( sy-subrc <> 0 ).
      WHEN zif_cd_ops_pattern_types=>gc_table-hck_def.
        lt_def = it_new.
        UPDATE zcd_hck_def FROM TABLE @lt_def.
        lv_failed = xsdbool( sy-subrc <> 0 ).
      WHEN zif_cd_ops_pattern_types=>gc_table-suppression.
        lt_suppress = it_new.
        UPDATE zcd_hck_suppress FROM TABLE @lt_suppress.
        lv_failed = xsdbool( sy-subrc <> 0 ).
    ENDCASE.
    IF lv_failed = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH iv_table.
    ENDIF.
  ENDMETHOD.


  METHOD stamp.
    GET TIME STAMP FIELD DATA(lv_now).
    ASSIGN COMPONENT gc_column-changed_by OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_by>).
    IF sy-subrc = 0.
      <lv_by> = sy-uname.
    ENDIF.
    ASSIGN COMPONENT gc_column-changed_at OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_at>).
    IF sy-subrc = 0.
      <lv_at> = lv_now.
    ENDIF.
    ASSIGN COMPONENT gc_column-local_changed OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_local>).
    IF sy-subrc = 0.
      <lv_local> = lv_now.
    ENDIF.
  ENDMETHOD.


  METHOD read_table.
    " Complete field lists (tools/tests/test_pattern_dao_fields.py compares them with ddic/):
    " a row is written back whole, so a missing field would be cleared
    CASE iv_table.
      WHEN zif_cd_ops_pattern_types=>gc_table-flow_pattern.
        SELECT priority, pattern, flow_type, active, last_changed_by, last_changed_at, local_last_changed_at
          FROM zcd_ebs_flow_pat
          ORDER BY PRIMARY KEY
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_flow).
        rr_rows = NEW tt_flow( lt_flow ).
      WHEN zif_cd_ops_pattern_types=>gc_table-fmon_iface.
        SELECT iface_id, direction, file_type, source_sys, target_sys, pay_method, lob, bank_key, name_pattern,
               min_bytes, max_bytes, ack_expected, ack_level, owner, active, description, last_changed_by,
               last_changed_at, local_last_changed_at
          FROM zcd_fmon_iface
          ORDER BY PRIMARY KEY
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_iface).
        rr_rows = NEW tt_iface( lt_iface ).
      WHEN zif_cd_ops_pattern_types=>gc_table-job_step.
        SELECT cycle_id, step_no, description, jobname, program, variant, pred_step, day_offset, window_from,
               window_to, max_runtime_min, skippable, critical, changed_by, changed_at, last_changed_by,
               last_changed_at, local_last_changed_at
          FROM zcd_job_step
          ORDER BY PRIMARY KEY
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_step).
        rr_rows = NEW tt_step( lt_step ).
      WHEN zif_cd_ops_pattern_types=>gc_table-alert_rule.
        SELECT rule_id, pe_area, min_severity, rule_pattern, check_pattern, group1_pattern, group2_pattern,
               min_rag, on_abort, channel, destination, digest, max_items, throttle_min, quiet_from, quiet_to,
               escalate_after, escalation_dest, esc_override, active, changed_by, changed_at, last_changed_by,
               last_changed_at, local_last_changed_at
          FROM zcd_ops_alrule
          ORDER BY PRIMARY KEY
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_rule).
        rr_rows = NEW tt_rule( lt_rule ).
      WHEN zif_cd_ops_pattern_types=>gc_table-hck_def.
        SELECT check_id, description, category, class_name, active, seq, priority, param1, param2, param3,
               param4, package_size, timeout_sec, changed_by, changed_at, last_changed_by, last_changed_at,
               local_last_changed_at
          FROM zcd_hck_def
          ORDER BY PRIMARY KEY
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_def).
        rr_rows = NEW tt_def( lt_def ).
      WHEN zif_cd_ops_pattern_types=>gc_table-suppression.
        SELECT suppress_uuid, check_id, key_pattern, bukrs, valid_from, valid_to, reason, status, created_by,
               created_at, approved_by, approved_at, local_last_changed_at, last_changed_at
          FROM zcd_hck_suppress
          ORDER BY PRIMARY KEY
          INTO CORRESPONDING FIELDS OF TABLE @DATA(lt_suppress).
        rr_rows = NEW tt_suppress( lt_suppress ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e012(zcd_ops) WITH iv_table.
    ENDCASE.
  ENDMETHOD.


  METHOD key_text.
    IF iv_field IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT iv_field OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_key>).
    IF sy-subrc = 0.
      rv_text = |{ <lv_key> }|.
    ENDIF.
  ENDMETHOD.


  METHOD scope.
    rt_scope = VALUE #(
      ( table = zif_cd_ops_pattern_types=>gc_table-flow_pattern field = zif_cd_ops_pattern_types=>gc_field-pattern
        key1  = gc_column-priority key2 = zif_cd_ops_pattern_types=>gc_field-pattern )
      ( table = zif_cd_ops_pattern_types=>gc_table-fmon_iface field = zif_cd_ops_pattern_types=>gc_field-name_pattern
        key1  = gc_column-iface_id )
      ( table = zif_cd_ops_pattern_types=>gc_table-job_step field = zif_cd_ops_pattern_types=>gc_field-jobname
        key1  = gc_column-cycle_id key2 = gc_column-step_no )
      ( table = zif_cd_ops_pattern_types=>gc_table-alert_rule field = zif_cd_ops_pattern_types=>gc_field-rule_pattern
        key1  = gc_column-rule_id )
      ( table = zif_cd_ops_pattern_types=>gc_table-alert_rule field = zif_cd_ops_pattern_types=>gc_field-check_pattern
        key1  = gc_column-rule_id )
      ( table = zif_cd_ops_pattern_types=>gc_table-alert_rule field = zif_cd_ops_pattern_types=>gc_field-group1_pattern
        key1  = gc_column-rule_id )
      ( table = zif_cd_ops_pattern_types=>gc_table-alert_rule field = zif_cd_ops_pattern_types=>gc_field-group2_pattern
        key1  = gc_column-rule_id )
      ( table      = zif_cd_ops_pattern_types=>gc_table-hck_def field = zif_cd_ops_pattern_types=>gc_field-param1
        key1       = gc_column-check_id is_list = abap_true
        class_name = zif_cd_ops_pattern_types=>gc_list_class-tech_jobs )
      ( table      = zif_cd_ops_pattern_types=>gc_table-hck_def field = zif_cd_ops_pattern_types=>gc_field-param1
        key1       = gc_column-check_id is_list = abap_true
        class_name = zif_cd_ops_pattern_types=>gc_list_class-job_runtime )
      ( table      = zif_cd_ops_pattern_types=>gc_table-hck_def field = zif_cd_ops_pattern_types=>gc_field-param1
        key1       = gc_column-check_id is_list = abap_true
        class_name = zif_cd_ops_pattern_types=>gc_list_class-applog )
      ( table      = zif_cd_ops_pattern_types=>gc_table-hck_def field = zif_cd_ops_pattern_types=>gc_field-param2
        key1       = gc_column-check_id is_list = abap_true
        class_name = zif_cd_ops_pattern_types=>gc_list_class-applog )
      ( table      = zif_cd_ops_pattern_types=>gc_table-hck_def field = zif_cd_ops_pattern_types=>gc_field-param2
        key1       = gc_column-check_id is_list = abap_true
        class_name = zif_cd_ops_pattern_types=>gc_list_class-job_cycle )
      ( table = zif_cd_ops_pattern_types=>gc_table-suppression field = zif_cd_ops_pattern_types=>gc_field-key_pattern
        key1  = gc_column-suppress_uuid ) ).
  ENDMETHOD.

ENDCLASS.
