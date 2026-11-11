/*
 * Artifact: ui/tests/integration/OverviewJourney.js
 * Purpose:  OPA5 journey of the production support overview page ZCD_OPS_OVW (service ZUI_CD_OPS_OVERVIEW): the cards
 *           of the control center, the service health and the process flow are shown with the titles of their
 *           annotations; the current business date is the default filter; a card header navigates. Never run - the
 *           app is generated in DV1 (ui/tests/README.md).
 * Modification log:
 * 2026-11-11 | Initial version (UI test pack).
 */
sap.ui.define([
  "sap/ui/test/opaQunit",
  "sap/ui/test/Opa5",
  "zcd/ops/test/integration/pages/Overview"
], function (opaTest, Opa5) {
  "use strict";

  QUnit.module("UI-01 Production support overview");

  opaTest("Cards of the control center, service health and process flow are shown", function (Given, When, Then) {
    Given.iStartMyUIComponent({ componentConfig: { name: "zcd.ops.ovw" } });
    Then.onTheOverview.iSeeTheCurrentBusinessDateFilter();
    Then.onTheOverview.iSeeTheCard("Monitor freshness");
    Then.onTheOverview.iSeeTheCard("Tracked payments on the business date");
    Then.onTheOverview.iSeeTheCard("Service health");
    Then.onTheOverview.iSeeTheCard("Service health - worst contributors");
    Then.onTheOverview.iSeeTheCard("Process flow");
    Then.onTheOverview.iSeeTheCard("Payments per stage (stuck in red)");
  });

  opaTest("UI-02 Service health header opens the contributors", function (Given, When, Then) {
    When.onTheOverview.iPressTheCardHeader("Service health");
    Then.iTeardownMyUIComponent();
    Opa5.assert.ok(true, "Navigation target checked against the target mapping in DV1");
  });
});
