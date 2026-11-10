*&---------------------------------------------------------------------*
*& Artifact: zcd_ops_pattern_check.prog.abap
*& Purpose:
*& Pattern check (read-only, user decision 2026-11-06): for one pattern area
*& (EBS flow pattern, FMON file name, HCK job name, HCK suppression key,
*& alert rule patterns) lists the real values of the area's source in a date
*& window and, per value, the configured PCRE pattern(s) that capture it -
*& values captured by no pattern, patterns that capture nothing and invalid
*& patterns first. An ad-hoc pattern can be checked before it is saved.
*& Matching as at runtime: complete value, case ignored. Authorisation
*& ZCD_OPS display (03) for the payment engine area of the pattern area.
*& Reads are capped (P_MAX); writes nothing.
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: check the complete record of a pattern).
*&---------------------------------------------------------------------*
REPORT zcd_ops_pattern_check.

TYPES ty_area TYPE zif_cd_ops_pattern_types=>ty_area.
TYPES ty_adhoc TYPE c LENGTH 128.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_area TYPE ty_area AS LISTBOX VISIBLE LENGTH 40 OBLIGATORY.
  PARAMETERS p_pcre TYPE ty_adhoc LOWER CASE.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  PARAMETERS p_from TYPE d OBLIGATORY.
  PARAMETERS p_to TYPE d OBLIGATORY.
  PARAMETERS p_max TYPE i DEFAULT zif_cd_ops_pattern_types=>gc_default_max_rows OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b02.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS gc_area_parameter TYPE vrm_id VALUE 'P_AREA'.
    CONSTANTS gc_default_days TYPE i VALUE 7.

    CLASS-METHODS fill_area_list.
    CLASS-METHODS check_selection.
    METHODS main.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_column,
        status  TYPE lvc_fname VALUE 'STATUS',
        value   TYPE lvc_fname VALUE 'VALUE',
        pattern TYPE lvc_fname VALUE 'PATTERN',
        source  TYPE lvc_fname VALUE 'SOURCE',
        hits    TYPE lvc_fname VALUE 'HITS',
      END OF gc_column.

    DATA mt_rows TYPE zif_cd_ops_pattern_types=>tt_check_row.

    METHODS display.
    METHODS set_text
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table
        iv_name    TYPE lvc_fname
        iv_text    TYPE clike.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD fill_area_list.
    DATA(lt_values) = VALUE vrm_values(
      ( key = zif_cd_ops_pattern_types=>gc_area-ebs_flow    text = TEXT-a01 )
      ( key = zif_cd_ops_pattern_types=>gc_area-fmon_file   text = TEXT-a02 )
      ( key = zif_cd_ops_pattern_types=>gc_area-hck_job     text = TEXT-a03 )
      ( key = zif_cd_ops_pattern_types=>gc_area-hck_suppr   text = TEXT-a04 )
      ( key = zif_cd_ops_pattern_types=>gc_area-alert_rule  text = TEXT-a05 )
      ( key = zif_cd_ops_pattern_types=>gc_area-alert_check text = TEXT-a06 )
      ( key = zif_cd_ops_pattern_types=>gc_area-alert_grp1  text = TEXT-a07 )
      ( key = zif_cd_ops_pattern_types=>gc_area-alert_grp2  text = TEXT-a08 ) ).
    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id              = gc_area_parameter
        values          = lt_values
      EXCEPTIONS
        id_illegal_name = 1
        OTHERS          = 2.
    IF sy-subrc <> 0.
      " Without the list the area is typed in; check_selection still validates it
      MESSAGE s051(zcd_ops) WITH gc_area_parameter TEXT-b01.
    ENDIF.
  ENDMETHOD.


  METHOD check_selection.
    IF zcl_cd_ops_pattern_check=>pe_area_of( p_area ) IS INITIAL.
      MESSAGE e051(zcd_ops) WITH p_area TEXT-b01.
    ENDIF.
    " An ad-hoc pattern is checked as it would be saved: it must compile
    IF zcl_ca_ops_util=>pcre_valid( p_pcre ) = abap_false.
      MESSAGE e743(zcd_ops) WITH p_pcre.
    ENDIF.
    IF p_from > p_to.
      MESSAGE e051(zcd_ops) WITH p_from TEXT-b02.
    ENDIF.
    IF p_max <= 0 OR p_max > zif_cd_ops_pattern_types=>gc_max_rows_limit.
      MESSAGE e051(zcd_ops) WITH p_max TEXT-c06.
    ENDIF.
  ENDMETHOD.


  METHOD main.
    TRY.
        zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-display
                                                iv_pe_area  = zcl_cd_ops_pattern_check=>pe_area_of( p_area ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA(lo_dao) = zcl_cd_ops_factory=>get_pattern_dao( ).
    DATA(lt_patterns) = lo_dao->get_patterns( p_area ).
    IF p_pcre IS NOT INITIAL.
      INSERT VALUE #( source = TEXT-c07 pattern = p_pcre ) INTO TABLE lt_patterns.
    ENDIF.
    DATA(lt_values) = lo_dao->get_values( iv_area     = p_area
                                          iv_from     = p_from
                                          iv_to       = p_to
                                          iv_max_rows = p_max ).
    DATA(ls_result) = zcl_cd_ops_pattern_check=>analyse( it_patterns = lt_patterns
                                                         it_values   = lt_values ).
    mt_rows = ls_result-rows.
    " A capped read can hide values: said, never silent
    IF lines( lt_values ) >= p_max.
      MESSAGE i747(zcd_ops) WITH p_max p_area.
    ENDIF.
    MESSAGE s746(zcd_ops) WITH ls_result-values ls_result-unmatched ls_result-unused.
    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_rows ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        set_text( io_columns = lo_columns iv_name = gc_column-status iv_text = TEXT-c01 ).
        set_text( io_columns = lo_columns iv_name = gc_column-value iv_text = TEXT-c02 ).
        set_text( io_columns = lo_columns iv_name = gc_column-pattern iv_text = TEXT-c03 ).
        set_text( io_columns = lo_columns iv_name = gc_column-source iv_text = TEXT-c04 ).
        set_text( io_columns = lo_columns iv_name = gc_column-hits iv_text = TEXT-c05 ).
        lo_alv->display( ).
      CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD set_text.
    TRY.
        DATA(lo_column) = io_columns->get_column( iv_name ).
        lo_column->set_short_text( CONV #( iv_text ) ).
        lo_column->set_medium_text( CONV #( iv_text ) ).
        lo_column->set_long_text( CONV #( iv_text ) ).
      CATCH cx_salv_not_found ##NO_HANDLER.
        " Column of the row type only - nothing to label
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  lcl_app=>fill_area_list( ).
  p_to   = sy-datum.
  p_from = sy-datum - lcl_app=>gc_default_days.

AT SELECTION-SCREEN.
  lcl_app=>check_selection( ).

START-OF-SELECTION.
  NEW lcl_app( )->main( ).
