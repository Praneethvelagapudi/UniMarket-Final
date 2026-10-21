// Prepare a conversation between the two local review accounts requested for
// the presentation. No real student's conversation or account is modified.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,signInWithEmailAndPassword,signOut} from 'firebase/auth';
import {getFirestore,doc,getDoc,setDoc,getDocs,collection,serverTimestamp} from 'firebase/firestore';

const config=JSON.parse(readFileSync('config/firebase.web.json','utf8'));
if(config.projectId!=='uni-market-7ef26')throw new Error('Wrong demo project.');
const accounts=JSON.parse(readFileSync('tmp/review-accounts.json','utf8'));
const owner=accounts.find(a=>a.label==='Seller');
const buyer=accounts.find(a=>a.label==='Buyer');
const clients=[];
try {
  for(const account of [owner,buyer]) {
    const app=initializeApp(config,`presentation-${account.label}`);
    const auth=getAuth(app),db=getFirestore(app);
    const {user}=await signInWithEmailAndPassword(auth,account.email,account.password);
    if(user.uid!==account.uid)throw new Error('Demo identity mismatch.');
    clients.push({app,auth,db,account});
  }
  const ownerDb=clients[0].db,buyerDb=clients[1].db;
  const listing=(await getDoc(doc(buyerDb,'listings',owner.listingId))).data();
  if(!listing||listing.ownerId!==owner.uid||!listing.title.startsWith('[Review demo]')) {
    throw new Error('Expected the explicitly labelled review listing.');
  }
  const id=`${owner.listingId}_${buyer.uid}`;
  const conversation=doc(buyerDb,'conversations',id);
  if(!(await getDoc(conversation)).exists()) {
    await setDoc(conversation,{listingId:owner.listingId,title:listing.title,buyerId:buyer.uid,
      sellerId:owner.uid,participants:[buyer.uid,owner.uid],buyerName:'Review Demo Buyer',
      sellerName:'Review Demo Seller',createdAt:serverTimestamp()});
  }
  for(const [db,senderId,messageId,text] of [
    [buyerDb,buyer.uid,'demo-buyer-question','Hi! Is the scientific calculator available for three days?'],
    [ownerDb,owner.uid,'demo-owner-reply','Yes. It is ₹15 per day. We can meet at the campus library entrance.'],
    [buyerDb,buyer.uid,'demo-buyer-pickup','Great. I will reserve it and confirm the pickup time here.'],
  ]) {
    const ref=doc(db,'conversations',id,'messages',messageId);
    if(!(await getDoc(ref)).exists())await setDoc(ref,{senderId,text,createdAt:serverTimestamp()});
  }
  for(const client of clients) {
    const messages=await getDocs(collection(client.db,'conversations',id,'messages'));
    if(!messages.docs.some(d=>d.data().senderId===owner.uid)||!messages.docs.some(d=>d.data().senderId===buyer.uid)) {
      throw new Error('Two-way chat did not persist for both participants.');
    }
  }
  mkdirSync('dist',{recursive:true});
  writeFileSync('dist/DEMO_ACCESS.txt',[
    'UniMarket presentation accounts (private demo access)',
    'Firebase project: Uni-Market / uni-market-7ef26',
    '',
    'PHONE 1: CUSTOMER',`Email: ${buyer.email}`,`Password: ${buyer.password}`,
    'Display name: Review Demo Buyer','',
    'PHONE 2: ITEM OWNER',`Email: ${owner.email}`,`Password: ${owner.password}`,
    'Display name: Review Demo Seller','',
    'Both are real Firebase demo accounts. Each can upload their own items.',
    'The owner can manage their own listings and reservations. These accounts',
    'do not grant Firebase Console administration access.',
    '',
    'Install UniMarket.apk on both Android phones and connect them to the internet.',
    'Use Messages to open the prepared Scientific calculator conversation.',
    'Send a new message on either phone and watch it appear on the other.',
    'Use Discover > List an item to add your own item and gallery/camera photo.',
    'Reserve an owner listing from the customer phone. View the receipt and Android alert.',
    'Use Bookings on the owner phone to see the same reservation.',
    'Cancel or complete a rental before repeating the demonstration.',
    '',
    'Keep this file private. The source ZIP and presentation exclude passwords.',
  ].join('\n'),'utf8');
  writeFileSync('docs/evidence/two-account-chat.txt',
    'Verified two authenticated Firebase clients in uni-market-7ef26.\n'+
    'The demo customer and item owner each read persisted messages from both participants.\n'+
    'Conversation: '+id+'\n','utf8');
  console.log('Verified two-way demo chat. Private account access saved in dist/DEMO_ACCESS.txt.');
} finally {
  for(const client of clients){await signOut(client.auth);await deleteApp(client.app);}
}
