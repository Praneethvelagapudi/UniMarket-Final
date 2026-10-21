// Explicitly requested review testing in the owner's Uni-Market project.
// Test credentials stay in ignored tmp/ and are never added to the source bundle.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,createUserWithEmailAndPassword,signOut} from 'firebase/auth';
import {getFirestore,doc,setDoc,serverTimestamp} from 'firebase/firestore';
const config=JSON.parse(readFileSync('config/firebase.web.json','utf8'));
if(config.projectId!=='uni-market-7ef26')throw new Error('Wrong review project.');
const stamp=Date.now();
const records=[];
for(const [label,branch] of [['Seller','CSE'],['Buyer','ECE']]){
  const app=initializeApp(config,`Review${label}`);
  const auth=getAuth(app),db=getFirestore(app);
  const roll=`CB.SC.U4${branch}9${stamp}`;
  const email=`${roll.toLowerCase()}@cb.students.edu`;
  const password=`ReviewDemo${stamp}!`;
  const {user}=await createUserWithEmailAndPassword(auth,email,password);
  await setDoc(doc(db,'users',user.uid),{name:`Review Demo ${label}`,email,roll,department:branch,createdAt:serverTimestamp()});
  const record={label,email,password,uid:user.uid,roll};
  if(label==='Seller'){
    for(const [title,department,category,salePrice,dailyRate] of [
      ['Scientific calculator','ECE','Electronics',300,15],
      ['Digital circuits lab kit','ECE','Lab equipment',650,25],
      ['Introduction to algorithms','CSE','Books',450,12],
      ['Engineering drawing board','MECH','Stationery',400,20],
    ]){
      const ref=doc(db,'listings',`review-${stamp}-${category.toLowerCase().replaceAll(' ','-')}`);
      await setDoc(ref,{title:`[Review demo] ${title}`,department,category,salePrice,dailyRate,
        description:'A clearly marked review test fixture. This listing demonstrates the real Firebase buy/rent workflow; it is not an item offered for sale.',
        condition:'Good',ownerId:user.uid,ownerName:`Review Demo ${label}`,imageUrl:'',status:'available',activeBookingId:'',createdAt:serverTimestamp()});
      if(category==='Electronics')record.listingId=ref.id;
    }
  }
  records.push(record);
  await signOut(auth);await deleteApp(app);
}
mkdirSync('tmp',{recursive:true});
writeFileSync('tmp/review-accounts.json',JSON.stringify(records,null,2));
console.log('Created two clearly marked review accounts and four test listings. Credentials saved only to tmp/review-accounts.json.');
