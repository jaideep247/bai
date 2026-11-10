*&---------------------------------------------------------------------*
*& Artifact: zcx_ca_ops_error.clas.abap
*& Purpose:
*& Checked exception of the operations framework ZCA_OPS, raised with
*& message class ZCA_OPS, e.g.
*& RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e010(zca_ops) WITH lv_table.
*& Consumers derive their own exception class from it (their message
*& class), so one CATCH zcx_ca_ops_error at a run boundary covers both.
*& CLASSIFY names the error class of the message (TRANSIENT / CONFIG,
*& blank = no rule; ZCL_CA_OPS_UTIL=>ERROR_CLASS); a subclass redefines it
*& for its own message class and calls the superclass for every other.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-10 | Moved from ZCX_CD_OPS_ERROR to the reusable framework ZCA_OPS (message class ZCA_OPS,
*&            | not final: consumers inherit; CLASSIFY replaces the message-number rules of the utility).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - checked exception</p>
"! Raise with message class ZCA_OPS, e.g.
"! RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e010(zca_ops) WITH lv_table.
"! Consumers inherit from it; CLASSIFY is redefined for their message class.
CLASS zcx_ca_ops_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL.

    "! Error class of this exception's message: TRANSIENT (lock, timeout) or CONFIG (configuration,
    "! authorisation) by the rules of ZIF_CA_OPS_TYPES=>GC_ERROR_RULE for messages of class ZCA_OPS;
    "! blank when no rule applies (the caller decides from the rest of the chain)
    METHODS classify
      RETURNING
        VALUE(rv_class) TYPE zif_ca_ops_types=>ty_error_class.

  PROTECTED SECTION.
    "! TRANSIENT / CONFIG / blank for a message number and the two comma lists of a rule set
    CLASS-METHODS class_of_number
      IMPORTING
        iv_msgno           TYPE symsgno
        iv_transient_msgno TYPE string
        iv_config_msgno    TYPE string
      RETURNING
        VALUE(rv_class)    TYPE zif_ca_ops_types=>ty_error_class.

  PRIVATE SECTION.
    CONSTANTS gc_list_separator TYPE string VALUE `,`.

ENDCLASS.



CLASS zcx_ca_ops_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.


  METHOD classify.
    IF if_t100_message~t100key-msgid <> zif_ca_ops_types=>gc_message_class.
      RETURN.
    ENDIF.
    rv_class = class_of_number( iv_msgno           = if_t100_message~t100key-msgno
                                iv_transient_msgno = zif_ca_ops_types=>gc_error_rule-transient_msgno
                                iv_config_msgno    = zif_ca_ops_types=>gc_error_rule-config_msgno ).
  ENDMETHOD.


  METHOD class_of_number.
    SPLIT iv_transient_msgno AT gc_list_separator INTO TABLE DATA(lt_transient).
    SPLIT iv_config_msgno AT gc_list_separator INTO TABLE DATA(lt_config).
    DATA(lv_msgno) = CONV string( iv_msgno ).
    rv_class = COND #( WHEN line_exists( lt_transient[ table_line = lv_msgno ] )
                       THEN zif_ca_ops_types=>gc_error_class-transient
                       WHEN line_exists( lt_config[ table_line = lv_msgno ] )
                       THEN zif_ca_ops_types=>gc_error_class-config ).
  ENDMETHOD.

ENDCLASS.
