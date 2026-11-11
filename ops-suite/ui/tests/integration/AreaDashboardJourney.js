/*
 * Artifact: ui/tests/integration/AreaDashboardJourney.js
 * Purpose:  OPA5 journey (sap.fe.test, OData V4) of the framework's area dashboard (ZUI_CA_OPS_DASH, entity set
 *           CheckStatus): the list shows the registered checks and opens one. Never run (ui/tests/README.md).
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
    launchUrl: sap.ui.require.toUrl("zca/ops/dash") + "/index.html",
    pages: {
      onTheChecks: new ListReport({ appId: "zca.ops.dash", componentId: "CheckStatusList", contextPath: "/CheckStatus" }),
      onTheCheck: new ObjectPage({ appId: "zca.ops.dash", componentId: "CheckStatusObjectPage", contextPath: "/CheckStatus" })
    }
  });

  QUnit.module("UI-09 Area dashboard");

  runner.run(function () {
    opaTest("Registered checks are listed and open", function (Given, When, Then) {
      Given.iStartMyApp();
      When.onTheChecks.onFilterBar().iExecuteSearch();
      Then.onTheChecks.onTable().iCheckRows();
      When.onTheChecks.onTable().iPressRow(0);
      Then.onTheCheck.iSeeThisPage();
      Given.iTearDownMyApp();
    });
  });
});
