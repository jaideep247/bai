*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_fmonfile.clas.abap
*& Purpose:
*& Behaviour pool of ZR_CD_FmonFile (FMON manual status, design 6.4).
*& Handler and saver in the local implementations; the transition rule is
*& ZCL_CD_FMON_OPS_POLICY / ZCL_CD_FMON_STATUS, the event goes through
*& ZIF_CD_FMON_DAO~INSERT_EVENT.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Monitored files manual status - behaviour pool</p>
CLASS zbp_r_cd_fmonfile DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zr_cd_fmonfile.
ENDCLASS.



CLASS zbp_r_cd_fmonfile IMPLEMENTATION.
ENDCLASS.
