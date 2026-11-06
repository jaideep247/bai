@EndUserText.label : 'FMON: returns/NOC lot completeness (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_lotcfg {
  key mandt         : abap.clnt not null;
  // Interface, or '*' = default for every interface of the lot type
  key iface_id      : abap.char(20) not null;
  // RETURNS or NOC (equals ZCD_FMON_IFACE-FILE_TYPE of the inbound interface)
  key lot_type      : abap.char(10) not null;
  // Optional header table linking a lot to the file (e.g. DFKKNRK)
  hdr_table         : abap.char(30);
  hdr_lot_field     : abap.char(30);
  hdr_link_field    : abap.char(30);
  // Item table (e.g. DFKKNRP for NOC, DFKKRP for returns)
  item_table        : abap.char(30);
  item_lot_field    : abap.char(30);
  item_key_field    : abap.char(30);
  item_status_field : abap.char(30);
  // File link on the item table when no header table is used
  item_link_field   : abap.char(30);
  // N = link value is the file name, R = file reference
  link_by           : abap.char(1);
  // Comma list of item status values that count as processed; <BLANK> = initial
  done_values       : abap.char(255);
  // NACHA NOC limit in banking days; 0 = parameter FMON_NOC_SLA_DAYS (6)
  noc_sla_days      : abap.int4;
  active            : abap_boolean;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
