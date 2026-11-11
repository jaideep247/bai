# Message class ZCD_OPS

Number ranges: 001–099, 700–799 and 800–849 core · 860–889 ledger and document changes (build C, HCK check A_DOC_CHANGE) · 100–199 and 500–599 EBS · 200–299 and 600–649 FMON · 300–399 and 650–699 HCK · 400–449 configuration apps (RAP).
Every user-facing text of the suite is one of these messages (built with `ZCL_CD_OPS_UTIL=>TEXT( )`) or a text symbol (`docs/text_elements/`); numbers are referenced through the `gc_msg-*` constants of each area's types interface.
Create in SE91 exactly as listed (short texts ≤ 73 characters). Messages the operations framework raises moved to its class ZCA_OPS with their numbers (2026-11-10, `ops-framework/config/zca_ops_messages.md`); a number listed there is not reused here.

| No. | Text |
|---|---|
| 000 | &1 &2 &3 &4 |
| 010 | Insert into table &1 failed |
| 011 | Update of table &1 failed |
| 012 | Read of table &1 failed |
| 030 | Class &1 does not exist |
| 031 | Class &1 cannot be instantiated as a plug-in |
| 032 | Class &1 does not implement interface &2 |
| 033 | Plug-in interface &1 does not exist |
| 041 | No authorization for &1 activity &2 |
| 050 | Configuration missing: &1 &2 |
| 051 | Configuration value &1 for &2 is invalid |
| 062 | A reason is required |
| 063 | Four-eyes: &1 requested this and cannot approve it |
| 100 | Code &1 &2 bank &3 flow &4 not mapped in ZBTM: blocked, never suspense |
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
| 148 | No posting rule in posting area ZBTM for &1 |
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
| 244 | Table &1 not approved for file monitoring (ZCD_OPS_TABWL, FMON SOURCE) |
| 245 | No display authorization for table &1 (S_TABU_NAM) |
| 246 | Database error in file monitoring, registry not saved: |
| 247 | &1 of &2 &3 item(s) open |
| 248 | Factory calendar &1: banking-day age unknown, no aging verdict: |
| 249 | Field &1 of table &2 not approved for file monitoring (ZCD_OPS_TABWL) |
| 250 | Field &1 is required |
| 251 | Field &1 has an invalid value |
| 252 | Field &1 is longer than &2 characters |
| 253 | Field &1 is sent more than once |
| 254 | Field &1 must be a string, number or boolean |
| 255 | Body is not valid JSON |
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
| 272 | &1 &2: file not received by &3 (&4 due) |
| 273 | &1 &2: received, not imported by &3 (&4 due) |
| 274 | &1 &2: imported, not fully posted by &3 (&4 due) |
| 275 | &1 of &2 payment engine account(s) imported. |
| 276 | &1 of &2 in-scope line(s) not posted; |
| 277 | Bank &1, statement date &2: |
| 278 | &1 &2: stage &4 not reached by &3 |
| 279 | Posting state not read or statement read capped - not proven; |
| 280 | &1: replaced by regenerated file &2 (generation &3) |
| 281 | &1: PRISM failed &2 min ago, not regenerated yet (generation &3) |
| 282 | &1: regenerated, but &2 did not fail (&3) - possible duplicate |
| 283 | &1: PRISM already has this name (error &2) - regenerate, do not resend |
| 284 | Source &1: at most &2 generation group fields (GROUP_FIELDS) |
| 300 | Variant &1, categories &2, priorities &3, checks: |
| 301 | File ACK lag not evaluated: FMON source &1 has no GROUP_FIELDS |
| 302 | Table &1 not approved for health check reads (ZCD_OPS_TABWL, HCK READ) |
| 303 | Table &1 does not exist in the ABAP Dictionary |
| 304 | Field &1 does not exist in table &2 |
| 305 | Operator &1 for field &2 is not supported (EQ NE GT LT GE LE IN) |
| 306 | Value &1 is not a valid number for field &2 |
| 307 | Aggregate &1 of check &2: date mode &3 is invalid (AGE, DAY, blank) |
| 308 | Aggregate on table &1 (&2) failed in the database |
| 309 | Date field &1 of table &2 is not of type DATS |
| 310 | Check &1 has no aggregate definition in ZCD_HCK_AGG |
| 311 | Hash of table &1 could not be calculated |
| 312 | File ACK lag not evaluated: group field &1 of source &2 not in DPAYH run |
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
| 346 | File ACK lag not evaluated: no outbound interface with ACK level &1 |
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
| 374 | &1 not yet snapshotted, &2 attribution ambiguous: evaluated live |
| 375 | Check &1: PARAM1 (number range objects) is not maintained |
| 376 | Number range &1 interval &2: &3 % used, &4 numbers left |
| 377 | Number range object &1 has no internal interval for &2 or &3 |
| 378 | Number range &1 interval &2: limits or level are not a valid number |
| 379 | Read capped by &1 at &2 rows for &3 - result may be incomplete |
| 380 | &1 queue &2 / &3 state &4: |
| 381 | &1 entry(ies), oldest &2 min - look in &3 |
| 382 | Queue source &1 (&2) was not read: |
| 383 | bgRFC is not monitored: PARAM4 (bgRFC source) of check &1 is blank |
| 384 | Check &1: no payment method is mapped to a method class (posting area) |
| 385 | Payment method &1 is mapped to two method classes (&2, &3) |
| 386 | Check &1: no limits in ZCD_HCK_THRESH for &2 - not evaluated |
| 387 | Check &1: no factory calendar (PARAM1) - business days = calendar days |
| 388 | &1: &2 payment(s) not cleared beyond the limit, &3 critical, oldest &4 |
| 389 | Payment &1, method &2, run date &3, aged from &4, |
| 390 | age &1, amount &2 &3 |
| 391 | (no value date: run date used) |
| 392 | &1 payment(s) without value date aged from the run date (&2) |
| 393 | &1 is not monitored: no payment methods in the method class posting area |
| 394 | Time field &1 of table &2 is not of type TIMS |
| 395 | &1: &2 payment(s) - &3 |
| 396 | Payment &1, method &2, run date &3 (&4): |
| 397 | held: |
| 398 | - not held: |
| 399 | - holds but must not: |
| 407 | No authorization for &1 of &2 configuration (object ZCA_OPS) |
| 410 | Class &1 does not exist or does not implement &2 |
| 411 | Table &1 does not exist in the ABAP dictionary |
| 412 | Field &1 does not exist in table &2 |
| 413 | Value &1 is not allowed for &2 (allowed: &3) |
| 414 | Enter both &1 and &2, or neither |
| 415 | Amber &1 and red &2 are in the wrong order for &3 |
| 416 | Rule group &1 has no active rule in ZCD_BTC_RULE |
| 417 | &1 must be greater than zero |
| 418 | &1 is not a valid PCRE pattern (matched to the whole value, any case) |
| 420 | &1: each token must be BLANK or one register state character |
| 421 | &1 is not a finding code of the in-flight check (upper case) |
| 422 | &1 is required when &2 is '&3' |
| 423 | &1 must be blank when &2 is '&3' |
| 424 | Value &1 of &2 belongs to another usage (&3) |
| 425 | Value &1 of &2 does not have the form &3 |
| 426 | &1: expected groups must be a comma list of distinct values |
| 427 | &1 must not be * here (generic key not supported by this mapping) |
| 428 | Value &1 of &2 is longer than &3 characters |
| 429 | &1 must not be blank - enter a value or * (any) |
| 430 | Method class &1 of flow &2 has no entry in posting area &3 |
| 431 | Payment method &1 of flow &2 has no entry with house bank * (&3) |
| 432 | Posting area &1 has no entries - nothing is mapped |
| 433 | &1 differs between the entries of &2 (&3) |
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
| 522 | Reason &1: mapping in posting area ZRSN incomplete (&2) |
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
| 534 | ZBTM entries for &1 &2 bank &3 flow &4 contradict each other (blank = *) |
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
| 650 | - anomaly of &1: |
| 651 | Evidence &1 (&2) not usable - its purposes are not judged: |
| 652 | &1 is not monitored: no active CLEARED rule in ZCD_HCK_CLRRULE |
| 653 | - also found: |
| 654 | bank codes |
| 655 | statement line &1 code &2 amount &3 posted &4 |
| 656 | &1 status &2 |
| 657 | returns lot &1 reason &2 amount &3 |
| 658 | G/L line &1 &2 &3 clearing &4 |
| 659 | - outcome &1 (rule &2) |
| 660 | - returns lot items &1, expected &2 |
| 661 | - return line amount &1, returns lot &2 |
| 662 | - no active pattern of ZCD_HCK_SEQOUT matches |
| 663 | - pending &1 days after the last line, more than &2 |
| 664 | returns lot item(s) &1 without a return line |
| 665 | Evidence &1: parameter &2 required (&3 &4) |
| 666 | Pattern &1 of ZCD_HCK_SEQOUT &2 is not a valid PCRE |
| 667 | Evidence &1 &2 not configured (settings / parameters) - its rows are ignored |
| 668 | payout log &1 type &2 payout &3 ACK &4 |
| 669 | G/L line &1 / &2 assignment &3 |
| 670 | - assignment changed (no longer AUGBL) |
| 671 | Evidence &1: expectation &2 invalid (EQUAL or CHANGED) |
| 672 | - cheque &1, register state &2 |
| 673 | - statement amount &1, payment amount &2 - clear manually in FPCHR |
| 674 | Evidence &1 (&2) not configured - mandatory: purpose not determinable |
| 675 | - not determinable (mandatory evidence unavailable): |
| 676 | &1 not configured |
| 677 | &1 not usable |
| 678 | no role for code &1 posted &2 amount &3 (&4) - add a ZBTR entry |
| 679 | - lifecycle &1: monetary line without role |
| 680 | - cheque &1 (state &2), not the deciding cheque: |
| 681 | - outcome row &1 needs the cheque register state: no DFKKCR row |
| 682 | - waiting for the payment status job: |
| 683 | Payment &1: DPAYH status still &2, bank evidence &3 since &4 |
| 684 | Payment &1: DPAYH status still &2, bank ACK received &3 |
| 685 | Status lag after the bank ACK not evaluated: &1 not configured |
| 686 | Status lag after the bank ACK not evaluated (&1): |
| 687 | - not updated &1 min after the evidence: |
| 688 | Payment &1: DPAYH status still &2, file ACK received &3 |
| 689 | - file of payment run &1, interface &2: |
| 690 | &1 &2: bank vs G/L differs by &3, unexplained &4 |
| 691 | &1 &2: G/L &3 vs payment engine control total &4 |
| 692 | Stripe group &1: charges &2, fees &3 vs deposit &4 |
| 693 | &1 &2: difference &3 is timing (&4) |
| 694 | &1 &2: difference &3 explained by variance bucket &4 |
| 695 | &1: &2 ACH assignment group(s) of &3 unmatched, amount &4 |
| 696 | &1: no bank, G/L or payment engine evidence from &2 to &3 |
| 697 | &1: bank code(s) without reconciliation role: &2 |
| 698 | Reconciliation: &1 group day(s), &2 break(s), &3 timing, &4 variance |
| 699 | Reconciliation set &1 not evaluated (&2) |
| 700 | Payment trace &1: verdict &2, first gap &3 (attempt &4) |
| 701 | Request &1 source &2 counter &3 status &4 |
| 702 | No SUCCESS row for FIN &1 source &2 (&3 row(s) read) |
| 703 | Source not configured: parameter &1 in ZCA_PARAM |
| 704 | Source &1 could not be read: |
| 705 | Not authorised to display company code &1 (ZCA_OPS 03) |
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
| 743 | Pattern &1 is not valid PCRE |
| 744 | Converted pattern &1 is longer than &2 (&3 characters) - not written |
| 745 | Pattern migration: &1 converted, &2 refused, &3 unchanged; test mode &4 |
| 746 | &1 value(s) read, &2 matched by no pattern, &3 pattern(s) match nothing |
| 747 | Row cap &1 reached reading the values of &2 - list may be incomplete |
| 748 | Configuration cannot be changed in this client - run the migration in DV1 |
| 749 | Line &1 fits &2 cheques of account &3 - not attributed: |
| 750 | &1 is in &2 sources (&3): outcome AMBIGUOUS, evaluated &4 |
| 751 | Payment outcome snapshot: source &1 not judged - |
| 752 | Source &1: &2 documents, &3 evaluated, &4 versions written |
| 753 | Outcome &1 of payment &2 run &3 &4 |
| 754 | Payment &1: method not in a watched method class - no outcome |
| 755 | Outcome of payment &1 could not be evaluated: |
| 756 | evidence &1: &2 |
| 757 | &1 run date &2: &3 payment(s) - &4 |
| 758 | Amount &1 &2 |
| 759 | First &1 of &2 payment(s), oldest first: |
| 760 | Full list: transactions dashboard / ZCD_PAY_OUTCOME, &1, run date &2 |
| 761 | Outcome snapshot &1 min behind (limit &2): &3 processed up to &4 |
| 762 | Outcome snapshot has not run yet: outcomes of &1 not current |
| 763 | Package &1 / &2 not finished in &3 s: abandoned, watermark kept |
| 764 | Parallel packages not available (bgPF), judged one by one: |
| 765 | FIN &1 source &2 payment &3: &4 |
| 766 | Requested &1, received &2 &3, due &4: |
| 767 | No payment engine item for the FIN |
| 768 | Item &1 has payment block &2 |
| 769 | Item &1 open, not in a payment run |
| 770 | Item &1 cleared by &2 without payment run |
| 771 | Paid by &1 in the payment run of &2 |
| 772 | &1 &2 due &3: &4 request(s) not paid in a payment run |
| 773 | FIN &1 source &2 due &3: |
| 774 | Full list: transactions dashboard, request &1 &2 due &3 |
| 775 | Sweep needs a date range and evidence sources of: &1 |
| 776 | &1 stopped after &2 package(s); the next run continues |
| 777 | Worklist re-check &1 not completed today (&2): requests unchecked |
| 778 | Cancelled after SUCCESS (&1): not expected to be paid |
| 779 | Request &1 &2: stage &3, &4 |
| 780 | &1 worklist entities changed by a concurrent run since judged (first &2) |
| 781 | A second current worklist row of &1 prevented |
| 782 | Database error in source &1 - package rolled back: |
| 783 | Source &1 not judged in &2 runs in a row (limit &3): |
| 784 | Source &1 stopped by a configuration error (&2 runs) - fix by transport: |
| 785 | Evidence &1 (&2) could not be read - its purposes are not judged: |
| 788 | Open exceptions of request &1 could not be read - record not saved |
| 804 | Run &1 &2 aborted by an error: |
| 810 | File &1 could not be opened or read |
| 812 | Field &1 of table &2 is not approved for EBS lookups (ZCD_OPS_TABWL) |
| 813 | No authorisation to display table &1 (S_TABU_NAM 03) |
| 815 | Partner filter not applied: source field &1 not usable - |
| 816 | House bank |
| 817 | Bank |
| 818 | File name |
| 819 | Interface |
| 820 | Payment method |
| 821 | Payments |
| 822 | Amount |
| 823 | Payment run (date / ID) |
| 824 | Business date |
| 825 | Generated in SAP |
| 826 | Sent to PRISM |
| 827 | Delivered to bank |
| 828 | ACK due |
| 829 | Overdue by |
| 830 | ACK level |
| 831 | Earlier file (regenerated) |
| 832 | Missed deadline of stage |
| 833 | Missing bank ACK: &1 file(s), &2 payments, &3 |
| 834 | Total |
| 835 | unknown |
| 836 | &1 h &2 min |
| 837 | Missing or late bank ACK - evidence per file |
| 838 | Expected &1, actual &2, difference &3, tolerance &4 - source: |
| 839 | Health check &1 (category &2, priority &3): &4 |
| 840 | No authorisation for company code &1 (ZCA_OPS, area CD_HCK) |
| 860 | Payment &1 reversed by &2 on &3 after it left SAP (&4) |
| 861 | Reversal &1 of payment &2: reconciliation key &3 has no G/L transfer |
| 862 | Bank line &1 references payment &2, reversed by &3 |
| 863 | Document changes: read capped at &1 rows (window &2 to &3) |
