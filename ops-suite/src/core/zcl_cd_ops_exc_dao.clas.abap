*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_exc_dao.clas.abap
*& Purpose:
*& Exception repository: finds the open exceptions of an object and closes
*& them as resolved with one ZCD_OPS_EXC_HIST row each. Used where an
*& exception is closed by another app's save (EBS release approval, PRISM
*& payment request handled manually). No commit - caller's LUW.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Webhook key peArea (rename regression fixed); column names in comments.
*& 2026-11-06 | Performance fix 5: index OBJ is (MANDT, PE_AREA, OBJECT_KEY) - the object type is not known here.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - exception repository</p>
CLASS zcl_cd_ops_exc_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_exc_dao.

  PRIVATE SECTION.
    TYPES tt_hist TYPE STANDARD TABLE OF zcd_ops_exc_hist WITH EMPTY KEY.
    TYPES ty_db_update TYPE zcd_ops_finding WITH INDICATORS col_ind TYPE abap_bool.
    TYPES tt_db_update TYPE STANDARD TABLE OF ty_db_update WITH EMPTY KEY.
ENDCLASS.



CLASS zcl_cd_ops_exc_dao IMPLEMENTATION.

  METHOD zif_cd_ops_exc_dao~find_open.
    " index ZCD_OPS_FINDING~OBJ: MANDT, PE_AREA, OBJECT_KEY (fix 5: callers know no object type)
    SELECT run_id, finding_no
      FROM zcd_ops_finding
      WHERE pe_area     = @iv_pe_area
        AND object_key = @iv_object_key
        AND ( check_code = @iv_check_code OR @iv_check_code = @space )
        AND disposition IN ( @zif_cd_ops_types=>gc_disposition-open,
                             @zif_cd_ops_types=>gc_disposition-assigned )
      ORDER BY run_id, finding_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_keys.
  ENDMETHOD.


  METHOD zif_cd_ops_exc_dao~resolve.
    DATA lt_hist TYPE tt_hist.
    DATA ls_hist TYPE zcd_ops_exc_hist.

    CHECK it_keys IS NOT INITIAL.
    SELECT run_id, finding_no, disposition, owner
      FROM zcd_ops_finding
      FOR ALL ENTRIES IN @it_keys
      WHERE run_id     = @it_keys-run_id
        AND finding_no = @it_keys-finding_no
      INTO TABLE @DATA(lt_current).

    DATA lt_update TYPE tt_db_update.
    DATA ls_update TYPE ty_db_update.
    LOOP AT lt_current INTO DATA(ls_current).
      CLEAR ls_update.
      ls_update-run_id              = ls_current-run_id.
      ls_update-finding_no          = ls_current-finding_no.
      ls_update-disposition         = zif_cd_ops_types=>gc_disposition-resolved.
      ls_update-resolved_by         = iv_user.
      ls_update-resolved_at         = iv_at.
      ls_update-resolution          = iv_reason.
      ls_update-col_ind-disposition = abap_true.
      ls_update-col_ind-resolved_by = abap_true.
      ls_update-col_ind-resolved_at = abap_true.
      ls_update-col_ind-resolution  = abap_true.
      INSERT ls_update INTO TABLE lt_update.

      CLEAR ls_hist.
      TRY.
          ls_hist-hist_uuid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO DATA(lx_uuid).
          RAISE EXCEPTION TYPE zcx_cd_ops_error
            MESSAGE e010(zcd_ops) WITH 'ZCD_OPS_EXC_HIST'
            EXPORTING
              previous = lx_uuid.
      ENDTRY.
      ls_hist-run_id     = ls_current-run_id.
      ls_hist-finding_no = ls_current-finding_no.
      ls_hist-action     = iv_action.
      ls_hist-from_disp  = ls_current-disposition.
      ls_hist-to_disp    = zif_cd_ops_types=>gc_disposition-resolved.
      ls_hist-owner      = ls_current-owner.
      ls_hist-reason     = iv_reason.
      ls_hist-reference  = iv_reference.
      ls_hist-created_by = iv_user.
      ls_hist-created_at = iv_at.
      INSERT ls_hist INTO TABLE lt_hist.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.
    UPDATE zcd_ops_finding FROM TABLE @lt_update INDICATORS SET STRUCTURE col_ind.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH 'ZCD_OPS_FINDING'.
    ENDIF.

    CHECK lt_hist IS NOT INITIAL.
    INSERT zcd_ops_exc_hist FROM TABLE @lt_hist.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_OPS_EXC_HIST'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
