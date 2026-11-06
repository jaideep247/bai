*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_injector.clas.abap
*& Purpose:
*& Unit tests only: writes the double slots of ZCL_CD_EBS_FACTORY. Always call
*& reset( ) in teardown. Not FOR TESTING so the factory can name it GLOBAL FRIEND.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | inject_release_dao (design 6.2).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - test injector</p>
CLASS zcl_cd_ebs_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS inject_cfg_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ebs_cfg_dao.

    CLASS-METHODS inject_feb_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ebs_feb_dao.

    CLASS-METHODS inject_sap_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ebs_sap_dao.

    CLASS-METHODS inject_parser
      IMPORTING
        io_parser TYPE REF TO zif_cd_ebs_parser.

    CLASS-METHODS inject_release_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ebs_release_dao.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_ebs_injector IMPLEMENTATION.

  METHOD inject_cfg_dao.
    zcl_cd_ebs_factory=>go_cfg_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_feb_dao.
    zcl_cd_ebs_factory=>go_feb_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_sap_dao.
    zcl_cd_ebs_factory=>go_sap_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_parser.
    zcl_cd_ebs_factory=>go_parser_double = io_parser.
  ENDMETHOD.


  METHOD inject_release_dao.
    zcl_cd_ebs_factory=>go_release_dao_double = io_dao.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_ebs_factory=>go_cfg_dao_double,
           zcl_cd_ebs_factory=>go_feb_dao_double,
           zcl_cd_ebs_factory=>go_sap_dao_double,
           zcl_cd_ebs_factory=>go_parser_double,
           zcl_cd_ebs_factory=>go_release_dao_double.
  ENDMETHOD.

ENDCLASS.
