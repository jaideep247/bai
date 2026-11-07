*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_adapter_generic.clas.testclasses.abap
*& Purpose:
*& ltc_mapping: pure tests (no doubles) of legacy row -> status record.
*& ltc_read: LTD_* DDIC/DAO doubles prove validation precedes any SQL.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A39/A52: malformed rows, payment key, half-open day range.
*& 2026-11-06 | Modern-syntax sweep: caught exception lx_error.
*& 2026-11-07 | Regenerated files (user 2026-11-07): GROUP_FIELDS give the record's generation group,
*&            | no GROUP_FIELDS no group, more than four fields refused (284).
*&---------------------------------------------------------------------*
CLASS ltc_mapping DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        no_status_field TYPE abap_bool,
        with_wildcard   TYPE abap_bool,
        status          TYPE string,
        file_key        TYPE string,
      END OF ty_flags.

    CONSTANTS gc_src TYPE zif_cd_fmon_types=>ty_src_id VALUE 'ACHACK'.
    CONSTANTS gc_name TYPE string VALUE `ach_pnc_20261102_01.txt`.

    DATA ms_request TYPE zif_cd_fmon_types=>ty_read_request.
    DATA ms_raw TYPE zif_cd_fmon_types=>ty_raw_row.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      RETURNING
        VALUE(rs_record) TYPE zif_cd_fmon_types=>ty_src_record.

    METHODS mapped_status_gives_stage FOR TESTING.
    METHODS unmapped_status_stays_blank FOR TESTING.
    METHODS wildcard_row_maps_the_rest FOR TESTING.
    METHODS no_status_field_uses_default FOR TESTING.
    METHODS file_key_is_correlation_ref FOR TESTING.
    METHODS malformed_count_quarantined FOR TESTING.
    METHODS invalid_date_quarantined FOR TESTING.
    METHODS payment_key_is_taken_over FOR TESTING.
    METHODS day_range_is_half_open FOR TESTING.
    METHODS group_fields_give_generation FOR TESTING.
    METHODS no_group_fields_no_generation FOR TESTING.
    METHODS five_group_fields_refused FOR TESTING.

ENDCLASS.


