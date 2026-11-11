*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_downtime.clas.abap
*& Purpose:
*& Planned downtime API (ZIF_CA_OPS_DOWNTIME, 2026-11-11): reads the windows
*& of an area from ZCA_OPS_DTWIN (index ARE: area, end; read only, one
*& set-based read per question) and lets ZCL_CA_OPS_DOWNTIME_POLICY decide
*& which one covers a finding. Writes nothing: windows are maintained in the
*& downtime app ZUI_CA_OPS_DTW.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: planned downtime).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - planned downtime windows</p>
CLASS zcl_ca_ops_downtime DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_downtime.

ENDCLASS.



CLASS zcl_ca_ops_downtime IMPLEMENTATION.

  METHOD zif_ca_ops_downtime~windows.
    DATA lt_area     TYPE RANGE OF zif_ca_ops_types=>ty_area.
    DATA lt_approved TYPE RANGE OF syuname.
    DATA(lv_to) = COND timestampl( WHEN iv_to IS INITIAL THEN iv_from ELSE iv_to ).
    IF iv_area IS NOT INITIAL.
      lt_area = VALUE #( ( sign = zif_ca_ops_types=>gc_range-sign_include option = zif_ca_ops_types=>gc_range-option_equal
                           low = iv_area ) ).
    ENDIF.
    IF iv_approved_only = abap_true.
      lt_approved = VALUE #( ( sign = zif_ca_ops_types=>gc_range-sign_exclude option = zif_ca_ops_types=>gc_range-option_equal
                               low = space ) ).
    ENDIF.
    " index ARE (MANDT, AREA, TO_UTC): windows of the area that have not ended before the period
    SELECT window_id, area, check_pattern, object_pattern, group_pattern, from_date, from_time, to_date, to_time,
           time_zone, from_utc, to_utc, reason, created_by, approved_by
      FROM zca_ops_dtwin
      WHERE area        IN @lt_area
        AND to_utc      >  @iv_from
        AND from_utc    <= @lv_to
        AND approved_by IN @lt_approved
      ORDER BY from_utc, window_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_windows.
  ENDMETHOD.


  METHOD zif_ca_ops_downtime~planned.
    DATA(lt_windows) = zif_ca_ops_downtime~windows( iv_area = iv_area iv_from = iv_from iv_to = iv_to ).
    rv_window_id = zcl_ca_ops_downtime_policy=>covering( it_windows  = lt_windows
                                                         iv_area     = iv_area
                                                         is_finding  = is_finding
                                                         iv_from     = iv_from
                                                         iv_to       = iv_to ).
  ENDMETHOD.


  METHOD zif_ca_ops_downtime~area_planned.
    DATA(lt_windows) = zif_ca_ops_downtime~windows( iv_area = iv_area iv_from = iv_at iv_to = iv_at ).
    rv_window_id = zcl_ca_ops_downtime_policy=>area_wide( it_windows = lt_windows
                                                          iv_area    = iv_area
                                                          iv_at      = iv_at ).
  ENDMETHOD.

ENDCLASS.
