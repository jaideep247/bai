*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_ddic.clas.testclasses.abap
*& Purpose:
*& Unit tests of the RTTI DDIC describer: fields and key flags of a DDIC
*& table (T000, delivered by SAP in every system), invalid names, unknown
*& names and non-structure types refused, S_TABU_NAM decision of the core
*& authorisation (double). Reads the runtime DDIC only (no table content); does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-10 | S_TABU_NAM decision through the core authorisation double (ZCL_CD_OPS_INJECTOR=>INJECT_AUTH).
*&---------------------------------------------------------------------*
CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool.
ENDCLASS.


CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_cd_ops_auth~may_read_table.
    rv_allowed = mv_allowed.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ddic DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_table       TYPE zif_cd_fmon_types=>ty_tabname VALUE 't000',
      gc_key_field   TYPE zif_cd_fmon_types=>ty_fieldname VALUE 'MANDT',
      gc_data_field  TYPE zif_cd_fmon_types=>ty_fieldname VALUE 'MTEXT',
      gc_invalid     TYPE zif_cd_fmon_types=>ty_tabname VALUE 'T000; DROP',
      gc_unknown     TYPE zif_cd_fmon_types=>ty_tabname VALUE 'ZCD_NO_SUCH_TABLE_X',
      gc_element     TYPE zif_cd_fmon_types=>ty_tabname VALUE 'BUKRS',
      gc_msgno_name  TYPE symsgno VALUE '202',
      gc_msgno_table TYPE symsgno VALUE '200'.

    DATA mo_cut TYPE REF TO zif_cd_fmon_ddic.

    METHODS setup.
    METHODS teardown.
    METHODS table_fields_with_key_flag FOR TESTING.
    METHODS invalid_name_raises_202 FOR TESTING.
    METHODS unknown_table_raises_200 FOR TESTING.
    METHODS data_element_raises_200 FOR TESTING.
    METHODS authorised_table_may_read FOR TESTING.
    METHODS refused_table_may_not_read FOR TESTING.

    METHODS assert_raises
      IMPORTING
        iv_table TYPE zif_cd_fmon_types=>ty_tabname
        iv_msgno TYPE symsgno.
ENDCLASS.


CLASS ltc_ddic IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_fmon_ddic( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_cut.
  ENDMETHOD.


  METHOD assert_raises.
    TRY.
        mo_cut->describe_table( iv_table ).
        cl_abap_unit_assert=>fail( msg = 'Describe must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = iv_msgno
                                            msg = 'Raised with the expected message' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the field list comes from the runtime DDIC (name upper-cased), key fields flagged
  METHOD table_fields_with_key_flag.
    TRY.
        DATA(lt_fields) = mo_cut->describe_table( gc_table ).
        cl_abap_unit_assert=>assert_true( act = VALUE #( lt_fields[ fieldname = gc_key_field ]-keyflag OPTIONAL )
                                          msg = 'Client is a key field' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_fields[ fieldname = gc_data_field ] ) )
                                          msg = 'Non-key field listed' ).
        cl_abap_unit_assert=>assert_false( act = lt_fields[ fieldname = gc_data_field ]-keyflag
                                           msg = 'Non-key field not flagged' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a name that is not a valid identifier is refused before RTTI (no injection)
  METHOD invalid_name_raises_202.
    assert_raises( iv_table = gc_invalid iv_msgno = gc_msgno_name ).
  ENDMETHOD.


  " Rule: an unknown name is refused
  METHOD unknown_table_raises_200.
    assert_raises( iv_table = gc_unknown iv_msgno = gc_msgno_table ).
  ENDMETHOD.


  " Rule: a DDIC type that is not a structure (data element) is refused
  METHOD data_element_raises_200.
    assert_raises( iv_table = gc_element iv_msgno = gc_msgno_table ).
  ENDMETHOD.


  " Rule: S_TABU_NAM display decides whether the dynamic reader may read the table
  METHOD authorised_table_may_read.
    TRY.
        zcl_cd_ops_injector=>inject_auth( NEW ltd_auth( ) ).
        CAST ltd_auth( zcl_cd_ops_factory=>get_auth( ) )->mv_allowed = abap_true.
        cl_abap_unit_assert=>assert_true( act = mo_cut->may_read( gc_table ) msg = 'Authorised table may be read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without S_TABU_NAM display the table is not read
  METHOD refused_table_may_not_read.
    TRY.
        zcl_cd_ops_injector=>inject_auth( NEW ltd_auth( ) ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->may_read( gc_table ) msg = 'Refused table is not read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
