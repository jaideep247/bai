*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pilot_dao.clas.abap
*& Purpose:
*& Data access of the pilot pack export: metrics per day (CDS
*& ZI_CA_OpsPilotDay, aggregated on the database), breaks explained (CDS
*& ZR_CA_OpsPilotBrk) and the baselines (ZCA_OPS_PILOTBL) of one area. The
*& caller checks ZCA_OPS display (03) for the area; the views have no DCL of
*& their own (area-level figures). Read only.
*& Modification log:
*& 2026-11-11 | Initial version (build F: pilot pack).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - pilot pack data access</p>
CLASS zcl_ca_ops_pilot_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pilot_dao.

ENDCLASS.



CLASS zcl_ca_ops_pilot_dao IMPLEMENTATION.

  METHOD zif_ca_ops_pilot_dao~days.
    SELECT raiseddate, area, processid, checkid, raisedcount, assignedcount, resolvedcount, falsepositivecount,
           detectknowncount, baselineknowncount, earliercount, minutestodetect, baselineminutes, minutestoassign,
           minutestoresolve
      FROM zi_ca_opspilotday
      WHERE area = @iv_area
        AND raiseddate BETWEEN @iv_from AND @iv_to
      ORDER BY raiseddate, processid, checkid
      INTO CORRESPONDING FIELDS OF TABLE @rt_days.
  ENDMETHOD.


  METHOD zif_ca_ops_pilot_dao~breaks.
    SELECT area, accountid, companycode, keydate, groupcount, explainedcount, unexplainedcount
      FROM zr_ca_opspilotbrk
      WHERE area = @iv_area
        AND keydate BETWEEN @iv_from AND @iv_to
      ORDER BY keydate, accountid, companycode
      INTO CORRESPONDING FIELDS OF TABLE @rt_breaks.
  ENDMETHOD.


  METHOD zif_ca_ops_pilot_dao~baselines.
    SELECT area, check_id, baseline_min, source
      FROM zca_ops_pilotbl
      WHERE area = @iv_area
      ORDER BY check_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_baselines.
  ENDMETHOD.

ENDCLASS.
