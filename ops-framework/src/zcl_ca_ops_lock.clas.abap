*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lock.clas.abap
*& Purpose:
*& Run lock over the standard generic lock object E_TABLE with table
*& ZCA_OPS_LOCK (key MANDT, AREA, VARIANT) as argument. _SCOPE '1': the lock
*& belongs to the program, not to the update task, so it survives the engines'
*& COMMIT WORK per package. Thin wrapper: the lock function calls sit in test
*& seams (ENQUEUE, DEQUEUE), so the own test include proves the result mapping;
*& engines are tested with an injected double; the lock server itself is QA1.
*& Modification log:
*& 2026-11-06 | Initial version (run lock).
*& 2026-11-06 | Webhook key of the area (rename regression fixed); column names in comments.
*& 2026-11-06 | Test seams ENQUEUE / DEQUEUE around the lock function calls (coverage gap closure).
*& 2026-11-10 | Moved from ZCL_CD_OPS_LOCK to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - run lock (E_TABLE on ZCA_OPS_LOCK)</p>
CLASS zcl_ca_ops_lock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_lock.

  PRIVATE SECTION.
    CONSTANTS gc_lock_table TYPE tabname VALUE 'ZCA_OPS_LOCK'.
    CONSTANTS gc_exclusive  TYPE enqmode VALUE 'E'.
    "! Lock owned by the program (dialog owner), kept across COMMIT WORK
    CONSTANTS gc_scope      TYPE ddenqscope VALUE '1'.

    METHODS varkey
      IMPORTING
        iv_area        TYPE zif_ca_ops_types=>ty_area
        iv_variant       TYPE zif_ca_ops_types=>ty_variant
      RETURNING
        VALUE(rv_varkey) TYPE rstable-varkey.

ENDCLASS.



CLASS zcl_ca_ops_lock IMPLEMENTATION.

  METHOD zif_ca_ops_lock~acquire.
    DATA lv_subrc TYPE sysubrc.
    DATA lv_holder TYPE syuname.
    DATA(lv_varkey) = varkey( iv_area = iv_area iv_variant = iv_variant ).
    CLEAR ev_holder.

    " VERIFY-SE37: ENQUEUE_E_TABLE parameters MODE_RSTABLE, TABNAME, VARKEY, _SCOPE
    TEST-SEAM enqueue.
      CALL FUNCTION 'ENQUEUE_E_TABLE'
        EXPORTING
          mode_rstable   = gc_exclusive
          tabname        = gc_lock_table
          varkey         = lv_varkey
          _scope         = gc_scope
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.
      lv_subrc  = sy-subrc.
      lv_holder = sy-msgv1.
    END-TEST-SEAM.
    CASE lv_subrc.
      WHEN 0.
        rv_acquired = abap_true.
      WHEN 1.
        ev_holder = lv_holder.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e042(zca_ops) WITH iv_area iv_variant.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_ca_ops_lock~release.
    DATA(lv_varkey) = varkey( iv_area = iv_area iv_variant = iv_variant ).

    " VERIFY-SE37: DEQUEUE_E_TABLE parameters MODE_RSTABLE, TABNAME, VARKEY, _SCOPE
    TEST-SEAM dequeue.
      CALL FUNCTION 'DEQUEUE_E_TABLE'
        EXPORTING
          mode_rstable = gc_exclusive
          tabname      = gc_lock_table
          varkey       = lv_varkey
          _scope       = gc_scope.
    END-TEST-SEAM.
  ENDMETHOD.


  METHOD varkey.
    " Fixed positions of the ZCA_OPS_LOCK key: MANDT (3), AREA (16), VARIANT (30)
    DATA lv_area  TYPE zif_ca_ops_types=>ty_area.
    DATA lv_variant TYPE zif_ca_ops_types=>ty_variant.
    lv_area  = iv_area.
    lv_variant = iv_variant.
    CONCATENATE sy-mandt lv_area lv_variant INTO rv_varkey RESPECTING BLANKS.
  ENDMETHOD.

ENDCLASS.
