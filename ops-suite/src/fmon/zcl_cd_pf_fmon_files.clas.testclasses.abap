*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_pf_fmon_files.clas.testclasses.abap
*& Purpose:
*& Tests of the overlay's file source: an FMON outbound file becomes a
*& payment file with its FMON reference as native key, business date and
*& generation time, the payment run and house bank from its generation
*& group (GROUP_FIELDS of its source), the DPAYH payments of that run and
*& house bank (others left out), the payment run as link object; a later
*& generation of the same group names the earlier file as predecessor;
*& the adapter is refused without interfaces (386). Pure (TO_FILES); READ_FILES
*& on a doubled DPAYH (ABAP SQL test environment) and FMON data access.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle overlay).
*&---------------------------------------------------------------------*
CLASS ltd_pf_fmon_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_pf_fmon_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~get_eval_files.
    rt_files = VALUE #( ( file_id = '01' iface_id = 'ZT_ACH' file_ref = 'ACH_1' direction = 'O' business_date = '20261116'
                          src_id = 'ZTSRC' gen_group = '20261116/ZT1/BANK1/ACC1' ) ).
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_sources.
    rt_sources = VALUE #( ( src_id = 'ZTSRC' group_fields = 'LAUFD,LAUFI,HBKID,HKTID' ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_pf_fmon_files_sql DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.
    METHODS proposal_left_out FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_pf_fmon_files_sql IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'DPAYH' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
  ENDMETHOD.


  " The payments of the run and house bank of the group; a proposal run's payment never
  METHOD proposal_left_out.
    DATA lt_dpayh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_dpayh = VALUE #( ( laufd = '20261116' laufi = 'ZT1' payno = 1 bbukr = '1000' hbkid = 'BANK1' hktid = 'ACC1'
                          waers = 'USD' rwbtr = '10.00' doc1r = 'D1' )
                        ( laufd = '20261116' laufi = 'ZT1' payno = 2 xvorl = 'X' bbukr = '1000' hbkid = 'BANK1'
                          hktid = 'ACC1' waers = 'USD' rwbtr = '20.00' ) ).
    go_env->insert_test_data( lt_dpayh ).
    zcl_cd_fmon_injector=>inject_dao( NEW ltd_pf_fmon_dao( ) ).
    DATA(lo_cut) = NEW zcl_cd_pf_fmon_files( ).
    lo_cut->zif_ca_ops_pf_adapter~configure( VALUE #( role = 'FILE' setting = 'IFACES=ZT_ACH' ) ).
    DATA(ls_batch) = lo_cut->zif_ca_ops_pf_file_src~read_files( VALUE #( from_ts = '20261116000000.0000000'
                                                                         to_ts   = '20261117000000.0000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_batch-files ) exp = 1 msg = 'One file' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_batch-files[ 1 ]-payments ) exp = 1 msg = 'The real payment only' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_pf_fmon_files DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS file_with_payments  FOR TESTING.
    METHODS regeneration_linked FOR TESTING.
    METHODS ifaces_required     FOR TESTING.
ENDCLASS.


CLASS ltc_pf_fmon_files IMPLEMENTATION.

  METHOD file_with_payments.
    DATA(lt_files) = VALUE zif_cd_fmon_types=>tt_file(
      ( file_id = '01' iface_id = 'ZT_ACH' file_ref = 'ACH_20261116_1' direction = 'O' business_date = '20261116'
        first_event_at = '20261116162000.0000000' record_count = 2 src_id = 'ZTSRC' gen_group = '20261116/ZT1/BANK1/ACC1' ) ).
    DATA(lt_sources) = VALUE zif_cd_fmon_types=>tt_src( ( src_id = 'ZTSRC' group_fields = 'LAUFD,LAUFI,HBKID,HKTID' ) ).
    DATA(lt_pay) = VALUE zcl_cd_pf_fmon_files=>tt_pay(
      ( laufd = '20261116' laufi = 'ZT1' payno = 1 bbukr = '1000' hbkid = 'BANK1' hktid = 'ACC1' waers = 'USD'
        rwbtr = '10.00' doc1r = 'D1' )
      ( laufd = '20261116' laufi = 'ZT1' payno = 2 bbukr = '1000' hbkid = 'BANK1' hktid = 'ACC1' waers = 'USD'
        rwbtr = '20.00' doc1r = 'D2' )
      ( laufd = '20261116' laufi = 'ZT1' payno = 3 bbukr = '1000' hbkid = 'BANK2' hktid = 'ACC1' waers = 'USD'
        rwbtr = '30.00' doc1r = 'D3' ) ).
    DATA(lt_out) = NEW zcl_cd_pf_fmon_files( )->to_files( it_files = lt_files it_sources = lt_sources it_payments = lt_pay ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_out ) exp = 1 msg = 'One file' ).
    DATA(ls_file) = lt_out[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_file-native_key exp = 'ACH_20261116_1' msg = 'FMON reference' ).
    cl_abap_unit_assert=>assert_equals( act = ls_file-run_id exp = 'ZT1' msg = 'Run from the group' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_file-payments ) exp = 2 msg = 'Payments of its house bank' ).
    cl_abap_unit_assert=>assert_equals( act = ls_file-bukrs exp = '1000' msg = 'Paying company code' ).
    cl_abap_unit_assert=>assert_equals( act = ls_file-link_object exp = zif_cd_fmon_types=>gc_pf_link-payrun msg = 'Link' ).
  ENDMETHOD.


  METHOD regeneration_linked.
    DATA(lt_files) = VALUE zif_cd_fmon_types=>tt_file(
      ( file_id = '01' iface_id = 'ZT_ACH' file_ref = 'F_OLD' direction = 'O' first_event_at = '20261116160000.0000000'
        gen_group = 'G1' )
      ( file_id = '02' iface_id = 'ZT_ACH' file_ref = 'F_NEW' direction = 'O' first_event_at = '20261116180000.0000000'
        gen_group = 'G1' ) ).
    DATA(lt_out) = NEW zcl_cd_pf_fmon_files( )->to_files( it_files = lt_files it_sources = VALUE #( ) it_payments = VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_out[ native_key = 'F_NEW' ]-predecessor_key exp = 'F_OLD' msg = 'Reissue' ).
    cl_abap_unit_assert=>assert_initial( act = lt_out[ native_key = 'F_OLD' ]-predecessor_key msg = 'The original' ).
  ENDMETHOD.


  METHOD ifaces_required.
    TRY.
        NEW zcl_cd_pf_fmon_files( )->zif_ca_ops_pf_adapter~configure( VALUE #( role = 'FILE' ) ).
        cl_abap_unit_assert=>fail( msg = 'Refused expected' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '386' msg = '386' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
