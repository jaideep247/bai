*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_catalog.clas.abap
*& Purpose:
*& The process catalogue (ZIF_CA_OPS_CATALOG): reads the catalogue rows and
*& the business processes of ZCA_OPS_PROC once through ZIF_CA_OPS_CAT_DAO
*& and answers from memory - the effective state of a catalogue process on
*& a day (the same rule as the CDS view ZI_CA_OpsCatProcEff: package off ->
*& inactive; else the latest activation row on or before the day; else the
*& delivered default), the definition of a process, the business processes
*& of an area that are not in effect, and the rule check of the catalogue
*& rows. No SQL here.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - process catalogue</p>
CLASS zcl_ca_ops_catalog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_catalog.

    "! @parameter io_dao | data access (default: the factory's)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_cat_dao OPTIONAL.

  PRIVATE SECTION.
    TYPES tt_ids TYPE SORTED TABLE OF zif_ca_ops_cat_types=>ty_process_id WITH UNIQUE KEY table_line.

    DATA mo_dao TYPE REF TO zif_ca_ops_cat_dao.
    DATA mv_loaded TYPE abap_bool.
    DATA mt_packages TYPE zif_ca_ops_cat_types=>tt_package.
    DATA mt_processes TYPE zif_ca_ops_cat_types=>tt_process.
    DATA mt_steps TYPE zif_ca_ops_cat_types=>tt_step.
    DATA mt_tables TYPE zif_ca_ops_cat_types=>tt_table.
    DATA mt_dependencies TYPE zif_ca_ops_cat_types=>tt_dependency.
    DATA mt_activations TYPE zif_ca_ops_cat_types=>tt_activation.
    DATA mt_onboarded TYPE zif_ca_ops_cat_types=>tt_onboarded.

    "! Read the catalogue once
    METHODS load.

    "! The processes reachable from iv_process_id over its dependencies (the process itself only on a cycle)
    METHODS predecessors
      IMPORTING
        iv_process_id TYPE zif_ca_ops_cat_types=>ty_process_id
      RETURNING
        VALUE(rt_ids) TYPE tt_ids.

    METHODS problem
      IMPORTING
        iv_key            TYPE clike
        iv_msgno          TYPE zif_ca_ops_types=>ty_msgno
        iv_v1             TYPE clike
        iv_v2             TYPE clike OPTIONAL
        iv_v3             TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_problem) TYPE zif_ca_ops_cat_types=>ty_problem.

ENDCLASS.



