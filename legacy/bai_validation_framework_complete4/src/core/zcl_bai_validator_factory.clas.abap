CLASS zcl_bai_validator_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS get_validator
      IMPORTING
        iv_bai_code        TYPE char10
        iv_flow_type       TYPE char1
      RETURNING
        VALUE(ro_validator) TYPE REF TO zif_bai_validator
      RAISING
        zcx_bai_config_error.

    CLASS-METHODS get_all_active_validators
      RETURNING
        VALUE(rt_validators) TYPE TABLE OF zbai_validator_config
      RAISING
        zcx_bai_db_error.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_validator_cache,
             bai_code  TYPE char10,
             flow_type TYPE char1,
             instance  TYPE REF TO zif_bai_validator,
           END OF ty_validator_cache.

    CLASS-DATA: gt_cache TYPE HASHED TABLE OF ty_validator_cache
                         WITH UNIQUE KEY bai_code flow_type.

ENDCLASS.



CLASS zcl_bai_validator_factory IMPLEMENTATION.


  METHOD get_validator.

    DATA: ls_config TYPE zbai_validator_config,
          ls_cache  TYPE ty_validator_cache,
          lv_key    TYPE string.

    " Build cache key
    lv_key = |{ iv_bai_code }{ iv_flow_type }|.

    " Check cache first
    READ TABLE gt_cache INTO ls_cache
      WITH TABLE KEY bai_code = iv_bai_code
                     flow_type = iv_flow_type.

    IF sy-subrc = 0.
      ro_validator = ls_cache-instance.
      RETURN.
    ENDIF.

    " Not in cache - load from config
    SELECT SINGLE *
      FROM zbai_validator_config
      WHERE bai_code = @iv_bai_code
        AND flow_type = @iv_flow_type
        AND active = @abap_true
      INTO @ls_config.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_config_error
        EXPORTING
          textid   = zcx_bai_config_error=>missing_config
          mv_text1 = |BAI { iv_bai_code } Flow { iv_flow_type }|.
    ENDIF.

    " Validate class name
    IF ls_config-class_name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bai_config_error
        EXPORTING
          textid   = zcx_bai_config_error=>invalid_bai_code
          mv_text1 = |Class name empty for BAI { iv_bai_code }|.
    ENDIF.

    " Dynamic instantiation based on config
    TRY.
        CREATE OBJECT ro_validator TYPE (ls_config-class_name).

      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE zcx_bai_config_error
          EXPORTING
            textid   = zcx_bai_config_error=>invalid_bai_code
            mv_text1 = |Cannot create { ls_config-class_name }: { lx_create->get_text( ) }|.
    ENDTRY.

    " Add to cache
    ls_cache-bai_code = iv_bai_code.
    ls_cache-flow_type = iv_flow_type.
    ls_cache-instance = ro_validator.
    INSERT ls_cache INTO TABLE gt_cache.

  ENDMETHOD.


  METHOD get_all_active_validators.

    TRY.
        SELECT *
          FROM zbai_validator_config
          WHERE active = @abap_true
          ORDER BY priority ASCENDING
          INTO TABLE @rt_validators.

      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_bai_db_error
          EXPORTING
            textid   = zcx_bai_db_error=>select_failed
            mv_table = 'ZBAI_VALIDATOR_CONFIG'.
    ENDTRY.

    IF rt_validators IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bai_config_error
        EXPORTING
          textid   = zcx_bai_config_error=>missing_config
          mv_text1 = 'No active validators configured'.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