CLASS ltc_mapping IMPLEMENTATION.

  " Rule (regenerated files): the values of GROUP_FIELDS, in their configured order, are the
  " record's generation group (payment run LAUFD / LAUFI / house bank of ZCDT_REGUT - VERIFY-SE11).
  METHOD group_fields_give_generation.
    TRY.
        configure_scenario( VALUE #( status = `A` ) ).
        ms_request-src-group_fields = 'LAUFD, LAUFI,HBKID'.
        DATA(ls_query) = zcl_cd_fmon_adapter_generic=>build_query( ms_request ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE zif_cd_fmon_types=>tt_qfield( FOR ls_field IN ls_query-fields
                                                    WHERE ( role = zif_cd_fmon_types=>gc_role-group_1
                                                         OR role = zif_cd_fmon_types=>gc_role-group_2
                                                         OR role = zif_cd_fmon_types=>gc_role-group_3
                                                         OR role = zif_cd_fmon_types=>gc_role-group_4 )
                                                    ( ls_field ) )
          exp = VALUE zif_cd_fmon_types=>tt_qfield( ( role = zif_cd_fmon_types=>gc_role-group_1 field = 'LAUFD' )
                                                    ( role = zif_cd_fmon_types=>gc_role-group_2 field = 'LAUFI' )
                                                    ( role = zif_cd_fmon_types=>gc_role-group_3 field = 'HBKID' ) )
          msg = 'The group fields are read in their configured order' ).
        ms_raw-group_1 = `20261102`.
        ms_raw-group_2 = `RUN01`.
        ms_raw-group_3 = `BOA1`.
        cl_abap_unit_assert=>assert_equals( act = act( )-gen_group
                                            exp = '20261102/RUN01/BOA1'
                                            msg = 'Generation group key of the record' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (no generation group configured): behaviour as before - no group key, no extra field read.
  METHOD no_group_fields_no_generation.
    TRY.
        configure_scenario( VALUE #( status = `A` ) ).
        ms_raw-group_1 = `20261102`.
        cl_abap_unit_assert=>assert_initial( act = act( )-gen_group
                                             msg = 'Without GROUP_FIELDS the record is not linked' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( zcl_cd_fmon_adapter_generic=>build_query( ms_request )-fields[
                                        role = zif_cd_fmon_types=>gc_role-group_1 ] ) )
          msg = 'No group field is read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (boundary): at most four group fields - a fifth is a configuration error, never ignored.
  METHOD five_group_fields_refused.
    configure_scenario( VALUE #( status = `A` ) ).
    ms_request-src-group_fields = 'LAUFD,LAUFI,HBKID,HKTID,BUKRS'.
    TRY.
        zcl_cd_fmon_adapter_generic=>build_query( ms_request ).
        cl_abap_unit_assert=>fail( msg = 'Five group fields must be refused' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = '284'
                                            msg = 'Message 284 names the limit' ).
    ENDTRY.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_map TYPE zif_cd_fmon_types=>ty_srcmap.
    CLEAR: ms_request, ms_raw.

    ms_request-src-src_id          = gc_src.
    ms_request-src-file_name_field = 'FNAME'.
    ms_request-src-date_field      = 'ADATE'.
    ms_request-src-time_field      = 'ATIME'.
    ms_request-src-count_field     = 'CNT'.
    ms_request-src-amount_field    = 'AMT'.
    IF is_flags-no_status_field = abap_true.
      ms_request-src-default_stage = zif_cd_fmon_types=>gc_stage-generated.
    ELSE.
      ms_request-src-status_field  = 'STAT'.
    ENDIF.
    IF is_flags-file_key IS NOT INITIAL.
      ms_request-src-file_key_field = 'FKEY'.
    ENDIF.
    ms_request-time_zone = 'UTC'.

    ls_map-src_id       = gc_src.
    ls_map-status_value = 'A'.
    ls_map-stage        = zif_cd_fmon_types=>gc_stage-ack.
    INSERT ls_map INTO TABLE ms_request-maps.
    IF is_flags-with_wildcard = abap_true.
      ls_map-status_value = zif_cd_fmon_types=>gc_wildcard.
      ls_map-stage        = zif_cd_fmon_types=>gc_stage-nack.
      INSERT ls_map INTO TABLE ms_request-maps.
    ENDIF.

    ms_raw-file_name = gc_name.
    ms_raw-file_key  = is_flags-file_key.
    ms_raw-ev_date   = `20261102`.
    ms_raw-ev_time   = `050000`.
    ms_raw-status    = is_flags-status.
    ms_raw-rec_count = `10`.
    ms_raw-amount    = `1000.00`.
  ENDMETHOD.


  METHOD act.
    rs_record = zcl_cd_fmon_adapter_generic=>to_record( is_request = ms_request
                                                       is_raw     = ms_raw ).
  ENDMETHOD.


  " Audit A52: a count that is not a number is not a known zero - the row is quarantined
  METHOD malformed_count_quarantined.
    TRY.
        configure_scenario( VALUE #( status = `A` ) ).
        ms_raw-rec_count = `1O`.
        DATA(ls_record) = act( ).
        cl_abap_unit_assert=>assert_true( act = ls_record-malformed
                                          msg = 'A non-numeric count must mark the row malformed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_record-malformed_role exp = zif_cd_fmon_types=>gc_role-rec_count
                                            msg = 'The malformed field must be named' ).
        cl_abap_unit_assert=>assert_false( act = ls_record-count_known
                                           msg = 'A malformed count must not be a known count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A52: a date that does not exist gives no event time - the row is quarantined
  METHOD invalid_date_quarantined.
    TRY.
        configure_scenario( VALUE #( status = `A` ) ).
        ms_raw-ev_date = `20261340`.
        DATA(ls_record) = act( ).
        cl_abap_unit_assert=>assert_true( act = ls_record-malformed
                                          msg = 'An invalid date must mark the row malformed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_record-malformed_role exp = zif_cd_fmon_types=>gc_role-ev_date
                                            msg = 'The date field must be named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A39: the payment identity of a per-payment ACK row is taken over for dedupe
  METHOD payment_key_is_taken_over.
    TRY.
        configure_scenario( VALUE #( status = `A` ) ).
        ms_request-src-item_key_field = 'PAYNO'.
        ms_raw-item_key = `PAY0001`.
        cl_abap_unit_assert=>assert_equals( act = act( )-item_key exp = 'PAY0001'
                                            msg = 'The payment key must be on the record' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A52: a timestamp-restricted read ends at the next local midnight (exclusive),
  " so rows with fractional seconds after 23:59:59 are not lost
  METHOD day_range_is_half_open.
    TRY.
        configure_scenario( VALUE #( status = `A` ) ).
        ms_request-src-table_name = 'ZCD_ACH_ACK'.
        ms_request-src-ts_field   = 'ACK_TS'.
        ms_request-date_from      = '20261102'.
        ms_request-date_to        = '20261102'.
        DATA(ls_query) = zcl_cd_fmon_adapter_generic=>build_query( ms_request ).
        cl_abap_unit_assert=>assert_equals( act = ls_query-ts_to exp = '20261103000000'
                                            msg = 'The range must end at the next midnight' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a status value maintained in ZCD_FMON_SRCMAP gives its stage; all
  " other attributes are taken over (whole record asserted).
  METHOD mapped_status_gives_stage.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_src_record.
    TRY.
        configure_scenario( VALUE #( status = `A` ) ).
        ls_exp-src_id        = gc_src.
        ls_exp-file_ref      = to_upper( gc_name ).
        ls_exp-file_name     = gc_name.
        ls_exp-raw_status    = 'A'.
        ls_exp-stage         = zif_cd_fmon_types=>gc_stage-ack.
        ls_exp-event_at      = '20261102050000'.
        ls_exp-business_date = '20261102'.
        ls_exp-rec_count     = 10.
        ls_exp-count_known   = abap_true.
        ls_exp-amount        = '1000.00'.
        cl_abap_unit_assert=>assert_equals( act = act( ) exp = ls_exp
                                            msg = 'Mapped row must give an ACK_RECEIVED record' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unmapped status is not guessed - the stage stays blank (engine raises UNMAPPED_STATUS).
  METHOD unmapped_status_stays_blank.
    TRY.
        configure_scenario( VALUE #( status = `Z` ) ).
        cl_abap_unit_assert=>assert_initial( act = act( )-stage
                                             msg = 'Unmapped status must not get a stage' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a '*' SRCMAP row maps every status value without an own row.
  METHOD wildcard_row_maps_the_rest.
    TRY.
        configure_scenario( VALUE #( status = `Z` with_wildcard = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-stage exp = zif_cd_fmon_types=>gc_stage-nack
                                            msg = 'Wildcard row must map Z to NACK_REJECTED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a source without status field reports its DEFAULT_STAGE (e.g. generation log).
  METHOD no_status_field_uses_default.
    TRY.
        configure_scenario( VALUE #( no_status_field = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-stage exp = zif_cd_fmon_types=>gc_stage-generated
                                            msg = 'Default stage must be used' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the file-key field, when configured, is the cross-source correlation reference.
  METHOD file_key_is_correlation_ref.
    TRY.
        configure_scenario( VALUE #( status = `A` file_key = ` run20261102-01 ` ) ).
        cl_abap_unit_assert=>assert_equals( act = act( )-file_ref exp = 'RUN20261102-01'
                                            msg = 'File key must be the normalised reference' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_ddic DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_ddic.
    DATA mt_fields TYPE zif_cd_fmon_types=>tt_ddic_field.
ENDCLASS.


CLASS ltd_ddic IMPLEMENTATION.
  METHOD zif_cd_fmon_ddic~describe_table.
    rt_fields = mt_fields.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
    DATA mv_read_count TYPE i.
ENDCLASS.


CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~read_legacy.
    mv_read_count += 1.
    CLEAR rt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_read DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_ddic TYPE REF TO ltd_ddic.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_request TYPE zif_cd_fmon_types=>ty_read_request.

    METHODS setup.
    METHODS teardown.
    METHODS unknown_field_stops_before_sql FOR TESTING.

ENDCLASS.


CLASS ltc_read IMPLEMENTATION.

  METHOD setup.
    DATA ls_field TYPE zif_cd_fmon_types=>ty_ddic_field.
    mo_ddic = NEW #( ).
    mo_dao  = NEW #( ).
    ls_field-fieldname = 'FNAME'.
    ls_field-inttype   = 'C'.
    INSERT ls_field INTO TABLE mo_ddic->mt_fields.
    ls_field-fieldname = 'ADATE'.
    ls_field-inttype   = 'D'.
    INSERT ls_field INTO TABLE mo_ddic->mt_fields.
    zcl_cd_fmon_injector=>inject_ddic( mo_ddic ).
    zcl_cd_fmon_injector=>inject_dao( mo_dao ).

    ms_request-src-src_id          = 'ACHACK'.
    ms_request-src-table_name      = 'ZCD_ACH_ACK'.
    ms_request-src-file_name_field = 'FNAME'.
    ms_request-src-date_field      = 'ADATE'.
    ms_request-src-status_field    = 'NOT_IN_TABLE'.
    ms_request-date_from           = '20261101'.
    ms_request-date_to             = '20261102'.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: a configured field missing in the DDIC raises 201 and no SQL is issued.
  METHOD unknown_field_stops_before_sql.
    DATA lv_msgno TYPE symsgno.
    TRY.
        DATA(lo_cut) = zcl_cd_fmon_factory=>get_adapter( ).
        lo_cut->read( ms_request ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        lv_msgno = lx_error->if_t100_message~t100key-msgno.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = lv_msgno exp = '201'
                                        msg = 'Unknown status field must raise 201' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_read_count exp = 0
                                        msg = 'No SQL may run before validation passes' ).
  ENDMETHOD.

ENDCLASS.
