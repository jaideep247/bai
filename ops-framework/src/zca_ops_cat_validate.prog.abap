*&---------------------------------------------------------------------*
*& Artifact: zca_ops_cat_validate.prog.abap
*& Purpose:
*& Catalogue milestone "platform-validated" (docs/EVALUATION_AND_
*& COVERAGE.md section 6): records that the runnable check of a catalogue
*& process ran on this system and release - by the install harness after
*& its ABAP Unit / check run (source H) or by an operator (source O) - with
*& the release text as stated (never derived), the date, the user, the
*& system ID and the evidence (a qualification file, a run ID). One row per
*& process and system in ZCA_OPS_CATVAL (replaced on a new validation).
*& The catalogue list (ZC_CA_OpsCatalogue) shows it. Authorisation ZCA_OPS
*& 02 for area CA_OPS. Test mode (default) writes nothing. Never seeded.
*& Modification log:
*& 2026-11-16 | Initial version (build O: catalogue milestones).
*&---------------------------------------------------------------------*
REPORT zca_ops_cat_validate.

PARAMETERS p_proc TYPE zif_ca_ops_eval_types=>ty_validation-process_id OBLIGATORY.
PARAMETERS p_rel TYPE zif_ca_ops_eval_types=>ty_validation-release_txt LOWER CASE.
PARAMETERS p_evid TYPE zif_ca_ops_eval_types=>ty_validation-evidence LOWER CASE.
PARAMETERS p_src TYPE zif_ca_ops_eval_types=>ty_validation-source DEFAULT 'O'.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                iv_area     = zif_ca_ops_types=>gc_param_area ).
        IF p_rel IS INITIAL.
          MESSAGE s582(zca_ops) DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.
        DATA(lo_dao) = zcl_ca_ops_factory=>get_cat_dao( ).
        DATA(lv_process) = to_upper( p_proc ).
        DATA(lt_processes) = lo_dao->get_processes( ).
        IF NOT line_exists( lt_processes[ process_id = lv_process ] ).
          MESSAGE s581(zca_ops) WITH lv_process DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.
        DATA(ls_validation) = VALUE zif_ca_ops_eval_types=>ty_validation(
          process_id   = lv_process
          sys_id       = sy-sysid
          release_txt  = p_rel
          validated_on = sy-datum
          validated_by = sy-uname
          source       = COND #( WHEN p_src = zif_ca_ops_eval_types=>gc_val_source-harness
                                 THEN zif_ca_ops_eval_types=>gc_val_source-harness
                                 ELSE zif_ca_ops_eval_types=>gc_val_source-operator )
          evidence     = p_evid ).
        IF p_test = abap_true.
          MESSAGE s583(zca_ops) WITH lv_process sy-sysid p_rel.
          RETURN.
        ENDIF.
        lo_dao->save_validation( ls_validation ).
        zcl_ca_ops_factory=>get_store( )->commit( ).
        MESSAGE s580(zca_ops) WITH lv_process sy-sysid p_rel.
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
