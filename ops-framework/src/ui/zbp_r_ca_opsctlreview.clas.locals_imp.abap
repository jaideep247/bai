*&---------------------------------------------------------------------*
*& Artifact: zbp_r_ca_opsctlreview.clas.locals_imp.abap
*& Purpose:
*& Handler of the daily control review: instance authorisation (ZCA_OPS
*& 02 per area for the sign-off), lock of one control and business date
*& (ZIF_CA_OPS_REVIEW_DAO=>LOCK) and the action markReviewed: the derived
*& status, the latest evidence run, the user and the time are taken from
*& SAP, never typed; ZCL_CA_OPS_REVIEW_POLICY decides whether observation
*& and next action are complete. The saver writes the sign-offs with one
*& call of the repository. Thin: no rule is decided here.
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*& 2026-11-10 | Company-code isolation: a row is a slice (control, date, company code); the sign-off needs
*&            | ZCA_OPS 02 for the area and, for a company-code slice, that BUKRS (ZCL_CA_OPS_EXC_POLICY=>
*&            | MAY_ACT); lock and save per slice.
*&---------------------------------------------------------------------*
CLASS lhc_review DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Review RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Review.

    METHODS markreviewed FOR MODIFY
      IMPORTING keys FOR ACTION Review~markReviewed RESULT result.
ENDCLASS.


CLASS lhc_review IMPLEMENTATION.

  METHOD get_instance_authorizations.
    DATA(lo_auth) = zcl_ca_ops_factory=>get_auth( ).
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      " answer only what the framework asked for (the sign-off changes the area's operations data: 02)
      INSERT VALUE #( %tky                 = <ls_key>-%tky
                      %action-markReviewed = COND #( WHEN requested_authorizations-%action-markReviewed <> if_abap_behv=>mk-on
                                                       THEN if_abap_behv=>auth-allowed
                                                     WHEN zcl_ca_ops_exc_policy=>may_act(
                                                            io_auth     = lo_auth
                                                            iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                            iv_area     = <ls_key>-Area
                                                            iv_bukrs    = <ls_key>-CompanyCode ) = abap_true
                                                       THEN if_abap_behv=>auth-allowed
                                                     ELSE if_abap_behv=>auth-unauthorized ) ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD lock.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_review_dao( ).
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      TRY.
          lo_dao->lock( iv_area          = <ls_key>-Area
                        iv_control_id    = <ls_key>-ControlId
                        iv_business_date = <ls_key>-BusinessDate
                        iv_bukrs         = <ls_key>-CompanyCode ).
        CATCH zcx_ca_ops_error INTO DATA(lx_locked).
          INSERT VALUE #( %tky = <ls_key>-%tky ) INTO TABLE failed-review.
          INSERT VALUE #( %tky = <ls_key>-%tky
                          %msg = new_message( id       = lx_locked->if_t100_message~t100key-msgid
                                              number   = lx_locked->if_t100_message~t100key-msgno
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = lx_locked->if_t100_dyn_msg~msgv1
                                              v2       = lx_locked->if_t100_dyn_msg~msgv2
                                              v3       = lx_locked->if_t100_dyn_msg~msgv3 ) ) INTO TABLE reported-review.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD markreviewed.
    READ ENTITIES OF zr_ca_opsctlreview IN LOCAL MODE
      ENTITY Review ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_reviews).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_reviews INTO DATA(ls_review).
      DATA(ls_key) = keys[ KEY id %tky = ls_review-%tky ].
      DATA(ls_input) = VALUE zif_ca_ops_ctl_types=>ty_review_input( derived_status = ls_review-ControlStatus
                                                                     review_result  = ls_key-%param-ReviewResult
                                                                     observation    = ls_key-%param-Observation
                                                                     next_action    = ls_key-%param-NextAction ).
      DATA(ls_decision) = zcl_ca_ops_review_policy=>can_review( ls_input ).
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = ls_review-%tky ) INTO TABLE failed-review.
        INSERT VALUE #( %tky = ls_review-%tky
                        %msg = new_message( id = zif_ca_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          INTO TABLE reported-review.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_ca_opsctlreview IN LOCAL MODE
        ENTITY Review
          UPDATE FIELDS ( StatusAtReview ReviewResult ReviewedEvidenceRun ReviewedBy ReviewedAt Observation
                          NextAction LastChangedAt )
          WITH VALUE #( ( %tky                = ls_review-%tky
                          StatusAtReview      = ls_review-ControlStatus
                          ReviewResult        = zcl_ca_ops_review_policy=>effective_result( ls_input )
                          ReviewedEvidenceRun = ls_review-EvidenceRun
                          ReviewedBy          = sy-uname
                          ReviewedAt          = lv_now
                          Observation         = ls_key-%param-Observation
                          NextAction          = ls_key-%param-NextAction
                          LastChangedAt       = lv_now ) ).
    ENDLOOP.
    READ ENTITIES OF zr_ca_opsctlreview IN LOCAL MODE
      ENTITY Review ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_zr_ca_opsctlreview DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_zr_ca_opsctlreview IMPLEMENTATION.

  METHOD save_modified.
    DATA lt_reviews TYPE zif_ca_ops_ctl_types=>tt_review.
    LOOP AT update-review ASSIGNING FIELD-SYMBOL(<ls_review>).
      " the action sets every field of the sign-off, so each update carries the complete row
      INSERT VALUE #( area             = <ls_review>-Area
                      control_id       = <ls_review>-ControlId
                      business_date    = <ls_review>-BusinessDate
                      bukrs            = <ls_review>-CompanyCode
                      status_at_review = <ls_review>-StatusAtReview
                      review_result    = <ls_review>-ReviewResult
                      evidence_run     = <ls_review>-ReviewedEvidenceRun
                      reviewed_by      = <ls_review>-ReviewedBy
                      reviewed_at      = <ls_review>-ReviewedAt
                      observation      = <ls_review>-Observation
                      next_action      = <ls_review>-NextAction
                      last_changed_at  = <ls_review>-LastChangedAt ) INTO TABLE lt_reviews.
    ENDLOOP.
    zcl_ca_ops_factory=>get_review_dao( )->save( lt_reviews ).
  ENDMETHOD.

ENDCLASS.
