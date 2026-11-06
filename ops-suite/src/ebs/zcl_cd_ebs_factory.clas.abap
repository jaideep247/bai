*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_factory.clas.abap
*& Purpose:
*& Resolves EBS repositories and parsers. Test doubles come from
*& ZCL_CD_EBS_INJECTOR. Getters never read the database.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Release repository seam (design 6.2).
*& 2026-11-06 | Audit A62: parser plug-in created with interface check (RTTI before CREATE OBJECT).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - factory</p>
CLASS zcl_cd_ebs_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_cd_ebs_injector.

  PUBLIC SECTION.
    CLASS-METHODS get_cfg_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_cfg_dao.

    CLASS-METHODS get_feb_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_feb_dao.

    CLASS-METHODS get_sap_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_sap_dao.

    "! Approved blocked-line releases for the posting gate (design 6.2)
    CLASS-METHODS get_release_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ebs_release_dao.

    "! Parser for a file format. Class from ZCD_OPS_PARAM EBS_PARSER_<format>,
    "! default ZCL_CD_EBS_PARSER_BAI2 / ZCL_CD_EBS_PARSER_CAMT.
    CLASS-METHODS get_parser
      IMPORTING
        iv_format        TYPE zif_cd_ebs_types=>ty_format
      RETURNING
        VALUE(ro_parser) TYPE REF TO zif_cd_ebs_parser
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    CLASS-DATA go_cfg_dao_double TYPE REF TO zif_cd_ebs_cfg_dao.
    CLASS-DATA go_feb_dao_double TYPE REF TO zif_cd_ebs_feb_dao.
    CLASS-DATA go_sap_dao_double TYPE REF TO zif_cd_ebs_sap_dao.
    CLASS-DATA go_parser_double  TYPE REF TO zif_cd_ebs_parser.
    CLASS-DATA go_release_dao_double TYPE REF TO zif_cd_ebs_release_dao.

ENDCLASS.



CLASS zcl_cd_ebs_factory IMPLEMENTATION.

  METHOD get_cfg_dao.
    ro_dao = COND #( WHEN go_cfg_dao_double IS BOUND THEN go_cfg_dao_double
                     ELSE NEW zcl_cd_ebs_cfg_dao( ) ).
  ENDMETHOD.


  METHOD get_feb_dao.
    ro_dao = COND #( WHEN go_feb_dao_double IS BOUND THEN go_feb_dao_double
                     ELSE NEW zcl_cd_ebs_feb_dao( ) ).
  ENDMETHOD.


  METHOD get_sap_dao.
    ro_dao = COND #( WHEN go_sap_dao_double IS BOUND THEN go_sap_dao_double
                     ELSE NEW zcl_cd_ebs_sap_dao( ) ).
  ENDMETHOD.


  METHOD get_release_dao.
    ro_dao = COND #( WHEN go_release_dao_double IS BOUND THEN go_release_dao_double
                     ELSE NEW zcl_cd_ebs_release_dao( ) ).
  ENDMETHOD.


  METHOD get_parser.
    IF go_parser_double IS BOUND.
      ro_parser = go_parser_double.
      RETURN.
    ENDIF.
    DATA(lv_default) = COND string( WHEN iv_format = zif_cd_ebs_types=>gc_format-bai2
                                    THEN `ZCL_CD_EBS_PARSER_BAI2`
                                    ELSE `ZCL_CD_EBS_PARSER_CAMT` ).
    DATA(lv_class) = zcl_cd_ops_factory=>get_store( )->get_param(
      iv_name    = CONV #( |EBS_PARSER_{ iv_format }| )
      iv_default = lv_default ).
    TRY.
        ro_parser = CAST zif_cd_ebs_parser( zcl_cd_ops_factory=>get_plugin(
                                              iv_class_name = CONV #( lv_class )
                                              iv_interface  = zif_cd_ebs_types=>gc_plugin_interface-parser ) ).
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e032(zcd_ops) WITH lv_class zif_cd_ebs_types=>gc_plugin_interface-parser.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
