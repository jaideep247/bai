CLASS zcx_bai_field_mismatch DEFINITION
  PUBLIC
  INHERITING FROM zcx_bai_validation_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF stars_mismatch,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '050',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF stars_mismatch.

    CONSTANTS:
      BEGIN OF status_mismatch,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '051',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF status_mismatch.

    CONSTANTS:
      BEGIN OF field_empty,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '052',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF field_empty.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcx_bai_field_mismatch IMPLEMENTATION.
ENDCLASS.
