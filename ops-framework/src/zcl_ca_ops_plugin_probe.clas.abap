*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_plugin_probe.clas.abap
*& Purpose:
*& Test support for ZCL_CA_OPS_FACTORY=>GET_PLUGIN (audit A62): a class that
*& implements no plug-in interface and counts its constructor calls, so a test can
*& prove that an unrelated class configured as a plug-in is refused before it is
*& instantiated. Not FOR TESTING so the factory can create it dynamically; it has
*& no other behavior and is never configured.
*& Modification log:
*& 2026-11-06 | Initial version (audit A62).
*& 2026-11-10 | Moved from ZCL_CD_OPS_PLUGIN_PROBE to the reusable framework ZCA_OPS (test support of the
*&            | plug-in creation of ZCL_CA_OPS_FACTORY).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - plug-in probe (test support)</p>
CLASS zcl_ca_ops_plugin_probe DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Number of instances created in this internal session
    CLASS-DATA gv_instances TYPE i READ-ONLY.

    METHODS constructor.

    "! Reset the counter (test setup)
    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_ca_ops_plugin_probe IMPLEMENTATION.

  METHOD constructor.
    gv_instances = gv_instances + 1.
  ENDMETHOD.


  METHOD reset.
    CLEAR gv_instances.
  ENDMETHOD.

ENDCLASS.
