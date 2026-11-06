*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_clock.clas.abap
*& Purpose:
*& Operations suite - system clock
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - system clock</p>
CLASS zcl_cd_ops_clock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.

ENDCLASS.



CLASS zcl_cd_ops_clock IMPLEMENTATION.

  METHOD zif_cd_ops_clock~now.
    GET TIME STAMP FIELD rv_timestamp.
  ENDMETHOD.


  METHOD zif_cd_ops_clock~today.
    rv_date = sy-datum.
  ENDMETHOD.


  METHOD zif_cd_ops_clock~time.
    rv_time = sy-uzeit.
  ENDMETHOD.

ENDCLASS.
