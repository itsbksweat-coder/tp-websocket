import fs from "fs";
import path from "path";
import crypto from "crypto";
import { TextEncoder } from "util";

const U32 = 0x100000000;
function ri(a,b){ return Math.floor(Math.random()*(b-a+1))+a; }
function ru32(){ return (Math.floor(Math.random()*U32)>>>0)||0x9e3779b9; }
function xs(v){
  v>>>=0;
  v^=(v<<13)>>>0;
  v^=v>>>17;
  v^=(v<<5)>>>0;
  return v>>>0;
}
function enc(s){ return new TextEncoder().encode(s); }
function adler(bytes){
  let a=1,b=0;
  for(const x of bytes){ a=(a+x)%65521; b=(b+a)%65521; }
  return (((b<<16)>>>0)|a)>>>0;
}
function randName(used){
  const A="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
  const B=A+"0123456789";
  let s;
  do{
    const n=ri(8,17);
    s=A[ri(0,A.length-1)];
    for(let i=1;i<n;i++) s+=B[ri(0,B.length-1)];
  }while(used.has(s));
  used.add(s);
  return s;
}
function uniqueNums(n,a,b){
  const s=new Set();
  while(s.size<n) s.add(ri(a,b));
  return [...s];
}
function shuffle(a){
  const x=a.slice();
  for(let i=x.length-1;i>0;i--){
    const j=ri(0,i);
    [x[i],x[j]]=[x[j],x[i]];
  }
  return x;
}
function chunks(bytes,n){
  const out=[];
  for(let i=0;i<bytes.length;i+=n) out.push(bytes.slice(i,i+n));
  return out;
}
function crypt(bytes,seed,salt){
  let st=seed>>>0;
  const out=new Uint8Array(bytes.length);
  for(let i=0;i<bytes.length;i++){
    st=xs(st);
    const k=(st>>>((i&3)*8))&255;
    out[i]=bytes[i]^k^((i*37+salt)&255);
  }
  return out;
}
function pack(bytes,seed){
  let st=seed>>>0;
  const out=[];
  for(let p=0;p<bytes.length;p+=4){
    const w=((bytes[p]||0)|((bytes[p+1]||0)<<8)|((bytes[p+2]||0)<<16)|((bytes[p+3]||0)<<24))>>>0;
    st=xs(st);
    out.push((w^st)>>>0);
  }
  return out;
}
function formatNums(a,indent="        "){
  const lines=[];
  let i=0;
  while(i<a.length){
    const n=ri(8,15);
    lines.push(indent+a.slice(i,i+n).join(","));
    i+=n;
  }
  return lines.join(",\n");
}
function bytesChecksum(bytes){ return adler(bytes); }
function randomBytes(n){ return new Uint8Array(crypto.randomBytes(n)); }
function luaArrayRows(rows){
  return rows.map((r,i)=>`        [${i+1}]={${r.join(",")}}`).join(",\n");
}
function configFor(level){
  if(level===1) return {chunk:72,decoyRatio:.30,noiseChance:.25,extraNoise:1};
  if(level===2) return {chunk:48,decoyRatio:.65,noiseChance:.55,extraNoise:2};
  return {chunk:32,decoyRatio:1.00,noiseChance:.85,extraNoise:4};
}

