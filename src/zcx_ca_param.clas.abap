*&---------------------------------------------------------------------*
*& Artifact: zcx_ca_param.clas.abap
*& Purpose:
*& The one exception of the parameter framework (checked, T100 messages of
*& class ZCA_PARAM). Created from a ZIF_CA_PARAM_TYPES=>TY_MESSAGE with
*& CREATE, so that the runtime, the validator and the maintenance app use
*& the same message numbers (ZIF_CA_PARAM_TYPES=>GC_MSG). It does not log.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - exception (ZCA_PARAM)</p>
CLASS zcx_ca_param DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.

    DATA msgv1 TYPE symsgv READ-ONLY.
    DATA msgv2 TYPE symsgv READ-ONLY.
    DATA msgv3 TYPE symsgv READ-ONLY.
    DATA msgv4 TYPE symsgv READ-ONLY.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        msgv1    TYPE symsgv OPTIONAL
        msgv2    TYPE symsgv OPTIONAL
        msgv3    TYPE symsgv OPTIONAL
        msgv4    TYPE symsgv OPTIONAL.

    "! Exception for a message of class ZCA_PARAM
    CLASS-METHODS create
      IMPORTING
        is_message      TYPE zif_ca_param_types=>ty_message
        ix_previous     TYPE REF TO cx_root OPTIONAL
      RETURNING
        VALUE(rx_error) TYPE REF TO zcx_ca_param.

    "! The message of this exception (for RAP messages and logs)
    METHODS get_message
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

  PRIVATE SECTION.
    CONSTANTS gc_attr1 TYPE scx_attrname VALUE 'MSGV1'.
    CONSTANTS gc_attr2 TYPE scx_attrname VALUE 'MSGV2'.
    CONSTANTS gc_attr3 TYPE scx_attrname VALUE 'MSGV3'.
    CONSTANTS gc_attr4 TYPE scx_attrname VALUE 'MSGV4'.

ENDCLASS.



CLASS zcx_ca_param IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->msgv1 = msgv1.
    me->msgv2 = msgv2.
    me->msgv3 = msgv3.
    me->msgv4 = msgv4.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.


  METHOD create.
    rx_error = NEW #( textid   = VALUE #( msgid = is_message-msgid
                                          msgno = is_message-msgno
                                          attr1 = gc_attr1
                                          attr2 = gc_attr2
                                          attr3 = gc_attr3
                                          attr4 = gc_attr4 )
                      previous = ix_previous
                      msgv1    = is_message-v1
                      msgv2    = is_message-v2
                      msgv3    = is_message-v3
                      msgv4    = is_message-v4 ).
  ENDMETHOD.


  METHOD get_message.
    rs_message = VALUE #( msgid = if_t100_message~t100key-msgid
                          msgno = if_t100_message~t100key-msgno
                          v1    = msgv1
                          v2    = msgv2
                          v3    = msgv3
                          v4    = msgv4 ).
  ENDMETHOD.

ENDCLASS.
