/*
 * Artifact: ui/tests/integration/pages/Overview.js
 * Purpose:  Page object of an overview page (OVP, OData V4): sap.fe.test has no OVP template, so plain OPA5
 *           matchers on sap.ovp cards - card found by its title (the @UI.chart / headerInfo titles of the CDS
 *           metadata extensions), the global filter field, the card header press. Used by the overview and persona
 *           journeys. Never run (apps generated in DV1).
 * Modification log:
 * 2026-11-11 | Initial version (UI test pack).
 */
sap.ui.define([
  "sap/ui/test/Opa5",
  "sap/ui/test/matchers/PropertyStrictEquals",
  "sap/ui/test/actions/Press"
], function (Opa5, PropertyStrictEquals, Press) {
  "use strict";

  function cardHeaderWith(sTitle) {
    return {
      controlType: "sap.m.Text",
      matchers: new PropertyStrictEquals({ name: "text", value: sTitle })
    };
  }

  Opa5.createPageObjects({
    onTheOverview: {
      actions: {
        iPressTheCardHeader: function (sTitle) {
          return this.waitFor(Object.assign(cardHeaderWith(sTitle), {
            actions: new Press(),
            errorMessage: "Card header '" + sTitle + "' not found"
          }));
        }
      },
      assertions: {
        iSeeTheCard: function (sTitle) {
          return this.waitFor(Object.assign(cardHeaderWith(sTitle), {
            success: function () {
              Opa5.assert.ok(true, "Card '" + sTitle + "' is shown");
            },
            errorMessage: "Card '" + sTitle + "' is not shown"
          }));
        },
        iSeeTheCurrentBusinessDateFilter: function () {
          return this.waitFor({
            controlType: "sap.ui.mdc.FilterField",
            matchers: new PropertyStrictEquals({ name: "label", value: "Current business date" }),
            success: function () {
              Opa5.assert.ok(true, "Global filter 'Current business date' present (default X)");
            },
            errorMessage: "Global filter 'Current business date' missing"
          });
        },
        iSeeNoColumn: function (sLabel) {
          return this.waitFor({
            controlType: "sap.m.Column",
            check: function (aColumns) {
              return !aColumns.some(function (oColumn) {
                return oColumn.getHeader && oColumn.getHeader() && oColumn.getHeader().getText() === sLabel;
              });
            },
            success: function () {
              Opa5.assert.ok(true, "No column '" + sLabel + "' on the page");
            },
            errorMessage: "Column '" + sLabel + "' is shown"
          });
        }
      }
    }
  });
});
