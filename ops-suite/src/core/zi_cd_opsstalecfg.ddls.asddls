// Artifact: zi_cd_opsstalecfg.ddls.asddls
// Purpose: Stale threshold (minutes) per payment engine area for the "as of" views of the dashboards
//          (ZR_CD_FmonAsOf, ZR_CD_EbsAsOf, ZR_CD_HckAsOf): the ZCA_PARAM parameters
//          MON_STALE_AFTER_MIN_<area> of area CD_OPS (table consolidation 2026-11-08, was ZCD_OPS_MONCFG)
//          - the maintained value (ZCA_PARAM_VAL, row 1 of a kind-P parameter), else the definition
//          default (ZCA_PARAM_DEF); one row per defined area. CDS cannot call the parameter API
//          (ZIF_CD_OPS_PARAMS), so this view reads the framework's own tables directly, read-only, with
//          the API's resolution (value, else definition default); the HCK self-check reads the same
//          parameters through the API, so dashboards and self-check agree. The area code and the
//          parameter-name prefix are literals compared with ZIF_CD_OPS_TYPES (portable check
//          cds_abap_parity). No row (definition not transported) = the as-of view's delivered literal.
// Modification log: 2026-11-08 | Initial version (table consolidation: ZCD_OPS_MONCFG into ZCA_PARAM).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitor stale threshold per area (ZCA_PARAM)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CD_OpsStaleCfg
  as select from    zca_param_def as Def
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
{
      // MON_STALE_AFTER_MIN_FMON -> FMON
  key cast( replace( Def.name, 'MON_STALE_AFTER_MIN_', '' ) as abap.char( 4 ) ) as PaymentEngineArea,
      // The framework validates the value type INT (MIN 1) on save, so the text is a number.
      // VERIFY-ADT: CHAR -> INT4 cast of a parameter value (CDS view entity, 7.58)
      cast( case when Val.low is null or Val.low = ''
                 then Def.default_value
                 else Val.low end as abap.int4 )                                  as StaleAfterMinutes
}
where Def.area = 'CD_OPS'
  and Def.name like 'MON_STALE_AFTER_MIN_%'
