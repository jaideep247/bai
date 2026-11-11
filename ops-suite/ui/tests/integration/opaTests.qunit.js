/*
 * Artifact: ui/tests/integration/opaTests.qunit.js
 * Purpose:  OPA5 runner of the UI test pack (ui/tests/README.md): loads the journeys of the generated apps. Never run
 *           (the apps are generated in DV1); set APPS to the generated app IDs before the first run.
 * Modification log:
 * 2026-11-11 | Initial version (UI test pack).
 */
/* global QUnit */
QUnit.config.autostart = false;

sap.ui.require([
  "zcd/ops/test/integration/OverviewJourney",
  "zcd/ops/test/integration/PersonaJourney",
  "zcd/ops/test/integration/ControlReviewJourney",
  "zcd/ops/test/integration/ExceptionJourney",
  "zcd/ops/test/integration/AreaDashboardJourney",
  "zcd/ops/test/integration/TransactionsJourney"
], function () {
  "use strict";
  QUnit.start();
});
