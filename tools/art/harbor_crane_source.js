// Original NightGrid harbor crane geometry, groups of interleaved position/normal/UV floats.
// Offline design source. Call model() to reproduce the position/normal/UV arrays.
function model(){
const groups=[[],[],[]], add=(a,b)=>a.map((x,i)=>x+b[i]), sub=(a,b)=>a.map((x,i)=>x-b[i]), mul=(a,s)=>a.map(x=>x*s),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],norm=a=>mul(a,1/Math.hypot(...a));
function quad(g,a,b,c,d){const n=norm(cross(sub(b,a),sub(c,a))),u=Math.hypot(...sub(b,a))/2,v=Math.hypot(...sub(d,a))/2;for(const [p,uv] of [[a,[0,0]],[b,[u,0]],[c,[u,v]],[a,[0,0]],[c,[u,v]],[d,[0,v]]])groups[g].push(...p,...n,...uv);}
function beam(g,a,b,w,h=w){const z=norm(sub(b,a)),x=norm(cross(Math.abs(z[1])>.95?[0,0,1]:[0,1,0],z)),y=cross(z,x);const corners=p=>[add(add(p,mul(x,-w/2)),mul(y,-h/2)),add(add(p,mul(x,w/2)),mul(y,-h/2)),add(add(p,mul(x,w/2)),mul(y,h/2)),add(add(p,mul(x,-w/2)),mul(y,h/2))];const A=corners(a),B=corners(b);quad(g,A[3],A[2],A[1],A[0]);quad(g,B[0],B[1],B[2],B[3]);for(let i=0;i<4;i++){let j=(i+1)%4;quad(g,A[i],A[j],B[j],B[i]);}}
function block(g,x,y,z,w,h,d){beam(g,[x,y-h/2,z],[x,y+h/2,z],d,w);}
for(const x of [-2,2])for(const z of [-2,2]){beam(0,[x,0,z],[x,28,z],.48);block(1,x,.25,z,1.15,.5,1.15);}
for(let y=0;y<28;y+=4){for(const z of [-2,2]){beam(0,[-2,y,z],[2,y,z],.26);beam(0,[-2,y,z],[2,y+4,z],.20);beam(0,[2,y,z],[-2,y+4,z],.20);}for(const x of [-2,2]){beam(0,[x,y,-2],[x,y,2],.26);beam(0,[x,y,-2],[x,y+4,2],.20);beam(0,[x,y,2],[x,y+4,-2],.20);}}
for(const z of [-1.15,1.15]){beam(0,[-9,28,z],[26,28,z],.40);beam(0,[-9,31,z],[26,31,z],.33);for(let x=-9;x<26;x+=5){beam(0,[x,28,z],[x,31,z],.25);beam(0,[x,28,z],[x+5,31,z],.23);beam(0,[x,31,z],[x+5,28,z],.23);}}for(let x=-9;x<=26;x+=5){beam(0,[x,28,-1.15],[x,28,1.15],.30);beam(0,[x,31,-1.15],[x,31,1.15],.30);}
block(1,-7,29.4,0,4,2.3,2.5);block(1,0,27.65,0,5,0.65,5);block(1,3,25.4,0,3.2,.3,2.4);block(1,3,27,0,3.2,.25,2.4);block(1,1.5,26.2,0,.22,1.6,2.4);
for(const z of [-1.17,1.17]){block(2,3,26.2,z,2.75,1.4,.08);for(const x of [1.65,3,4.4])block(1,x,26.2,z,.13,1.6,.16);}block(2,4.55,26.2,0,.08,1.4,2.2);
block(1,18,27.65,0,1.3,.7,2.6);for(const z of [-.28,.28])beam(1,[18,27.3,z],[18,13,z],.075);block(1,18,12.7,0,1,.6,.9);beam(1,[18,12.4,0],[18,11.7,0],.23);beam(1,[18,11.7,0],[18.5,11.3,0],.23);beam(1,[18.5,11.3,0],[18.95,11.8,0],.23);
for(let y=1;y<=27;y+=.45)beam(1,[-2.35,y,-.25],[-2.35,y,.25],.065);for(const z of [-.27,.27])beam(1,[-2.35,.7,z],[-2.35,28,z],.10);
return groups;}
if (typeof module !== "undefined") module.exports = model;
