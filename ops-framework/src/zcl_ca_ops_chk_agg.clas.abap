*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_agg.clas.abap
*& Purpose:
*& No-code aggregate check of the check registry: every active row of
*& ZCA_OPS_AGG of the check (area + check ID) is one database aggregate over
*& a table approved for the area - COUNT of the rows in a status, or AGE in
*& days of the oldest of them - per company code when the row names the
*& company-code field, compared with the row's AMBER / RED limits. A value at
*& or above a limit is a finding with the company code (exception); below
*& both nothing, so the runner auto-resolves the earlier exception. A row
*& that cannot be measured is an AGG_CONFIG_INVALID finding and makes the
*& check partial (its earlier exceptions stay open); the other rows are
*& still measured. Reads only through ZIF_CA_OPS_CHECK_DAO.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - no-code aggregate check</p>
"! Example: requests in status PENDING whose request date passed, per company code, amber 1 /
"! red 3 days (AGE) - configuration rows only (ZCA_OPS_CHECK, ZCA_OPS_AGG, ZCA_OPS_TABWL).
CLASS zcl_ca_ops_chk_agg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

ENDCLASS.



CLASS zcl_ca_ops_chk_agg IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_check_dao( ).
    DATA(lt_aggs) = lo_dao->get_aggregates( iv_area     = is_check-area
                                            iv_check_id = is_check-check_id ).
    IF lt_aggs IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e092(zca_ops) WITH is_check-check_id is_check-area.
    ENDIF.
    LOOP AT lt_aggs ASSIGNING FIELD-SYMBOL(<ls_agg>).
      TRY.
          DATA(lt_rows) = lo_dao->aggregate( is_agg         = <ls_agg>
                                             iv_bukrs_aware = is_check-bukrs_aware
                                             iv_today       = is_context-today ).
          INSERT LINES OF zcl_ca_ops_agg_query=>to_findings( is_agg   = <ls_agg>
                                                             it_rows  = lt_rows
                                                             iv_today = is_context-today )
                 INTO TABLE rs_result-findings.
          rs_result-item_count += lines( lt_rows ).
          " a result at the row cap may be cut off: an absent company code is unknown, not resolved
          IF lines( lt_rows ) >= zif_ca_ops_chk_types=>gc_max_groups.
            rs_result-partial = abap_true.
          ENDIF.
        CATCH zcx_ca_ops_error INTO DATA(lx_error).
          rs_result-partial = abap_true.
          INSERT VALUE #( object_type = zif_ca_ops_chk_types=>gc_object_type-aggregate
                          object_key  = |{ <ls_agg>-check_id }/{ <ls_agg>-agg_id }|
                          rule_id     = <ls_agg>-agg_id
                          check_code  = zif_ca_ops_chk_types=>gc_code-agg_invalid
                          severity    = zif_ca_ops_types=>gc_severity-error
                          action      = zif_ca_ops_types=>gc_action-notify
                          reference   = <ls_agg>-tabname
                          message     = lx_error->get_text( )
                          details     = zcl_ca_ops_util=>exception_trace( lx_error )
                          error_class = zcl_ca_ops_util=>error_class( lx_error ) ) INTO TABLE rs_result-findings.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