function makeLayer(source,layerNo,strength,watermark){
  const cfg=configFor(strength);
  const sourceBytes=enc(source);
  const sourceHash=adler(sourceBytes);

  const used=new Set();
  const N=Array.from({length:64},()=>randName(used));
  const [
    LIB,POOL,META,CODE,SEEDS,HANDLERS,VM,READMETA,DECRYPT,DECINS,XS,
    PC,REG,OUT,SRC,FN,ERR,A,B,I,J,K,W,V,X,Y,Z,NEXT,OP,R1,R2,R3,
    M,WORDS,LEN,SSEED,WSEED,SALT,HASH,IDX,TEXT,SEED,KEY,TMP,
    BYTE,SHIFT,CUR,REC,ROW,RET,ARG,STATE,COUNT,ENTRY,ORDER,
    Q1,Q2,Q3,Q4,Q5,Q6,Q7,Q8,Q9
  ]=N;

  const H=uniqueNums(15,19,251);
  const [HBX,HBA,HR,HL,HCHAR,HCONCAT,HLOAD,HERROR,HBYTE,HSUB,HLEN,HINSERT,HFLOOR,HUNPACK,HTYPE]=H;

  const OPS=uniqueNums(13,500,64000);
  const [
    O_INIT,O_LOADMETA,O_DECRYPT,O_PUSH,O_VERIFY,
    O_JOIN,O_COMPILE,O_CALL,O_NOISE,O_NOP,O_SET,O_HALT,O_TRAP
  ]=OPS;

  const R=uniqueNums(12,1,63);
  const [
    RG_META,RG_TEXT,RG_SOURCE,RG_FN,RG_ERR,RG_A,RG_B,
    RG_LEN,RG_TMP,RG_MISC1,RG_MISC2,RG_MISC3
  ]=R;

  const realChunks=chunks(sourceBytes,cfg.chunk);
  const payload=[];
  const rawMetaReal=[];

  for(let i=0;i<realChunks.length;i++){
    const block=realChunks[i];
    const sseed=ru32(),wseed=ru32(),salt=ri(1,255);
    const encrypted=crypt(block,sseed,salt);
    const words=pack(encrypted,wseed);
    payload.push(words);
    rawMetaReal.push([
      payload.length,
      block.length,
      sseed,
      wseed,
      salt,
      bytesChecksum(block),
      1,
      i+1
    ]);
  }

  const decoyCount=Math.max(2,Math.ceil(realChunks.length*cfg.decoyRatio));
  const rawMetaDecoy=[];
  for(let i=0;i<decoyCount;i++){
    const len=ri(Math.max(12,Math.floor(cfg.chunk*.45)),cfg.chunk+18);
    const block=randomBytes(len);
    const sseed=ru32(),wseed=ru32(),salt=ri(1,255);
    payload.push(pack(crypt(block,sseed,salt),wseed));
    rawMetaDecoy.push([
      payload.length,
      len,
      sseed,
      wseed,
      salt,
      bytesChecksum(block),
      0,
      0
    ]);
  }

  const tagged=[];
  rawMetaReal.forEach((m,i)=>tagged.push({kind:"real",orig:i,meta:m}));
  rawMetaDecoy.forEach((m,i)=>tagged.push({kind:"decoy",orig:i,meta:m}));
  const shuffledMeta=shuffle(tagged);

  const realMetaIndex=new Array(realChunks.length);
  shuffledMeta.forEach((x,i)=>{
    if(x.kind==="real") realMetaIndex[x.orig]=i+1;
  });

  const metaMaster=ru32();
  const encodedMeta=[];
  for(let i=0;i<shuffledMeta.length;i++){
    const rec=shuffledMeta[i].meta;
    let s=(metaMaster^(i+1)*0x45d9f3b)>>>0;
    const row=[];
    for(let j=0;j<rec.length;j++){
      s=xs(s);
      row.push((rec[j]^s)>>>0);
    }
    encodedMeta.push(row);
  }

  const prog=[];
  prog.push([O_INIT,0,0,0]);
  for(let i=0;i<realMetaIndex.length;i++){
    const mi=realMetaIndex[i];
    prog.push([O_LOADMETA,mi,i+1,0]);
    prog.push([O_DECRYPT,mi,0,0]);

    const noiseN=(Math.random()<cfg.noiseChance)?ri(1,cfg.extraNoise):0;
    for(let n=0;n<noiseN;n++){
      prog.push([O_NOISE,ri(1000,900000),ri(1000,900000),ri(1,255)]);
      if(Math.random()<.35) prog.push([O_NOP,ri(1,9999),0,0]);
    }

    prog.push([O_PUSH,mi,i+1,0]);
  }

  prog.push([O_VERIFY,sourceHash,sourceBytes.length,0]);
  prog.push([O_JOIN,0,0,0]);
  prog.push([O_COMPILE,layerNo,0,0]);
  prog.push([O_CALL,0,0,0]);
  prog.push([O_HALT,0,0,0]);

  const decoyPrograms=[];
  const decoyInstrCount=Math.max(3,Math.floor(prog.length*(strength===3?.75:.35)));
  for(let i=0;i<decoyInstrCount;i++){
    const choices=[O_NOISE,O_NOP,O_SET,O_TRAP];
    decoyPrograms.push([
      choices[ri(0,choices.length-1)],
      ri(1,0x7fffffff),
      ri(1,0x7fffffff),
      ri(1,0x7fffffff)
    ]);
  }

  const logicalRecords=prog.map((ins,i)=>({real:true,logical:i,ins}));
  const physicalRecords=shuffle(
    logicalRecords.concat(decoyPrograms.map((ins)=>({real:false,logical:-1,ins})))
  );

  const physOfLogical=new Array(prog.length);
  physicalRecords.forEach((r,i)=>{
    if(r.real) physOfLogical[r.logical]=i+1;
  });

  const entryPoint=physOfLogical[0];

  const codeMaster=ru32();
  const encodedCode=[];
  const encodedSeeds=[];

  for(let p=0;p<physicalRecords.length;p++){
    const rec=physicalRecords[p];
    const seed=ru32();
    let next=0;

    if(rec.real){
      if(rec.logical+1<prog.length) next=physOfLogical[rec.logical+1];
      else next=0;
    }else{
      const decoyTargets=[];
      for(let z=0;z<physicalRecords.length;z++){
        if(!physicalRecords[z].real) decoyTargets.push(z+1);
      }
      next=Math.random()<.55 && decoyTargets.length
        ? decoyTargets[ri(0,decoyTargets.length-1)]
        : 0;
    }

    let s=seed;
    const vals=[rec.ins[0],rec.ins[1],rec.ins[2],rec.ins[3],next];
    const row=[];
    for(const val of vals){
      s=xs(s);
      row.push((val^s)>>>0);
    }

    const seedMask=xs((codeMaster^(p+1)*0x27d4eb2d)>>>0);
    encodedSeeds.push((seed^seedMask)>>>0);
    encodedCode.push(row);
  }

  const junk1=ri(100000,900000),junk2=ri(100000,900000),junk3=ri(100000,900000);
  const wm=watermark ? "-- volta obfuscator discord.gg/voltrahub\n" : "";

  return `${wm}return (function(...)
    local ${LIB}={
        [${HBX}]=bit32.bxor,
        [${HBA}]=bit32.band,
        [${HR}]=bit32.rshift,
        [${HL}]=bit32.lshift,
        [${HCHAR}]=string.char,
        [${HCONCAT}]=table.concat,
        [${HLOAD}]=loadstring,
        [${HERROR}]=error,
        [${HBYTE}]=string.byte,
        [${HSUB}]=string.sub,
        [${HLEN}]=string.len,
        [${HINSERT}]=table.insert,
        [${HFLOOR}]=math.floor,
        [${HUNPACK}]=table.unpack or unpack,
        [${HTYPE}]=type
    }

    local ${POOL}={
${luaArrayRows(payload)}
    }

    local ${META}={
${luaArrayRows(encodedMeta)}
    }

    local ${CODE}={
${luaArrayRows(encodedCode)}
    }

    local ${SEEDS}={
${formatNums(encodedSeeds)}
    }

    local function ${XS}(${V})
        ${V}=${LIB}[${HBX}](${V},${LIB}[${HL}](${V},13))
        ${V}=${LIB}[${HBX}](${V},${LIB}[${HR}](${V},17))
        ${V}=${LIB}[${HBX}](${V},${LIB}[${HL}](${V},5))
        return ${LIB}[${HBA}](${V},4294967295)
    end

    local function ${READMETA}(${IDX})
        local ${ROW}=${META}[${IDX}]
        local ${STATE}=${LIB}[${HBX}](${metaMaster},(${IDX}*73244475))
        ${STATE}=${LIB}[${HBA}](${STATE},4294967295)
        local ${RET}={}
        for ${I}=1,8 do
            ${STATE}=${XS}(${STATE})
            ${RET}[${I}]=${LIB}[${HBX}](${ROW}[${I}],${STATE})
        end
        return ${RET}
    end

    local function ${DECRYPT}(${ARG})
        local ${M}=${READMETA}(${ARG})
        local ${WORDS}=${POOL}[${M}[1]]
        local ${LEN}=${M}[2]
        local ${SSEED}=${M}[3]
        local ${WSEED}=${M}[4]
        local ${SALT}=${M}[5]
        local ${HASH}=${M}[6]
        local ${OUT}={}
        local ${COUNT}=0
        local ${A}=1
        local ${B}=0

        for ${I}=1,#${WORDS} do
            ${WSEED}=${XS}(${WSEED})
            local ${W}=${LIB}[${HBX}](${WORDS}[${I}],${WSEED})

            for ${J}=0,3 do
                if ${COUNT}>=${LEN} then break end

                local ${SHIFT}=${J}*8
                local ${BYTE}=${LIB}[${HBA}](${LIB}[${HR}](${W},${SHIFT}),255)

                ${SSEED}=${XS}(${SSEED})
                local ${KEY}=${LIB}[${HBA}](
                    ${LIB}[${HR}](${SSEED},(${COUNT}%4)*8),
                    255
                )

                ${BYTE}=${LIB}[${HBX}](${BYTE},${KEY})
                ${BYTE}=${LIB}[${HBX}](
                    ${BYTE},
                    ${LIB}[${HBA}](${COUNT}*37+${SALT},255)
                )

                ${COUNT}=${COUNT}+1
                ${OUT}[${COUNT}]=${LIB}[${HCHAR}](${BYTE})
                ${A}=(${A}+${BYTE})%65521
                ${B}=(${B}+${A})%65521
            end
        end

        if (${B}*65536+${A})~=${HASH} then
            ${LIB}[${HERROR}]("block integrity fault",0)
        end

        return ${LIB}[${HCONCAT}](${OUT})
    end

    local function ${DECINS}(${IDX})
        local ${REC}=${CODE}[${IDX}]
        local ${KEY}=${XS}(
            ${LIB}[${HBX}](${codeMaster},(${IDX}*668265261))
        )
        local ${SEED}=${LIB}[${HBX}](${SEEDS}[${IDX}],${KEY})
        local ${RET}={}

        for ${I}=1,5 do
            ${SEED}=${XS}(${SEED})
            ${RET}[${I}]=${LIB}[${HBX}](${REC}[${I}],${SEED})
        end

        return ${RET}[1],${RET}[2],${RET}[3],${RET}[4],${RET}[5]
    end

    local ${HANDLERS}={}

    ${HANDLERS}[${O_INIT}]=function(${REG},${OUT},${X},${Y},${Z})
        ${REG}[${RG_A}]=1
        ${REG}[${RG_B}]=0
        ${REG}[${RG_LEN}]=0
        ${REG}[${RG_MISC1}]=(${junk1}-${junk1})+1
    end

    ${HANDLERS}[${O_LOADMETA}]=function(${REG},${OUT},${X},${Y},${Z})
        ${REG}[${RG_META}]=${READMETA}(${X})
        ${REG}[${RG_MISC2}]=${Y}
    end

    ${HANDLERS}[${O_DECRYPT}]=function(${REG},${OUT},${X},${Y},${Z})
        ${REG}[${RG_TEXT}]=${DECRYPT}(${X})
    end

    ${HANDLERS}[${O_PUSH}]=function(${REG},${OUT},${X},${Y},${Z})
        local ${TEXT}=${REG}[${RG_TEXT}]
        ${OUT}[#${OUT}+1]=${TEXT}
        ${REG}[${RG_LEN}]=${REG}[${RG_LEN}]+#${TEXT}

        for ${I}=1,#${TEXT} do
            local ${BYTE}=${LIB}[${HBYTE}](${TEXT},${I})
            ${REG}[${RG_A}]=(${REG}[${RG_A}]+${BYTE})%65521
            ${REG}[${RG_B}]=(${REG}[${RG_B}]+${REG}[${RG_A}])%65521
        end
    end

    ${HANDLERS}[${O_VERIFY}]=function(${REG},${OUT},${X},${Y},${Z})
        if (${REG}[${RG_B}]*65536+${REG}[${RG_A}])~=${X} or ${REG}[${RG_LEN}]~=${Y} then
            ${LIB}[${HERROR}]("source integrity fault",0)
        end
    end

    ${HANDLERS}[${O_JOIN}]=function(${REG},${OUT},${X},${Y},${Z})
        ${REG}[${RG_SOURCE}]=${LIB}[${HCONCAT}](${OUT})
    end

    ${HANDLERS}[${O_COMPILE}]=function(${REG},${OUT},${X},${Y},${Z})
        local ${FN},${ERR}=${LIB}[${HLOAD}](${REG}[${RG_SOURCE}],"@vm:"..tostring(${X}))
        ${REG}[${RG_SOURCE}]=nil
        for ${I}=1,#${OUT} do ${OUT}[${I}]=nil end
        if not ${FN} then ${LIB}[${HERROR}](${ERR},0) end
        ${REG}[${RG_FN}]=${FN}
    end

    ${HANDLERS}[${O_NOISE}]=function(${REG},${OUT},${X},${Y},${Z})
        local ${TMP}=${LIB}[${HBX}](${X},${X})
        ${REG}[${RG_TMP}]=${TMP}+(${junk2}-${junk2})+(${Z}-${Z})
        if ${REG}[${RG_TMP}]~=0 then
            ${LIB}[${HERROR}]("vm arithmetic fault",0)
        end
    end

    ${HANDLERS}[${O_NOP}]=function(${REG},${OUT},${X},${Y},${Z})
        ${REG}[${RG_MISC3}]=(${X}-${X})+(${junk3}-${junk3})
    end

    ${HANDLERS}[${O_SET}]=function(${REG},${OUT},${X},${Y},${Z})
        ${REG}[${LIB}[${HBA}](${X},63)]=${LIB}[${HBX}](${Y},${Z})
    end

    ${HANDLERS}[${O_TRAP}]=function(${REG},${OUT},${X},${Y},${Z})
        ${LIB}[${HERROR}]("vm trap",0)
    end

    ${HANDLERS}[${O_HALT}]=function(${REG},${OUT},${X},${Y},${Z})
        return false
    end

    local function ${VM}(...)
        local ${PC}=${entryPoint}
        local ${REG}={}
        local ${OUT}={}

        while ${PC}~=0 do
            local ${OP},${X},${Y},${Z},${NEXT}=${DECINS}(${PC})

            if ${OP}==${O_CALL} then
                return ${REG}[${RG_FN}](...)
            end

            local ${FN}=${HANDLERS}[${OP}]
            if not ${FN} then
                ${LIB}[${HERROR}]("invalid vm opcode",0)
            end

            local ${RET}=${FN}(${REG},${OUT},${X},${Y},${Z})
            if ${RET}==false then return end
            ${PC}=${NEXT}
        end
    end

    return ${VM}(...)
end)(...)`;
}

