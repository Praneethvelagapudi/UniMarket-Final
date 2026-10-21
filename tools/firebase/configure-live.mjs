// Uses the normal, locally authorized Firebase CLI credentials in memory.
// Never writes or prints OAuth tokens. Restricts every request to Uni-Market.
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const auth=require('firebase-tools/lib/auth.js');
const account=auth.getGlobalDefaultAccount();
if(!account)throw new Error('Run firebase login first.');
const token=await auth.getAccessToken(account.tokens.refresh_token,[
  'openid','email','https://www.googleapis.com/auth/firebase',
  'https://www.googleapis.com/auth/cloud-platform',
  'https://www.googleapis.com/auth/cloudplatformprojects.readonly',
]);
const project='uni-market-7ef26';
async function request(url,method='GET',body){
  const response=await fetch(url,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
  const data=await response.json();
  if(!response.ok)throw new Error(`${response.status}: ${data.error?.message}`);
  return data;
}
const action=process.argv[2];
if(action==='enable-apis'){
  for(const service of ['firestore.googleapis.com','identitytoolkit.googleapis.com']){
    const result=await request(`https://serviceusage.googleapis.com/v1/projects/${project}/services/${service}:enable`,'POST',{});
    console.log(`Enabled ${service}: ${result.name}`);
  }
}else if(action==='auth-status'){
  const config=await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`);
  console.log(JSON.stringify({email:config.signIn?.email,authorizedDomains:config.authorizedDomains,subtype:config.subtype},null,2));
}else if(action==='enable-email'){
  const config=await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired`,'PATCH',{signIn:{email:{enabled:true,passwordRequired:true}}});
  console.log(JSON.stringify({email:config.signIn?.email},null,2));
}else throw new Error('Specify enable-apis, auth-status, or enable-email.');
