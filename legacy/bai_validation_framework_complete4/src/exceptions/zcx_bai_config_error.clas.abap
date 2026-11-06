CLASS zcx_bai_config_error DEFINITION
  PUBLIC
  INHERITING FROM zcx_bai_validation_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF missing_config,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '030',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF missing_config.

    CONSTANTS:
      BEGIN OF invalid_bai_code,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '031',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_bai_code.

    CONSTANTS:
      BEGIN OF invalid_flow_type,
        msgid TYPE symsgid VALUE 'ZBAI',
        msgno TYPE symsgno VALUE '032',
        attr1 TYPE scx_attrname VALUE 'MV_TEXT1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_flow_type.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcx_bai_config_error IMPLEMENTATION.
ENDCLASS.
