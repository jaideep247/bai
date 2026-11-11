*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cat_dao.clas.abap
*& Purpose:
*& Data access of the process catalogue (all SQL of the catalogue): the six
*& catalogue tables ZCA_OPS_CATPKG / _CATPRC / _CATSTP / _CATTAB / _CATDEP /
*& _CATACT, read whole (small customizing tables), and the business
*& processes of ZCA_OPS_PROC with their catalogue process. Read only:
*& writes nothing.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - process catalogue data access</p>
CLASS zcl_ca_ops_cat_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cat_dao.

ENDCLASS.



CLASS zcl_ca_ops_cat_dao IMPLEMENTATION.

  METHOD zif_ca_ops_cat_dao~get_packages.
    SELECT pkg_id, pkg_kind, pkg_rank, id_prefix, mon_area, description, owner, active
      FROM zca_ops_catpkg
      ORDER BY pkg_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_packages.
  ENDMETHOD.


  METHOD zif_ca_ops_cat_dao~get_processes.
    SELECT process_id, pkg_id, description, component, dash_card, owner_role, schedule, dflt_active, evidence,
           verify_ref, seq
      FROM zca_ops_catprc
      ORDER BY process_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_processes.
  ENDMETHOD.


  METHOD zif_ca_ops_cat_dao~get_steps.
    SELECT process_id, step_no, step_kind, obj_name, description, evidence, verify_ref
      FROM zca_ops_catstp
      ORDER BY process_id, step_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_steps.
  ENDMETHOD.


  METHOD zif_ca_ops_cat_dao~get_tables.
    SELECT process_id, tabname, tab_role, link_object, description, evidence, verify_ref
      FROM zca_ops_cattab
      ORDER BY process_id, tabname
      INTO CORRESPONDING FIELDS OF TABLE @rt_tables.
  ENDMETHOD.


  METHOD zif_ca_ops_cat_dao~get_dependencies.
    SELECT process_id, pred_id, dep_kind, description
      FROM zca_ops_catdep
      ORDER BY process_id, pred_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_dependencies.
  ENDMETHOD.


  METHOD zif_ca_ops_cat_dao~get_activations.
    SELECT process_id, valid_from, active, pkg_id, reason, approved_by, approved_on
      FROM zca_ops_catact
      ORDER BY process_id, valid_from
      INTO CORRESPONDING FIELDS OF TABLE @rt_activations.
  ENDMETHOD.


  METHOD zif_ca_ops_cat_dao~get_onboarded.
    IF iv_area IS INITIAL.
      SELECT area, process_id, cat_process, active
        FROM zca_ops_proc
        ORDER BY area, process_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_onboarded.
    ELSE.
      SELECT area, process_id, cat_process, active
        FROM zca_ops_proc
        WHERE area = @iv_area
        ORDER BY area, process_id
        INTO CORRESPONDING FIELDS OF TABLE @rt_onboarded.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
