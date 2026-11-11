*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_field.clas.abap
*& Purpose:
*& Parent / child resolver FIELD of the SAP job monitor: the parent job
*& name and count from two TBTCO fields, when the release has such fields.
*& The field names are configuration (JOB_PARENT_FIELDS, two names, blank
*& = resolver off) and are checked against the runtime DDIC of TBTCO
*& (RTTI) before any read - a name the table does not have is never put
*& into SQL (127). Quality C (confirmed by key). Reads through the job
*& monitor's data access only.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job resolver FIELD (TBTCO)</p>
"! VERIFY-SE11 V62: whether TBTCO of 7.58 has parent job fields at all; delivered off (blank parameter).
CLASS zcl_ca_ops_job_res_field DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_resolver.

  PRIVATE SECTION.
    CONSTANTS gc_table TYPE string VALUE `TBTCO`.
    "! Number of names in JOB_PARENT_FIELDS: parent job name, parent job count
    CONSTANTS gc_field_count TYPE i VALUE 2.

    "! The two configured fields when both are fields of TBTCO; blank when the parameter is blank
    "! @raising zcx_ca_ops_error | 127 a configured name is not a field of TBTCO
    METHODS fields
      EXPORTING
        ev_name_field  TYPE zif_ca_ops_job_types=>ty_fieldname
        ev_count_field TYPE zif_ca_ops_job_types=>ty_fieldname
      RAISING
        zcx_ca_ops_error.

    "! Field names of the runtime DDIC of TBTCO
    METHODS table_fields
      RETURNING
        VALUE(rt_fields) TYPE string_table
      RAISING
        zcx_ca_ops_error.

    METHODS keys
      IMPORTING
        it_jobs        TYPE zif_ca_ops_job_types=>tt_job
      RETURNING
        VALUE(rt_keys) TYPE zif_ca_ops_job_types=>tt_job_key.

ENDCLASS.



CLASS zcl_ca_ops_job_res_field IMPLEMENTATION.

  METHOD zif_ca_ops_job_resolver~id.
    rv_id = zif_ca_ops_job_types=>gc_resolver-field.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~parents.
    fields( IMPORTING ev_name_field  = DATA(lv_name)
                      ev_count_field = DATA(lv_count) ).
    IF lv_name IS INITIAL OR it_jobs IS INITIAL.
      RETURN.
    ENDIF.
    rt_links = io_dao->parents_by_fields( it_keys        = keys( it_jobs )
                                          iv_name_field  = lv_name
                                          iv_count_field = lv_count ).
    LOOP AT rt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      <ls_link>-resolver = zif_ca_ops_job_types=>gc_resolver-field.
      <ls_link>-quality  = zif_ca_ops_job_types=>gc_quality-confirmed.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~children.
    fields( IMPORTING ev_name_field  = DATA(lv_name)
                      ev_count_field = DATA(lv_count) ).
    IF lv_name IS INITIAL OR it_jobs IS INITIAL.
      RETURN.
    ENDIF.
    rt_links = io_dao->children_by_fields( it_keys        = keys( it_jobs )
                                           iv_name_field  = lv_name
                                           iv_count_field = lv_count
                                           iv_max         = is_config-max_children * lines( it_jobs ) ).
    LOOP AT rt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      <ls_link>-resolver = zif_ca_ops_job_types=>gc_resolver-field.
      <ls_link>-quality  = zif_ca_ops_job_types=>gc_quality-confirmed.
    ENDLOOP.
  ENDMETHOD.


  METHOD fields.
    CLEAR: ev_name_field, ev_count_field.
    DATA(lt_names) = zcl_ca_ops_util=>split_list(
                       zcl_ca_ops_factory=>get_params( )->get_param(
                         iv_name = zif_ca_ops_job_types=>gc_param-parent_fields
                         iv_area = zif_ca_ops_types=>gc_param_area ) ).
    IF lt_names IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( lt_names ) <> gc_field_count.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e121(zca_ops) WITH zif_ca_ops_job_types=>gc_param-parent_fields.
    ENDIF.
    DATA(lt_fields) = table_fields( ).
    LOOP AT lt_names ASSIGNING FIELD-SYMBOL(<lv_name>).
      DATA(lv_field) = to_upper( <lv_name> ).
      IF NOT line_exists( lt_fields[ table_line = lv_field ] ).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e127(zca_ops) WITH lv_field.
      ENDIF.
    ENDLOOP.
    ev_name_field  = to_upper( lt_names[ 1 ] ).
    ev_count_field = to_upper( lt_names[ 2 ] ).
  ENDMETHOD.


  METHOD table_fields.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = gc_table
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e127(zca_ops) WITH gc_table.
    ENDIF.
    TRY.
        lo_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e127(zca_ops) WITH gc_table
          EXPORTING
            previous = lx_error.
    ENDTRY.
    LOOP AT lo_struct->components ASSIGNING FIELD-SYMBOL(<ls_component>).
      INSERT CONV string( <ls_component>-name ) INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD keys.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      INSERT VALUE #( jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
