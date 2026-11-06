CLASS zcx_bai_invalid_state DEFINITION
  PUBLIC
  INHERITING FROM zcx_bai_validation_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF invalid_state,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '060',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_state.

    CONSTANTS:
      BEGIN OF not_all_state_b,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '061',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF not_all_state_b.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcx_bai_invalid_state IMPLEMENTATION.
ENDCLASS.
