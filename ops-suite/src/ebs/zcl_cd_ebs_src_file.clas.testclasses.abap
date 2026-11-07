*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_src_file.clas.testclasses.abap
*& Purpose:
*& Application tests of the bank-file source with an LTD_* parser double
*& injected through ZCL_CD_EBS_INJECTOR: one package carrying the parser's
*& statements, lines and findings, then the end of the run. Written after the
*& class (characterisation tests). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (TDD gap closure).
*& 2026-11-07 | file_is_parsed_only_once without the removed get_file.
*&---------------------------------------------------------------------*
CLASS ltd_parser DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_parser.
    DATA mv_calls TYPE i.
    DATA mv_content TYPE string.
ENDCLASS.

CLASS ltd_parser IMPLEMENTATION.
  METHOD zif_cd_ebs_parser~parse.
    DATA ls_statement TYPE zif_cd_ebs_types=>ty_statement.
    DATA ls_line      TYPE zif_cd_ebs_types=>ty_line.
    DATA ls_finding   TYPE zif_cd_ops_types=>ty_finding.
    mv_calls += 1.
    mv_content = iv_content.
    rs_file-format    = zif_cd_ebs_types=>gc_format-bai2.
    rs_file-file_name = iv_file_name.
    ls_statement-stmt_key = 'S0001'.
    INSERT ls_statement INTO TABLE rs_file-statements.
    ls_line-stmt_key = 'S0001'.
    ls_line-line_no  = 1.
    INSERT ls_line INTO TABLE rs_file-lines.
    ls_finding-rule_id    = 'S06'.
    ls_finding-check_code = 'BAI2_FILE_CTRL_TOTAL'.
    ls_finding-severity   = zif_cd_ops_types=>gc_severity-block.
    INSERT ls_finding INTO TABLE rs_file-findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_src_file DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_content TYPE string VALUE `01,SENDER,RECEIVER,261105,0800,1,,,2/`.

    DATA mo_parser TYPE REF TO ltd_parser.
    DATA mo_cut    TYPE REF TO zcl_cd_ebs_src_file.

    METHODS setup.
    METHODS teardown.

    METHODS first_package_is_parsed_file FOR TESTING.
    METHODS parser_findings_are_passed   FOR TESTING.
    METHODS second_call_ends_the_run     FOR TESTING.
    METHODS file_is_parsed_only_once     FOR TESTING.
ENDCLASS.


CLASS ltc_src_file IMPLEMENTATION.

  METHOD setup.
    mo_parser = NEW #( ).
    zcl_cd_ebs_injector=>inject_parser( mo_parser ).
    mo_cut = NEW #( iv_content   = gc_content
                    iv_format    = zif_cd_ebs_types=>gc_format-bai2
                    iv_file_name = `JPMC_20261105.bai` ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ebs_injector=>reset( ).
    CLEAR: mo_parser, mo_cut.
  ENDMETHOD.


  " The first package carries the parsed statements and lines of the file content
  METHOD first_package_is_parsed_file.
    TRY.
        DATA(ls_package) = mo_cut->zif_cd_ebs_source~next_package( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_package-statements ) exp = 1 msg = 'One statement expected' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_package-lines ) exp = 1 msg = 'One line expected' ).
        cl_abap_unit_assert=>assert_equals( act = mo_parser->mv_content exp = gc_content
                                            msg = 'Parser must receive the file content unchanged' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Structural findings of the parser (S06 etc.) reach the engine with the package
  METHOD parser_findings_are_passed.
    TRY.
        DATA(ls_package) = mo_cut->zif_cd_ebs_source~next_package( ).
        cl_abap_unit_assert=>assert_equals( act = ls_package-findings[ 1 ]-rule_id exp = 'S06'
                                            msg = 'Parser findings must be handed on' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A file is one package; the second call returns an initial package (end of run)
  METHOD second_call_ends_the_run.
    TRY.
        mo_cut->zif_cd_ebs_source~next_package( ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->zif_cd_ebs_source~next_package( )
                                             msg = 'Second call must end the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The file is parsed once per source
  METHOD file_is_parsed_only_once.
    TRY.
        mo_cut->zif_cd_ebs_source~next_package( ).
        mo_cut->zif_cd_ebs_source~next_package( ).
        cl_abap_unit_assert=>assert_equals( act = mo_parser->mv_calls exp = 1 msg = 'Parser must run once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
