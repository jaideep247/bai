@EndUserText.label : 'BAI Validation Checkpoint'
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY_ONLY
define table zbai_checkpoint {
  key client        : mandt not null;
  key batch_id      : sysuuid_x16 not null;
  key chunk_number  : int4 not null;
  
  @Semantics.calendar.date
  execution_date    : datum not null;
  
  status            : char1 default 'P';
  
  records_processed : int4 default 0;
  records_passed    : int4 default 0;
  records_failed    : int4 default 0;
  
  duration_ms       : int8 default 0;
  
  @AbapCatalog.dataType : #STRING
  @AbapCatalog.fieldLength : 500
  error_message     : abap.string(500);
  
  @Semantics.user.createdBy
  created_by        : syuname;
  
  @Semantics.systemDateTime.createdAt
  created_at        : timestampl;
  
  @Semantics.user.lastChangedBy
  changed_by        : syuname;
  
  @Semantics.systemDateTime.lastChangedAt
  changed_at        : timestampl;
}
