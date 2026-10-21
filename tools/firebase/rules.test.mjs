import { readFileSync } from 'node:fs';
import { before, beforeEach, after, test } from 'node:test';
import { strict as assert } from 'node:assert';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, query, where, updateDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
const email = id => `cb.sc.u4cse${id === 'seller' ? '24157' : id === 'buyer' ? '24128' : '24742'}@cb.students.edu`;
const db = id => env.authenticatedContext(id,{email:email(id)}).firestore();
const listing = { title:'Scientific calculator',description:'A working calculator for engineering coursework.',department:'CSE',category:'Electronics',condition:'Good',salePrice:300,dailyRate:19.99,ownerId:'seller',ownerName:'Seller',imageUrl:'',status:'available',activeBookingId:'',createdAt:Timestamp.now() };
before(async()=>{
  env = await initializeTestEnvironment({projectId:'demo-unimarket',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync('firestore.rules','utf8')}});
});
beforeEach(async()=>{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context=>{
    const admin=context.firestore();
    for(const id of ['seller','buyer','other'])await setDoc(doc(admin,'users',id),{name:id==='seller'?'Seller':id==='buyer'?'Buyer':'Other',roll:email(id).split('@')[0].toUpperCase(),email:email(id),department:'CSE',createdAt:Timestamp.now()});
    await setDoc(doc(admin,'listings','calculator'),listing);
  });
});
after(async()=>{await env.cleanup();});

function booking(mode='rent',overrides={}){
  const today=new Date();today.setHours(0,0,0,0);
  return {listingId:'calculator',title:listing.title,buyerId:'buyer',sellerId:'seller',buyerName:'Buyer',sellerName:'Seller',participants:['buyer','seller'],mode,status:'confirmed',total:mode==='rent'?59.97:300,days:mode==='rent'?3:0,startAt:Timestamp.fromDate(today),endAt:Timestamp.fromMillis(today.getTime()+3*86400000),pickupAt:Timestamp.fromMillis(Date.now()+3600000),pickupSpot:'Campus library entrance',createdAt:serverTimestamp(),...overrides};
}
function reserve(database,id='reservation',data=booking()){
  const batch=writeBatch(database);
  batch.set(doc(database,'bookings',id),data);
  batch.update(doc(database,'listings','calculator'),{status:'reserved',activeBookingId:id});
  return batch.commit();
}
function transition(database,status,mode='rent'){
  const batch=writeBatch(database);
  batch.update(doc(database,'bookings','reservation'),{status,updatedAt:serverTimestamp()});
  batch.update(doc(database,'listings','calculator'),{status:status==='completed'&&mode==='buy'?'sold':'available',activeBookingId:''});
  return batch.commit();
}

