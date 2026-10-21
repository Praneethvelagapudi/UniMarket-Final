"""Record completed checks and explicit hardware limits without altering the app."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
docs = ROOT / 'docs'
testing = docs / 'EVALUATION2_TESTING.md'
text = testing.read_text(encoding='utf-8')
text = text.replace('**38/38 passed**, `tmp/eval2-tests-verified.log`', '**39/39 passed**, `tmp/eval2-final-tests.log`')
text = text.replace('`tmp/eval2-analysis-release.log`', '`tmp/eval2-final-analysis.log`')
text = text.replace('Awaiting fresh device run', 'Not completed: emulator System UI ANR at both RAM configurations')
text = text.replace('Baseline tests/rules pass; fresh Android run pending', 'Baseline tests/rules pass; browser search/reserve/cancel verified; native run blocked by emulator ANR')
text = text.replace('Awaiting integration/export check | PENDING', 'Actual browser download matched ten saved fields/labels/timestamps; tmp/eval2-browser-pdf-verified.log | PASS')
text = text.replace('Awaiting runtime check | PENDING', 'Browser preview/download verified; Android share targets still pending | PARTIAL')
text = text.replace('Hardware/runtime check pending', 'Embedded-browser permission unresolved; Cancel verified. Android test stopped after System UI ANR')
text = text.replace('Fresh device check pending', 'Native playback pending due to System UI ANR; private exact-byte validation covered by codec/rules')
text = text.replace('Fresh OS inspection pending', 'Unverified: emulator System UI ANR prevented reliable OS inspection')
text = text.replace('Runtime check pending | PENDING | Conditional web', 'OS permission unresolved in embedded browser; in-app alerts covered by tests | PARTIAL | Conditional web')
text = text.replace('Runtime inspection pending | PENDING', 'Browser payment/receipt/PDF and pending-mic Cancel inspected; native inspection pending | PARTIAL')
text = text.replace('Build pending | PENDING | No framework migration', 'Release command succeeded; build/web exists | PASS | No framework migration')
text = text.replace('Build pending | PENDING | Existing key preserved', 'Release build/signature/install succeeded; emulator System UI ANR limits launch validation | PARTIAL | Existing key preserved')
text = text.replace('Build pending | PENDING | No production key created', 'Release build and jarsigner verification succeeded | PASS | No production key created')
text += '\n## Final browser and environment evidence\n\nThe actual browser PDF `output/evaluation2/browser-saved-booking.pdf` was matched against its server-read JSON: booking/item/parties/amount/pickup/reference/labels/timestamps all passed. Both labelled browser test reservations were cancelled after inspection. The snapshot reflects its successful state at issue time. Payment success now provides **View booking receipt**, a deterministic explicit action after saved success.\n\nThe native voice integration command began debug assembly but was stopped after the emulator repeatedly displayed a System UI ANR, including at its original 2 GB allocation. No native capture, notification delivery, fresh session persistence or full native regression pass is claimed. The failed environment screenshots are retained. Prior failed generated-plugin registration was corrected by normal sequential Flutter regeneration; subsequent release APK and AAB builds passed. Final permission-preference race coverage brings the Flutter count to 39.\n'
testing.write_text(text, encoding='utf-8')
contrib = docs / 'EVALUATION2_CONTRIBUTION_DRAFT.md'
contrib.write_text(contrib.read_text(encoding='utf-8').replace('38 Flutter', '39 Flutter'), encoding='utf-8')
rubric = docs / 'EVALUATION2_RUBRIC.md'
text = rubric.read_text(encoding='utf-8').replace('Fresh 38-case', 'Fresh 39-case')
text = text.replace('New mobile views still require fresh emulator/phone inspection.', 'Browser payment/receipt/PDF and permission-pending Cancel inspected; native views require a stable emulator/phone because System UI ANRs blocked inspection.')
text = text.replace('| F1 — APK and AAB | Partial | Fresh web releases have built. First APK attempt failed on stale generated test-plugin registration; normal Flutter regeneration/rebuild is in progress. No fresh APK/AAB is claimed until its command succeeds and file/signature is verified. Existing development signing is preserved; production Play signing is not configured. |', '| F1 — APK and AAB | Complete | Fresh web/APK/AAB release commands succeeded; output metadata and signatures verified. APK installation succeeded. Existing development signing is preserved; production Play signing is not configured. Native runtime validation remains separately Partial because the emulator System UI failed. |')
text = text.replace('Fresh build/device results will be reflected in this audit and the final handover before delivery.', 'Final build/evidence details and exact artifact manifest are linked from EVALUATION2_HANDOVER.md.')
rubric.write_text(text, encoding='utf-8')
print('Updated factual test, rubric and contribution records.')
