// Capture only UniMarket's active Android NotificationRecord fields during a
// bounded integration-test observation window. This never changes device UI.
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const [logFile, marker, output, expectedChannel] = process.argv.slice(2);
if (!logFile || !marker || !output || !expectedChannel) throw new Error('Usage: <test-log> <marker> <output> <bookings|messages>');
const adb = 'C:\\Users\\jdvel\\develop\\android-sdk\\platform-tools\\adb.exe';
const deadline = Date.now() + 20 * 60 * 1000;
let observedAt;
function poll() {
  try {
    const log = fs.existsSync(logFile) ? fs.readFileSync(logFile, 'utf8') : '';
    if (log.includes(marker)) {
      observedAt ??= Date.now();
      const raw = execFileSync(adb, ['-s','emulator-5554','shell','dumpsys','notification','--noredact'], {encoding:'utf8',timeout:15000,maxBuffer:8*1024*1024});
      // Android 10 does not implement `cmd notification list`. Restrict the dump
      // to its active Notification List, excluding snoozed and historical data.
      const normalized = raw.replace(/\r/g,'');
      const listHeading = '  Notification List:\n';
      const listStart = normalized.indexOf(listHeading);
      if (listStart < 0) throw new Error('Android did not expose the active Notification List.');
      const active = normalized.slice(listStart + listHeading.length).split(/\n(?=  \S)/)[0];
      const lines = active.split('\n'), records = [];
      for (let i=0; i<lines.length; i++) {
        if (!lines[i].includes('NotificationRecord(') || !lines[i].includes('pkg=edu.students.unimarket')) continue;
        const selected = [lines[i]];
        for (let j=i+1; j<Math.min(lines.length,i+85); j++) {
          if (lines[j].includes('NotificationRecord(')) break;
          if (/android[.]title|android[.]text|mChannel=|channelId=|channel=|effectiveNotificationChannel=/.test(lines[j])) selected.push(lines[j]);
        }
        const block=selected.join('\n');
        if (block.includes(expectedChannel)) records.push(block);
      }
      if (records.length) {
        fs.writeFileSync(output,`Captured ${new Date().toISOString()}\nDevice: emulator-5554\nPackage: edu.students.unimarket\nExpected channel: ${expectedChannel}\nVerified in Android dumpsys notification's active Notification List, excluding historical and snoozed records.\n\n${records.join('\n\n')}\n`);
        process.stdout.write(`PASS: captured actual UniMarket Android ${expectedChannel} NotificationRecord.\n`);
        return;
      }
      if (Date.now()-observedAt>7000) throw new Error('The test marker appeared, but no matching active OS notification was found.');
    } else if (/Some tests failed|BUILD FAILED|Test failed/.test(log)) {
      throw new Error('The integration test failed before the notification observation window.');
    }
    if (Date.now()>deadline) throw new Error('Notification evidence capture timed out.');
    setTimeout(poll,250);
  } catch(error) { process.stderr.write(`${error.message}\n`); process.exitCode=1; }
}
poll();
