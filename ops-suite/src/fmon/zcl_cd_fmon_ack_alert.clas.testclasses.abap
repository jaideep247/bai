*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_ack_alert.clas.testclasses.abap
*& Purpose:
*& Domain tests of the missing bank ACK evidence: house bank and payment run
*& parsed from the generation group by GROUP_FIELDS, a digest key not split,
*& the payment-run fallback only when the file's counts are not known, never
*& 0 for an unknown count, ACK codes and the missed ACK deadline recognised.
*& No doubles. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (missing bank ACK alert, user request 2026-11-10).
*&---------------------------------------------------------------------*
CLASS ltc_ack_alert DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        fields     TYPE zif_cd_fmon_types=>ty_field_list VALUE 'LAUFD,LAUFI,HBKID',
        gen_group  TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261110/R0001/JPMC1',
        laufd      TYPE d VALUE '20261110',
        laufi      TYPE c LENGTH 6 VALUE 'R0001',
        hbkid      TYPE c LENGTH 5 VALUE 'JPMC1',
        file_name  TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_JPMC_20261110_01.txt',
        count      TYPE i VALUE 120,
        total      TYPE zif_cd_ops_types=>ty_amount VALUE '1234567.80',
        run_count  TYPE i VALUE 118,
        run_amount TYPE zif_cd_ops_types=>ty_amount VALUE '99000.00',
        usd        TYPE zif_cd_ops_types=>ty_currency VALUE 'USD',
        cad        TYPE zif_cd_ops_types=>ty_currency VALUE 'CAD',
      END OF gc_test.

    METHODS house_bank_from_group_fields FOR TESTING.
    METHODS digest_key_not_split         FOR TESTING.
    METHODS fallback_only_when_unknown   FOR TESTING.
    METHODS file_counts_win_over_run     FOR TESTING.
    METHODS run_totals_fill_unknown      FOR TESTING.
    METHODS nothing_known_never_zero     FOR TESTING.
    METHODS ack_codes_recognised         FOR TESTING.
    METHODS ack_deadline_recognised      FOR TESTING.

    METHODS file
      IMPORTING
        iv_count       TYPE i DEFAULT gc_test-count
        iv_total       TYPE zif_cd_ops_types=>ty_amount DEFAULT gc_test-total
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    METHODS value_of
      IMPORTING
        iv_text         TYPE string
        iv_label        TYPE zif_cd_ops_types=>ty_msgno
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.


