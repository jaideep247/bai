*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_auth.clas.abap
*& Purpose:
*& The only AUTHORITY-CHECK on object ZCD_OPS. Thin wrapper - deliberately
*& not unit tested (it would only assert the kernel call); every consumer is
*& tested with an injected double (ZCL_CD_OPS_INJECTOR=>INJECT_AUTH).
*& Modification log:
*& 2026-11-06 | Initial version (authorisation object ZCD_OPS, gap G3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - authorisation check ZCD_OPS</p>
"! Object ZCD_OPS must exist (SU21, config/auth_zcd_ops.md) before activation.
CLASS zcl_cd_ops_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_auth.

ENDCLASS.



CLASS zcl_cd_ops_auth IMPLEMENTATION.

  METHOD zif_cd_ops_auth~is_allowed.
    IF iv_bukrs IS INITIAL.
      AUTHORITY-CHECK OBJECT zif_cd_ops_auth=>gc_object
        ID 'ACTVT'      FIELD iv_activity
        ID 'ZCD_MODULE' FIELD iv_pe_area
        ID 'BUKRS'      DUMMY.
      rv_allowed = xsdbool( sy-subrc = 0 ).
      RETURN.
    ENDIF.
    AUTHORITY-CHECK OBJECT zif_cd_ops_auth=>gc_object
      ID 'ACTVT'      FIELD iv_activity
      ID 'ZCD_MODULE' FIELD iv_pe_area
      ID 'BUKRS'      FIELD iv_bukrs.
    rv_allowed = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD zif_cd_ops_auth~check.
    IF zif_cd_ops_auth~is_allowed( iv_activity = iv_activity
                                   iv_pe_area   = iv_pe_area
                                   iv_bukrs    = iv_bukrs ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e041(zcd_ops) WITH |{ zif_cd_ops_auth=>gc_object } { iv_pe_area }| iv_activity.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
