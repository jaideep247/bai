CLASS zcx_bai_validation_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    CONSTANTS:
      BEGIN OF invalid_configuration,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF invalid_configuration.

    CONSTANTS:
      BEGIN OF no_validators_configured,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF no_validators_configured.

    CONSTANTS:
      BEGIN OF batch_id_generation_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '012',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF batch_id_generation_failed.

    CONSTANTS:
      BEGIN OF batch_already_running,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '013',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF batch_already_running.

    CONSTANTS:
      BEGIN OF not_authorized,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '014',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF not_authorized.

    CONSTANTS:
      BEGIN OF failure_threshold_exceeded,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '015',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF failure_threshold_exceeded.

    CONSTANTS:
      BEGIN OF internal_error,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '999',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE 'MV_TEXT3',
        attr4 TYPE scx_attrname VALUE 'MV_TEXT4',
      END OF internal_error.

    DATA mv_text1 TYPE string.
    DATA mv_text2 TYPE string.
    DATA mv_text3 TYPE string.
    DATA mv_text4 TYPE string.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        mv_text1 TYPE string OPTIONAL
        mv_text2 TYPE string OPTIONAL
        mv_text3 TYPE string OPTIONAL
        mv_text4 TYPE string OPTIONAL.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcx_bai_validation_error IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    CALL METHOD super->constructor
      EXPORTING
        previous = previous.

    me->mv_text1 = mv_text1.
    me->mv_text2 = mv_text2.
    me->mv_text3 = mv_text3.
    me->mv_text4 = mv_text4.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = internal_error.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
