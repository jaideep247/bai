# Message class ZCD_OPS

Number ranges: 001–099 core · 100–199 EBS · 200–299 FMON · 300–399 HCK · 400–449 configuration apps (RAP).
Create in SE91 exactly as listed (short texts ≤ 73 characters).

| No. | Text |
|---|---|
| 000 | &1 &2 &3 &4 |
| 001 | Run ID could not be generated |
| 010 | Insert into table &1 failed |
| 011 | Update of table &1 failed |
| 012 | Read of table &1 failed |
| 020 | Alert for route &1 could not be sent |
| 021 | Alert rule &1 has no recipient |
| 022 | Application log &1/&2 could not be written |
| 023 | HTTP destination &1 could not be reached (&2) |
| 024 | HTTP destination &1 answered &2 &3 |
| 030 | Class &1 does not exist |
| 031 | Class &1 cannot be instantiated as a plug-in |
| 032 | Class &1 does not implement interface &2 |
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
| 103 | Validation could not run: &1 |
| 104 | Rule &1 (&2) failed: &3 |
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
| 159 | Opening &1 <> prior closing &2 |
| 160 | Release is not waiting for approval (status &1) |
| 161 | Line (object key) and check code are required for a release |
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
| 179 | Released by &1 (requested by &2): |
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
| 225 | Source &1 (&2): &3 |
| 226 | Reference &1 of &2 reused on &3: configure a unique FILE_KEY_FIELD |
| 227 | Source &1: no interface matches file &2 |
| 228 | Source &1: status '&2' has no &3 stage in ZCD_FMON_SRCMAP |
| 229 | Lot reader &1 (&2): &3 |
| 230 | Stage &1 cannot be set by hand on file &2 (current stage &3) |
| 231 | Factory calendar &1: &2; calendar days used |
| 232 | PRISM request, handling reference and reason are required |
| 233 | Factory calendar &1: &2; NORMAL day used |
| 234 | Check &1 (&2): &3 |
| 235 | Registry not saved: &1 |
| 236 | &1: &2 file(s), &3 finding(s) |
| 237 | Alert dispatch failed: &1 |
| 238 | &1: &2 of &3 &4 transaction(s) unprocessed |
| 300 | Check &1: class &2 does not implement ZIF_CD_HCK_CHECK |
| 301 | Check &1 failed: &2 |
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
| 312 | (reserved) |
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
| 332 | &1 after &2 min (max &3) |
| 333 | &1 in &2 min (max &3) |
| 334 | &1, blocked by predecessor &2 |
| 335 | Check &1 ran &2 ms, timeout &3 s |
| 336 | Health score &1/100, &2 red, &3 amber |
| 337 | Suppressed until &1 by &2: &3 |
| 338 | Table &1 changed since baseline of &2 by &3 (rows &4) |
| 401 | New entries are created in DV1 and transported (client &1) |
| 402 | Enter a customizing request: changes in this client are recorded |
| 403 | Transport request &1 does not exist |
| 404 | &1 is not a customizing request or customizing task |
| 405 | Transport request &1 is released or no longer modifiable |
| 406 | Entries are deleted in DV1 and transported (client &1) |
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