CLASS zcl_ca_ops_catalog IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE zcl_ca_ops_factory=>get_cat_dao( ) ).
  ENDMETHOD.


  METHOD load.
    IF mv_loaded = abap_true.
      RETURN.
    ENDIF.
    mt_packages     = mo_dao->get_packages( ).
    mt_processes    = mo_dao->get_processes( ).
    mt_steps        = mo_dao->get_steps( ).
    mt_tables       = mo_dao->get_tables( ).
    mt_dependencies = mo_dao->get_dependencies( ).
    mt_activations  = mo_dao->get_activations( ).
    mt_onboarded    = mo_dao->get_onboarded( ).
    mv_loaded = abap_true.
  ENDMETHOD.


  METHOD zif_ca_ops_catalog~state.
    load( ).
    rs_state-process_id = iv_process_id.
    rs_state-source     = zif_ca_ops_cat_types=>gc_source-unknown.
    DATA(ls_process) = VALUE #( mt_processes[ process_id = iv_process_id ] OPTIONAL ).
    IF ls_process IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_package) = VALUE #( mt_packages[ pkg_id = ls_process-pkg_id ] OPTIONAL ).
    IF ls_package-active = abap_false.
      rs_state-source = zif_ca_ops_cat_types=>gc_source-package.
      RETURN.
    ENDIF.
    " The rows are sorted by VALID_FROM: the last one on or before the day decides
    LOOP AT mt_activations ASSIGNING FIELD-SYMBOL(<ls_act>)
         WHERE process_id = iv_process_id AND valid_from <= iv_date.
      rs_state-active      = <ls_act>-active.
      rs_state-source      = zif_ca_ops_cat_types=>gc_source-activation.
      rs_state-valid_from  = <ls_act>-valid_from.
      rs_state-reason      = <ls_act>-reason.
      rs_state-approved_by = <ls_act>-approved_by.
    ENDLOOP.
    IF rs_state-source <> zif_ca_ops_cat_types=>gc_source-activation.
      rs_state-active = ls_process-dflt_active.
      rs_state-source = zif_ca_ops_cat_types=>gc_source-default.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_catalog~states.
    load( ).
    LOOP AT mt_processes ASSIGNING FIELD-SYMBOL(<ls_process>).
      INSERT zif_ca_ops_catalog~state( iv_process_id = <ls_process>-process_id
                                       iv_date       = iv_date ) INTO TABLE rt_states.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_catalog~definition.
    load( ).
    rs_definition-process = VALUE #( mt_processes[ process_id = iv_process_id ] OPTIONAL ).
    IF rs_definition-process IS INITIAL.
      RETURN.
    ENDIF.
    rs_definition-package = VALUE #( mt_packages[ pkg_id = rs_definition-process-pkg_id ] OPTIONAL ).
    rs_definition-state = zif_ca_ops_catalog~state( iv_process_id = iv_process_id
                                                    iv_date       = iv_date ).
    rs_definition-steps = FILTER #( mt_steps WHERE process_id = iv_process_id ).
    rs_definition-tables = FILTER #( mt_tables WHERE process_id = iv_process_id ).
    rs_definition-dependencies = FILTER #( mt_dependencies WHERE process_id = iv_process_id ).
    LOOP AT mt_onboarded ASSIGNING FIELD-SYMBOL(<ls_onb>) WHERE cat_process = iv_process_id.
      INSERT <ls_onb> INTO TABLE rs_definition-monitors.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_catalog~active_processes.
    load( ).
    LOOP AT mt_processes ASSIGNING FIELD-SYMBOL(<ls_process>).
      IF zif_ca_ops_catalog~state( iv_process_id = <ls_process>-process_id
                                   iv_date       = iv_date )-active = abap_true.
        INSERT <ls_process> INTO TABLE rt_processes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_catalog~inactive_onboarded.
    load( ).
    LOOP AT mt_onboarded ASSIGNING FIELD-SYMBOL(<ls_onb>) WHERE area = iv_area.
      IF <ls_onb>-active = abap_false
         OR ( <ls_onb>-cat_process IS NOT INITIAL
              AND zif_ca_ops_catalog~state( iv_process_id = <ls_onb>-cat_process
                                            iv_date       = iv_date )-active = abap_false ).
        INSERT <ls_onb>-process_id INTO TABLE rt_processes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_catalog~onboarded.
    load( ).
    rt_onboarded = mt_onboarded.
  ENDMETHOD.


  METHOD zif_ca_ops_catalog~validate.
    load( ).
    LOOP AT mt_processes ASSIGNING FIELD-SYMBOL(<ls_process>).
      DATA(ls_package) = VALUE #( mt_packages[ pkg_id = <ls_process>-pkg_id ] OPTIONAL ).
      IF ls_package IS INITIAL.
        INSERT problem( iv_key   = <ls_process>-process_id
                        iv_msgno = zif_ca_ops_cat_types=>gc_msg-package_unknown
                        iv_v1    = <ls_process>-process_id
                        iv_v2    = <ls_process>-pkg_id ) INTO TABLE rt_problems.
        CONTINUE.
      ENDIF.
      DATA(lv_prefix) = condense( ls_package-id_prefix ).
      IF lv_prefix IS NOT INITIAL AND find( val = <ls_process>-process_id sub = lv_prefix ) <> 0.
        INSERT problem( iv_key   = <ls_process>-process_id
                        iv_msgno = zif_ca_ops_cat_types=>gc_msg-prefix
                        iv_v1    = <ls_process>-process_id
                        iv_v2    = lv_prefix
                        iv_v3    = ls_package-pkg_id ) INTO TABLE rt_problems.
      ENDIF.
    ENDLOOP.

    LOOP AT mt_dependencies ASSIGNING FIELD-SYMBOL(<ls_dep>).
      DATA(ls_from) = VALUE #( mt_processes[ process_id = <ls_dep>-process_id ] OPTIONAL ).
      DATA(ls_pred) = VALUE #( mt_processes[ process_id = <ls_dep>-pred_id ] OPTIONAL ).
      DATA(lv_from_rank) = VALUE #( mt_packages[ pkg_id = ls_from-pkg_id ]-pkg_rank OPTIONAL ).
      DATA(lv_pred_rank) = VALUE #( mt_packages[ pkg_id = ls_pred-pkg_id ]-pkg_rank OPTIONAL ).
      IF ls_from IS INITIAL OR ls_pred IS INITIAL OR lv_pred_rank > lv_from_rank.
        INSERT problem( iv_key   = <ls_dep>-process_id
                        iv_msgno = zif_ca_ops_cat_types=>gc_msg-dep_invalid
                        iv_v1    = <ls_dep>-process_id
                        iv_v2    = <ls_dep>-pred_id ) INTO TABLE rt_problems.
      ENDIF.
    ENDLOOP.
    LOOP AT mt_processes ASSIGNING <ls_process>.
      DATA(lt_reach) = predecessors( <ls_process>-process_id ).
      IF line_exists( lt_reach[ table_line = <ls_process>-process_id ] ).
        INSERT problem( iv_key   = <ls_process>-process_id
                        iv_msgno = zif_ca_ops_cat_types=>gc_msg-dep_cycle
                        iv_v1    = <ls_process>-process_id ) INTO TABLE rt_problems.
      ENDIF.
    ENDLOOP.

    LOOP AT mt_activations ASSIGNING FIELD-SYMBOL(<ls_act>).
      IF NOT line_exists( mt_processes[ process_id = <ls_act>-process_id ] ).
        INSERT problem( iv_key   = <ls_act>-process_id
                        iv_msgno = zif_ca_ops_cat_types=>gc_msg-act_unknown
                        iv_v1    = <ls_act>-process_id
                        iv_v2    = <ls_act>-valid_from ) INTO TABLE rt_problems.
      ELSEIF <ls_act>-reason IS INITIAL OR <ls_act>-approved_by IS INITIAL.
        INSERT problem( iv_key   = <ls_act>-process_id
                        iv_msgno = zif_ca_ops_cat_types=>gc_msg-act_incomplete
                        iv_v1    = <ls_act>-process_id
                        iv_v2    = <ls_act>-valid_from ) INTO TABLE rt_problems.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD predecessors.
    DATA lt_todo TYPE tt_ids.
    INSERT iv_process_id INTO TABLE lt_todo.
    WHILE lt_todo IS NOT INITIAL.
      DATA(lv_id) = lt_todo[ 1 ].
      DELETE lt_todo INDEX 1.
      LOOP AT mt_dependencies ASSIGNING FIELD-SYMBOL(<ls_dep>) WHERE process_id = lv_id.
        IF NOT line_exists( rt_ids[ table_line = <ls_dep>-pred_id ] ).
          INSERT <ls_dep>-pred_id INTO TABLE rt_ids.
          INSERT <ls_dep>-pred_id INTO TABLE lt_todo.
        ENDIF.
      ENDLOOP.
    ENDWHILE.
  ENDMETHOD.


  METHOD problem.
    rs_problem = VALUE #( object_key = iv_key
                          msgno      = iv_msgno
                          v1         = iv_v1
                          v2         = iv_v2
                          v3         = iv_v3 ).
  ENDMETHOD.

ENDCLASS.