test('anonymous and non-campus accounts cannot browse campus items',async()=>{
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'listings','calculator')));
  await assertFails(getDoc(doc(env.authenticatedContext('outsider',{email:'someone@gmail.com'}).firestore(),'listings','calculator')));
});
test('campus profile creation requires matching email, roll and department',async()=>{
  const newdb=env.authenticatedContext('new',{email:'cb.sc.u4mech25999@cb.students.edu'}).firestore();
  const profile={name:'New Student',roll:'CB.SC.U4MECH25999',email:'cb.sc.u4mech25999@cb.students.edu',department:'MECH',createdAt:serverTimestamp()};
  await assertFails(setDoc(doc(newdb,'users','new'),{...profile,roll:'CB.SC.U4CSE25999'}));
  await assertFails(setDoc(doc(newdb,'users','new'),{...profile,department:'CSE'}));
  await assertSucceeds(setDoc(doc(newdb,'users','new'),profile));
});
test('campus email without a completed profile cannot access marketplace data',async()=>{
  await assertFails(getDoc(doc(env.authenticatedContext('incomplete',{email:email('buyer')}).firestore(),'listings','calculator')));
});
test('user profiles remain private and cannot be reassigned',async()=>{
  await assertFails(getDoc(doc(db('buyer'),'users','seller')));
  await assertFails(updateDoc(doc(db('buyer'),'users','buyer'),{email:email('seller')}));
});
test('seller may publish valid listings; cannot spoof owner or use negative prices',async()=>{
  await assertSucceeds(setDoc(doc(db('seller'),'listings','new-item'),{...listing,createdAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db('buyer'),'listings','spoof'),{...listing,createdAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db('seller'),'listings','bad-price'),{...listing,salePrice:-1,createdAt:serverTimestamp()}));
});
test('photo document and listing can be created atomically within size bound',async()=>{
  const seller=db('seller');const batch=writeBatch(seller);
  batch.set(doc(seller,'listings','photo-item'),{...listing,imageUrl:'firestore:photo-item',createdAt:serverTimestamp()});
  batch.set(doc(seller,'listing-images','photo-item'),{ownerId:'seller',data:'validBase64Example',contentType:'image/jpeg',createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(db('buyer'),'listing-images','calculator'),{ownerId:'buyer',data:'x',contentType:'image/jpeg',createdAt:serverTimestamp()}));
});
test('photo payloads larger than the allowed bound are rejected',async()=>{
  const seller=db('seller');const batch=writeBatch(seller);
  batch.set(doc(seller,'listings','big-photo'),{...listing,imageUrl:'firestore:big-photo',createdAt:serverTimestamp()});
  batch.set(doc(seller,'listing-images','big-photo'),{ownerId:'seller',data:'x'.repeat(240001),contentType:'image/jpeg',createdAt:serverTimestamp()});
  await assertFails(batch.commit());
});
test('booking must atomically reserve the item and use the correct total',async()=>{
  await assertFails(setDoc(doc(db('buyer'),'bookings','unlocked'),booking()));
  await assertFails(reserve(db('buyer'),'wrong-total',booking('rent',{total:1})));
  await assertSucceeds(reserve(db('buyer')));
});
test('zero-day and invalid pickup rentals are rejected',async()=>{
  await assertFails(reserve(db('buyer'),'zero-day',booking('rent',{days:0,total:0})));
  await assertFails(reserve(db('buyer'),'late-pickup',booking('rent',{pickupAt:Timestamp.fromMillis(Date.now()+10*86400000)})));
});
test('seller cannot self-book; another buyer cannot reserve a reserved item',async()=>{
  await assertFails(reserve(db('seller'),'self',booking('buy',{buyerId:'seller',buyerName:'Seller',participants:['seller','seller']})));
  await assertSucceeds(reserve(db('buyer')));
  await assertFails(reserve(db('other'),'second',booking('rent',{buyerId:'other',buyerName:'Other',participants:['other','seller']})));
});
test('only participants can read bookings, including filtered history queries',async()=>{
  await reserve(db('buyer'));
  await assertSucceeds(getDoc(doc(db('seller'),'bookings','reservation')));
  await assertFails(getDoc(doc(db('other'),'bookings','reservation')));
  await assertSucceeds(getDocs(query(collection(db('buyer'),'bookings'),where('participants','array-contains','buyer'))));
});
test('cancellation releases availability atomically and prevents later status changes',async()=>{
  await reserve(db('buyer'));
  await assertFails(updateDoc(doc(db('buyer'),'bookings','reservation'),{status:'cancelled',updatedAt:serverTimestamp()}));
  await assertSucceeds(transition(db('buyer'),'cancelled'));
  assert.equal((await getDoc(doc(db('buyer'),'listings','calculator'))).data().status,'available');
  await assertFails(transition(db('seller'),'completed'));
});
test('only seller can complete a rental; completed rentals become available',async()=>{
  await reserve(db('buyer'));
  await assertFails(transition(db('buyer'),'completed'));
  await assertSucceeds(transition(db('seller'),'completed'));
  assert.equal((await getDoc(doc(db('buyer'),'listings','calculator'))).data().status,'available');
});
test('purchase completion marks item sold and blocks price tampering',async()=>{
  await reserve(db('buyer'),'reservation',booking('buy'));
  await assertFails(updateDoc(doc(db('buyer'),'bookings','reservation'),{total:1}));
  await assertSucceeds(transition(db('seller'),'completed','buy'));
  assert.equal((await getDoc(doc(db('buyer'),'listings','calculator'))).data().status,'sold');
});
test('only owner may archive available items; reserved items cannot be archived',async()=>{
  await assertFails(updateDoc(doc(db('buyer'),'listings','calculator'),{status:'archived'}));
  await reserve(db('buyer'));
  await assertFails(updateDoc(doc(db('seller'),'listings','calculator'),{status:'archived'}));
});
test('bookmarks belong to their user and contain truthful item snapshots',async()=>{
  const snapshot={title:listing.title,department:listing.department,category:listing.category,imageUrl:'',salePrice:300,dailyRate:19.99,ownerName:'Seller',listingId:'calculator',savedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('buyer'),'users','buyer','bookmarks','calculator'),snapshot));
  await assertFails(getDoc(doc(db('other'),'users','buyer','bookmarks','calculator')));
  await assertFails(setDoc(doc(db('buyer'),'users','buyer','bookmarks','calculator'),{...snapshot,salePrice:1}));
});
test('bargaining conversations and messages are participant-restricted',async()=>{
  const buyer=db('buyer');
  await assertSucceeds(getDoc(doc(buyer,'conversations','calculator_buyer')));
  await assertSucceeds(setDoc(doc(buyer,'conversations','calculator_buyer'),{listingId:'calculator',title:listing.title,buyerId:'buyer',sellerId:'seller',buyerName:'Buyer',sellerName:'Seller',participants:['buyer','seller'],createdAt:serverTimestamp()}));
  await assertSucceeds(setDoc(doc(buyer,'conversations','calculator_buyer','messages','hello'),{senderId:'buyer',text:'Would you accept ₹250? Meet at the library?',createdAt:serverTimestamp()}));
  await assertSucceeds(getDocs(collection(db('seller'),'conversations','calculator_buyer','messages')));
  await assertFails(getDocs(collection(db('other'),'conversations','calculator_buyer','messages')));
  await assertFails(setDoc(doc(buyer,'conversations','calculator_buyer','messages','spoof'),{senderId:'seller',text:'Spoofed',createdAt:serverTimestamp()}));
});

