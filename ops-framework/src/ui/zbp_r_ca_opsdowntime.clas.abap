*&---------------------------------------------------------------------*
*& Artifact: zbp_r_ca_opsdowntime.clas.abap
*& Purpose:
*& Behaviour pool of ZR_CA_OpsDowntime (downtime app, planned downtime
*& windows). Handlers are in the local implementations; every rule of a
*& window is decided by ZCL_CA_OPS_DOWNTIME_POLICY, authorisation by
*& ZCL_CA_OPS_AUTH (ZCA_OPS of the window's area).
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: planned downtime).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Planned downtime windows - behaviour pool</p>
CLASS zbp_r_ca_opsdowntime DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zr_ca_opsdowntime.
ENDCLASS.



CLASS zbp_r_ca_opsdowntime IMPLEMENTATION.
ENDCLASS.
