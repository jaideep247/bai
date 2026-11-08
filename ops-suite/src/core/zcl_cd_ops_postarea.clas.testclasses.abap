*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea.clas.testclasses.abap
*& Purpose:
*& Application tests of the posting area reader with the in-memory posting
*& areas ZCL_CD_OPS_POSTAREA_MEM (injected through ZCL_CD_OPS_POSTAREA_INJECTOR)
*& and the delivered parameters (ZCL_CD_OPS_PARAM_SEED): FQC0 precedence
*& (exact beats '*', the most specific entry from the left wins, no match),
*& one read per area and run, posting area / application area / chart of
*& accounts from the parameters. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-08 | Initial version (written before the class; customer posting areas).
*&---------------------------------------------------------------------*
CLASS ltc_postarea DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        area     TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZBTM',
        renamed  TYPE zif_cd_ops_postarea_types=>ty_area VALUE 'ZB01',
        ktopl    TYPE zif_cd_ops_postarea_types=>ty_ktopl VALUE 'CAUS',
        purpose  TYPE zif_cd_ops_postarea_types=>ty_purpose VALUE 'XXX',
        bai2     TYPE string VALUE `BAI2`,
        iso      TYPE string VALUE `ISO`,
        code     TYPE string VALUE `495`,
        domain   TYPE string VALUE `PMNT`,
        family   TYPE string VALUE `ICDT`,
        jpmc     TYPE string VALUE `JPMC`,
        boa      TYPE string VALUE `BOA`,
        result_a TYPE string VALUE `A`,
        result_b TYPE string VALUE `B`,
        result_c TYPE string VALUE `C`,
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        exact_and_generic TYPE abap_bool,
        generic_left      TYPE abap_bool,
        renamed           TYPE abap_bool,
      END OF ty_flags.

    DATA mo_mem    TYPE REF TO zcl_cd_ops_postarea_mem.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.

    METHODS exact_key_beats_generic   FOR TESTING.
    METHODS leftmost_specific_wins    FOR TESTING.
    METHODS no_match_is_initial       FOR TESTING.
    METHODS one_read_per_area_and_run FOR TESTING.
    METHODS delivered_area_names      FOR TESTING.
    METHODS area_names_are_parameters FOR TESTING.
    METHODS unknown_purpose_reads_none FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS keys
      IMPORTING
        iv_key01       TYPE string
        iv_key02       TYPE string
        iv_key03       TYPE string OPTIONAL
        iv_key04       TYPE string OPTIONAL
      RETURNING
        VALUE(rs_keys) TYPE zif_cd_ops_postarea_types=>ty_keys.
    METHODS cut
      RETURNING
        VALUE(ro_cut) TYPE REF TO zif_cd_ops_postarea.
ENDCLASS.


