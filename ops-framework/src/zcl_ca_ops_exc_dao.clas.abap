*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_exc_dao.clas.abap
*& Purpose:
*& Exception repository: finds the open exceptions of an object (with the
*& disposition and change stamp read) and closes them as resolved with one
*& ZCA_OPS_EXC_HIST row each - all or nothing: an exception is written only
*& while it is as read, the history rows only when every exception was
*& written. Used where an exception is closed by another app's save (PRISM
*& payment request handled manually). No commit - caller's LUW.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Webhook key peArea (rename regression fixed); column names in comments.
*& 2026-11-06 | Performance fix 5: index OBJ is (MANDT, AREA, OBJECT_KEY) - the object type is not known here.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-07 | Purpose: the EBS release approval is no longer a caller (read-only scope).
*& 2026-11-10 | Concurrency review: guarded resolve (WHERE key AND disposition AND LAST_CHANGED_AT as read,
*&            | sy-dbcnt counted) - a half-written closure is never possible: a count short of the exceptions
*&            | raises 787 before the history insert; LAST_CHANGED_AT set; history inserted accepting duplicate
*&            | keys with a count check.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - exception repository</p>
CLASS zcl_ca_ops_exc_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_exc_dao.

  PRIVATE SECTION.
    TYPES tt_hist TYPE STANDARD TABLE OF zca_ops_exc_hist WITH EMPTY KEY.

    "! Resolve one exception only while its disposition and change stamp are the ones read; abap_false =
    "! changed meanwhile, nothing written
    METHODS guarded_resolve
      IMPORTING
        is_open        TYPE zif_ca_ops_exc_types=>ty_exc_open
        iv_reason      TYPE zif_ca_ops_exc_types=>ty_reason
        iv_user        TYPE syuname
        iv_at          TYPE timestampl
      RETURNING
        VALUE(rv_done) TYPE abap_bool.
ENDCLASS.



CLASS zcl_ca_ops_exc_dao IMPLEMENTATION.

  METHOD zif_ca_ops_exc_dao~find_open.
    " index ZCA_OPS_FINDING~OBJ: MANDT, AREA, OBJECT_KEY (fix 5: callers know no object type)
    SELECT run_id, finding_no, disposition, owner, last_changed_at
      FROM zca_ops_finding
      WHERE area    = @iv_area
        AND object_key = @iv_object_key
        AND ( check_code = @iv_check_code OR @iv_check_code = @space )
        AND disposition IN ( @zif_ca_ops_types=>gc_disposition-open,
                             @zif_ca_ops_types=>gc_disposition-assigned )
      ORDER BY run_id, finding_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_open.
  ENDMETHOD.


  METHOD zif_ca_ops_exc_dao~resolve.
    DATA lt_hist TYPE tt_hist.
    DATA ls_hist TYPE zca_ops_exc_hist.

    CHECK it_open IS NOT INITIAL.
    DATA(lv_done) = 0.
    DATA(ls_changed) = VALUE zif_ca_ops_exc_types=>ty_exc_open( ).
    LOOP AT it_open ASSIGNING FIELD-SYMBOL(<ls_open>).
      IF guarded_resolve( is_open   = <ls_open>
                          iv_reason = iv_reason
                          iv_user   = iv_user
                          iv_at     = iv_at ) = abap_true.
        lv_done = lv_done + 1.
      ELSEIF ls_changed IS INITIAL.
        ls_changed = <ls_open>.
      ENDIF.

      CLEAR ls_hist.
      TRY.
          ls_hist-hist_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO DATA(lx_uuid).
          RAISE EXCEPTION TYPE zcx_ca_ops_error
            MESSAGE e010(zca_ops) WITH 'ZCA_OPS_EXC_HIST'
            EXPORTING
              previous = lx_uuid.
      ENDTRY.
      ls_hist-run_id     = <ls_open>-run_id.
      ls_hist-finding_no = <ls_open>-finding_no.
      ls_hist-action     = iv_action.
      ls_hist-from_disp  = <ls_open>-disposition.
      ls_hist-to_disp    = zif_ca_ops_types=>gc_disposition-resolved.
      ls_hist-owner      = <ls_open>-owner.
      ls_hist-reason     = iv_reason.
      ls_hist-reference  = iv_reference.
      ls_hist-created_by = iv_user.
      ls_hist-created_at = iv_at.
      INSERT ls_hist INTO TABLE lt_hist.
    ENDLOOP.

    " All or nothing: every exception written before any history row. One changed by a user or a run since
    " it was read means nothing of this closure may stay - the caller ends the LUW without commit (RAP
    " save: short dump, the framework rolls back the rows already written)
    IF lv_done <> lines( it_open ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e787(zca_ops) WITH ls_changed-run_id ls_changed-finding_no.
    ENDIF.
    INSERT zca_ops_exc_hist FROM TABLE @lt_hist ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 OR sy-dbcnt <> lines( lt_hist ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e010(zca_ops) WITH 'ZCA_OPS_EXC_HIST'.
    ENDIF.
  ENDMETHOD.


  METHOD guarded_resolve.
    " One keyed UPDATE per exception (an app save closes the few exceptions of one request): ABAP SQL has
    " no set-based compare-and-set, an UPDATE FROM TABLE matches by key only and would overwrite a change
    UPDATE zca_ops_finding
      SET disposition     = @zif_ca_ops_types=>gc_disposition-resolved,
          resolved_by     = @iv_user,
          resolved_at     = @iv_at,
          resolution      = @iv_reason,
          last_changed_at = @iv_at
      WHERE run_id          = @is_open-run_id
        AND finding_no      = @is_open-finding_no
        AND disposition     = @is_open-disposition
        AND last_changed_at = @is_open-last_changed_at.
    rv_done = xsdbool( sy-subrc = 0 AND sy-dbcnt = 1 ).
  ENDMETHOD.

ENDCLASS.
