CLASS zcx_bai_missing_data DEFINITION
  PUBLIC
  INHERITING FROM zcx_bai_validation_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF missing_dfkkrp,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '040',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_dfkkrp.

    CONSTANTS:
      BEGIN OF missing_dfkkrk,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '041',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_dfkkrk.

    CONSTANTS:
      BEGIN OF missing_dpayh,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '042',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_dpayh.

    CONSTANTS:
      BEGIN OF missing_bseg,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '043',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_bseg.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcx_bai_missing_data IMPLEMENTATION.
ENDCLASS.
