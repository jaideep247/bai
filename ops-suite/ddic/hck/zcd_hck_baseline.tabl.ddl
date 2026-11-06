@EndUserText.label : 'Health check: configuration baseline hashes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_hck_baseline {
  key mandt     : abap.clnt not null;
  key tabname   : abap.char(30) not null;
  // SHA-256 (hex) over all rows ordered by primary key
  hash          : abap.char(64);
  row_count     : abap.int4;
  taken_at      : timestampl;
  taken_by      : syuname;
  // Serialization version of HASH (audit A57): 2 = length-prefixed typed fields
  hash_version  : abap.char(2);
}
// Delivery class A: the golden baseline is per system (taken after each approved transport), never transported.
