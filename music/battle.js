/* ORIGINAL BGM: "Fate at the Broken Bridge"
   Composed for Fantasy RPG. No sampled/copyrighted melodies.
   164 BPM, E minor, 4/4, eight-bar loop; battle only.
   iOS requires user gesture to activate audio.
*/
(() => {
"use strict";
const bpm=164, beat=60/bpm, step=beat/4, loopSteps=128;
const lead=[
  "E5","G5","B5","D6","B5","G5","A5","B5","E6","D6","B5","A5","G5","B5","D6","B5",
  "C6","B5","G5","E5","G5","A5","B5","G5","A5","G5","E5","D5","E5","G5","A5","B5",
  "D6","B5","A5","F#5","A5","B5","D6","F#6","E6","D6","B5","A5","B5","D6","E6","D6",
  "B5","A5","G5","E5","G5","B5","E6","D6","B5","G5","F#5","E5","D5","E5","G5","B5",
  "E6","D6","B5","G5","A5","B5","G5","E5","C6","B5","G5","E5","G5","A5","B5","D6",
  "E6","F#6","G6","E6","D6","B5","A5","G5","B5","D6","E6","D6","B5","A5","G5","F#5",
  "G5","B5","E6","G6","F#6","E6","D6","B5","A5","B5","D6","B5","G5","A5","B5","D6",
  "E6","D6","B5","A5","G5","F#5","E5","D5","E5","G5","B5","D6","B5","G5","F#5","E5"
];
const chords=[
 ["E3","G3","B3"],["C3","E3","G3"],["D3","F#3","A3"],["E3","G3","B3"],
 ["C3","E3","G3"],["D3","F#3","A3"],["E3","G3","B3"],["B2","D#3","F#3"]
];
const bassRoots=["E2","C2","D2","E2","C2","D2","E2","B1"];
const pitch=n=>{const m=/^([A-G])(#?)(\d)$/.exec(n);if(!m)return 0;
 const note={C:0,D:2,E:4,F:5,G:7,A:9,B:11}[m[1]]+(m[2]?1:0);
 return 440*Math.pow(2,((Number(m[3])+1)*12+note-69)/12);};
let ctx,master,currently=false,timer=null,nextAt=0,stepIndex=0,voices=[],noiseBuffer;
const AudioContext=window.AudioContext||window.webkitAudioContext;
function setup(){
 if(ctx)return;
 if(!AudioContext)return;
 ctx=new AudioContext();
 master=ctx.createGain();master.gain.value=.19;
 const compressor=ctx.createDynamicsCompressor();
 compressor.threshold.value=-18;compressor.knee.value=12;compressor.ratio.value=5;
 compressor.attack.value=.003;compressor.release.value=.2;
 master.connect(compressor);compressor.connect(ctx.destination);
 noiseBuffer=ctx.createBuffer(1,ctx.sampleRate*.15,ctx.sampleRate);
 let array=noiseBuffer.getChannelData(0),v=0;
 for(let i=0;i<array.length;i++){v=(Math.random()*2-1)*.75+v*.25;array[i]=v;}
}
function tone(note,time,duration,type,volume,octaveSlide=0){
 if(!ctx||!note)return;
 const osc=ctx.createOscillator(),gain=ctx.createGain();
 const f=pitch(note);
 osc.type=type;osc.frequency.setValueAtTime(f,time);
 if(octaveSlide)osc.frequency.exponentialRampToValueAtTime(f*Math.pow(2,octaveSlide),time+duration);
 const a=.008,r=Math.min(.14,duration*.36);
 gain.gain.setValueAtTime(.0001,time);
 gain.gain.exponentialRampToValueAtTime(Math.max(.0002,volume),time+a);
 gain.gain.setValueAtTime(Math.max(.0002,volume*.72),time+Math.max(a,duration-r));
 gain.gain.exponentialRampToValueAtTime(.0001,time+duration);
 osc.connect(gain);gain.connect(master);osc.start(time);osc.stop(time+duration+.005);
}
function percussion(time,kind){
 if(!ctx)return;
 if(kind==="kick"){
  const osc=ctx.createOscillator(),g=ctx.createGain();
  osc.type="sine";osc.frequency.setValueAtTime(140,time);
  osc.frequency.exponentialRampToValueAtTime(47,time+.13);
  g.gain.setValueAtTime(.6,time);g.gain.exponentialRampToValueAtTime(.0001,time+.15);
  osc.connect(g);g.connect(master);osc.start(time);osc.stop(time+.16);
 }else{
  const src=ctx.createBufferSource(),g=ctx.createGain(),f=ctx.createBiquadFilter();
  src.buffer=noiseBuffer;f.type="highpass";f.frequency.value=kind==="snare"?1200:6500;
  const len=kind==="snare"?.11:.035;
  g.gain.setValueAtTime(kind==="snare"?.22:.065,time);
  g.gain.exponentialRampToValueAtTime(.0001,time+len);
  src.connect(f);f.connect(g);g.connect(master);src.start(time);src.stop(time+len);
 }
}
function schedule(i,time){
 const measure=Math.floor(i/16)%8,pos=i%16;
 if(pos===0||pos===8)percussion(time,"kick");
 if(pos===4||pos===12)percussion(time,"snare");
 if(pos%2===0)percussion(time,"hat");
 if(i%4===0){
  let chord=chords[measure];
  for(const n of chord)tone(n,time,beat*.94,"sawtooth",.021);
 }
 const root=bassRoots[measure];
 if(pos%4===0)tone(root,time,beat*.73,"sawtooth",.1);
 else if(pos===6||pos===14)tone(root,time,step*1.45,"square",.04);
 let note=lead[i%lead.length];
 const accent=pos%4===0?.105:.075;
 tone(note,time,step*.89,"square",accent);
 // A soft upper harmonic makes the lead less like a raw beep.
 if(pos%2===0)tone(note,time,step*.86,"triangle",.029);
}
function pump(){
 if(!ctx||!currently)return;
 while(nextAt<ctx.currentTime+.19){
  schedule(stepIndex,nextAt);
  nextAt+=step;stepIndex=(stepIndex+1)%loopSteps;
 }
}
async function start(){
 try{
  setup();if(!ctx)return false;
  await ctx.resume();
  if(currently)return true;
  currently=true;stepIndex=0;nextAt=ctx.currentTime+.07;
  pump();timer=setInterval(pump,60);return true;
 }catch(e){console.warn("Music unavailable",e);return false;}
}
function stop(){
 currently=false;if(timer!==null){clearInterval(timer);timer=null;}
 if(ctx){ctx.suspend().catch(()=>{});}
}
const api={start,stop,get enabled(){return currently;},get context(){return ctx;}};
window.FantasyMusic=api;
})();