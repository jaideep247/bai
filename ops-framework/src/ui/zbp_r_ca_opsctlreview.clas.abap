*&---------------------------------------------------------------------*
*& Artifact: zbp_r_ca_opsctlreview.clas.abap
*& Purpose:
*& Behaviour pool of ZR_CA_OpsCtlReview (daily control review). Handler
*& (authorisation, lock, action markReviewed) and saver are in the local
*& implementations; every decision is ZCL_CA_OPS_REVIEW_POLICY's, every
*& write ZIF_CA_OPS_REVIEW_DAO's.
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Daily control review - behaviour pool</p>
CLASS zbp_r_ca_opsctlreview DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zr_ca_opsctlreview.
ENDCLASS.



CLASS zbp_r_ca_opsctlreview IMPLEMENTATION.
ENDCLASS.
