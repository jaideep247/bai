*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_clock.clas.abap
*& Purpose:
*& Operations framework - system clock
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-10 | Moved from ZCL_CD_OPS_CLOCK to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - system clock</p>
CLASS zcl_ca_ops_clock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.

ENDCLASS.



CLASS zcl_ca_ops_clock IMPLEMENTATION.

  METHOD zif_ca_ops_clock~now.
    GET TIME STAMP FIELD rv_timestamp.
  ENDMETHOD.


  METHOD zif_ca_ops_clock~today.
    rv_date = sy-datum.
  ENDMETHOD.


  METHOD zif_ca_ops_clock~time.
    rv_time = sy-uzeit.
  ENDMETHOD.

ENDCLASS.
