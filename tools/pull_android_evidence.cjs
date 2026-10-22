const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process');
const adb='C:\\Users\\jdvel\\develop\\android-sdk\\platform-tools\\adb.exe';
const [mode,...args]=process.argv.slice(2);
let bytes,dest;
if(mode==='screenshot') {
  [dest]=args;
  bytes=execFileSync(adb,['-s','emulator-5554','exec-out','screencap','-p'],{maxBuffer:16*1024*1024});
} else if(mode==='private') {
  const [remote,local]=args;dest=local;
  if(!remote.startsWith('/data/user/0/edu.students.unimarket/')||remote.includes('..')||!['eval2-saved-booking.pdf','eval2-saved-booking.json','eval2-saved-receipt.png'].includes(path.posix.basename(remote)))throw new Error('Not an expected UniMarket test-evidence file.');
  bytes=execFileSync(adb,['-s','emulator-5554','exec-out','run-as','edu.students.unimarket','cat',remote],{maxBuffer:16*1024*1024});
} else throw new Error('Use screenshot <local-file> or private <exact-test-file> <local-file>.');
if(!dest)throw new Error('Output file required.');
fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);
process.stdout.write(`Saved ${path.basename(dest)} (${bytes.length} bytes).\n`);
