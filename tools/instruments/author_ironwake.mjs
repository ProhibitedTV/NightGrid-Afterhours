import {writeFileSync} from 'node:fs';
function author(bass=false){
 const materials=[
 ["Satin lacquer",bass?[.16,.025,.028,1]:[.025,.09,.105,1],.15,.36],
 ["Exposed wood",[.35,.18,.08,1],0,.58],
 ["Dark fretboard",[.045,.027,.019,1],0,.68],
 ["Brushed nickel",[.44,.46,.48,1],.88,.3],
 ["Black hardware",[.022,.026,.028,1],.32,.55],
 ["Copper winding",[.56,.24,.08,1],.83,.38],
 ["Ivory markers",[.69,.67,.56,1],0,.5],
 ["String steel",[.53,.56,.59,1],.92,.22],
 ["Lacquer edge",[.014,.019,.021,1],.1,.42]];
 const data=materials.map(()=>({p:[],n:[],uv:[],idx:[]}));
 function face(m,verts,indices){const a=verts[0],v=verts[1].map((x,i)=>x-a[i]),w=verts[2].map((x,i)=>x-a[i]);let n=[v[1]*w[2]-v[2]*w[1],v[2]*w[0]-v[0]*w[2],v[0]*w[1]-v[1]*w[0]],l=Math.hypot(...n);if(l<1e-10)return;n=n.map(x=>x/l);const d=data[m],at=d.p.length/3;for(const p of verts){d.p.push(...p);d.n.push(...n);d.uv.push(p[0]/.38+.5,p[1]/1.25)}d.idx.push(...indices.map(x=>at+x))}
 function tri(m,a,b,c){face(m,[a,b,c],[0,1,2])}
 function quad(m,a,b,c,d){face(m,[a,b,c,d],[0,1,2,0,2,3])}
 function outline(points){let p=[];for(let i=0;i<points.length;i++){let a=points[(i+points.length-1)%points.length],b=points[i],c=points[(i+1)%points.length],d=points[(i+2)%points.length];for(let j=0;j<3;j++){let t=j/3,t2=t*t,t3=t2*t;p.push([0,1].map(k=>.5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t2+(-a[k]+3*b[k]-3*c[k]+d[k])*t3)))} }return p}
 function area(p){return p.reduce((s,a,i)=>{let b=p[(i+1)%p.length];return s+a[0]*b[1]-b[0]*a[1]},0)}
 function cross(a,b,c){return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])}
 function triang(p){let ids=p.map((_,i)=>i),out=[];while(ids.length>3){let found=false;for(let j=0;j<ids.length;j++){let a=ids[(j+ids.length-1)%ids.length],b=ids[j],c=ids[(j+1)%ids.length];if(cross(p[a],p[b],p[c])<=1e-12)continue;if(ids.some(i=>i!==a&&i!==b&&i!==c&&cross(p[a],p[b],p[i])>=0&&cross(p[b],p[c],p[i])>=0&&cross(p[c],p[a],p[i])>=0))continue;out.push(a,b,c);ids.splice(j,1);found=true;break}if(!found)throw Error("non-simple outline")}out.push(...ids);return out}
 function slab(m,p,z0,z1,bevel=0,edge=m){if(area(p)<0)p=p.slice().reverse();let center=p.reduce((s,x)=>[s[0]+x[0]/p.length,s[1]+x[1]/p.length],[0,0]),inner=p.map(x=>[center[0]+(x[0]-center[0])*(1-bevel),center[1]+(x[1]-center[1])*(1-bevel)]),dz=Math.min((z1-z0)*.24,.004),layers=bevel?[[inner,z0],[p,z0+dz],[p,z1-dz],[inner,z1]]:[[p,z0],[p,z1]];for(let k=0;k<layers.length-1;k++)for(let i=0;i<p.length;i++){let j=(i+1)%p.length,a=layers[k],b=layers[k+1];quad(k===1?edge:m,[...a[0][i],a[1]],[...a[0][j],a[1]],[...b[0][j],b[1]],[...b[0][i],b[1]])}let idx=triang(inner);if(!bevel)inner=p;face(m,inner.map(x=>[...x,z1]),idx);let rev=[];for(let i=0;i<idx.length;i+=3)rev.push(idx[i],idx[i+2],idx[i+1]);face(m,inner.slice().reverse().map(x=>[...x,z0]),rev.map(i=>inner.length-1-i))}
 function rect(m,x,y,w,h,z0,z1){slab(m,[[x-w/2,y-h/2],[x+w/2,y-h/2],[x+w/2,y+h/2],[x-w/2,y+h/2]],z0,z1)}
 function disk(m,x,y,r,z0,z1,n=12){let p=Array.from({length:n},(_,i)=>[x+r*Math.cos(i*2*Math.PI/n),y+r*Math.sin(i*2*Math.PI/n)]);slab(m,p,z0,z1,.04)}
 function tube(m,a,b,r,n=6){let d=b.map((x,i)=>x-a[i]),l=Math.hypot(...d);d=d.map(x=>x/l);let u=Math.abs(d[2])<.9?[-d[1],d[0],0]:[0,-d[2],d[1]];let len=Math.hypot(...u);u=u.map(x=>x/len);let v=[d[1]*u[2]-d[2]*u[1],d[2]*u[0]-d[0]*u[2],d[0]*u[1]-d[1]*u[0]],p=[],q=[];for(let i=0;i<n;i++){let t=i*2*Math.PI/n,off=u.map((x,k)=>r*(x*Math.cos(t)+v[k]*Math.sin(t)));p.push(a.map((x,k)=>x+off[k]));q.push(b.map((x,k)=>x+off[k]))}for(let i=0;i<n;i++){let j=(i+1)%n;quad(m,p[i],p[j],q[j],q[i])}}
 const shape=bass?[[0,.015],[.115,.032],[.166,.10],[.165,.18],[.125,.245],[.12,.31],[.148,.39],[.11,.426],[.066,.389],[.038,.315],[-.035,.32],[-.062,.45],[-.11,.47],[-.145,.392],[-.13,.285],[-.16,.225],[-.176,.135],[-.13,.045]]:[[0,.015],[.116,.035],[.17,.103],[.155,.185],[.11,.242],[.12,.30],[.15,.38],[.11,.408],[.06,.365],[.035,.31],[-.04,.314],[-.082,.405],[-.13,.42],[-.153,.365],[-.116,.267],[-.157,.215],[-.179,.13],[-.135,.045]];
 const body=outline(shape);slab(0,body,-.024,.025,.045,8);
 const bridgeY=bass?.147:.145,scale=bass?.864:.648,nut=bridgeY+scale,strings=bass?4:6,neckBase=.29,neckHalf=bass?.030:.027,nutHalf=bass?.022:.021;
 slab(1,[[-neckHalf,neckBase],[neckHalf,neckBase],[nutHalf,nut],[-nutHalf,nut]],-.018,.029,.025);
 slab(2,[[-neckHalf,neckBase],[neckHalf,neckBase],[nutHalf,nut],[-nutHalf,nut]],.029,.037,.012);
 let head=outline([[-nutHalf,nut-.005],[nutHalf,nut-.005],[.046,nut+.038],[.041,nut+.115],[.019,nut+.145],[-.035,nut+.131],[-.047,nut+.06]]);
 slab(0,head,-.012,.027,.035,8);
 rect(6,0,nut,.045,.006,.037,.041);
 for(let f=1;f<=(bass?22:24);f++){let y=nut-scale*(1-Math.pow(2,-f/12)),w=2*(nutHalf+(neckHalf-nutHalf)*(nut-y)/(nut-neckBase));rect(3,0,y,w,.0015,.037,.039);if([3,5,7,9,12,15,17,19,21].includes(f)){let prev=nut-scale*(1-Math.pow(2,-(f-1)/12));for(let x of (f===12?[-.008,.008]:[0]))disk(6,x,(prev+y)/2,.0028,.037,.0376,8)}}
 rect(4,0,bridgeY,.065,.034,.025,.032);rect(3,0,bridgeY+.003,.058,.016,.032,.038);
 for(let y of [bridgeY+.052,bridgeY+.12]){rect(4,0,y,.070,bass?.022:.031,.025,.035);rect(5,0,y,.061,.012,.035,.037);for(let i=0;i<strings;i++){let x=(i-(strings-1)/2)*(bass?.012:.009);disk(3,x,y,.0024,.037,.039,8)}}
 for(let i=0;i<strings;i++){let bx=(i-(strings-1)/2)*(bass?.012:.009),nx=(i-(strings-1)/2)*(bass?.010:.0068),side=i%2?1:-1,ty=nut+.035+Math.floor(i/2)*.036,tx=side*.031;rect(3,bx,bridgeY+.003,.005,.012,.038,.041);disk(3,tx,ty,.005,.027,.037);rect(3,tx+side*.015,ty,.023,.012,.008,.021);tube(7,[bx,bridgeY,.043],[nx,nut,.043],(bass?.00075:.00038)+i*.00009);tube(7,[nx,nut,.043],[tx,ty,.038],(bass?.00075:.00038)+i*.00009)}
 for(let [x,y] of [[.094,.172],[.112,.114],[-.087,.12]]){disk(4,x,y,.011,.025,.03);disk(3,x,y,.009,.03,.042);rect(6,x,y+.003,.002,.007,.042,.043)}
 disk(3,.133,.073,.009,.025,.029);disk(4,.133,.073,.004,.029,.03);
 // rear cover, screws and strap buttons
 slab(4,[[-.062,.086],[.067,.086],[.09,.19],[-.037,.218]],-.025,-.024);
 for(let x of [-.053,.056])for(let y of [.098,.179])disk(3,x,y,.003,-.027,-.025,8);
 tube(3,[0,.017,0],[0,-.002,0],.005,10);
 tube(3,[-.106,bass?.448:.402,0],[-.106,bass?.464:.418,0],.0045,10);
 const chunks=[],views=[],accessors=[],primitives=[];let offset=0;
 function acc(a,type,comp,n,target,pos=false){let raw=new Uint8Array(a.length*4),dv=new DataView(raw.buffer);for(let i=0;i<a.length;i++)comp===5126?dv.setFloat32(i*4,a[i],true):dv.setUint32(i*4,a[i],true);let item={bufferView:views.length,componentType:comp,count:a.length/n,type};if(pos){item.min=[Infinity,Infinity,Infinity];item.max=[-Infinity,-Infinity,-Infinity];for(let i=0;i<a.length;i++){item.min[i%3]=Math.min(item.min[i%3],a[i]);item.max[i%3]=Math.max(item.max[i%3],a[i])}}views.push({buffer:0,byteOffset:offset,byteLength:raw.length,target});offset+=raw.length;chunks.push(raw);accessors.push(item);return accessors.length-1}
 for(let i=0;i<data.length;i++){let d=data[i];if(d.idx.length)primitives.push({attributes:{POSITION:acc(d.p,"VEC3",5126,3,34962,true),NORMAL:acc(d.n,"VEC3",5126,3,34962),TEXCOORD_0:acc(d.uv,"VEC2",5126,2,34962)},indices:acc(d.idx,"SCALAR",5125,1,34963),material:i})}
 let bin=new Uint8Array(offset),at=0;for(let c of chunks){bin.set(c,at);at+=c.length}let name=bass?"Ironwake_Dredge_B4":"Ironwake_Breaker_G6",json={asset:{version:"2.0",generator:"NightGrid Ironwake offline instrument workshop"},scene:0,scenes:[{nodes:[0]}],nodes:[{name,mesh:0}],meshes:[{name,primitives}],materials:materials.map(([name,color,metal,rough])=>({name,pbrMetallicRoughness:{baseColorFactor:color,metallicFactor:metal,roughnessFactor:rough}})),bufferViews:views,accessors,buffers:[{byteLength:bin.length}]};let j=Uint8Array.from(JSON.stringify(json),c=>c.charCodeAt(0)),n=(j.length+3)&~3,glb=new Uint8Array(28+n+bin.length),dv=new DataView(glb.buffer);dv.setUint32(0,0x46546c67,true);dv.setUint32(4,2,true);dv.setUint32(8,glb.length,true);dv.setUint32(12,n,true);dv.setUint32(16,0x4e4f534a,true);glb.fill(32,20,20+n);glb.set(j,20);dv.setUint32(20+n,bin.length,true);dv.setUint32(24+n,0x004e4942,true);glb.set(bin,28+n);
 return {glb,triangles:data.reduce((s,d)=>s+d.idx.length/3,0),batches:primitives.length,length:nut+.145,strings,scale};
}
for(const bass of [false,true]){const name=bass?'ironwake_dredge_b4':'ironwake_breaker_g6';const a=author(bass);writeFileSync('assets/instruments/'+name+'.glb',a.glb);console.log(name,a.triangles,'triangles');}