async function conversation() {
  await setDoc(doc(db('buyer'),'conversations','calculator_buyer'),{listingId:'calculator',title:listing.title,buyerId:'buyer',sellerId:'seller',buyerName:'Buyer',sellerName:'Seller',participants:['buyer','seller'],createdAt:serverTimestamp()});
}
function wav() {
  const b=Buffer.alloc(16044);
  b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVE',8);b.write('fmt ',12);
  b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(8000,24);
  b.writeUInt32LE(16000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(16000,40);
  return b.toString('base64');
}
function voice(database,id='voice',overrides={}) {
  const batch=writeBatch(database);
  batch.set(doc(database,'conversations','calculator_buyer','messages',id),{senderId:'buyer',type:'audio',durationMs:1000,audioId:id,createdAt:serverTimestamp(),...overrides.message});
  batch.set(doc(database,'conversations','calculator_buyer','audio',id),{senderId:'buyer',data:wav(),contentType:'audio/wav',durationMs:1000,createdAt:serverTimestamp(),...overrides.audio});
  return batch.commit();
}
test('actual bounded WAV and metadata save atomically and recipient alone can read',async()=>{
  await conversation();await assertSucceeds(voice(db('buyer')));
  const audio=doc(db('seller'),'conversations','calculator_buyer','audio','voice');
  assert.equal((await assertSucceeds(getDoc(audio))).data().data,wav());
  await assertFails(getDoc(doc(db('other'),'conversations','calculator_buyer','audio','voice')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'conversations','calculator_buyer','audio','voice')));
});
test('voice rejects oversized data, wrong type, invalid duration and sender spoofing',async()=>{
  await conversation();
  await assertFails(voice(db('buyer'),'huge',{audio:{data:'UklGR'+'A'.repeat(320060)}}));
  await assertFails(voice(db('buyer'),'type',{audio:{contentType:'application/javascript'}}));
  await assertFails(voice(db('buyer'),'duration',{message:{durationMs:15001},audio:{durationMs:15001}}));
  await assertFails(voice(db('buyer'),'mismatch',{audio:{durationMs:2000}}));
  await assertFails(voice(db('buyer'),'spoof',{message:{senderId:'seller'},audio:{senderId:'seller'}}));
  await assertFails(voice(db('other'),'intrusion'));
});
test('voice cannot be orphaned, overwritten or edited after sending',async()=>{
  await conversation();const buyer=db('buyer');
  await assertFails(setDoc(doc(buyer,'conversations','calculator_buyer','messages','metadata-only'),{senderId:'buyer',type:'audio',durationMs:1000,audioId:'metadata-only',createdAt:serverTimestamp()}));
  await assertFails(setDoc(doc(buyer,'conversations','calculator_buyer','audio','audio-only'),{senderId:'buyer',data:wav(),contentType:'audio/wav',durationMs:1000,createdAt:serverTimestamp()}));
  await assertSucceeds(voice(buyer));await assertFails(voice(buyer));
  await assertFails(updateDoc(doc(buyer,'conversations','calculator_buyer','messages','voice'),{durationMs:2000}));
});
test('read receipts are private, owned, monotonic and cannot be set in the future',async()=>{
  await conversation();const buyer=db('buyer');const at=Timestamp.fromMillis(Date.now()-5000);
  await assertSucceeds(setDoc(doc(buyer,'conversations','calculator_buyer','reads','buyer'),{readAt:at}));
  await assertFails(getDoc(doc(db('seller'),'conversations','calculator_buyer','reads','buyer')));
  await assertFails(setDoc(doc(db('other'),'conversations','calculator_buyer','reads','other'),{readAt:at}));
  await assertFails(setDoc(doc(db('seller'),'conversations','calculator_buyer','reads','buyer'),{readAt:at}));
  await assertFails(setDoc(doc(buyer,'conversations','calculator_buyer','reads','buyer'),{readAt:Timestamp.fromMillis(at.toMillis()-1000)}));
  await assertFails(setDoc(doc(buyer,'conversations','calculator_buyer','reads','buyer'),{readAt:Timestamp.fromMillis(Date.now()+3600000)}));
  await assertSucceeds(setDoc(doc(buyer,'conversations','calculator_buyer','reads','buyer'),{readAt:serverTimestamp()}));
});

