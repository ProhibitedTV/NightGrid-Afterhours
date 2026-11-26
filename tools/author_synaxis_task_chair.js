function authorChair(){
 const mats=[{name:"Charcoal woven upholstery",pbrMetallicRoughness:{baseColorFactor:[.065,.078,.082,1],metallicFactor:0,roughnessFactor:.91}},{name:"Graphite molded polymer",pbrMetallicRoughness:{baseColorFactor:[.025,.031,.037,1],metallicFactor:0,roughnessFactor:.64}},{name:"Satin aluminum",pbrMetallicRoughness:{baseColorFactor:[.31,.35,.37,1],metallicFactor:.82,roughnessFactor:.36}},{name:"Caster rubber",pbrMetallicRoughness:{baseColorFactor:[.018,.02,.022,1],metallicFactor:0,roughnessFactor:.92}}];
 const groups=mats.map(()=>({p:[],n:[],uv:[],idx:[]}));
 const add=(a,b)=>a.map((x,i)=>x+b[i]),sub=(a,b)=>a.map((x,i)=>x-b[i]),mul=(a,s)=>a.map(x=>x*s),dot=(a,b)=>a.reduce((s,x,i)=>s+x*b[i],0),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],norm=a=>mul(a,1/(Math.hypot(...a)||1));
 function surface(mat,nu,nv,fn,center){
  const g=groups[mat],off=g.p.length/3,pts=[],nn=[],tris=[];
  for(let j=0;j<=nv;j++)for(let i=0;i<=nu;i++){const p=fn(i/nu,j/nv);pts.push(p);nn.push([0,0,0]);g.uv.push(i/nu,j/nv)}
  function tri(i,j,k){let n=cross(sub(pts[j],pts[i]),sub(pts[k],pts[i]));const mid=mul(add(add(pts[i],pts[j]),pts[k]),1/3);if(dot(n,sub(mid,center))<0){[j,k]=[k,j];n=mul(n,-1)}if(Math.hypot(...n)<1e-10)return;tris.push(i+off,j+off,k+off);for(let t of [i,j,k])nn[t]=add(nn[t],n)}
  for(let j=0;j<nv;j++)for(let i=0;i<nu;i++){let a=j*(nu+1)+i,b=a+1,c=a+nu+1,d=c+1;tri(a,b,c);tri(b,d,c)}
  for(let j=0;j<=nv;j++){let a=j*(nu+1),b=a+nu;nn[a]=nn[b]=add(nn[a],nn[b])}
  pts.forEach((p,i)=>{g.p.push(...p);g.n.push(...norm(nn[i]))});g.idx.push(...tris)
 }
 const sp=(x,e)=>Math.sign(x)*Math.pow(Math.abs(x),e);
 function cushion(mat,center,rad,e=.64,tilt=0,nu=32,nv=14){
  surface(mat,nu,nv,(u,v)=>{let a=u*2*Math.PI,b=(v-.5)*Math.PI*.9999;let x=rad[0]*sp(Math.cos(b),e)*sp(Math.cos(a),e),y=rad[1]*sp(Math.sin(b),e),z=rad[2]*sp(Math.cos(b),e)*sp(Math.sin(a),e);return add(center,[x,y*Math.cos(tilt)-z*Math.sin(tilt),y*Math.sin(tilt)+z*Math.cos(tilt)])},center)
 }
 function tube(mat,a,b,r0,r1,segments=12){
  const axis=norm(sub(b,a)),x=norm(cross(axis,Math.abs(axis[1])>.9?[1,0,0]:[0,1,0])),z=cross(axis,x),center=mul(add(a,b),.5);
  surface(mat,segments,4,(u,v)=>{let t=u*2*Math.PI, k=v===0?0:v===1?1:v, radius=v===0||v===1?.00005:(r0+(r1-r0)*k);let pos=add(a,mul(sub(b,a),k));return add(pos,add(mul(x,radius*Math.cos(t)),mul(z,radius*Math.sin(t))))},center)
 }
 // Curved separate seat shell, upholstered seat and lumbar/back support.
 cushion(1,[0,.456,0],[.262,.042,.254],.52);
 cushion(0,[0,.500,.015],[.255,.055,.252],.57);
 cushion(1,[0,.803,-.242],[.254,.293,.041],.64,-.16);
 cushion(0,[0,.802,-.206],[.235,.268,.043],.72,-.16);
 cushion(0,[0,.677,-.162],[.19,.078,.037],.78,-.16,24,10);
 tube(1,[0,.47,-.09],[0,.67,-.25],.040,.034);
 tube(2,[0,.129,0],[0,.422,0],.037,.024,20);
 tube(1,[0,.127,0],[0,.30,0],.060,.048,20);
 cushion(1,[0,.408,0],[.136,.031,.129],.6,0,20,8);
 // Five tapered cast-aluminum spokes with actual wheel/axle geometry.
 for(let i=0;i<5;i++){let a=i*Math.PI*2/5,d=[Math.sin(a),0,Math.cos(a)],side=[Math.cos(a),0,-Math.sin(a)];
  tube(2,[0,.12,0],add(mul(d,.283),[0,.073,0]),.044,.024,12);
  let hub=add(mul(d,.286),[0,.061,0]);
  tube(1,add(hub,[0,.007,0]),add(hub,[0,.040,0]),.030,.026);
  for(let sign of [-1,1]){let c=add(hub,mul(side,sign*.026));tube(3,add(c,mul(side,-.013)),add(c,mul(side,.013)),.042,.042,20);tube(1,add(c,mul(side,-.014)),add(c,mul(side,.014)),.023,.023,12)}
 }
 for(let sign of [-1,1]){
  let x=sign*.258;
  tube(1,[sign*.20,.443,-.025],[x,.606,-.045],.025,.021);
  cushion(1,[x,.645,-.017],[.036,.029,.157],.48,0,24,10);
 }
 tube(1,[.075,.414,.15],[.18,.402,.19],.008,.008,8);
 cushion(1,[.188,.402,.193],[.032,.014,.02],.64,0,16,8);
 const bytes=[],views=[],accessors=[],primitives=[];
 function put(values,type,components,target,mins=false){while(bytes.length%4)bytes.push(0);const offset=bytes.length,buf=new ArrayBuffer(values.length*(type===5126?4:2)),v=new DataView(buf);values.forEach((x,i)=>type===5126?v.setFloat32(i*4,x,true):v.setUint16(i*2,x,true));for(let x of new Uint8Array(buf))bytes.push(x);const view=views.length;views.push({buffer:0,byteOffset:offset,byteLength:buf.byteLength,target});let a={bufferView:view,componentType:type,count:values.length/components,type:components===1?"SCALAR":"VEC"+components};if(mins){a.min=Array(components).fill(Infinity);a.max=Array(components).fill(-Infinity);values.forEach((x,i)=>{a.min[i%components]=Math.min(a.min[i%components],x);a.max[i%components]=Math.max(a.max[i%components],x)})}accessors.push(a);return accessors.length-1}
 for(let i=0;i<groups.length;i++){let g=groups[i];primitives.push({attributes:{POSITION:put(g.p,5126,3,34962,true),NORMAL:put(g.n,5126,3,34962),TEXCOORD_0:put(g.uv,5126,2,34962)},indices:put(g.idx,5123,1,34963),material:i,mode:4})}
 const abc="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";let encoded="";for(let i=0;i<bytes.length;i+=3){let n=(bytes[i]<<16)|((bytes[i+1]||0)<<8)|(bytes[i+2]||0);encoded+=abc[(n>>18)&63]+abc[(n>>12)&63]+(i+1<bytes.length?abc[(n>>6)&63]:"=")+(i+2<bytes.length?abc[n&63]:"=")}
 const asset={asset:{version:"2.0",generator:"NightGrid original chair mesh author v1"},scene:0,scenes:[{nodes:[0]}],nodes:[{name:"ErgonomicChairMesh",mesh:0}],meshes:[{name:"Synaxis ergonomic task chair",primitives}],materials:mats,buffers:[{byteLength:bytes.length,uri:"data:application/octet-stream;base64,"+encoded}],bufferViews:views,accessors};
 return {asset,stats:{vertices:groups.reduce((a,g)=>a+g.p.length/3,0),triangles:groups.reduce((a,g)=>a+g.idx.length/3,0),materials:mats.length}}
}
// Run from repository root with Node.js; source of the committed glTF.
const fs = require("node:fs");
const result=authorChair();
fs.writeFileSync("assets/models/nightgrid/synaxis_task_chair/task_chair.gltf",JSON.stringify(result.asset)+"\n");
console.log(result.stats);
