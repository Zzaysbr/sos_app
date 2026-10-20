# Week 5 physical retest — no implied PASS

Preserve existing app data; never uninstall/clear storage. Use the controlled Guest/test accounts only, synthetic text and no private coordinates. Keep screens foreground/unlocked. Original Phase 7 physical failures remain historical evidence.

1. Android update continuity: update with `adb install -r`, open original SOS/details. **USER PASS:** original records complete and Confirmed received retained. The final additional author guard refresh is separate.
2. Android native reactivation: Guest BLE advertising → Login controlled A → BLE scan → Logout → Guest BLE advertising. Record each actual result/error. Guest advertising → Login A → Start Scan: USER PASS. Logout → Guest advertising: USER PASS. This uses the same fixed native bridge before final generation/scheduling refresh.
3. iPhone lifecycle: install final signed development profile preserving data, launch Guest, exercise initial advertising/discovery, Login/Logout with controlled account and scan/advertise again. Build/install/runtime must be confirmed separately. NOT RUN.
4. New SOS Android → iPhone after both final builds: Guest/offline/no location, iPhone advertise, Android select iPhone explicitly. Exactly one received SOS; sender persisted application ACK. NOT RUN on fixed builds.
5. Incident Chat on that *new* SOS: iPhone sends unique synthetic text once using established reply route; Android sees exactly one row and iPhone shows Delivered. Reverse direction; restart each app and check persistence. Do not repurpose old unbound Chat fixtures as a compatibility success. NOT RUN on fixed builds.
6. Location: use a controlled synthetic location source or obtain consent for location; initial/newer update, wrong recipient, stop; correlate same message ACK and displayed source. No personal coordinates in exported logs. NOT RUN physically.
7. Pending delivery/reconnect/restart: disconnect intended peer, queue one message, reconnect same peer, verify same-ID retry and one received record/ACK; repeat with app restart and controlled dropped ACK. NOT RUN physically.
8. Wrong peer/logical author: controlled third peer/injection required; do not infer from unit tests. NOT RUN physically.
9. Permission revoke/regrant/Bluetooth-off recovery per platform; repeated active A/B session transitions and stale native callbacks. Existing Phase 7 Android error handling PASS predates native fix. New recovery sequences NOT RUN.
10. No Android B is available: Android ↔ Android NOT RUN. Signed App Store/release NOT RUN. Free production provider outage/quota/live release configuration NOT RUN; debug/profile use development tiles only.

Export only message/status/attempt relationships; redact native IDs, account identifiers and locations. Raw device diagnostics stay in private `/tmp` files. Installation ID is nonsecret but need not be exported.
