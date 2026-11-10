*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_c_refund.clas.abap
*& Purpose:
*& Check COLL_R3_REFUND of process BASE_REQ_LIFE (area CD_COLL):
*& R3 source reject without a successful Stripe refund
*& Registered in ZCA_OPS_CHECK; run by ZCL_CA_OPS_CHECK_RUNNER, which stamps
*& GROUP1 = process and GROUP2 = check. Reads only through its own data
*& access class (one set-based read, no SELECT in a loop). Read only.
*& Modification log:
*& 2026-11-10 | Initial version (scaffold tools/abaptools/new_process.py).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Check COLL_R3_REFUND</p>
CLASS zcl_cd_coll_c_refund DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    "! The objects of the check that break its rule (one set-based read of the data access class;
    "! add the context - today, company codes - the read needs)
    METHODS evaluate
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

ENDCLASS.



CLASS zcl_cd_coll_c_refund IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    rs_result-findings = evaluate( ).
    rs_result-item_count = lines( rs_result-findings ).
  ENDMETHOD.


  METHOD evaluate.
    " Read the objects through the data access class of the process; one finding per object:
    " object key, check code, severity, company code, message of the consumer's message class.
    CLEAR rt_findings.
  ENDMETHOD.

ENDCLASS.
