/*
 * Artifact: ui/tests/integration/ExceptionJourney.js
 * Purpose:  OPA5 journey (sap.fe.test, OData V4) of the owned-exceptions app (ZUI_CA_OPS_EXC, entity set Exception,
 *           action classifyException): an open reconciliation break is classified TIMING and shows the reason code.
 *           Never run (ui/tests/README.md).
 * Modification log:
 * 2026-11-11 | Initial version (UI test pack).
 */
sap.ui.define([
  "sap/ui/test/opaQunit",
  "sap/fe/test/JourneyRunner",
  "sap/fe/test/ListReport",
  "sap/fe/test/ObjectPage"
], function (opaTest, JourneyRunner, ListReport, ObjectPage) {
  "use strict";

  var runner = new JourneyRunner({
    launchUrl: sap.ui.require.toUrl("zca/ops/exception") + "/index.html",
    pages: {
      onTheExceptionList: new ListReport({ appId: "zca.ops.exception", componentId: "ExceptionList", contextPath: "/Exception" }),
      onTheException: new ObjectPage({ appId: "zca.ops.exception", componentId: "ExceptionObjectPage", contextPath: "/Exception" })
    }
  });

  QUnit.module("UI-08 Exceptions - Classify");

  runner.run(function () {
    opaTest("Classify a reconciliation break as timing", function (Given, When, Then) {
      Given.iStartMyApp();
      When.onTheExceptionList.onFilterBar().iChangeFilterField("Area", "CD_HCK").and.iExecuteSearch();
      When.onTheExceptionList.onTable().iPressRow(0);
      When.onTheException.onHeader().iExecuteAction("Classify");
      When.onTheException.onActionDialog().iChangeDialogField({ property: "ReasonCode" }, "TIMING");
      When.onTheException.onActionDialog().iConfirm();
      Then.onTheException.onHeader().iCheckFieldInFieldGroup({ fieldGroup: "Status", field: "ReasonCode" }, "TIMING");
      Given.iTearDownMyApp();
    });
  });
});
