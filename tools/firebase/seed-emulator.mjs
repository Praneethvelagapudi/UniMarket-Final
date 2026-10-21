// This fixture only touches the local demo project. It never seeds production.
import { initializeApp } from 'firebase/app';
import { getAuth,connectAuthEmulator,createUserWithEmailAndPassword,signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore,connectFirestoreEmulator,doc,setDoc,serverTimestamp } from 'firebase/firestore';

const password='UniMarketDemo2026!';
for(const [label,roll] of [['Seller','CB.SC.U4CSE99001'],['Buyer','CB.SC.U4ECE99002']]){
  const app=initializeApp({apiKey:'demo-api-key',projectId:'demo-unimarket',appId:'1:123456789:web:demo'},label);
  const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
  const db=getFirestore(app);connectFirestoreEmulator(db,'127.0.0.1',8080);
  const email=`${roll.toLowerCase()}@cb.students.edu`;
  let result;
  try{result=await createUserWithEmailAndPassword(auth,email,password);}
  catch(e){if(e.code!=='auth/email-already-in-use')throw e;result=await signInWithEmailAndPassword(auth,email,password);}
  try{await setDoc(doc(db,'users',result.user.uid),{name:`Demo ${label}`,email,roll,department:label==='Seller'?'CSE':'ECE',createdAt:serverTimestamp()});}
  catch(e){if(e.code!=='permission-denied')throw e;}
  if(label==='Seller'){
    for(const [id,title,department,category,salePrice,dailyRate] of [
      ['demo-calculator','Scientific calculator','ECE','Electronics',300,15],
      ['demo-circuits','Digital circuits lab kit','ECE','Lab equipment',650,25],
      ['demo-book','Introduction to algorithms','CSE','Books',450,12],
      ['demo-board','Engineering drawing board','MECH','Stationery',400,20],
    ]){
      try{await setDoc(doc(db,'listings',id),{title,department,category,salePrice,dailyRate,
        description:'Demo fixture for local testing: a useful campus essential in good working condition.',
        condition:'Good',ownerId:result.user.uid,ownerName:'Demo Seller',imageUrl:'',status:'available',activeBookingId:'',createdAt:serverTimestamp()});}
      catch(e){if(e.code!=='permission-denied')throw e;}
    }
  }
  console.log(`Local emulator account: ${email}`);
}
console.log('Local fixture ready. Password: UniMarketDemo2026!');
process.exit(0);
