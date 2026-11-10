// Artifact: zi_cd_ebsfinding.ddls.asddls
// Purpose: Basic view of EBS findings (ZCA_OPS_FINDING, area EBS) for the EBS validation dashboard:
//          every open / assigned finding, plus every finding created in the last 31 days (bounded
//          read). Keys as ZCL_CD_EBS_FINDING writes them: statement OBJECT_KEY = FEB<KUKEY> (FEB
//          source) or S0001.. (bank file, not imported); line OBJECT_KEY = <statement key>/<ESNUM
//          without leading zeros>; line GROUP1 = <scheme>:<BAI / ISO code>, GROUP2 = category;
//          statement GROUP1 = bank account number (never shown: masked to the last 4 characters),
//          GROUP2 = bank key. Statement and file findings of the file source can carry the account
//          number in the message - their message is not exposed (owned-exceptions app).
//          Classification from the rule registry: ZCD_EBS_RULE_DEF-FINDING_CLASS DUPLICATE (seed S07,
//          R09, R22) / POSTING (seed S13) - a new duplicate rule costs configuration only; check code
//          POSTING_INCOMPLETE counts as posting incomplete as before (config/zcd_ebs_rule_def.csv).
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
//                   2026-11-07 | IsDuplicate / IsPostingIncomplete from ZCD_EBS_RULE_DEF-FINDING_CLASS
//                              | (association) instead of rule literals.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation finding (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsFinding
  as select from zca_ops_finding
  // VERIFY-ADT: path to a 0..1 association in the element list (left outer join) on 7.58
  association [0..1] to zcd_ebs_rule_def as _RuleDef on $projection.RuleId = _RuleDef.rule_id
{
  key run_id                                                as RunId,
  key finding_no                                            as FindingNo,
      cast( 'CD_EBS' as abap.char( 16 ) )                       as PaymentEngineArea,
      object_type                                           as ObjectType,
      object_key                                            as ObjectKey,
      // FEB = imported statement (FEBKO / FEBEP), FILE = bank file validated before import
      cast( case when left( object_key, 3 ) = 'FEB' then 'FEB' else 'FILE' end as abap.char( 4 ) ) as StatementSource,
      // Statement key FEB<KUKEY> (11 characters) of a statement or line finding of the FEB source
      cast( case when ( object_type = 'STMT' or object_type = 'LINE' ) and left( object_key, 3 ) = 'FEB'
                 then left( object_key, 11 ) else ' ' end as abap.char( 11 ) ) as StmtObjectKey,
      cast( case when object_type = 'LINE' then object_key else ' ' end as abap.char( 70 ) ) as LineObjectKey,
      cast( case when object_type = 'LINE' and left( object_key, 3 ) = 'FEB'
                 then substring( object_key, 13, 5 ) else ' ' end as abap.char( 5 ) ) as LineNo,
      cast( case when object_type = 'LINE' then group1 else ' ' end as abap.char( 35 ) ) as BaiCode,
      cast( case when object_type = 'LINE' then group2 else ' ' end as abap.char( 35 ) ) as Category,
      cast( case when object_type = 'STMT' then group2 else ' ' end as abap.char( 35 ) ) as BankKey,
      // Bank account number masked: '****' + last 4 characters (VERIFY-ADT: RIGHT on RTRIM of CHAR)
      cast( case when object_type = 'STMT' and group1 <> ' '
                 then concat( '****', right( rtrim( group1, ' ' ), 4 ) )
                 else ' ' end as abap.char( 8 ) )           as AccountMasked,
      rule_id                                               as RuleId,
      check_code                                            as CheckCode,
      severity                                              as Severity,
      // Severity as a rank: 4 B (block), 3 E, 2 W, 1 I
      cast( case severity when 'B' then 4
                          when 'E' then 3
                          when 'W' then 2
                          when 'I' then 1
                          else 0 end as abap.int1 )         as SeverityRank,
      // UI criticality: 1 red (B, E), 2 yellow (W), 0 neutral (I)
      cast( case severity when 'B' then 1
                          when 'E' then 1
                          when 'W' then 2
                          else 0 end as abap.int1 )         as SeverityCriticality,
      action                                                as FindingAction,
      amount                                                as Amount,
      currency                                              as Currency,
      reference                                             as Reference,
      cast( case when ( object_type = 'STMT' or object_type = 'FILE' ) and left( object_key, 3 ) <> 'FEB'
                 then ' ' else message end as abap.char( 255 ) ) as FindingMessage,
      disposition                                           as Disposition,
      // Open = O open or A assigned (not I information, R resolved, W waived, S superseded)
      case when disposition = 'O' or disposition = 'A'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsOpen,
      case when _RuleDef.finding_class = 'POSTING' or check_code = 'POSTING_INCOMPLETE'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsPostingIncomplete,
      case when _RuleDef.finding_class = 'DUPLICATE'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsDuplicate,
      owner                                                 as Owner,
      due_date                                              as DueDate,
      first_seen_at                                         as FirstSeenAt,
      occurrences                                           as Occurrences,
      created_at                                            as CreatedAt,
      tstmp_to_dats( cast( created_at as timestamp ), 'UTC', $session.client, 'NULL' ) as CreatedDate
}
where area = 'CD_EBS'
  and ( disposition = 'O' or disposition = 'A'
     or tstmp_to_dats( cast( created_at as timestamp ), 'UTC', $session.client, 'NULL' )
        >= dats_add_days( $session.system_date, -31, 'INITIAL' ) )
