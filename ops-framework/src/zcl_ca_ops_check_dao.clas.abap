*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_check_dao.clas.abap
*& Purpose:
*& Data access of the process onboarding framework (all SQL of the check
*& registry): registered checks and processes, aggregate rows, approved
*& tables, the runtime DDIC of an approved table (RTTI, S_TABU_NAM 03), the
*& aggregate itself - rebuilt from its definition here and run on the
*& database (COUNT / MIN, GROUP BY the company-code field, row cap) - and
*& the facts of the onboarding check (controls covering a check, areas with
*& an active alert rule, active parameter areas). Read only: writes nothing.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - check registry data access</p>
CLASS zcl_ca_ops_check_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check_dao.

ENDCLASS.



CLASS zcl_ca_ops_check_dao IMPLEMENTATION.

  METHOD zif_ca_ops_check_dao~get_checks.
    SELECT area, check_id, process_id, description, class_name, sched_group, bukrs_aware, active, seq
      FROM zca_ops_check
      WHERE area        = @iv_area
        AND sched_group = @iv_sched_group
        AND active      = @abap_true
      ORDER BY seq, check_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_checks.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~get_all_checks.
    SELECT area, check_id, process_id, description, class_name, sched_group, bukrs_aware, active, seq
      FROM zca_ops_check
      WHERE active = @abap_true
      ORDER BY area, check_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_checks.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~get_processes.
    SELECT area, process_id, description, owner, backup, runbook_url, auth_role, own_data, purge_target,
           active, seq
      FROM zca_ops_proc
      WHERE active = @abap_true
      ORDER BY area, process_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_processes.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~get_aggregates.
    SELECT area, check_id, agg_id, description, tabname, agg_func, date_field, min_age_days, bukrs_field,
           status_field, status_op, status_value, cond_field, cond_op, cond_value, amber, red, check_code, active
      FROM zca_ops_agg
      WHERE area     = @iv_area
        AND check_id = @iv_check_id
        AND active   = @abap_true
      ORDER BY agg_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_aggs.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~is_table_approved.
    DATA(lv_tabname) = CONV zif_ca_ops_chk_types=>ty_tabname( to_upper( condense( iv_tabname ) ) ).
    " Full key of the approved-table list
    SELECT SINGLE active
      FROM zca_ops_tabwl
      WHERE area       = @iv_area
        AND table_name = @lv_tabname
      INTO @DATA(lv_active).
    rv_approved = xsdbool( sy-subrc = 0 AND lv_active = abap_true ).
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~get_table_fields.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_ddic TYPE ddfields.

    DATA(lv_name) = to_upper( condense( CONV string( iv_tabname ) ) ).
    " Every dynamic read describes its table here first: S_TABU_NAM display of the running user, in
    " addition to the approved-table list
    IF zcl_ca_ops_factory=>get_auth( )->may_read_table( lv_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e087(zca_ops) WITH lv_name.
    ENDIF.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = lv_name
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e082(zca_ops) WITH lv_name.
    ENDIF.
    TRY.
        lo_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e082(zca_ops) WITH lv_name
          EXPORTING
            previous = lx_error.
    ENDTRY.
    lo_struct->get_ddic_field_list(
      RECEIVING
        p_field_list = lt_ddic
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e082(zca_ops) WITH lv_name.
    ENDIF.
    LOOP AT lt_ddic ASSIGNING FIELD-SYMBOL(<ls_ddic>).
      INSERT VALUE #( fieldname = <ls_ddic>-fieldname
                      type_kind = <ls_ddic>-inttype ) INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~aggregate.
    DATA lt_fields TYPE zif_ca_ops_chk_types=>tt_field.
    " The SQL boundary trusts no caller-built string: the query is built here from its definition -
    " approved table, DDIC field names, quoted literals - and only that runs
    DATA(lv_approved) = zif_ca_ops_check_dao~is_table_approved( iv_area    = is_agg-area
                                                                iv_tabname = is_agg-tabname ).
    IF lv_approved = abap_true.
      lt_fields = zif_ca_ops_check_dao~get_table_fields( is_agg-tabname ).
    ENDIF.
    DATA(ls_query) = zcl_ca_ops_agg_query=>build( is_agg         = is_agg
                                                  it_fields      = lt_fields
                                                  iv_approved    = lv_approved
                                                  iv_bukrs_aware = iv_bukrs_aware
                                                  iv_today       = iv_today ).
    DATA(lv_select) = ls_query-select_list.
    DATA(lv_from) = CONV string( ls_query-tabname ).
    DATA(lv_where) = ls_query-where_clause.
    DATA(lv_group) = CONV string( ls_query-group_field ).
    DATA(lv_max_rows) = zif_ca_ops_chk_types=>gc_max_groups.
    TRY.
        IF lv_group IS INITIAL.
          " Aggregate without GROUP BY returns exactly one row: order is irrelevant
          SELECT (lv_select)
            FROM (lv_from)
            WHERE (lv_where)
            INTO CORRESPONDING FIELDS OF TABLE @rt_rows.             "#EC CI_NOORDER
        ELSE.
          SELECT (lv_select)
            FROM (lv_from)
            WHERE (lv_where)
            GROUP BY (lv_group)
            ORDER BY (lv_group)
            INTO CORRESPONDING FIELDS OF TABLE @rt_rows
            UP TO @lv_max_rows ROWS.
        ENDIF.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e093(zca_ops) WITH is_agg-agg_id ls_query-tabname
          EXPORTING
            previous = lx_sql.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~get_covered_checks.
    SELECT DISTINCT chk~check_area AS area, chk~match_value AS check_id
      FROM zca_ops_ctlchk AS chk
        INNER JOIN zca_ops_control AS ctl ON  ctl~area       = chk~area
                                          AND ctl~control_id = chk~control_id
      WHERE chk~match_field = @zif_ca_ops_ctl_types=>gc_match_field-group2
        AND ctl~active      = @abap_true
      ORDER BY area, check_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_covered.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~get_alert_areas.
    SELECT DISTINCT area
      FROM zca_ops_alrule
      WHERE active = @abap_true
      ORDER BY area
      INTO TABLE @rt_areas.
  ENDMETHOD.


  METHOD zif_ca_ops_check_dao~is_area_active.
    " One area register: the parameter framework decides (the same check as the configuration apps)
    rv_active = zcl_ca_ops_cfg_checks=>area_valid( iv_area        = iv_area
                                                   iv_any_allowed = abap_false ).
  ENDMETHOD.

ENDCLASS.
