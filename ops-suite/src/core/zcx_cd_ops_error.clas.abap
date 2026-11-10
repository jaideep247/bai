*&---------------------------------------------------------------------*
*& Artifact: zcx_cd_ops_error.clas.abap
*& Purpose:
*& Raise with message class ZCD_OPS, e.g.
*& RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e010(zcd_ops) WITH lv_table.
*& Message number ranges: 001-099 core, 100-199 EBS, 200-299 FMON, 300-399 HCK.
*& Inherits from the framework exception ZCX_CA_OPS_ERROR: callers declare
*& and catch ZCX_CA_OPS_ERROR, which covers both. CLASSIFY applies the
*& suite's rules (ZIF_CD_OPS_TYPES=>GC_ERROR_RULE) to ZCD_OPS messages.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-10 | Inherits from ZCX_CA_OPS_ERROR (framework ZCA_OPS); CLASSIFY for ZCD_OPS messages (the
*&            | message-number rules of the former ZCL_CD_OPS_UTIL=>ERROR_CLASS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - checked exception</p>
"! Raise with message class ZCD_OPS, e.g.
"! RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e010(zcd_ops) WITH lv_table.
"! Message number ranges: 001-099 core, 100-199 EBS, 200-299 FMON, 300-399 HCK.
CLASS zcx_cd_ops_error DEFINITION
  PUBLIC
  INHERITING FROM zcx_ca_ops_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL.

    METHODS classify REDEFINITION.

ENDCLASS.



CLASS zcx_cd_ops_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid   = textid
                        previous = previous ).
  ENDMETHOD.


  METHOD classify.
    IF if_t100_message~t100key-msgid <> zif_cd_ops_types=>gc_message_class.
      rv_class = super->classify( ).
      RETURN.
    ENDIF.
    rv_class = class_of_number( iv_msgno           = if_t100_message~t100key-msgno
                                iv_transient_msgno = zif_cd_ops_types=>gc_error_rule-transient_msgno
                                iv_config_msgno    = zif_cd_ops_types=>gc_error_rule-config_msgno ).
  ENDMETHOD.

ENDCLASS.
