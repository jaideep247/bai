*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_links.clas.abap
*& Purpose:
*& Registered check of the link registry (ZIF_CA_OPS_CHECK; a consumer
*& registers it in ZCA_OPS_CHECK of its area, docs/LINK_REGISTRY.md): the
*& runtime validation of the registry rows - every rule of
*& ZCL_CA_OPS_LINK_REGISTRY=>VALIDATE (a problem takes its link or object
*& out of every walk) and every declared field of an active object present
*& in the runtime DDIC of its source (metadata only, no data read) - as
*& warning findings, plus one information finding with the counts. The
*& twin of the offline validator (tools/link_registry.py --check), which
*& runs before a transport; this one proves the rows of the system.
*& Since 2026-11-16 (build Q): every "to one" link ambiguous by design
*& (its conditions do not cover the identity of its target) is a warning
*& LINK_AMBIGUOUS - effective, never accepted silently; objects that name
*& a table, view or field this system does not have make the evaluation
*& partial or not evaluated with the reason (TY_RESULT-EVAL, build O).
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*& 2026-11-16 | LINK_AMBIGUOUS findings; missing DDIC objects as the evaluation's reason (build Q).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link registry check</p>
CLASS zcl_ca_ops_chk_links DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! @parameter io_dao | Data access (default ZCL_CA_OPS_LINK_DAO; a double in tests)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_link_dao OPTIONAL.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO zif_ca_ops_link_dao.

    "! Declared fields of active objects that the runtime DDIC of their source does not know
    METHODS ddic_problems
      IMPORTING
        is_registry        TYPE zif_ca_ops_link_types=>ty_registry
      RETURNING
        VALUE(rt_problems) TYPE zif_ca_ops_link_types=>tt_problem.

    "! The evaluation of the run (build O): objects whose table, view or field this system lacks are not
    "! evaluated (some = partial, all = not evaluated) with the reason 633
    METHODS evaluation
      IMPORTING
        is_registry     TYPE zif_ca_ops_link_types=>ty_registry
        it_ddic         TYPE zif_ca_ops_link_types=>tt_problem
      RETURNING
        VALUE(rs_eval)  TYPE zif_ca_ops_eval_types=>ty_check_eval.

    METHODS finding
      IMPORTING
        is_problem        TYPE zif_ca_ops_link_types=>ty_problem
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_ca_ops_chk_links IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_link_dao( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_check~run.
    DATA(ls_effective) = zcl_ca_ops_link_registry=>effective( mo_dao->read_registry( ) ).
    LOOP AT ls_effective-problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
      INSERT finding( is_problem  = <ls_problem>
                      iv_code     = zif_ca_ops_link_types=>gc_code-problem
                      iv_severity = zif_ca_ops_types=>gc_severity-warning ) INTO TABLE rs_result-findings.
    ENDLOOP.
    " ambiguous by design: effective, its candidates are shown - reported, never accepted silently (build Q)
    LOOP AT ls_effective-notes ASSIGNING <ls_problem>.
      INSERT finding( is_problem  = <ls_problem>
                      iv_code     = zif_ca_ops_link_types=>gc_code-ambiguous
                      iv_severity = zif_ca_ops_types=>gc_severity-warning ) INTO TABLE rs_result-findings.
    ENDLOOP.
    DATA(lt_ddic) = ddic_problems( ls_effective-registry ).
    LOOP AT lt_ddic ASSIGNING <ls_problem>.
      INSERT finding( is_problem  = <ls_problem>
                      iv_code     = zif_ca_ops_link_types=>gc_code-ddic
                      iv_severity = zif_ca_ops_types=>gc_severity-warning ) INTO TABLE rs_result-findings.
    ENDLOOP.
    rs_result-eval = evaluation( is_registry = ls_effective-registry it_ddic = lt_ddic ).

    DATA(lv_links) = 0.
    LOOP AT ls_effective-chains ASSIGNING FIELD-SYMBOL(<ls_chain>).
      lv_links = lv_links + lines( <ls_chain>-links ).
    ENDLOOP.
    INSERT finding( is_problem  = VALUE #( subject = zif_ca_ops_link_types=>gc_rule_id
                                           msgno   = zif_ca_ops_link_types=>gc_msg-summary
                                           v1      = lv_links
                                           v2      = lines( ls_effective-problems ) + lines( lt_ddic ) )
                    iv_code     = zif_ca_ops_link_types=>gc_code-summary
                    iv_severity = zif_ca_ops_types=>gc_severity-info ) INTO TABLE rs_result-findings.
    rs_result-item_count = lines( ls_effective-registry-links ) + lines( ls_effective-registry-objects ).
  ENDMETHOD.


  METHOD ddic_problems.
    LOOP AT is_registry-objects ASSIGNING FIELD-SYMBOL(<ls_object>) WHERE active = abap_true.
      DATA(lt_fields) = mo_dao->source_fields( <ls_object>-source_name ).
      IF lt_fields IS INITIAL.
        INSERT VALUE #( subject = <ls_object>-object_id msgno = zif_ca_ops_link_types=>gc_msg-field_unknown
                        v1 = <ls_object>-object_id v2 = zif_ca_ops_link_types=>gc_mask_char
                        v3 = <ls_object>-source_name ) INTO TABLE rt_problems.
        CONTINUE.
      ENDIF.
      LOOP AT is_registry-fields ASSIGNING FIELD-SYMBOL(<ls_field>) WHERE object_id = <ls_object>-object_id.
        IF NOT line_exists( lt_fields[ fieldname = <ls_field>-field_name ] ).
          INSERT VALUE #( subject = <ls_object>-object_id msgno = zif_ca_ops_link_types=>gc_msg-field_unknown
                          v1 = <ls_object>-object_id v2 = <ls_field>-field_name
                          v3 = <ls_object>-source_name ) INTO TABLE rt_problems.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD evaluation.
    DATA lt_missing TYPE SORTED TABLE OF zif_ca_ops_link_types=>ty_link_id WITH UNIQUE KEY table_line.

    LOOP AT it_ddic ASSIGNING FIELD-SYMBOL(<ls_problem>).
      INSERT <ls_problem>-subject INTO TABLE lt_missing.
    ENDLOOP.
    DATA(lv_active) = 0.
    LOOP AT is_registry-objects TRANSPORTING NO FIELDS WHERE active = abap_true.
      lv_active += 1.
    ENDLOOP.
    rs_eval-unevaluated = lines( lt_missing ).
    rs_eval-evaluated   = lv_active - rs_eval-unevaluated.
    IF lt_missing IS NOT INITIAL.
      rs_eval-reason_code = zif_ca_ops_eval_types=>gc_reason-ddic_missing.
      rs_eval-reason      = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_link_types=>gc_msg-ddic_missing
                                                   iv_v1    = lines( lt_missing )
                                                   iv_v2    = lv_active
                                                   iv_v3    = lt_missing[ 1 ] ).
    ENDIF.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_type = zif_ca_ops_link_types=>gc_object_type.
    rs_finding-object_key  = |{ is_problem-subject }/{ is_problem-msgno }/{ is_problem-v2 }|.
    rs_finding-rule_id     = zif_ca_ops_link_types=>gc_rule_id.
    rs_finding-check_code  = iv_code.
    rs_finding-severity    = iv_severity.
    rs_finding-action      = COND #( WHEN iv_severity = zif_ca_ops_types=>gc_severity-info
                                     THEN zif_ca_ops_types=>gc_action-notify
                                     ELSE zif_ca_ops_types=>gc_action-exception ).
    rs_finding-reference   = is_problem-subject.
    rs_finding-message     = zcl_ca_ops_util=>text( iv_msgno = is_problem-msgno
                                                    iv_v1    = is_problem-v1
                                                    iv_v2    = is_problem-v2
                                                    iv_v3    = is_problem-v3
                                                    iv_v4    = is_problem-v4 ).
  ENDMETHOD.

ENDCLASS.
