@EndUserText.label : 'Example XX: transfer folder log'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zxx_pf_folder {
  key mandt     : abap.clnt not null;
  // A payment file the customer's transfer job wrote to its outbound folder and uploaded to the bank's server
  // (no middleware): one row per file and attempt
  key file_name : abap.char(70) not null;
  key attempt   : abap.int4 not null;
  run_date      : abap.dats;
  run_id        : abap.char(5);
  bukrs         : bukrs;
  // WRITTEN (in the folder), UPLOADED (on the bank's server), UPLOAD_ERR (the upload failed)
  status        : abap.char(12);
  changed_at    : timestampl;
}
