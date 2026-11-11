/*
 * Artifact: ui/cards/processflow/Component.js
 * Purpose:  Custom overview page card "Process flow": the stages of the payment lifecycle of the business date as a
 *           sap.suite.ui.commons.ProcessFlow (lane per counted source, node per stage, state from FlowCriticality)
 *           over the entity set PaymentFlow of ZUI_CD_OPS_OVERVIEW. Computes nothing: counts, stuck, drop and the
 *           criticality come from the CDS view ZC_CD_PayFlow. Read-only.
 *           VERIFY (V97): never run - the overview app manifest is not in the repository; the custom card API of
 *           the UI5 release of the landscape and the library sap.suite.ui.commons must be checked in DV1.
 * Modification log:
 * 2026-11-11 | Initial version (process flow card specification, docs/Process_Flow_Card.md).
 */
sap.ui.define([
  "sap/ovp/cards/custom/Component"
], function (CustomCard) {
  "use strict";

  return CustomCard.extend("zcd.ops.cards.processflow.Component", {
    metadata: {
      properties: {
        contentFragment: { type: "string", defaultValue: "zcd.ops.cards.processflow.ProcessFlow" },
        controllerName: { type: "string", defaultValue: "zcd.ops.cards.processflow.ProcessFlow" }
      },
      version: "0.1.0",
      library: "sap.ovp"
    }
  });
});
