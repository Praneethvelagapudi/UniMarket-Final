// Read-only comparison evidence for a labelled Evaluation 2 booking.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,signInWithEmailAndPassword,signOut} from 'firebase/auth';
import {getFirestore,doc,getDocFromServer} from 'firebase/firestore';
const id=process.argv[2];
if(!id||!/^[A-Za-z0-9]{20}$/.test(id))throw new Error('Supply the exact review booking ID.');
const config=JSON.parse(readFileSync('config/firebase.web.json','utf8'));
if(config.projectId!=='uni-market-7ef26')throw new Error('Unexpected project.');
const buyer=JSON.parse(readFileSync('tmp/review-accounts.json','utf8')).find(a=>a.label==='Buyer');
const app=initializeApp(config,`eval2-pdf-check-${Date.now()}`),auth=getAuth(app);
try {
  const credential=await signInWithEmailAndPassword(auth,buyer.email,buyer.password);
  if(credential.user.uid!==buyer.uid)throw new Error('Unexpected review identity.');
  const snapshot=await getDocFromServer(doc(getFirestore(app),'bookings',id)),d=snapshot.data();
  if(!d||d.buyerId!==buyer.uid||!d.title.startsWith('[Review demo]')||!d.pickupSpot.startsWith('Evaluation 2 test'))throw new Error('Not a labelled owned Evaluation 2 fixture.');
  const output={id,title:d.title,buyer:d.buyerName,seller:d.sellerName,total:d.total,pickupSpot:d.pickupSpot,status:d.status,paymentMethod:d.paymentMethod,paymentStatus:d.paymentStatus,paymentReference:d.paymentReference,createdAtEpochMs:d.createdAt.toMillis(),pickupAtEpochMs:d.pickupAt.toMillis()};
  mkdirSync('output/evaluation2',{recursive:true});
  writeFileSync('output/evaluation2/browser-saved-booking.json',JSON.stringify(output,null,2));
  console.log('PASS: read the exact saved Evaluation 2 review booking for PDF comparison.');
} finally {await signOut(auth);await deleteApp(app);}
