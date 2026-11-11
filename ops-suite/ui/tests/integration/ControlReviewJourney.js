/*
 * Artifact: ui/tests/integration/ControlReviewJourney.js
 * Purpose:  OPA5 journey (sap.fe.test, OData V4) of the daily control review (ZUI_CA_OPS_REV, entity set
 *           ControlReview, action markReviewed): "Mark reviewed" with result Action required and no observation /
 *           next action is refused with message 076 of class ZCA_OPS; with both it is saved. Meaningful only against
 *           DV1 / QA1 (the validation is the behaviour pool's). Never run (ui/tests/README.md).
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
    launchUrl: sap.ui.require.toUrl("zca/ops/review") + "/index.html",
    pages: {
      onTheReviewList: new ListReport({ appId: "zca.ops.review", componentId: "ControlReviewList", contextPath: "/ControlReview" }),
      onTheReview: new ObjectPage({ appId: "zca.ops.review", componentId: "ControlReviewObjectPage", contextPath: "/ControlReview" })
    }
  });

  QUnit.module("UI-07 Daily control review - Mark reviewed");

  runner.run(function () {
    opaTest("Action required needs an observation and a next action", function (Given, When, Then) {
      Given.iStartMyApp();
      When.onTheReviewList.onFilterBar().iExecuteSearch();
      When.onTheReviewList.onTable().iPressRow(0);
      When.onTheReview.onHeader().iExecuteAction("Mark reviewed");
      When.onTheReview.onActionDialog().iChangeDialogField({ property: "ReviewResult" }, "Action required");
      When.onTheReview.onActionDialog().iConfirm();
      Then.onTheReview.onMessageDialog().iCheckMessage({ text: "Action required: enter the observation and the next action" });
      When.onTheReview.onMessageDialog().iConfirm();
      When.onTheReview.onHeader().iExecuteAction("Mark reviewed");
      When.onTheReview.onActionDialog().iChangeDialogField({ property: "ReviewResult" }, "Action required");
      When.onTheReview.onActionDialog().iChangeDialogField({ property: "Observation" }, "File of JPMC late by 40 minutes");
      When.onTheReview.onActionDialog().iChangeDialogField({ property: "NextAction" }, "Payments team confirms with PRISM");
      When.onTheReview.onActionDialog().iConfirm();
      Then.onTheReview.iSeeThisPage();
      Given.iTearDownMyApp();
    });
  });
});
