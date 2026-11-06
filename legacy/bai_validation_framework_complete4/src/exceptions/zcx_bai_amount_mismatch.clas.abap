CLASS zcx_bai_amount_mismatch DEFINITION
  PUBLIC
  INHERITING FROM zcx_bai_validation_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF sum_mismatch,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '070',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF sum_mismatch.

    CONSTANTS:
      BEGIN OF currency_mismatch,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '071',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE 'MV_TEXT2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF currency_mismatch.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcx_bai_amount_mismatch IMPLEMENTATION.
ENDCLASS.
