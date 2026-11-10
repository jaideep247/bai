*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cfg_transport.intf.abap
*& Purpose:
*& Records the changed customizing rows of one RAP save on a customizing
*& request. Called from save_modified of the configuration apps only
*& where the client records changes (DV1).
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: transport recording</p>
INTERFACE zif_ca_ops_cfg_transport
  PUBLIC.

  "! ir_create / ir_update / ir_delete: REF #( create ) etc. of the RAP saver
  METHODS record
    IMPORTING
      iv_request   TYPE zif_ca_ops_cfg_types=>ty_request
      it_relations TYPE zif_ca_ops_cfg_types=>tt_relation
      ir_create    TYPE REF TO data OPTIONAL
      ir_update    TYPE REF TO data OPTIONAL
      ir_delete    TYPE REF TO data OPTIONAL
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
