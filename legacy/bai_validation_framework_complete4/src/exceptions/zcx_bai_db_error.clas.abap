CLASS zcx_bai_db_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    CONSTANTS:
      BEGIN OF insert_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF insert_failed.

    CONSTANTS:
      BEGIN OF update_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF update_failed.

    CONSTANTS:
      BEGIN OF summary_insert_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '022',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF summary_insert_failed.

    CONSTANTS:
      BEGIN OF batch_audit_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '023',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF batch_audit_failed.

    CONSTANTS:
      BEGIN OF commit_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '024',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF commit_failed.

    CONSTANTS:
      BEGIN OF rollback_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '025',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF rollback_failed.

    CONSTANTS:
      BEGIN OF delete_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '026',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF delete_failed.

    CONSTANTS:
      BEGIN OF select_failed,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '027',
        attr1 TYPE scx_attrname VALUE 'MV_TABLE',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF select_failed.

    DATA mv_table TYPE tabname.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        mv_table TYPE tabname OPTIONAL.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcx_bai_db_error IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    CALL METHOD super->constructor
      EXPORTING
        previous = previous.

    me->mv_table = mv_table.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = insert_failed.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