CLASS ltc_postarea IMPLEMENTATION.

  METHOD setup.
    mo_params = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    mo_mem = NEW #( ).
    zcl_cd_ops_postarea_injector=>inject_dao( mo_mem ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_postarea_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_mem, mo_params.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-exact_and_generic = abap_true.
      " BAI2 495: default row for every bank and a row of one bank
      mo_mem->add( iv_area = gc_test-area iv_keys = |{ gc_test-bai2 }/{ gc_test-code }/*|
                   iv_results = gc_test-result_a ).
      mo_mem->add( iv_area = gc_test-area iv_keys = |{ gc_test-bai2 }/{ gc_test-code }/{ gc_test-jpmc }|
                   iv_results = gc_test-result_b ).
    ENDIF.
    IF is_flags-generic_left = abap_true.
      " Two generic keys at different places and the all-generic row
      mo_mem->add( iv_area = gc_test-area iv_keys = |{ gc_test-iso }/{ gc_test-domain }/*/{ gc_test-jpmc }|
                   iv_results = gc_test-result_a ).
      mo_mem->add( iv_area = gc_test-area iv_keys = |{ gc_test-iso }/{ gc_test-domain }/{ gc_test-family }/*|
                   iv_results = gc_test-result_b ).
      mo_mem->add( iv_area = gc_test-area iv_keys = |{ gc_test-iso }/{ gc_test-domain }/*/*|
                   iv_results = gc_test-result_c ).
    ENDIF.
    IF is_flags-renamed = abap_true.
      mo_params->set( iv_name = zif_cd_ops_postarea_types=>gc_param-btc_map iv_value = gc_test-renamed ).
      mo_params->set( iv_name = zif_cd_ops_postarea_types=>gc_param-ktopl iv_value = gc_test-ktopl ).
      mo_mem->add( iv_area = gc_test-renamed iv_keys = |{ gc_test-bai2 }/{ gc_test-code }/*|
                   iv_results = gc_test-result_c ).
    ENDIF.
  ENDMETHOD.


  METHOD keys.
    rs_keys-key01 = iv_key01.
    rs_keys-key02 = iv_key02.
    rs_keys-key03 = iv_key03.
    rs_keys-key04 = iv_key04.
  ENDMETHOD.


  METHOD cut.
    ro_cut = zcl_cd_ops_postarea_factory=>get_reader( ).
  ENDMETHOD.


  " Rule (FQC0): an exact key value beats '*'; '*' applies to every other value
  METHOD exact_key_beats_generic.
    TRY.
        configure_scenario( VALUE #( exact_and_generic = abap_true ) ).
        cl_abap_unit_assert=>assert_equals(
          act = cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                              is_keys    = keys( iv_key01 = gc_test-bai2 iv_key02 = gc_test-code
                                                 iv_key03 = gc_test-jpmc ) )-fun01
          exp = gc_test-result_b
          msg = 'The bank entry wins for its bank' ).
        cl_abap_unit_assert=>assert_equals(
          act = cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                              is_keys    = keys( iv_key01 = gc_test-bai2 iv_key02 = gc_test-code
                                                 iv_key03 = gc_test-boa ) )-fun01
          exp = gc_test-result_a
          msg = 'Another bank takes the * entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (FQC0): several generic candidates - the exact value in the first key where they
  " differ wins (KEY03 exact beats KEY03 '*', even if that one is exact in KEY04)
  METHOD leftmost_specific_wins.
    TRY.
        configure_scenario( VALUE #( generic_left = abap_true ) ).
        DATA(ls_entry) = cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                                       is_keys    = keys( iv_key01 = gc_test-iso iv_key02 = gc_test-domain
                                                          iv_key03 = gc_test-family iv_key04 = gc_test-jpmc ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_entry-fun01 exp = gc_test-result_b
                                            msg = 'Exact KEY03 is more specific than exact KEY04' ).
        cl_abap_unit_assert=>assert_equals( act = ls_entry-key03 exp = gc_test-family
                                            msg = 'The entry is returned with its keys' ).
        cl_abap_unit_assert=>assert_equals(
          act = cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                              is_keys    = keys( iv_key01 = gc_test-iso iv_key02 = gc_test-domain
                                                 iv_key03 = gc_test-code iv_key04 = gc_test-jpmc ) )-fun01
          exp = gc_test-result_a
          msg = 'Other family, bank JPMC: the bank entry beats the all-generic entry' ).
        cl_abap_unit_assert=>assert_equals(
          act = cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                              is_keys    = keys( iv_key01 = gc_test-iso iv_key02 = gc_test-domain
                                                 iv_key03 = gc_test-code iv_key04 = gc_test-boa ) )-fun01
          exp = gc_test-result_c
          msg = 'Nothing exact: the all-generic entry' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: no entry matches - initial, never a partial match
  METHOD no_match_is_initial.
    TRY.
        configure_scenario( VALUE #( exact_and_generic = abap_true ) ).
        cl_abap_unit_assert=>assert_initial(
          act = cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                              is_keys    = keys( iv_key01 = gc_test-iso iv_key02 = gc_test-code
                                                 iv_key03 = gc_test-jpmc ) )
          msg = 'Another scheme matches no entry' ).
        cl_abap_unit_assert=>assert_initial(
          act = cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                              is_keys    = keys( iv_key01 = gc_test-bai2 iv_key02 = gc_test-code ) )
          msg = 'An empty posting area matches nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a posting area is read once per run (cache of the reader the factory keeps)
  METHOD one_read_per_area_and_run.
    TRY.
        configure_scenario( VALUE #( exact_and_generic = abap_true ) ).
        DATA(lt_first) = cut( )->entries( zif_cd_ops_postarea_types=>gc_purpose-btc_map ).
        DATA(lt_second) = cut( )->entries( zif_cd_ops_postarea_types=>gc_purpose-btc_map ).
        cut( )->find( iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map
                      is_keys    = keys( iv_key01 = gc_test-bai2 iv_key02 = gc_test-code ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_mem->reads( ) exp = 1
                                            msg = 'One read of the posting area per run' ).
        cl_abap_unit_assert=>assert_equals( act = lt_second exp = lt_first msg = 'The cache returns the same entries' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_first ) exp = 2 msg = 'Every entry of the area' ).
        cl_abap_unit_assert=>assert_equals( act = lt_first[ 1 ]-key03 exp = zif_cd_ops_postarea_types=>gc_generic
                                            msg = 'Ordered by the key values' ).
        cut( )->entries( zif_cd_ops_postarea_types=>gc_purpose-reason ).
        cl_abap_unit_assert=>assert_equals( act = mo_mem->reads( ) exp = 2
                                            msg = 'A second posting area is a second read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: delivered parameters - posting area ZBTM, application area V, no chart of accounts
  METHOD delivered_area_names.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = cut( )->area( zif_cd_ops_postarea_types=>gc_purpose-btc_map )
                                            exp = gc_test-area msg = 'Delivered name ZBTM' ).
        cut( )->entries( zif_cd_ops_postarea_types=>gc_purpose-pm_class ).
        cl_abap_unit_assert=>assert_equals( act = mo_mem->last_read( )-key01
                                            exp = zif_cd_ops_postarea_types=>gc_param_default-applk
                                            msg = 'Delivered application area' ).
        cl_abap_unit_assert=>assert_initial( act = mo_mem->last_read( )-key02 msg = 'No chart of accounts delivered' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: posting area and chart of accounts are parameters (renamed without code)
  METHOD area_names_are_parameters.
    TRY.
        configure_scenario( VALUE #( renamed = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = cut( )->area( zif_cd_ops_postarea_types=>gc_purpose-btc_map )
                                            exp = gc_test-renamed msg = 'Renamed by the parameter' ).
        DATA(lt_entries) = cut( )->entries( zif_cd_ops_postarea_types=>gc_purpose-btc_map ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_entries ) exp = 1 msg = 'The renamed area is read' ).
        cl_abap_unit_assert=>assert_equals( act = mo_mem->last_read( )-key02 exp = gc_test-ktopl
                                            msg = 'Chart of accounts from the parameter' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Boundary: a purpose without a posting area reads nothing
  METHOD unknown_purpose_reads_none.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = cut( )->entries( gc_test-purpose ) msg = 'No entries' ).
        cl_abap_unit_assert=>assert_equals( act = mo_mem->reads( ) exp = 0 msg = 'No read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
