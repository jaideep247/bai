*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_copy.clas.abap
*& Purpose:
*& Migration of the entries of a purpose from its FI-CA customer posting
*& area (TFK033D, read-only - FQC0 stays as it is) into a new mapping version
*& of its typed table (product review 2026-11-15), for the report
*& ZCD_OPS_POSTAREA_COPY: PLAN reads the stored entries whatever source the
*& purpose has now and gives each a status (COPY, TOO_LONG - a value longer
*& than the typed column; VERSION_USED - the target version already has
*& rows, nothing is copied); ZBTM entries get the disposition POSTED (TFK033D
*& holds no 7th result: every entry was posted as usual - review sweeps to
*& NOT_POSTED in the app before the version is activated). WRITE inserts the
*& COPY rows through the typed table repository (no commit). The active
*& version and the source stay parameters: the copy changes no behaviour.
*& Modification log:
*& 2026-11-15 | Initial version (typed product mapping tables, migration step).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - copy posting area entries to a typed table</p>
CLASS zcl_cd_ops_postarea_copy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Every stored entry of the posting area of the purpose with its status for the target version
    CLASS-METHODS plan
      IMPORTING
        iv_purpose     TYPE zif_cd_ops_postarea_types=>ty_purpose
        iv_version     TYPE zif_cd_ops_postarea_types=>ty_version
      RETURNING
        VALUE(rt_rows) TYPE zif_cd_ops_postarea_types=>tt_copy_row.

    "! Inserts the COPY rows as rows of the version (status WRITTEN); returns the typed rows written
    "! (for the customizing request) - initial when nothing is to be copied
    CLASS-METHODS write
      IMPORTING
        iv_purpose     TYPE zif_cd_ops_postarea_types=>ty_purpose
        iv_version     TYPE zif_cd_ops_postarea_types=>ty_version
      EXPORTING
        er_rows        TYPE REF TO data
      CHANGING
        ct_rows        TYPE zif_cd_ops_postarea_types=>tt_copy_row
      RAISING
        zcx_ca_ops_error.

    "! Number of rows with the status
    CLASS-METHODS count
      IMPORTING
        it_rows         TYPE zif_cd_ops_postarea_types=>tt_copy_row
        iv_status       TYPE zif_cd_ops_postarea_types=>ty_copy_status
      RETURNING
        VALUE(rv_count) TYPE i.

  PRIVATE SECTION.
    "! A value of the entry is longer than its column of the typed table (layout length)
    CLASS-METHODS too_long
      IMPORTING
        is_layout       TYPE zif_cd_ops_postarea_types=>ty_layout
        is_entry        TYPE zif_cd_ops_postarea_types=>ty_entry
      RETURNING
        VALUE(rv_long)  TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ops_postarea_copy IMPLEMENTATION.

  METHOD plan.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(lo_reader) = zcl_cd_ops_postarea_factory=>get_reader( ).
    DATA(lv_area) = lo_reader->area( iv_purpose ).
    IF lv_area IS INITIAL.
      RETURN.
    ENDIF.
    " The stored FQC0 entries, read-only, whatever the source of the purpose is now
    DATA(lt_entries) = zcl_cd_ops_postarea_factory=>get_dao( )->read_entries(
                         iv_applk = CONV #( lo_params->get_param(
                                              iv_name    = zif_cd_ops_postarea_types=>gc_param-applk
                                              iv_default = zif_cd_ops_postarea_types=>gc_param_default-applk ) )
                         iv_area  = lv_area
                         iv_ktopl = CONV #( lo_params->get_param( zif_cd_ops_postarea_types=>gc_param-ktopl ) ) ).
    DATA(lv_used) = xsdbool( zcl_cd_ops_postarea_factory=>get_typed_dao( )->read_entries(
                               iv_purpose = iv_purpose
                               iv_version = iv_version ) IS NOT INITIAL ).
    DATA(ls_layout) = zcl_cd_ops_postarea_layout=>layout( iv_purpose ).
    LOOP AT lt_entries ASSIGNING FIELD-SYMBOL(<ls_entry>).
      INSERT CORRESPONDING #( <ls_entry> ) INTO TABLE rt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-btc_map.
        " TFK033D holds no disposition: the reader posted every FQC0 entry as usual
        <ls_row>-fun07 = zif_cd_ebs_types=>gc_disposition-posted.
      ENDIF.
      <ls_row>-status = COND #( WHEN lv_used = abap_true THEN zif_cd_ops_postarea_types=>gc_copy-version_used
                                WHEN too_long( is_layout = ls_layout is_entry = <ls_entry> ) = abap_true
                                  THEN zif_cd_ops_postarea_types=>gc_copy-too_long
                                ELSE zif_cd_ops_postarea_types=>gc_copy-copy ).
    ENDLOOP.
  ENDMETHOD.


  METHOD write.
    DATA lt_entries TYPE zif_cd_ops_postarea_types=>tt_entry.

    CLEAR er_rows.
    LOOP AT ct_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE status = zif_cd_ops_postarea_types=>gc_copy-copy.
      INSERT CORRESPONDING #( <ls_row> ) INTO TABLE lt_entries.
    ENDLOOP.
    IF lt_entries IS INITIAL.
      RETURN.
    ENDIF.
    er_rows = zcl_cd_ops_postarea_factory=>get_typed_dao( )->insert_entries( iv_purpose = iv_purpose
                                                                             iv_version = iv_version
                                                                             it_entries = lt_entries ).
    LOOP AT ct_rows ASSIGNING <ls_row> WHERE status = zif_cd_ops_postarea_types=>gc_copy-copy.
      <ls_row>-status = zif_cd_ops_postarea_types=>gc_copy-written.
    ENDLOOP.
  ENDMETHOD.


  METHOD count.
    rv_count = REDUCE #( INIT lv_count = 0
                         FOR ls_row IN it_rows WHERE ( status = iv_status )
                         NEXT lv_count = lv_count + 1 ).
  ENDMETHOD.


  METHOD too_long.
    DATA lv_position TYPE i.

    LOOP AT is_layout-keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      lv_position = sy-tabix.
      ASSIGN COMPONENT lv_position OF STRUCTURE is_entry TO FIELD-SYMBOL(<lv_key>).
      IF sy-subrc = 0 AND strlen( <lv_key> ) > <ls_key>-length.
        rv_long = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
    LOOP AT is_layout-results ASSIGNING FIELD-SYMBOL(<ls_result>).
      lv_position = zif_cd_ops_postarea_types=>gc_key_count + sy-tabix.
      ASSIGN COMPONENT lv_position OF STRUCTURE is_entry TO FIELD-SYMBOL(<lv_result>).
      IF sy-subrc = 0 AND strlen( <lv_result> ) > <ls_result>-length.
        rv_long = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