function obfuscate(source,layers=2,strength=2,watermark=true){
  let out=source;
  for(let i=1;i<=layers;i++){
    out=makeLayer(out,i,strength,watermark && i===layers);
  }
  return out;
}

function walk(dir,out=[]){
  for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
    if(entry.name===".git" || entry.name==="node_modules") continue;
    const full=path.join(dir,entry.name);
    if(entry.isDirectory()) walk(full,out);
    else if(entry.isFile() && entry.name.endsWith(".lua")) out.push(full);
  }
  return out;
}

const files=walk(process.cwd());
if(!files.length) throw new Error("No .lua files found");

for(const file of files){
  const src=fs.readFileSync(file,"utf8");
  if(src.startsWith("-- volta obfuscator discord.gg/voltrahub")){
    console.log("Already obfuscated:",file);
    continue;
  }
  console.log("Obfuscating:",file);
  const out=obfuscate(src,2,2,true);
  fs.writeFileSync(file,out,"utf8");
  console.log("Wrote",out.length,"bytes");
}

// One-time build: remove the temporary builder and workflow before commit.
try{ fs.unlinkSync(path.join(process.cwd(),".github","scripts","obfuscate-once.js")); }catch{}
try{ fs.unlinkSync(path.join(process.cwd(),".github","workflows","obfuscate-once.yml")); }catch{}