CLASS ltc_ack_alert IMPLEMENTATION.

  METHOD file.
    rs_file-file_name     = gc_test-file_name.
    rs_file-gen_group     = gc_test-gen_group.
    rs_file-record_count  = iv_count.
    rs_file-control_total = iv_total.
    rs_file-business_date = gc_test-laufd.
  ENDMETHOD.


  METHOD value_of.
    DATA(lv_prefix) = |{ zcl_cd_ops_util=>text( iv_label ) }{ zif_cd_ops_types=>gc_ack_label_separator }|.
    SPLIT iv_text AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).
    LOOP AT lt_lines INTO DATA(lv_line).
      IF find( val = lv_line sub = lv_prefix ) = 0.
        rv_value = substring( val = lv_line off = strlen( lv_prefix ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  " The house bank and the payment run come from the generation group, split by GROUP_FIELDS
  METHOD house_bank_from_group_fields.
    DATA(ls_key) = zcl_cd_fmon_ack_alert=>run_key( iv_gen_group    = gc_test-gen_group
                                                   iv_group_fields = gc_test-fields ).
    cl_abap_unit_assert=>assert_equals( act = ls_key
                                        exp = VALUE zif_cd_fmon_types=>ty_payrun_key( laufd = gc_test-laufd
                                                                                      laufi = gc_test-laufi
                                                                                      hbkid = gc_test-hbkid )
                                        msg = 'LAUFD, LAUFI and HBKID in the order of GROUP_FIELDS' ).
  ENDMETHOD.


  " A group key with more parts than names (or a digest) is not guessed
  METHOD digest_key_not_split.
    cl_abap_unit_assert=>assert_initial(
      act = zcl_cd_fmon_ack_alert=>run_key( iv_gen_group    = gc_test-gen_group
                                            iv_group_fields = CONV #( zif_cd_fmon_types=>gc_run_field-laufd ) )
      msg = 'Parts that cannot be named stay blank' ).
  ENDMETHOD.


  " The payment-run read is needed only when the file's count or total is not known
  METHOD fallback_only_when_unknown.
    cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_ack_alert=>needs_fallback( file( ) )
                                       msg = 'Known count and total: no payment-run read' ).
    cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_ack_alert=>needs_fallback( file( iv_count = 0 ) )
                                      msg = 'Count not known: payment-run read' ).
    cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_ack_alert=>needs_fallback( file( iv_total = 0 ) )
                                      msg = 'Total not known: payment-run read' ).
  ENDMETHOD.


  " The file's own counts are shown, never the payment run's
  METHOD file_counts_win_over_run.
    DATA ls_input TYPE zcl_cd_fmon_ack_alert=>ty_input.
    ls_input-file           = file( ).
    ls_input-currency       = gc_test-usd.
    ls_input-total-payments = gc_test-run_count.
    ls_input-total-amount   = gc_test-run_amount.
    ls_input-total-currency = gc_test-cad.
    DATA(ls_block) = zcl_cd_fmon_ack_alert=>block( ls_input ).
    cl_abap_unit_assert=>assert_equals( act = value_of( iv_text = ls_block-text iv_label = zif_cd_ops_types=>gc_ack_msg-payments )
                                        exp = |{ gc_test-count }|
                                        msg = 'RECORD_COUNT of the file' ).
    cl_abap_unit_assert=>assert_equals( act = ls_block-amount exp = gc_test-total msg = 'CONTROL_TOTAL of the file' ).
    cl_abap_unit_assert=>assert_equals( act = ls_block-currency exp = gc_test-usd msg = 'Default currency' ).
    cl_abap_unit_assert=>assert_equals( act = value_of( iv_text = ls_block-text iv_label = zif_cd_ops_types=>gc_ack_msg-amount )
                                        exp = `USD 1,234,567.80`
                                        msg = 'Amount with thousands separators and two decimals' ).
  ENDMETHOD.


  " Counts not delivered by the source come from the payment run
  METHOD run_totals_fill_unknown.
    DATA ls_input TYPE zcl_cd_fmon_ack_alert=>ty_input.
    ls_input-file           = file( iv_count = 0 iv_total = 0 ).
    ls_input-currency       = gc_test-usd.
    ls_input-total-payments = gc_test-run_count.
    ls_input-total-amount   = gc_test-run_amount.
    ls_input-total-currency = gc_test-cad.
    DATA(ls_block) = zcl_cd_fmon_ack_alert=>block( ls_input ).
    cl_abap_unit_assert=>assert_equals( act = value_of( iv_text = ls_block-text iv_label = zif_cd_ops_types=>gc_ack_msg-payments )
                                        exp = |{ gc_test-run_count }|
                                        msg = 'Payments of the payment run' ).
    cl_abap_unit_assert=>assert_equals( act = ls_block-currency exp = gc_test-cad msg = 'Currency of the payment run' ).
  ENDMETHOD.


  " Neither the file nor the payment run knows the counts: unknown, never 0
  METHOD nothing_known_never_zero.
    DATA ls_input TYPE zcl_cd_fmon_ack_alert=>ty_input.
    ls_input-file = file( iv_count = 0 iv_total = 0 ).
    DATA(ls_block) = zcl_cd_fmon_ack_alert=>block( ls_input ).
    DATA(lv_unknown) = zcl_cd_ops_util=>text( zif_cd_ops_types=>gc_ack_msg-unknown ).
    cl_abap_unit_assert=>assert_equals( act = value_of( iv_text = ls_block-text iv_label = zif_cd_ops_types=>gc_ack_msg-payments )
                                        exp = lv_unknown
                                        msg = 'Payments unknown' ).
    cl_abap_unit_assert=>assert_false( act = ls_block-amount_known msg = 'Amount unknown' ).
    cl_abap_unit_assert=>assert_equals( act = value_of( iv_text = ls_block-text iv_label = zif_cd_ops_types=>gc_ack_msg-house_bank )
                                        exp = lv_unknown
                                        msg = 'House bank unknown without run key' ).
  ENDMETHOD.


  METHOD ack_codes_recognised.
    cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_ack_alert=>is_ack_code( zif_cd_fmon_types=>gc_check_code-no_bank_ack )
                                      msg = 'NO_BANK_ACK' ).
    cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_ack_alert=>is_ack_code( zif_cd_fmon_types=>gc_check_code-ack_amount )
                                      msg = 'ACK_AMOUNT_MISMATCH' ).
    cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_ack_alert=>is_ack_code( zif_cd_fmon_types=>gc_check_code-nack )
                                       msg = 'A NACK is not a missing ACK' ).
  ENDMETHOD.


  " A missed deadline is an ACK alert only when its stage is ACK_RECEIVED
  METHOD ack_deadline_recognised.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    ls_finding-check_code = zif_cd_fmon_types=>gc_check_code-deadline_missed.
    ls_finding-details    = zcl_cd_fmon_ack_alert=>missed_stage_line( zif_cd_fmon_types=>gc_stage-ack ).
    cl_abap_unit_assert=>assert_true( act = zcl_cd_fmon_ack_alert=>is_ack_deadline( ls_finding )
                                      msg = 'Deadline of ACK_RECEIVED' ).
    ls_finding-details = zcl_cd_fmon_ack_alert=>missed_stage_line( zif_cd_fmon_types=>gc_stage-sent ).
    cl_abap_unit_assert=>assert_false( act = zcl_cd_fmon_ack_alert=>is_ack_deadline( ls_finding )
                                       msg = 'Deadline of another stage' ).
  ENDMETHOD.

ENDCLASS.
