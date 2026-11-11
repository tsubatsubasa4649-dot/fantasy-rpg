const TILE=32, W=320, H=240;
const maps={
 village:{name:"始まりの村",rows:["##########","#........#","#..H.....#","#........#","#....N...#","#........#","#........#","####..####"],npc:{x:5,y:4,text:"長老「風鳴りの洞窟に異変がある。気をつけてな。」"},exits:[{x:4,y:7,to:"field",tx:3,ty:6},{x:5,y:7,to:"field",tx:4,ty:6}]},
 field:{name:"小さな草原",rows:["############","#..........#","#.......C..#","#..........#","#..........#","#..........#","#..........#","#..........#","###..#######"],exits:[{x:3,y:8,to:"village",tx:4,ty:6},{x:4,y:8,to:"village",tx:5,ty:6},{x:8,y:2,to:"cave",tx:1,ty:5}]},
 cave:{name:"風鳴りの洞窟",rows:["##########","#........#","#..###...#","#..#.....#","#........#","#........#","#........#","##########"],boss:{x:7,y:2},exits:[{x:1,y:5,to:"field",tx:8,ty:3}]}
};
const fresh=()=>({map:"village",x:4,y:6,hp:30,maxHp:30,mp:10,maxMp:10,atk:8,level:1,exp:0,potions:3,steps:0,bossDefeated:false});
let state=fresh(),enemy=null;
const el=id=>document.getElementById(id),ctx=el("game").getContext("2d");
ctx.imageSmoothingEnabled=false;
const files={ground:"ground.png",wall:"wall.png",house:"house.png",cave:"cave-entrance.png",npc:"elder.png",hero:"hero.png",slime:"slime.png",guardian:"guardian.png"};
const imgs={};
for(const [name,file] of Object.entries(files)){const img=new Image();img.onload=render;img.src="assets/"+file;imgs[name]=img;}
function paint(name,x,y){let i=imgs[name];if(i&&i.complete&&i.naturalWidth)ctx.drawImage(i,x,y,TILE,TILE);}
function tell(msg){el("message").textContent=msg;}
function showStats(){el("place").textContent=maps[state.map].name;el("status").textContent="Lv."+state.level+" HP "+state.hp+"/"+state.maxHp+" MP "+state.mp+"/"+state.maxMp+" EXP "+state.exp+" 薬 "+state.potions;}
function cell(m,x,y){return m.rows[y]?.[x]??"#";}
function render(){const m=maps[state.map];ctx.clearRect(0,0,W,H);let ox=Math.max(0,Math.min(m.rows[0].length-10,state.x-4))*TILE,oy=Math.max(0,Math.min(m.rows.length-7,state.y-3))*TILE;for(let y=0;y<m.rows.length;y++)for(let x=0;x<m.rows[0].length;x++){let c=cell(m,x,y),px=x*TILE-ox,py=y*TILE-oy;paint("ground",px,py);if(c==="#")paint("wall",px,py);if(c==="H")paint("house",px,py);if(c==="C")paint("cave",px,py);if(c==="N")paint("npc",px,py);}if(m.boss&&!state.bossDefeated)paint("guardian",m.boss.x*TILE-ox,m.boss.y*TILE-oy);paint("hero",state.x*TILE-ox,state.y*TILE-oy);showStats();}
function warp(to,x,y){state.map=to;state.x=x;state.y=y;tell(maps[to].name+"に入った。");render();}
function move(dx,dy){if(enemy)return;let m=maps[state.map],x=state.x+dx,y=state.y+dy;if(x<0||y<0||x>=m.rows[0].length||y>=m.rows.length||cell(m,x,y)==="#")return;
if(m.npc&&m.npc.x===x&&m.npc.y===y){tell(m.npc.text);return;}
const exit=m.exits.find(e=>e.x===x&&e.y===y);if(exit){warp(exit.to,exit.tx,exit.ty);return;}
state.x=x;state.y=y;state.steps++;
if(m.boss&&!state.bossDefeated&&m.boss.x===x&&m.boss.y===y){battle(true);return;}
if(state.map!=="village"&&state.steps%7===0&&Math.random()<0.65){battle(false);return;}
render();}
function interact(){if(enemy)return;let m=maps[state.map];if(m.npc&&Math.abs(state.x-m.npc.x)+Math.abs(state.y-m.npc.y)<=1){tell(m.npc.text);return;}
if(state.map==="village"&&Math.abs(state.x-3)+Math.abs(state.y-2)<=1){state.hp=state.maxHp;state.mp=state.maxMp;tell("宿屋で休んだ。HPとMPが全回復した。");render();return;}
tell("特に何もない。");}
function battle(boss){enemy=boss?{name:"洞窟の守護者",hp:48,atk:7,exp:20,boss:true,img:"guardian"}:{name:"スライム",hp:15,atk:4,exp:5,boss:false,img:"slime"};
el("battle").hidden=false;el("enemy-name").textContent=enemy.name;
const img=imgs[enemy.img];if(img.complete&&img.naturalWidth)el("enemy-img").src=img.src;else el("enemy-img").removeAttribute("src");
const menu=el("battle-menu");menu.replaceChildren();for(const [name,action] of [["攻撃","attack"],["魔法 MP3","magic"],["ポーション","potion"],["逃げる","run"]]){let b=document.createElement("button");b.textContent=name;b.onclick=()=>turn(action);menu.append(b);}
message(enemy.name+"が現れた！");render();}
function message(s){el("battle-msg").textContent=s;tell(s);}
function end(){enemy=null;el("battle").hidden=true;render();}
function turn(action){if(!enemy)return;let s="";
if(action==="run"){if(enemy.boss)s="守護者からは逃げられない！";else if(Math.random()<0.75){message("逃げ切った！");end();return;}else s="逃げられなかった！";}
else if(action==="potion"){if(!state.potions){message("ポーションがない！");return;}state.potions--;let heal=Math.min(20,state.maxHp-state.hp);state.hp+=heal;s="HPを"+heal+"回復！";}
else if(action==="magic"){if(state.mp<3){message("MPが足りない！");return;}state.mp-=3;let d=12+Math.floor(Math.random()*5);enemy.hp-=d;s="ファイア！ "+d+"ダメージ！";}
else{let d=Math.max(1,state.atk+Math.floor(Math.random()*5)-2);enemy.hp-=d;s="攻撃！ "+d+"ダメージ！";}
if(enemy.hp<=0){s+=" "+enemy.name+"を倒した！";state.exp+=enemy.exp;if(enemy.boss){state.bossDefeated=true;s+=" 序章クリア！";}
while(state.exp>=state.level*12){state.exp-=state.level*12;state.level++;state.maxHp+=5;state.maxMp+=2;state.atk+=2;state.hp=state.maxHp;state.mp=state.maxMp;s+=" レベル"+state.level+"に上がった！";}
end();tell(s);return;}
let damage=Math.max(1,enemy.atk+Math.floor(Math.random()*3)-1);state.hp-=damage;s+=" "+enemy.name+"の攻撃！ "+damage+"ダメージ。";
if(state.hp<=0){state.hp=state.maxHp;state.mp=state.maxMp;end();warp("village",4,6);tell("力尽きた……村で目を覚ました。");return;}message(s);render();}
function save(){try{localStorage.setItem("fantasy-rpg-save-v1",JSON.stringify(state));tell("セーブした。");}catch{tell("セーブできなかった。");}}
function load(){try{let s=JSON.parse(localStorage.getItem("fantasy-rpg-save-v1")||"null");if(!s||!maps[s.map]){tell("セーブデータがない。");return;}state={...fresh(),...s};enemy=null;el("battle").hidden=true;render();tell("ロードした。");}catch{tell("ロードに失敗した。");}}
for(const button of document.querySelectorAll("[data-dir]")){let timer;const dirs={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]};let step=()=>move(...dirs[button.dataset.dir]);button.addEventListener("pointerdown",e=>{e.preventDefault();step();clearInterval(timer);timer=setInterval(step,165)});for(let name of ["pointerup","pointercancel","pointerleave"])button.addEventListener(name,()=>clearInterval(timer));}
el("interact").onclick=interact;el("save").onclick=save;el("load").onclick=load;
window.addEventListener("keydown",e=>{const dirs={ArrowUp:[0,-1],w:[0,-1],ArrowDown:[0,1],s:[0,1],ArrowLeft:[-1,0],a:[-1,0],ArrowRight:[1,0],d:[1,0]};if(dirs[e.key]){e.preventDefault();if(!e.repeat)move(...dirs[e.key]);}else if(e.key==="Enter"||e.key===" "){e.preventDefault();interact();}});
render();