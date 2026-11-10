*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_auth.clas.abap
*& Purpose:
*& The only AUTHORITY-CHECK on object ZCA_OPS. Thin wrapper: each kernel
*& check sits in a test seam (AUTH_AREA, AUTH_BUKRS), so the own test include
*& proves the branch and check( ); consumers use an injected double
*& (zcl_ca_ops_injector=>INJECT_AUTH). The kernel check itself is QA1 (roles).
*& Modification log:
*& 2026-11-06 | Initial version (authorisation object ZCA_OPS, gap G3).
*& 2026-11-06 | Test seams AUTH_AREA / AUTH_BUKRS around the kernel check (coverage gap closure).
*& 2026-11-10 | Field ZCA_PARAR (SU20, auth_zcd_ops.md section 1); a wrong field name failed every check.
*& 2026-11-10 | may_read_table: S_TABU_NAM 03 in test seam AUTH_TABLE (was a consumer's DDIC helper, now shared).
*& 2026-11-10 | Moved from ZCL_CD_OPS_AUTH to the reusable framework ZCA_OPS.
*& 2026-11-10 | user_exists in test seam USER_EXISTS (SUSR_USER_CHECK_EXISTENCE, control register).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - authorisation check ZCA_OPS</p>
"! Object ZCA_OPS must exist (SU21, config/auth_zcd_ops.md) before activation.
CLASS zcl_ca_ops_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth.

ENDCLASS.



CLASS zcl_ca_ops_auth IMPLEMENTATION.

  METHOD zif_ca_ops_auth~is_allowed.
    IF iv_bukrs IS INITIAL.
      TEST-SEAM auth_area.
        AUTHORITY-CHECK OBJECT zif_ca_ops_auth=>gc_object
          ID 'ACTVT'      FIELD iv_activity
          ID 'ZCA_PARAR' FIELD iv_area
          ID 'BUKRS'      DUMMY.
        rv_allowed = xsdbool( sy-subrc = 0 ).
      END-TEST-SEAM.
      RETURN.
    ENDIF.
    TEST-SEAM auth_bukrs.
      AUTHORITY-CHECK OBJECT zif_ca_ops_auth=>gc_object
        ID 'ACTVT'      FIELD iv_activity
        ID 'ZCA_PARAR' FIELD iv_area
        ID 'BUKRS'      FIELD iv_bukrs.
      rv_allowed = xsdbool( sy-subrc = 0 ).
    END-TEST-SEAM.
  ENDMETHOD.


  METHOD zif_ca_ops_auth~may_read_table.
    DATA(lv_table) = to_upper( condense( CONV string( iv_table ) ) ).
    TEST-SEAM auth_table.
      AUTHORITY-CHECK OBJECT zif_ca_ops_auth=>gc_table_auth-object
        ID zif_ca_ops_auth=>gc_table_auth-id_actvt FIELD zif_ca_ops_auth=>gc_table_auth-display
        ID zif_ca_ops_auth=>gc_table_auth-id_table FIELD lv_table.
      rv_allowed = xsdbool( sy-subrc = 0 ).
    END-TEST-SEAM.
  ENDMETHOD.


  METHOD zif_ca_ops_auth~user_exists.
    IF iv_user IS INITIAL.
      RETURN.
    ENDIF.
    TEST-SEAM user_exists.
      " VERIFY-ADT: function module and its exception (user master USR02, read by SAP)
      CALL FUNCTION 'SUSR_USER_CHECK_EXISTENCE'
        EXPORTING
          user_name            = iv_user
        EXCEPTIONS
          user_name_not_exists = 1
          OTHERS               = 2.
      rv_exists = xsdbool( sy-subrc = 0 ).
    END-TEST-SEAM.
  ENDMETHOD.


  METHOD zif_ca_ops_auth~check.
    IF zif_ca_ops_auth~is_allowed( iv_activity = iv_activity
                                   iv_area   = iv_area
                                   iv_bukrs    = iv_bukrs ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e041(zca_ops) WITH |{ zif_ca_ops_auth=>gc_object } { iv_area }| iv_activity.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
