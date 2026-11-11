/*
 * Artifact: ui/tests/integration/TransactionsJourney.js
 * Purpose:  OPA5 journey (sap.fe.test, OData V4) of the transactions dashboard (ZUI_CD_TRX_DASH, entity set
 *           Transaction): the worklist filters by date and a problem row opens. Never run (ui/tests/README.md).
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
    launchUrl: sap.ui.require.toUrl("zcd/trx/dash") + "/index.html",
    pages: {
      onTheTransactions: new ListReport({ appId: "zcd.trx.dash", componentId: "TransactionList", contextPath: "/Transaction" }),
      onTheTransaction: new ObjectPage({ appId: "zcd.trx.dash", componentId: "TransactionObjectPage", contextPath: "/Transaction" })
    }
  });

  QUnit.module("UI-10 Transactions dashboard");

  runner.run(function () {
    opaTest("Worklist rows of the day open", function (Given, When, Then) {
      Given.iStartMyApp();
      When.onTheTransactions.onFilterBar().iExecuteSearch();
      Then.onTheTransactions.onTable().iCheckRows();
      When.onTheTransactions.onTable().iPressRow(0);
      Then.onTheTransaction.iSeeThisPage();
      Given.iTearDownMyApp();
    });
  });
});
