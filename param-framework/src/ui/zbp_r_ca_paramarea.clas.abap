*&---------------------------------------------------------------------*
*& Artifact: zbp_r_ca_paramarea.clas.abap
*& Purpose:
*& Behaviour pool of ZR_CA_ParamArea (areas, definitions, values). Handlers
*& and saver are in the local implementations; every decision is delegated
*& to ZCL_CA_PARAM_MAINT (policy, authorization, request, recording) and
*& ZCL_CA_PARAM_VALIDATOR (the same rules as at runtime).
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - behaviour pool</p>
CLASS zbp_r_ca_paramarea DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zr_ca_paramarea.
ENDCLASS.



CLASS zbp_r_ca_paramarea IMPLEMENTATION.
ENDCLASS.
