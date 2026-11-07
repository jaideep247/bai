# Message class ZCD_OPS

Number ranges: 001–099 and 700–799 core · 100–199 and 500–599 EBS · 200–299 and 600–649 FMON · 300–399 and 650–699 HCK · 400–449 configuration apps (RAP).
Every user-facing text of the suite is one of these messages (built with `ZCL_CD_OPS_UTIL=>TEXT( )`) or a text symbol (`docs/text_elements/`); numbers are referenced through the `gc_msg-*` constants of each area's types interface.
Create in SE91 exactly as listed (short texts ≤ 73 characters).

| No. | Text |
|---|---|
| 000 | &1 &2 &3 &4 |
| 001 | Run ID could not be generated |
| 002 | [&1] run &2 ended &3 / RAG &4 |
| 003 | [&1][&2] &3 finding(s) - rule &4 |
| 004 | Run &1 status &2, RAG &3, items &4, |
| 005 | failed &1, blocked &2. |
| 006 | &1 more finding(s) in ZCD_OPS_FINDING. |
| 007 | Channel &1 not configured or inactive in ZCD_OPS_ALCHN |
| 008 | Passed on re-run &1 |
| 010 | Insert into table &1 failed |
| 011 | Update of table &1 failed |
| 012 | Read of table &1 failed |
| 020 | Alert for route &1 could not be sent |
| 021 | Alert rule &1 has no recipient |
| 022 | Application log &1/&2 could not be written |
| 025 | Application log &1/&2 written only in part (&3 of &4 lines) |
| 026 | E-mail for &1 was not accepted by SAPconnect (BCS send result) |
| 027 | Alert route &1: &2 is not a shared SO23 distribution list |
| 030 | Class &1 does not exist |
| 031 | Class &1 cannot be instantiated as a plug-in |
| 032 | Class &1 does not implement interface &2 |
| 033 | Plug-in interface &1 does not exist |
| 040 | Run for &1 &2 is already active (lock held by &3) |
| 041 | No authorization for &1 activity &2 |
| 042 | Lock service failed for &1 &2 (run not started) |
| 050 | Configuration missing: &1 &2 |
| 051 | Configuration value &1 for &2 is invalid |
| 060 | Purge &1: &2 row(s) older than &3 (&4) |
| 061 | Exception is closed (disposition &1): no further action possible |
| 062 | A reason is required |
| 063 | Four-eyes: &1 requested this and cannot approve it |
| 064 | No waiver request is pending for this exception |
| 065 | Waiver end date &1 is in the past |
| 066 | An owner (user) is required |
| 067 | A waiver request by &1 is already pending |
| 100 | Code &1 &2 bank &3 flow &4 not in ZCD_BTC_MAP: blocked, never suspense |
| 101 | Category &1 is configured never to post |
| 102 | Run stopped: &1 consecutive packages above &2 % failures |
| 104 | Rule &1 (&2) failed: |
| 105 | File &1 is empty: expected BAI2 records, found none |
| 106 | Type code &1 in line &2 is non-monetary information; no line created |
| 107 | Type code '&1' in line &2 is not a detail code; expected 100-699 |
| 108 | Account &1: expected account trailer 49, found none before line &2 |
| 109 | Account &1: statement without detail entries (16) |
| 110 | File &1: expected file trailer 99 as last record, found none |
| 111 | File &1: expected at least one account record 03, found none |
| 112 | &1: expected &2, found &3 (records) |
| 113 | &1: expected &2, found &3 |
| 114 | Line &1: expected amount of digits with optional sign, found '&2'; 0 used |
| 115 | Line &1: expected date YYMMDD, found '&2' |
| 116 | Line &1: expected time HHMM, found '&2' |
| 117 | File &1 is empty: expected camt.053/054 XML, found no content |
| 118 | File &1: expected at least one Stmt/Ntfctn, found none |
| 119 | Statement &1: expected entries (Ntry), found none |
| 120 | &1: expected &2, found &3 (entries) |
| 121 | &1: expected &2, found &3 entries |
| 122 | Element &1: expected decimal amount, found '&2'; 0 used |
| 123 | Element &1: expected date YYYY-MM-DD, found '&2' |
| 124 | &1 expects &2, bank sent &3 |
| 125 | Amount &1 below minimum &2 |
| 126 | Amount &1 above maximum &2 |
| 127 | Entry in &1, statement in &2 |
| 128 | Required reference &1 missing for &2 |
| 129 | Reference &1 is not alphanumeric |
| 130 | Return/NOC reason missing for &1 |
| 131 | Reason &1 not mapped to an payment engine return reason |
| 132 | Reason &1 is not R01-R85 or C01-C07 |
| 133 | No payment run entry (DPAYH) for document &1 |
| 134 | Payment &1 status &2, expected &3 |
| 135 | Check &1: statement has no house bank, check exists in several accounts |
| 136 | Check &1 not in the check register |
| 137 | Check &1 has register status &2 |
| 138 | No ACH retrieval log for document &1 |
| 139 | Retrieval &1 status &2, expected &3 |
| 140 | Payment &1 is in no returns lot |
| 141 | Returns lot(s) of &1 have status &2, expected &3 |
| 142 | Check &1: bank &2, register &3 |
| 143 | Duplicate of an earlier entry with reference &1 |
| 144 | Value date &1 more than &2 days from booking date &3 |
| 145 | Group &1: statement has no house bank, totals not comparable |
| 146 | Group &1: bank total &2, register &3 |
| 147 | Group &1: &2 bank entries, &3 in register |
| 148 | No posting rule in ZCD_BTC_MAP for &1 |
| 149 | Posted with &1, map prescribes &2 |
| 150 | Content is not a BAI2 file: first record &1 (expected type 01) |
| 151 | XML content could not be parsed: &1 |
| 152 | Unsupported XML message &1/&2; expected camt.053 or camt.054 |
| 153 | Account &1: no G/L account in ZCD_EBS_ACCT, closing not reconciled |
| 154 | G/L &1 balance &2 <> closing &3 |
| 155 | Entry &1 &2 has no FI document |
| 156 | FI document &1 &2 &3 not found |
| 157 | FI document &1 &2 is not cleared |
| 158 | Account &1 trailer 49 |
| 159 | Opening &1 <> prior closing &2 |
| 162 | Opening &1 + &2 - &3 <> closing &4 |
| 163 | Declared totals do not balance: difference &1 |
| 164 | Statement &1 follows &2: &3 missing |
| 165 | Statement &1 not after last imported &2 |
| 166 | Account &1 not active in ZCD_EBS_ACCT |
| 167 | Statement in &1, account in &2 |
| 168 | Statement dated &1 is in the future |
| 169 | Statement dated &1 is older than &2 days |
| 170 | Statement &1 of &2 appears twice |
| 171 | Statement &1 of &2 already imported |
| 172 | &1 of &2 entries have an unmapped transaction code |
| 173 | &1 entries neither posted nor blocked (total &2) |
| 174 | Header declares &1 entries, &2 read |
| 175 | &1 entries: &2 passed, &3 failed, |
| 176 | &1 blocked, &2 warnings |
| 177 | Unknown record &1 in line &2 ignored (valid: 01 02 03 16 49 88 98 99) |
| 178 | Group &1 (originator &2): no group trailer 98 before line &3 |
| 180 | &1 control total |
| 181 | &1 number of records |
| 182 | Group &1 trailer 98 |
| 183 | &1 number of accounts |
| 184 | File trailer 99 control total |
| 185 | File trailer 99 number of groups |
| 186 | File trailer 99 number of records |
| 187 | Account &1 |
| 188 | &1 total credits (100) |
| 189 | &1 total debits (400) |
| 190 | &1 credit item count (100) |
| 191 | &1 debit item count (400) |
| 192 | Statement &1 TxsSummry |
| 193 | &1 TtlNtries/NbOfNtries |
| 194 | &1 TtlNtries/Sum |
| 195 | &1 TtlNtries/TtlNetNtry (signed) |
| 196 | &1 TtlCdtNtries |
| 197 | &1 TtlDbtNtries |
| 198 | &1/NbOfNtries |
| 199 | &1/Sum |
| 200 | Table &1 not found in the DDIC or not a flat DDIC structure |
| 201 | Field &1 does not exist in table &2 |
| 202 | &1 is not a valid DDIC name |
| 203 | Field &1 of table &2 has type &3, expected &4 |
| 204 | Source &1: no field configured for &2 |
| 205 | Read of table &1 failed: &2 |
| 206 | Factory calendar &1: date &2 cannot be converted |
| 207 | &1: &2 record(s) sent, &3 ACK + &4 NACK |
| 208 | Lot configuration &1 &2: field &3 missing |
| 209 | Read of table &1 has no date or key restriction |
| 210 | &1: control total &2, acknowledged &3 |
| 211 | File ID could not be generated |
| 212 | &1: reported &2 times by the source |
| 213 | &1: same name/checksum as &2 of &3 |
| 214 | &1: first event after the window end |
| 215 | &1: window closed, &2 of &3 file(s) received |
| 216 | &1: loaded, but no &2 lot found |
| 217 | &1: &2 of &3 expected file(s) received (&4) |
| 218 | &1: &2 file(s) on a &3 day that expects none |
| 219 | &1: &2 NOC entr(ies) open after &3 banking day(s) (NACHA limit &4) |
| 220 | File monitoring &1: &2 file(s), &3 finding(s), RAG &4 |
| 221 | &1: rejected by the bank (&2 record(s) NACK) |
| 222 | &1: processing FAILED |
| 223 | &1: &2 bytes (min &3, max &4) |
| 224 | &1: &2 after &3 min (SLA &4 min) |
| 225 | Source &1 (&2): |
| 227 | Source &1: no interface matches file &2 |
| 228 | Source &1: status '&2' has no &3 stage in ZCD_FMON_SRCMAP |
| 229 | Lot reader &1 (&2): |
| 230 | Stage &1 cannot be set by hand on file &2 (current stage &3) |
| 232 | PRISM request, handling reference and reason are required |
| 233 | Factory calendar &1 (NORMAL day used): |
| 234 | Check &1 (&2): |
| 235 | Registry not saved: |
| 236 | &1: &2 file(s), &3 finding(s) |
| 237 | Alert dispatch failed: |
| 238 | &1: &2 of &3 &4 transaction(s) unprocessed |
| 239 | &1 source row(s), status &2 |
| 240 | &1: newer registry state written by another process - not overwritten |
| 241 | &1: lot item scan stopped at &2 row(s) - completion not proven |
| 242 | Reference &1 of &2 matches files of several business dates - not applied |
| 243 | Source &1: &2 row(s) skipped, field &3 malformed |
| 244 | Table &1 is not approved for file monitoring (ZCD_FMON_TABWL) |
| 245 | No display authorization for table &1 (S_TABU_NAM) |
| 246 | Database error in file monitoring, registry not saved: |
| 247 | &1 of &2 &3 item(s) open |
| 248 | Factory calendar &1: banking-day age unknown, no aging verdict: |
| 249 | Field &1 of table &2 is not approved for file monitoring (ZCD_FMON_TABWL) |
| 250 | Field &1 is required |
| 251 | Field &1 has an invalid value |
| 252 | Field &1 is longer than &2 characters |
| 253 | Field &1 is sent more than once |
| 254 | Field &1 must be a string, number or boolean |
| 255 | Body is not valid JSON: |
| 256 | Body must be one JSON object |
| 257 | Method &1 is not allowed - use POST |
| 258 | Content type &1 is not supported - use application/json |
| 259 | Body of &1 bytes exceeds the limit of &2 bytes |
| 260 | No authorization to record PRISM events (ZCD_OPS &1 &2) |
| 261 | Event &1 is already recorded with a different payload |
| 262 | Event &1 could not be stored - retry later |
| 263 | Field &1 lies more than &2 minutes in the future |
| 264 | Field &1 requires field &2 |
| 265 | &1: PRISM could not process or deliver the file (direction &2) |
| 266 | &1: reported by PRISM, but SAP has no generation record of it |
| 267 | &1: delivered by PRISM &2 min ago, not yet received in SAP |
| 268 | Event &1: instant processing could not be queued (bgPF) |
| 269 | &1: PRISM queue of &2 file(s) exceeds the maximum of &3 - check PRISM |
| 270 | &1: &2 after &3 min (SLA &4 min incl. PRISM queue allowance) |
| 271 | Interface &1: file name pattern &2 is not valid PCRE - not used |
| 302 | Table &1 is not on the health check whitelist ZCD_HCK_TABWL |
| 303 | Table &1 does not exist in the ABAP Dictionary |
| 304 | Field &1 does not exist in table &2 |
| 305 | Operator &1 for field &2 is not supported (EQ NE GT LT GE LE IN) |
| 306 | Value &1 is not a valid number for field &2 |
| 307 | Aggregate &1 of check &2: date mode &3 is invalid (AGE, DAY, blank) |
| 308 | Aggregate on table &1 (&2) failed in the database |
| 309 | Date field &1 of table &2 is not of type DATS |
| 310 | Check &1 has no aggregate definition in ZCD_HCK_AGG |
| 311 | Hash of table &1 could not be calculated |
| 313 | Lock table could not be read (ENQUEUE_READ return code &1) |
| 314 | Configuration baseline taken for &1 tables &2 |
| 315 | Morning report exported to &1 |
| 316 | Export file &1 could not be opened for writing |
| 317 | Aggregate function &1 of check &2 is not supported (COUNT, SUM) |
| 318 | SUM field &1 of table &2 is not numeric |
| 319 | Cheque &1: status &2 -> &3 is not allowed |
| 320 | Suppression period is invalid (from &1 to &2) |
| 321 | Suppression is not waiting for approval (status &1) |
| 322 | A check ID is required for a suppression |
| 323 | Value query on table &1 has no date restriction (DATE parameter) |
| 324 | Table &1 has no configuration baseline yet |
| 325 | Reconciliation key &1 has totals records but no GL document (&2 - &3) |
| 326 | Payment request &1 is CANCELLED but its open item is cleared (paid) |
| 327 | Payment request &1 failed without SPE row: the source is never told |
| 328 | Job &1 cancelled (started &2 &3) |
| 329 | Job &1 active for &2 min (limit &3) |
| 330 | Job &1 planned &2 &3 has not started |
| 331 | Cycle &1 step &2 (&3): &4 |
| 332 | after &1 min (max &2) |
| 333 | in &1 min (max &2) |
| 334 | blocked by predecessor &1 |
| 335 | Check &1 ran &2 ms, timeout &3 s |
| 336 | Health score &1/100, &2 red, &3 amber |
| 337 | Suppressed until &1 by &2: |
| 338 | Table &1 changed since baseline of &2 by &3 (rows &4) |
| 339 | Report date &1, generated by &2 |
| 340 | &1 red (critical), &2 amber (high), &3 baseline warm-up |
| 341 | Payment engine morning report &1: &2, score &3/100, |
| 342 | &1 red / &2 amber |
| 343 | &1 > &2 STALE |
| 344 | Check &1: PARAM1 (application log objects) is not maintained |
| 345 | Check &1: PARAM1 (job name patterns) is not maintained |
| 347 | No active job cycle configured |
| 348 | OK - &1 metric(s) within limits |
| 349 | (+&1 more) |
| 350 | Health of the health check (EBS, FMON, HCK ran) |
| 351 | Payment engine area &1 has never run |
| 352 | Payment engine area &1 last ran &2 h ago (max &3 h) |
| 353 | Enter the report date (P_DATE) for 'Other date' |
| 354 | Enter the export file path (P_FILE) |
| 355 | Test mode never sends the report e-mail (P_MAIL ignored) |
| 356 | Payment engine morning report &1 |
| 357 | (&1 red, &2 amber of &3) |
| 358 | Payment engine area &1 |
| 359 | last run &1, &2 h ago, &3 errors |
| 360 | Payment engine area &1: &2 run(s) still running after &3 min |
| 361 | No business check selected or active - the report proves nothing |
| 362 | Health check configuration (selected and active checks) |
| 363 | retried: &1 attempt(s), completed attempt started &2 |
| 364 | completed attempt started &1, after window end &2 |
| 365 | Job read capped at &1 rows for &2 - result may be incomplete |
| 366 | &1 reconciliation key(s) / company code(s) without GL document, &2 listed |
| 367 | Baseline of &1 uses hash version &2 (current &3): take a new baseline |
| 368 | Export file &1 could not be written completely - no partial file kept |
| 369 | Check &1 stopped after &2 of &3 item(s): time budget of &4 s used |
| 370 | &1 &2: baseline warm-up, &3 of &4 history run(s) - no verdict yet |
| 371 | Job step &1/&2: job name pattern &3 is not valid PCRE - not evaluated |
| 372 | Suppression for &1: key pattern &2 is not valid PCRE - not applied |
| 373 | Check &1: pattern &2 in the parameters is not valid PCRE |
| 402 | Enter a customizing request: changes in this client are recorded |
| 403 | Transport request &1 does not exist |
| 404 | &1 is not a customizing request or customizing task |
| 405 | Transport request &1 is released or no longer modifiable |
| 407 | No authorization for &1 of &2 configuration (object ZCD_OPS) |
| 408 | Changes could not be recorded on transport request &1 |
| 410 | Class &1 does not exist or does not implement &2 |
| 411 | Table &1 does not exist in the ABAP dictionary |
| 412 | Field &1 does not exist in table &2 |
| 413 | Value &1 is not allowed for &2 (allowed: &3) |
| 414 | Enter both &1 and &2, or neither |
| 415 | Amber &1 and red &2 are in the wrong order for &3 |
| 416 | Rule group &1 has no active rule in ZCD_BTC_RULE |
| 417 | &1 must be greater than zero |
| 418 | &1 is not a valid PCRE pattern (matched to the whole value, any case) |
| 419 | Channel &1 cannot deliver to &2 (e-mail: shared SO23 list name) |
| 500 | Second file header 01 in line &1 ignored; expected one 01 per file |
| 501 | Account record 03 in line &1 outside a group; expected 02 before 03 |
| 502 | Detail record 16 in line &1 outside an account; expected 03 before 16 |
| 503 | Account trailer 49 in line &1 without an open account; expected 03 first |
| 504 | Group trailer 98 in line &1 without an open group; expected 02 first |
| 505 | Record &1 in line &2 found after file trailer 99; expected end of file |
| 506 | Statement has no date |
| 507 | EBS &1/&2: &3 failed, &4 blocked |
| 508 | EBS validation &1 - status &2 RAG &3 |
| 509 | Saved as run, &1 findings |
| 510 | Enter the bank file path (P_PATH) to validate a file |
| 511 | Lookup &1: &2 not found in &3 |
| 512 | Lookup &1: &2 has status &3, expected &4 |
| 513 | Rule group &1 has no usable rule assignment (configuration) |
| 514 | Rule &1 of group &2 is missing or inactive in ZCD_EBS_RULE_DEF |
| 515 | Entry &1: currency missing on the entry or its statement |
| 516 | Account &1: currency missing in the statement or in ZCD_EBS_ACCT |
| 517 | Entry &1 already in statement &2 of the account (reference &3) |
| 518 | Statement &1: &2 entries without debit/credit indicator |
| 519 | Declared credits &1, entries &2 |
| 520 | Declared debits &1, entries &2 |
| 521 | Entry &1 imported without posting rule; map prescribes &2 |
| 522 | Reason &1: mapping in ZCD_EBS_RSN_MAP incomplete (&2) |
| 523 | Reason &1 is not a &2 code |
| 524 | &1: not declared on the trailer (computed value not accepted) |
| 525 | Reference &1 has &2 characters; the key holds &3 |
| 526 | Key length &1 exceeds the key width &2 (configuration) |
| 527 | Date range invalid: from &1 is after to &2 |
| 528 | No statement selected - nothing evaluated (variant &1) |
| 529 | &1 entries not evaluated (a rule could not run) |
| 530 | File &1 is not valid UTF-8 (after line &2) - not validated |
| 531 | File &1: read error (return code &2) after line &3 - not validated |
| 532 | Entry &1: &2 not found yet - statement within the &3 h in-flight window |
| 534 | ZCD_BTC_MAP rows for &1 &2 bank &3 flow &4 contradict each other (blank flow = *) |
| 535 | Entry type &1 in line &2: funds-type layout invalid (&3) - entry not read |
| 536 | CAMT document &1: &2 &3 not accepted |
| 537 | Element &1: '&2' is not a count |
| 538 | Entry &1 (&2 &3) has status '&4' - not booked, not posted |
| 539 | Entry &1: transaction details &2 do not reconcile to the entry &3 (&4) |
| 540 | Entry &1: a transaction detail has no amount - the batch stays one entry line |
| 541 | &1 entries not posted yet (total &2) - posting checks not evaluated |
| 542 | &1 entries not evaluated (posting not complete) |
| 543 | &1 lot &2 item of payment &3 has no reason |
| 544 | &1 reason &2 of payment &3 is not a configured payment engine reason |
| 545 | Payment &1: &2 lot items with different reasons (&3) |
| 546 | &1 statements out of scope (lines not all payment engine accounts) |
| 547 | Flow pattern &1 (priority &2) is not valid PCRE - line blocked |
| 700 | Payment trace &1: verdict &2, first gap &3 (attempt &4) |
| 701 | Request &1 source &2 counter &3 status &4 |
| 702 | No SUCCESS row for FIN &1 source &2 (&3 row(s) read) |
| 703 | Source not configured: parameter &1 in ZCD_OPS_PARAM |
| 704 | Source &1 could not be read: |
| 705 | Not authorised to display company code &1 (ZCD_OPS 03) |
| 706 | Item &1 partner &2 company &3 amount &4 |
| 707 | Items of FIN &1 belong to &2 partners - review the candidates |
| 708 | Earlier clearing &1 of item &2 reset on &3 (&4) |
| 709 | Item &1 reversed or reset (&2) but no history row in &3 |
| 710 | No earlier clearing reference for item &1 in &2 |
| 711 | Payment run &1 / &2 status &3 for document &4 |
| 712 | Cheque &1 house bank &2 / &3 status &4 |
| 713 | File &1 generated for payment run &2 / &3 |
| 714 | File &1 interface &2: &3 at &4 |
| 715 | File &1 is not registered in file monitoring |
| 716 | Payment-level ACK &1 status &2 |
| 717 | Bank line &1 / &2 reference &3 posted &4 |
| 718 | Returned: returns lot document &1 status &2, return reason &3 |
| 719 | Retrieval logged for &1 status &2 |
| 720 | Cheque &1 status &2 |
| 721 | Item &1 cleared by &2 on &3 |
| 722 | Clearing &1 of item &2 was reset on &3 |
| 723 | G/L document &1 / &2 / &3 for FIKEY &4 |
| 724 | FIKEY &1 has no non-reversed G/L document (AWTYP &2) |
| 725 | Document &1 has no FIKEY |
| 726 | Not applicable: &1 |
| 727 | No link key - earlier stage &1 not verified |
| 730 | G/L line &1 / &2 account &3 XREF2 &4 |
| 731 | Enter a FIN ID, a clearing document or a cheque number |
| 732 | FIKEY &1 has no summary record in DFKKSUMC |
| 733 | No &1 evidence found for &2 |
| 737 | Partner &1 found by external number without source (legacy) |
| 738 | Request partner &1 owns none of the items of FIN &2 - review the link |
| 739 | Clearing &1: returns lot items with different return reasons (&2) |
| 740 | NOC lot &1 item &2: NOC reason &3 (INFOF &4) |
| 741 | No NOC lot item for clearing &1 or payment reference &2 |
| 742 | Alert rule &1: pattern &2 is not valid PCRE - rule not applied |
| 743 | Pattern &1 is not valid PCRE |
| 744 | Converted pattern &1 is longer than &2 (&3 characters) - not written |
| 745 | Pattern migration: &1 converted, &2 refused, &3 unchanged; test mode &4 |
| 746 | &1 value(s) read, &2 matched by no pattern, &3 pattern(s) match nothing |
| 747 | Row cap &1 reached reading the values of &2 - list may be incomplete |
| 748 | Configuration cannot be changed in this client - run the migration in DV1 |
