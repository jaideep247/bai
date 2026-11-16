@EndUserText.label : 'Ops framework: platform validation of a process'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_catval {
  key mandt     : abap.clnt not null;
  // Catalogue milestones (2026-11-16, build O): evidence that the runnable check of a catalogue process ran on a
  // supported release - recorded by the install harness or an operator (report ZCA_OPS_CAT_VALIDATE), never seeded
  key process_id : abap.char(20) not null;
  key sys_id    : abap.char(8) not null;
  // Release and support package as recorded (e.g. S/4HANA 2023 FPS02), never derived
  release_txt   : abap.char(40);
  validated_on  : abap.dats;
  validated_by  : syuname;
  // H install harness, O operator
  source        : abap.char(1);
  evidence      : abap.char(255);
}
