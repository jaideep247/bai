#!/bin/bash

# Create individual table DDL files from the source

# Table 1: ZBAI_LOCK
cat > zbai_lock.tabl.ddl << 'EOF'
@EndUserText.label : 'BAI Validation Lock Table'
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zbai_lock {
  key client      : mandt not null;
  key lock_key    : char50 not null;
  description     : char100;
  created_by      : syuname;
  created_at      : timestampl;
}
EOF

# Table 2: ZBAI_CONFIG
cat > zbai_config.tabl.ddl << 'EOF'
@EndUserText.label : 'BAI System Configuration'
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zbai_config {
  key client      : mandt not null;
  key param_name  : char30 not null;
  
  @AbapCatalog.dataType : #STRING
  @AbapCatalog.fieldLength : 255
  param_value     : abap.string(255);
  
  description     : char100;
  data_type       : char10;
  
  @Semantics.user.lastChangedBy
  changed_by      : syuname;
  
  @Semantics.systemDateTime.lastChangedAt
  changed_at      : timestampl;
}
EOF

# Table 3: ZBAI_CHECKPOINT
cat > zbai_checkpoint.tabl.ddl << 'EOF'
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
EOF

echo "✅ Created 3 table DDL files"
