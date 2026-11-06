*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_ddic.clas.abap
*& Purpose:
*& RTTI-based DDIC describer: returns the field list of a configured
*& table so ZCL_CD_FMON_QUERY can validate names before any dynamic SQL.
*& Thin wrapper over CL_ABAP_TYPEDESCR; no database access. The S_TABU_NAM
*& check sits in test seam TABLE_AUTH (own test include).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A51: S_TABU_NAM display check for the dynamic reader.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Test seam TABLE_AUTH around the S_TABU_NAM check (coverage gap closure).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - DDIC describer (RTTI)</p>
CLASS zcl_cd_fmon_ddic DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_ddic.

ENDCLASS.



CLASS zcl_cd_fmon_ddic IMPLEMENTATION.

  METHOD zif_cd_fmon_ddic~may_read.
    DATA(lv_table) = to_upper( condense( CONV string( iv_table ) ) ).
    TEST-SEAM table_auth.
      AUTHORITY-CHECK OBJECT zif_cd_fmon_types=>gc_table_auth-object
        ID zif_cd_fmon_types=>gc_table_auth-id_actvt FIELD zif_cd_fmon_types=>gc_table_auth-display
        ID zif_cd_fmon_types=>gc_table_auth-id_table FIELD lv_table.
      rv_allowed = xsdbool( sy-subrc = 0 ).
    END-TEST-SEAM.
  ENDMETHOD.


  METHOD zif_cd_fmon_ddic~describe_table.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_dfies TYPE ddfields.
    DATA ls_field TYPE zif_cd_fmon_types=>ty_ddic_field.

    DATA(lv_name) = to_upper( condense( CONV string( iv_table ) ) ).
    IF zcl_cd_fmon_query=>is_valid_name( lv_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e202(zcd_ops) WITH iv_table.
    ENDIF.

    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = lv_name
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e200(zcd_ops) WITH iv_table.
    ENDIF.

    TRY.
        lo_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e200(zcd_ops) WITH iv_table.
    ENDTRY.

    IF lo_struct->is_ddic_type( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e200(zcd_ops) WITH iv_table.
    ENDIF.

    lo_struct->get_ddic_field_list(
      RECEIVING
        p_field_list = lt_dfies
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e200(zcd_ops) WITH iv_table.
    ENDIF.

    LOOP AT lt_dfies ASSIGNING FIELD-SYMBOL(<ls_dfies>).
      CLEAR ls_field.
      ls_field-fieldname = <ls_dfies>-fieldname.
      ls_field-inttype   = <ls_dfies>-inttype.
      ls_field-leng      = <ls_dfies>-leng.
      ls_field-keyflag   = xsdbool( <ls_dfies>-keyflag = abap_true ).
      INSERT ls_field INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
