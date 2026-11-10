*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_transport.clas.testclasses.abap
*& Purpose:
*& Unit tests of the transport recording wrapper through test seam CTS_API:
*& a recorded change returns, any error of the CTS API becomes message 408
*& with the original exception as previous (the save is aborted). The API
*& is replaced by TEST-INJECTION; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-08 | Example table ZT_CONFIG (ZT_CONFIG_OLD is now the customer posting area ZBTM).
*& 2026-11-10 | Moved from ZCL_CD_OPS_CFG_TRANSPORT to the reusable framework ZCA_OPS (test include).
*&---------------------------------------------------------------------*
CLASS ltc_cfg_transport DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_request TYPE zif_ca_ops_cfg_types=>ty_request VALUE 'DV1K900123'.
    CONSTANTS gc_entity TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'BtcMap'.
    CONSTANTS gc_table TYPE zif_ca_ops_cfg_types=>ty_name VALUE 'ZT_CONFIG'.
    CONSTANTS gc_msgno_not_recorded TYPE symsgno VALUE '408'.

    TYPES:
      BEGIN OF ty_flags,
        api_fails TYPE abap_bool,
      END OF ty_flags.

    DATA mo_cut TYPE REF TO zif_ca_ops_cfg_transport.

    METHODS setup.
    METHODS teardown.
    METHODS recorded_change_returns FOR TESTING.
    METHODS api_error_raises_408 FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_cfg_transport IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_ca_ops_cfg_transport( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-api_fails = abap_true.
      " the API raised: the seam leaves its exception behind
      TEST-INJECTION cts_api.
        lx_error = NEW cx_sy_ref_is_initial( ).
      END-TEST-INJECTION.
      RETURN.
    ENDIF.
    TEST-INJECTION cts_api.
    END-TEST-INJECTION.
  ENDMETHOD.


  METHOD act.
    DATA lt_relations TYPE zif_ca_ops_cfg_types=>tt_relation.
    DATA ls_relation TYPE zif_ca_ops_cfg_types=>ty_relation.
    ls_relation-entity = gc_entity.
    ls_relation-table  = gc_table.
    INSERT ls_relation INTO TABLE lt_relations.
    mo_cut->record( iv_request   = gc_request
                    it_relations = lt_relations ).
  ENDMETHOD.


  " Rule: a change the API recorded returns without exception
  METHOD recorded_change_returns.
    TRY.
        configure_scenario( VALUE #( ) ).
        act( ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Recording returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: whatever the CTS API raises, the save must not go through unrecorded (408)
  METHOD api_error_raises_408.
    configure_scenario( VALUE #( api_fails = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'API error must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_not_recorded
                                            msg = 'Not recorded is message 408' ).
        cl_abap_unit_assert=>assert_bound( act = lx_error->previous msg = 'API exception kept as previous' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
