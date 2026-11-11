/*
 * Artifact: ui/tests/integration/PersonaJourney.js
 * Purpose:  OPA5 journeys of the three persona overview pages on ZUI_CD_PAYM (business ZCD_PAYM_BIZ, managers
 *           ZCD_PAYM_MGR, IT support ZCD_PAYM_IT) and the payment object page: cards by their chart titles, no
 *           technical code column on the business page, the drill-down list needs a business date, the payment
 *           object page shows its requests. Never run - the apps are generated in DV1 (ui/tests/README.md).
 * Modification log:
 * 2026-11-11 | Initial version (UI test pack).
 * 2026-11-11 | Build C: ledger facet and changes timeline of the payment object page.
 */
sap.ui.define([
  "sap/ui/test/opaQunit",
  "sap/fe/test/JourneyRunner",
  "sap/fe/test/ListReport",
  "sap/fe/test/ObjectPage",
  "zcd/ops/test/integration/pages/Overview"
], function (opaTest, JourneyRunner, ListReport, ObjectPage) {
  "use strict";

  QUnit.module("UI-03 Business users page");

  opaTest("Plain-language cards, amounts per currency", function (Given, When, Then) {
    Given.iStartMyUIComponent({ componentConfig: { name: "zcd.paym.biz" } });
    Then.onTheOverview.iSeeTheCard("Payments by source and payment status");
    Then.onTheOverview.iSeeTheCard("Payments by payment type and payment status");
    Then.onTheOverview.iSeeTheCard("Amount by source (per currency)");
    Then.onTheOverview.iSeeTheCard("Daily payments by source");
    Then.onTheOverview.iSeeNoColumn("Open finding");
    Then.iTeardownMyUIComponent();
  });

  QUnit.module("UI-04 Managers page");

  opaTest("Trend, on-time share and exceptions raised vs resolved", function (Given, When, Then) {
    Given.iStartMyUIComponent({ componentConfig: { name: "zcd.paym.mgr" } });
    Then.onTheOverview.iSeeTheCard("Payments per day vs same weekday last week");
    Then.onTheOverview.iSeeTheCard("On time and late by payment type");
    Then.onTheOverview.iSeeTheCard("Exceptions raised vs resolved per day");
    Then.iTeardownMyUIComponent();
  });

  QUnit.module("UI-05 IT support page");

  opaTest("Open payments and evidence gaps by method class", function (Given, When, Then) {
    Given.iStartMyUIComponent({ componentConfig: { name: "zcd.paym.it" } });
    Then.onTheOverview.iSeeTheCard("Open payments by method class and outcome");
    Then.onTheOverview.iSeeTheCard("Evidence gaps by method class and finding");
    Then.onTheOverview.iSeeTheCard("Failures per day and area");
    Then.iTeardownMyUIComponent();
  });

  QUnit.module("UI-06 Payment drill-down");

  var runner = new JourneyRunner({
    launchUrl: sap.ui.require.toUrl("zcd/paym/list") + "/index.html",
    pages: {
      onThePaymentList: new ListReport({ appId: "zcd.paym.list", componentId: "PaymentList", contextPath: "/Payment" }),
      onThePayment: new ObjectPage({ appId: "zcd.paym.list", componentId: "PaymentObjectPage", contextPath: "/Payment" })
    }
  });

  runner.run(function () {
    opaTest("The list needs a business date; the payment shows its requests", function (Given, When, Then) {
      Given.iStartMyApp();
      Then.onThePaymentList.onFilterBar().iCheckFilterField("Business date");
      When.onThePaymentList.onFilterBar().iChangeFilterField("Business date", "11/10/2026").and.iExecuteSearch();
      Then.onThePaymentList.onTable().iCheckRows();
      When.onThePaymentList.onTable().iPressRow(0);
      Then.onThePayment.iSeeThisPage();
      Then.onThePayment.onTable({ property: "_Requests" }).iCheckRows();
      Given.iTearDownMyApp();
    });

    // >>> build C - ledger facet and changes timeline of the payment (LDG-01, LDG-10)
    opaTest("The payment shows its ledger share and its changes", function (Given, When, Then) {
      Given.iStartMyApp();
      When.onThePaymentList.onFilterBar().iChangeFilterField("Business date", "11/10/2026").and.iExecuteSearch();
      When.onThePaymentList.onTable().iPressRow(0);
      Then.onThePayment.iSeeThisPage();
      Then.onThePayment.onTable({ property: "_Ledger" }).iCheckColumns(11);
      Then.onThePayment.onTable({ property: "_Changes" }).iCheckRows();
      Given.iTearDownMyApp();
    });
    // <<< build C
  });
});
