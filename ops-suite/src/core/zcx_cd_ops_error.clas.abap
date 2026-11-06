*&---------------------------------------------------------------------*
*& Artifact: zcx_cd_ops_error.clas.abap
*& Purpose:
*& Raise with message class ZCD_OPS, e.g.
*& RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e010(zcd_ops) WITH lv_table.
*& Message number ranges: 001-099 core, 100-199 EBS, 200-299 FMON, 300-399 HCK.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - checked exception</p>
"! Raise with message class ZCD_OPS, e.g.
"! RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e010(zcd_ops) WITH lv_table.
"! Message number ranges: 001-099 core, 100-199 EBS, 200-299 FMON, 300-399 HCK.
CLASS zcx_cd_ops_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL.

ENDCLASS.



CLASS zcx_cd_ops_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
