*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_lock.clas.abap
*& Purpose:
*& Run lock over the standard generic lock object E_TABLE with table
*& ZCD_OPS_LOCK (key MANDT, MODULE, VARIANT) as argument. _SCOPE '1': the lock
*& belongs to the program, not to the update task, so it survives the engines'
*& COMMIT WORK per package. Thin wrapper - deliberately not unit tested; engines
*& are tested with an injected double.
*& Modification log:
*& 2026-11-06 | Initial version (run lock).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - run lock (E_TABLE on ZCD_OPS_LOCK)</p>
CLASS zcl_cd_ops_lock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_lock.

  PRIVATE SECTION.
    CONSTANTS gc_lock_table TYPE tabname VALUE 'ZCD_OPS_LOCK'.
    CONSTANTS gc_exclusive  TYPE enqmode VALUE 'E'.
    "! Lock owned by the program (dialog owner), kept across COMMIT WORK
    CONSTANTS gc_scope      TYPE ddenqscope VALUE '1'.

    METHODS varkey
      IMPORTING
        iv_module        TYPE zif_cd_ops_types=>ty_module
        iv_variant       TYPE zif_cd_ops_types=>ty_variant
      RETURNING
        VALUE(rv_varkey) TYPE rstable-varkey.

ENDCLASS.



CLASS zcl_cd_ops_lock IMPLEMENTATION.

  METHOD zif_cd_ops_lock~acquire.
    DATA(lv_varkey) = varkey( iv_module = iv_module iv_variant = iv_variant ).
    CLEAR ev_holder.

    " VERIFY-SE37: ENQUEUE_E_TABLE parameters MODE_RSTABLE, TABNAME, VARKEY, _SCOPE
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
    CASE sy-subrc.
      WHEN 0.
        rv_acquired = abap_true.
      WHEN 1.
        ev_holder = sy-msgv1.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e042(zcd_ops) WITH iv_module iv_variant.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_cd_ops_lock~release.
    DATA(lv_varkey) = varkey( iv_module = iv_module iv_variant = iv_variant ).

    " VERIFY-SE37: DEQUEUE_E_TABLE parameters MODE_RSTABLE, TABNAME, VARKEY, _SCOPE
    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = gc_exclusive
        tabname      = gc_lock_table
        varkey       = lv_varkey
        _scope       = gc_scope.
  ENDMETHOD.


  METHOD varkey.
    " Fixed positions of the ZCD_OPS_LOCK key: MANDT (3), MODULE (4), VARIANT (30)
    DATA lv_module  TYPE zif_cd_ops_types=>ty_module.
    DATA lv_variant TYPE zif_cd_ops_types=>ty_variant.
    lv_module  = iv_module.
    lv_variant = iv_variant.
    CONCATENATE sy-mandt lv_module lv_variant INTO rv_varkey RESPECTING BLANKS.
  ENDMETHOD.

ENDCLASS.
