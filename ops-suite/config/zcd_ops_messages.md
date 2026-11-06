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
| 150 | Content is not a BAI2 file: first record &1 (expected type 01) |
| 151 | XML content could not be parsed: &1 |
| 152 | Unsupported XML message &1/&2; expected camt.053 or camt.054 |
| 160 | Release is not waiting for approval (status &1) |
| 161 | Line (object key) and check code are required for a release |
| 200 | Table &1 not found in the DDIC or not a flat DDIC structure |
| 201 | Field &1 does not exist in table &2 |
| 202 | &1 is not a valid DDIC name |
| 203 | Field &1 of table &2 has type &3, expected &4 |
| 204 | Source &1: no field configured for &2 |
| 205 | Read of table &1 failed: &2 |
| 206 | Factory calendar &1: date &2 cannot be converted |
| 208 | Lot configuration &1 &2: field &3 missing |
| 209 | Read of table &1 has no date or key restriction |
| 211 | File ID could not be generated |
| 220 | File monitoring &1: &2 file(s), &3 finding(s), RAG &4 |
| 230 | Stage &1 cannot be set by hand on file &2 (current stage &3) |
| 232 | PRISM request, handling reference and reason are required |
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
| 320 | Suppression period is invalid (from &1 to &2) |
| 321 | Suppression is not waiting for approval (status &1) |
| 322 | A check ID is required for a suppression |
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
