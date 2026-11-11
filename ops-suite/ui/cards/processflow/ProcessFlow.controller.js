/*
 * Artifact: ui/cards/processflow/ProcessFlow.controller.js
 * Purpose:  Reads the aggregated stages of PaymentFlow (current business date, the user's company codes through the
 *           DCL) and builds the ProcessFlow lanes and nodes (docs/Process_Flow_Card.md section 3).
 *           VERIFY (V97): not run; OData V4 $apply on the card model and the ProcessFlow API of the landscape's UI5.
 * Modification log:
 * 2026-11-11 | Initial version.
 */
sap.ui.define([
  "sap/ovp/cards/custom/Card.controller",
  "sap/suite/ui/commons/ProcessFlowLaneHeader",
  "sap/suite/ui/commons/ProcessFlowNode",
  "sap/ui/model/json/JSONModel"
], function (CardController, LaneHeader, FlowNode, JSONModel) {
  "use strict";

  var STATE = { 3: "Positive", 2: "Critical", 1: "Negative", 0: "Neutral" };

  return CardController.extend("zcd.ops.cards.processflow.ProcessFlow", {
    onInit: function () {
      CardController.prototype.onInit.apply(this, arguments);
      this.getView().setModel(new JSONModel({ lanes: [], nodes: [] }), "flow");
      this._load();
    },

    _load: function () {
      var oModel = this.getCardPropertiesModel().getProperty("/model") || this.getView().getModel();
      var sApply = "filter(IsCurrentDay eq true)/groupby((Stage,StageLabel,StageSequence,StageSource,FlowCriticality)," +
        "aggregate(PaymentCount with sum as PaymentCount,StuckCount with sum as StuckCount,DropCount with sum as DropCount))";
      var oList = oModel.bindList("/PaymentFlow", null, null, null, { $apply: sApply, $orderby: "StageSequence" });
      oList.requestContexts(0, 50).then(function (aContexts) {
        this._build(aContexts.map(function (oContext) { return oContext.getObject(); }));
      }.bind(this));
    },

    _build: function (aStages) {
      var aLanes = [];
      var aNodes = [];
      aStages.forEach(function (oStage, iIndex) {
        var iLane = aLanes.indexOf(oStage.StageSource);
        if (iLane < 0) {
          aLanes.push(oStage.StageSource);
          iLane = aLanes.length - 1;
        }
        var oNext = aStages.slice(iIndex + 1).filter(function (oLater) {
          return oLater.StageSource === oStage.StageSource;
        })[0];
        aNodes.push({
          id: oStage.Stage,
          lane: String(iLane),
          title: oStage.StageLabel,
          state: STATE[oStage.FlowCriticality] || "Neutral",
          texts: [oStage.PaymentCount + " in stage", oStage.StuckCount + " stuck", oStage.DropCount + " dropped"],
          children: oNext ? [oNext.Stage] : []
        });
      });
      this.getView().getModel("flow").setData({
        lanes: aLanes.map(function (sSource, iLane) {
          return { id: String(iLane), text: sSource, position: iLane };
        }),
        nodes: aNodes
      });
    }
  });
});