const mockFields={paymentMethod:'mock',paymentStatus:'pending',paymentReference:'',paymentAttemptId:''};
const attemptId='abcdefghijklmnopqrst';
function payment(database,status,attempt=attemptId,reference=status==='succeeded'?`mock_reservation_${attempt}`:'') {
  return updateDoc(doc(database,'bookings','reservation'),{paymentStatus:status,paymentAttemptId:attempt,paymentReference:reference,paymentUpdatedAt:serverTimestamp()});
}
test('mock reservation requires explicit simulation fields and cannot claim payment on create',async()=>{
  await assertFails(reserve(db('buyer'),'paid-on-create',booking('buy',{...mockFields,paymentStatus:'succeeded'})));
  await assertFails(reserve(db('buyer'),'real-provider',booking('buy',{...mockFields,paymentMethod:'razorpay'})));
  await assertFails(reserve(db('buyer'),'partial-fields',booking('buy',{paymentStatus:'pending'})));
  await assertSucceeds(reserve(db('buyer'),'reservation',booking('buy',mockFields)));
});
test('only buyer can start a simulation; amount, identity and provider stay immutable',async()=>{
  await reserve(db('buyer'),'reservation',booking('buy',mockFields));
  await assertFails(payment(db('seller'),'pending'));await assertFails(payment(db('other'),'pending'));
  await assertSucceeds(payment(db('buyer'),'pending'));
  await assertFails(updateDoc(doc(db('buyer'),'bookings','reservation'),{total:1}));
  await assertFails(updateDoc(doc(db('buyer'),'bookings','reservation'),{paymentMethod:'razorpay'}));
  await assertFails(transition(db('seller'),'completed','buy'));
});
test('simulation cannot skip pending, forge a reference or rewrite a successful result',async()=>{
  await reserve(db('buyer'),'reservation',booking('buy',mockFields));
  await assertFails(payment(db('buyer'),'succeeded'));
  await assertSucceeds(payment(db('buyer'),'pending'));
  await assertFails(payment(db('buyer'),'succeeded',attemptId,'real_razorpay_payment'));
  await assertFails(payment(db('buyer'),'succeeded','ABCDEFGHIJKLMNOPQRST'));
  await assertSucceeds(payment(db('buyer'),'succeeded'));
  await assertFails(payment(db('buyer'),'pending'));await assertFails(payment(db('buyer'),'failed'));
  await assertSucceeds(transition(db('seller'),'completed','buy'));
});
test('failed and cancelled simulations retry safely with new attempt IDs',async()=>{
  await reserve(db('buyer'),'reservation',booking('buy',mockFields));
  await payment(db('buyer'),'pending');await assertSucceeds(payment(db('buyer'),'failed'));
  await assertFails(payment(db('buyer'),'succeeded'));await assertFails(payment(db('buyer'),'pending'));
  const retry='ABCDEFGHIJKLMNOPQRST';await assertSucceeds(payment(db('buyer'),'pending',retry));
  await assertSucceeds(payment(db('buyer'),'cancelled',retry));
  const third='12345678901234567890';await assertSucceeds(payment(db('buyer'),'pending',third));
  await assertSucceeds(payment(db('buyer'),'succeeded',third));
});
test('cancelling a pending simulation releases the item and blocks late payment results',async()=>{
  await reserve(db('buyer'),'reservation',booking('buy',mockFields));await payment(db('buyer'),'pending');
  await assertSucceeds(transition(db('buyer'),'cancelled','buy'));
  await assertFails(payment(db('buyer'),'succeeded'));
  assert.equal((await getDoc(doc(db('buyer'),'listings','calculator'))).data().status,'available');
});
