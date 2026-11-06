*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_query.clas.testclasses.abap
*& Purpose:
*& Pure unit tests (no doubles) for the DDIC validation of configured
*& table / field names. A DDIC field list is passed in as plain data.
*& Static ABAP Unit only; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A51: approved table / field checks.
*& 2026-11-06 | Modern-syntax sweep: caught exception lx_error.
*&---------------------------------------------------------------------*
CLASS ltc_query DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        status_field TYPE zif_cd_fmon_types=>ty_fieldname,
        date_on_char TYPE abap_bool,
        no_condition TYPE abap_bool,
      END OF ty_flags.

    CONSTANTS gc_table TYPE zif_cd_fmon_types=>ty_tabname VALUE 'ZCD_ACH_ACK'.
    CONSTANTS gc_file_fld TYPE zif_cd_fmon_types=>ty_fieldname VALUE 'FILE_NAME_X'.
    CONSTANTS gc_date_fld TYPE zif_cd_fmon_types=>ty_fieldname VALUE 'CREATED_ON_X'.
    CONSTANTS gc_stat_fld TYPE zif_cd_fmon_types=>ty_fieldname VALUE 'STATUS_X'.

    DATA ms_query TYPE zif_cd_fmon_types=>ty_query.
    DATA mt_fields TYPE zif_cd_fmon_types=>tt_ddic_field.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    "! Returns the message number raised, blank when the query is valid
    METHODS act
      RETURNING
        VALUE(rv_msgno) TYPE symsgno.

    METHODS valid_query_passes FOR TESTING.
    METHODS unknown_field_is_rejected FOR TESTING.
    METHODS injected_name_is_rejected FOR TESTING.
    METHODS date_field_must_be_a_date FOR TESTING.
    METHODS unrestricted_read_is_rejected FOR TESTING.
    METHODS approved_read_passes FOR TESTING.
    METHODS unapproved_table_is_rejected FOR TESTING.
    METHODS unapproved_field_is_rejected FOR TESTING.

    "! Returns the message number raised by the approval check, blank when approved
    METHODS act_approval
      IMPORTING
        it_allow        TYPE zif_cd_fmon_types=>tt_tab_allow
      RETURNING
        VALUE(rv_msgno) TYPE symsgno.

ENDCLASS.


CLASS ltc_query IMPLEMENTATION.

  METHOD configure_scenario.
    DATA ls_field TYPE zif_cd_fmon_types=>ty_ddic_field.
    CLEAR: ms_query, mt_fields.

    ls_field-fieldname = gc_file_fld.
    ls_field-inttype   = 'C'.
    INSERT ls_field INTO TABLE mt_fields.
    ls_field-fieldname = gc_date_fld.
    ls_field-inttype   = COND #( WHEN is_flags-date_on_char = abap_true THEN 'C' ELSE 'D' ).
    INSERT ls_field INTO TABLE mt_fields.
    ls_field-fieldname = gc_stat_fld.
    ls_field-inttype   = 'C'.
    INSERT ls_field INTO TABLE mt_fields.

    ms_query-table_name = gc_table.
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-file_name
                                            iv_field = gc_file_fld
                                  CHANGING  cs_query = ms_query ).
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-status
                                            iv_field = COND #( WHEN is_flags-status_field IS INITIAL
                                                               THEN gc_stat_fld ELSE is_flags-status_field )
                                  CHANGING  cs_query = ms_query ).
    IF is_flags-no_condition = abap_false.
      ms_query-date_field = gc_date_fld.
      ms_query-date_kind  = zif_cd_fmon_types=>gc_date_kind-date.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    TRY.
        zcl_cd_fmon_query=>validate( is_query  = ms_query
                                     it_fields = mt_fields ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        rv_msgno = lx_error->if_t100_message~t100key-msgno.
    ENDTRY.
  ENDMETHOD.


  " Rule: names that all exist in the DDIC with fitting types are accepted.
  METHOD valid_query_passes.
    configure_scenario( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( act = act( )
                                         msg = 'A fully DDIC-backed query must pass' ).
  ENDMETHOD.


  " Rule: a configured field that is not in the table is rejected (message 201).
  METHOD unknown_field_is_rejected.
    configure_scenario( VALUE #( status_field = 'NO_SUCH_FIELD' ) ).
    cl_abap_unit_assert=>assert_equals( act = act( ) exp = '201'
                                        msg = 'Unknown field must raise 201' ).
  ENDMETHOD.


  " Rule: a name that is not a DDIC identifier never reaches SQL (message 202).
  METHOD injected_name_is_rejected.
    configure_scenario( VALUE #( status_field = 'X OR 1 = 1' ) ).
    cl_abap_unit_assert=>assert_equals( act = act( ) exp = '202'
                                        msg = 'Non-identifier must raise 202' ).
  ENDMETHOD.


  " Rule: the date field of a date-restricted read must be of DDIC type D (message 203).
  METHOD date_field_must_be_a_date.
    configure_scenario( VALUE #( date_on_char = abap_true ) ).
    cl_abap_unit_assert=>assert_equals( act = act( ) exp = '203'
                                        msg = 'Character date field must raise 203' ).
  ENDMETHOD.


  " Rule: a read without date or key restriction is refused (message 209).
  METHOD unrestricted_read_is_rejected.
    configure_scenario( VALUE #( no_condition = abap_true ) ).
    cl_abap_unit_assert=>assert_equals( act = act( ) exp = '209'
                                        msg = 'Unrestricted read must raise 209' ).
  ENDMETHOD.


  METHOD act_approval.
    TRY.
        zcl_cd_fmon_query=>check_approved( is_query = ms_query
                                           it_allow = it_allow ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        rv_msgno = lx_error->if_t100_message~t100key-msgno.
    ENDTRY.
  ENDMETHOD.


  " Audit A51: an approved table with '*' allows every field of it
  METHOD approved_read_passes.
    configure_scenario( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial(
      act = act_approval( VALUE #( ( table_name = gc_table field_name = zif_cd_fmon_types=>gc_wildcard ) ) )
      msg = 'A table approved with * must pass' ).
  ENDMETHOD.


  " Audit A51: a valid DDIC identifier of a table nobody approved never reaches SQL (244)
  METHOD unapproved_table_is_rejected.
    configure_scenario( VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = act_approval( VALUE #( ( table_name = 'ZCD_OTHER_TABLE' field_name = zif_cd_fmon_types=>gc_wildcard ) ) )
      exp = '244'
      msg = 'A table outside ZCD_FMON_TABWL must raise 244' ).
  ENDMETHOD.


  " Audit A51: with field-level approval, a field not listed is refused (249)
  METHOD unapproved_field_is_rejected.
    configure_scenario( VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = act_approval( VALUE #( ( table_name = gc_table field_name = gc_file_fld )
                                   ( table_name = gc_table field_name = gc_date_fld ) ) )
      exp = '249'
      msg = 'The status field is not approved and must raise 249' ).
  ENDMETHOD.

ENDCLASS.
