// Two concurrent authenticated SDK clients, scoped to pre-existing labelled
// review fixtures. No real student conversation, account or listing is changed.
import {readFileSync,writeFileSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,signInWithEmailAndPassword,signOut} from 'firebase/auth';
import {getFirestore,doc,getDoc,setDoc,collection,onSnapshot,serverTimestamp} from 'firebase/firestore';

const config=JSON.parse(readFileSync('config/firebase.web.json','utf8'));
if(config.projectId!=='uni-market-7ef26')throw new Error('Unexpected project.');
const accounts=JSON.parse(readFileSync('tmp/review-accounts.json','utf8'));
const seller=accounts.find(a=>a.label==='Seller'), buyer=accounts.find(a=>a.label==='Buyer');
if(!seller||!buyer||!seller.listingId)throw new Error('Existing review fixtures are required.');
const clients=[];
const stamp=Date.now();
const conversationId=`${seller.listingId}_${buyer.uid}`;
const evidence={project:config.projectId,checkedAt:new Date().toISOString(),kind:'Two concurrent SDK clients, not physical-device notification verification',checks:[]};
function received(database,id) {
  let unsub,timer;
  const promise=new Promise((resolve,reject)=>{
    timer=setTimeout(()=>{unsub?.();reject(new Error('Realtime message timed out.'));},30000);
    unsub=onSnapshot(doc(database,'conversations',conversationId,'messages',id),snapshot=>{
      if(snapshot.exists()&&!snapshot.metadata.hasPendingWrites){clearTimeout(timer);unsub?.();resolve(snapshot.data());}
    },error=>{clearTimeout(timer);unsub?.();reject(error);});
  });
  return {promise,cancel:()=>{clearTimeout(timer);unsub?.();}};
}
try {
  for(const account of [seller,buyer]) {
    const app=initializeApp(config,`eval2-${account.label}-${stamp}`),auth=getAuth(app),db=getFirestore(app);
    const credential=await signInWithEmailAndPassword(auth,account.email,account.password);
    if(credential.user.uid!==account.uid)throw new Error('Unexpected review identity.');
    clients.push({app,auth,db});
  }
  const ownerDb=clients[0].db,buyerDb=clients[1].db;
  const listing=(await getDoc(doc(buyerDb,'listings',seller.listingId))).data();
  if(!listing?.title.startsWith('[Review demo]')||listing.ownerId!==seller.uid)throw new Error('Not an authorized labelled review fixture.');
  const chat=(await getDoc(doc(buyerDb,'conversations',conversationId))).data();
  if(chat?.buyerId!==buyer.uid||chat?.sellerId!==seller.uid)throw new Error('Review conversation is missing or mismatched.');
  for(const [from,to,sender,id,text] of [
    [buyerDb,ownerDb,buyer.uid,`eval2-buyer-${stamp}`,'Evaluation 2 sync check: buyer to seller.'],
    [ownerDb,buyerDb,seller.uid,`eval2-seller-${stamp}`,'Evaluation 2 sync check: seller to buyer.'],
  ]) {
    const wait=received(to,id);
    try {
      await setDoc(doc(from,'conversations',conversationId,'messages',id),{senderId:sender,text,createdAt:serverTimestamp()});
      const actual=await wait.promise;
      if(actual.senderId!==sender||actual.text!==text)throw new Error('Recipient received incorrect message.');
      evidence.checks.push({direction:sender===buyer.uid?'buyer -> seller':'seller -> buyer',result:'PASS',messageId:id});
    } finally {wait.cancel();}
  }
  const own=doc(buyerDb,'conversations',conversationId,'reads',buyer.uid);
  await setDoc(own,{readAt:serverTimestamp()});
  if(!(await getDoc(own)).exists())throw new Error('Read receipt not persisted.');
  try {
    await getDoc(doc(ownerDb,'conversations',conversationId,'reads',buyer.uid));
    throw new Error('A participant unexpectedly read the other user private receipt.');
  } catch(error) {if(error.code!=='permission-denied')throw error;}
  evidence.checks.push({case:'Owned read receipt persists and other-user read is denied',result:'PASS'});
  writeFileSync('tmp/eval2-live-sync.json',JSON.stringify(evidence,null,2));
  console.log('PASS: two-way real-time delivery between two concurrent live Firebase clients; owned/private read receipts.');
} finally {
  await Promise.allSettled(clients.map(async c=>{await signOut(c.auth);await deleteApp(c.app);}));
}
