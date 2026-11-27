#!/usr/bin/env python3
"""NightGrid original music candidate factory; ACE-Step 1.5, no publishing."""
import argparse, fcntl, hashlib, json, os, shutil, subprocess, sys, tempfile, time, struct
from pathlib import Path

# id, scene/title, duration, tempo, key, musical direction
CUES = [
('synaxis.arrival.security-pulse','Terms of Employment — HQ arrival',42,82,'D minor','Restrained corporate surveillance score; sub-bass pulse, glassy digital ticks, long cold synth chords, restrained suspense; sparse under dialogue, no big drop.'),
('synaxis.offboarding.empty-floor','Your Access Has Expired — offboarding',60,68,'D minor','Hollow electric piano, low analog drone, weary minor-key intervals, almost no percussion, restrained human sadness amid a sterile corporate environment.'),
('synaxis.lobby.after-hours','Glass and Concrete — HQ lobby',78,76,'D minor','Elegant unsettling corporate ambient, muted mallet motifs, airy synth strings, distant mechanical rhythm, warm reflections against a cold harmonic bed.'),
('synaxis.basement.server-room','Below the Surface — IT basement',84,92,'F minor','Hypnotic minimal electronic score; quiet sequenced bass, brittle metallic ticks, low electrical texture and nervous sparse motifs; no dramatic climax.'),
('synaxis.departure.street','No Longer an Employee — street departure',90,88,'D minor','Cinematic noir electronics; fragile electric piano evolving into a determined analog bassline, slow drums, bittersweet restrained transition from defeat to freedom.'),
('morrow.title.theme','Morrow Bay — main theme',120,96,'D minor','Distinct original four-note synth motif, warm analog bass, dark orchestral strings, distant industrial percussion; slow build and memorable understated resolution.'),
('central-exchange.day','Glass District — daylight exploration',100,112,'A minor','Sophisticated future city instrumental, brushed electronic percussion, buoyant subdued bass and glassy electric keys, steady urban momentum without crowding dialogue.'),
('brickwater.night','Rain in Brickwater — night exploration',110,82,'F minor','Rain-soaked dub techno and noir ambient, deep chord stabs, long filtered delays, muted kick, worn tape texture, slow subtle progression.'),
('vesper.market','Vesper After Dark — market',96,108,'G minor','Warm crowded nighttime market groove, plucked synth, syncopated drum machine, round bass, lively but understated futuristic street atmosphere.'),
('horizon.commons','A Place to Breathe — park',96,72,'C major','Intimate calm ambient score, felt piano, softly shifting synth harmonics and barely audible percussion; hopeful without sentimentality.'),
('north-quay.harbor','Salt in the Circuit — harbor',90,74,'E minor','Wide atmospheric electronic score, distant metallic resonances, slow pulsing bass, sparse low strings, melancholy coastal industrial atmosphere.'),
('southworks.industrial','Shift Change — industrial district',96,104,'F minor','Industrial downtempo groove with mechanical percussion, rubbery synth bass, muted abrasive textures and sparse metallic melodic fragments.'),
('m-line.transit','Last Train to Helix — transit',84,108,'A minor','Rhythmic minimalist electronic travel music, steady train-like percussion, soft arpeggios and warm filtered bass, smooth unobtrusive development.'),
('courier.delivery','Quota Drop — delivery',96,120,'D minor','Propulsive restrained breakbeat instrumental, tight syncopated drums, elastic bass and short melodic synth figures, purposeful forward motion.'),
('pursuit.alert','Signal Intercept — alert',60,126,'F minor','Tense pulsing synth bass, dry syncopated percussion, unstable minor harmonies, escalating but controlled energy, no vocals or alarm sound effects.'),
('pursuit.escape','Lost in the Grid — chase',90,150,'F minor','Urgent industrial drum and bass, tight breakbeats and distorted low end, angular synth ostinato, clear rhythmic drive, leave room for engine sounds.'),
('pursuit.cooldown','Out of Sight — cooldown',60,80,'F minor','Fading tension, muted kick and breathing low synth chords, descending bass pattern, sparse electronic textures, gradual emotional release.'),
('brickwater.arcade.attract-loop','Insert Cred — arcade attract',24,142,'C minor','Original retro FM-synthesis arcade instrumental, playful short arpeggios, punchy electronic drums, distinctive original hook, even dynamics and loop-friendly ending.'),
('brickwater.arcade.racing','Patch Day Raceway — cabinet race',60,156,'E minor','High-energy original 16-bit-inspired FM racing music, bright angular lead, driving bass, crisp drum machine, repeating groove and loop-friendly ending.'),
('afterhours.club.original-break','Under the Overpass — club band',90,138,'E minor','Raw original industrial punk instrumental, live-feeling drums, distorted electric bass, gritty guitar and sequenced synths, energetic underground club performance.'),
('vesper.club.floor','Neon Sweat — dance floor',120,132,'A minor','Original hypnotic warehouse techno instrumental, firm four-on-the-floor kick, rolling analog bass, evolving metallic hats and restrained acid synth, continuous club groove.'),
('lantern.cup.lounge','Late Coffee — cafe',90,84,'G minor','Laid-back instrumental future jazz, Rhodes electric piano, upright-style bass, brushed drum texture and warm understated melodic improvisation.'),
('morrow.home.safe','A Room of Your Own — apartment',90,70,'D minor','Intimate atmospheric electronic instrumental, quiet tape-worn piano, gentle warm pads, sparse soft bass, peaceful refuge from the city.'),
('morrow.credits','Tomorrow Is Not Guaranteed — credits',120,90,'D minor','Original bittersweet cinematic electronic finale, fragile piano evolving into broad analog harmonies, restrained drums, reflective and quietly defiant, natural ending.'),
]
HOME=Path('/home/anubis/AI/ACE-Step-1.5')
NAS=Path('/mnt/z/NightGrid-Afterhours')
DIT='acestep-v15-turbo'; LM='acestep-5Hz-lm-0.6B'

def sha(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for block in iter(lambda:f.read(8*1024*1024),b''): h.update(block)
    return h.hexdigest()

def digest(data):
    return hashlib.sha256(json.dumps(data,sort_keys=True,ensure_ascii=True).encode()).hexdigest()

def atomic_json(path,obj):
    tmp=path.with_name(path.name+'.partial')
    tmp.write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    os.replace(tmp,path)

def checkpoint_record():
    files={}
    for name in [DIT,LM,'vae','Qwen3-Embedding-0.6B']:
        folder=HOME/'checkpoints'/name
        weights=sorted(folder.rglob('*.safetensors'))
        if not weights: raise RuntimeError('Missing local weights: '+str(folder))
        for path in sorted(folder.rglob('*')):
            if path.is_file() and (path.suffix in ('.safetensors','.pt','.json','.py','.txt','.jinja') or path.name.startswith('LICENSE')):
                files[str(path.relative_to(HOME/'checkpoints'))]=sha(path)
    return {'source_commit':subprocess.check_output(['git','-C',str(HOME),'rev-parse','HEAD'],text=True).strip(),'dit':DIT,'lm':LM,'files_sha256':files}

def gpu_guard():
    smi=shutil.which('nvidia-smi') or '/usr/lib/wsl/lib/nvidia-smi'
    lines=subprocess.check_output([smi,'--query-gpu=temperature.gpu,memory.used,memory.total','--format=csv,noheader,nounits'],text=True,timeout=10).strip().splitlines()
    if len(lines)!=1: raise RuntimeError('Expected the one Anubis GPU')
    temp,used,total=lines[0].split(',')
    try: t=float(temp)
    except ValueError: raise RuntimeError('GPU temperature unavailable; stop rather than run unmonitored')
    if not 0<t<85: raise RuntimeError('GPU temperature guard: '+temp)
    print(f'GPU: {t:.1f} C, {used.strip()}/{total.strip()} MiB',flush=True)
    return float(used),float(total)

def audio_info(path):
    """Validate classic and extensible little-endian integer PCM RIFF WAVs.

    FFmpeg writes 24-bit PCM as WAVE_FORMAT_EXTENSIBLE, which Python's
    wave module cannot read before Python 3.12. No model dependencies.
    """
    pcm_guid = bytes.fromhex('0100000000001000800000aa00389b71')
    with open(path, 'rb') as f:
        size = os.fstat(f.fileno()).st_size
        header = f.read(12)
        if len(header) != 12 or header[:4] != b'RIFF' or header[8:] != b'WAVE':
            raise ValueError('Expected RIFF/WAVE master')
        end = 8 + struct.unpack_from('<I', header, 4)[0]
        if end != size:
            raise ValueError('Truncated or inconsistent RIFF master')
        fmt = None; data_bytes = None
        while f.tell() < end:
            chunk = f.read(8)
            if len(chunk) != 8:
                raise ValueError('Truncated WAV chunk header')
            name, length = struct.unpack('<4sI', chunk)
            start = f.tell(); next_chunk = start + length + (length & 1)
            if next_chunk > end:
                raise ValueError('Truncated WAV chunk payload')
            if name == b'fmt ':
                if fmt is not None or length < 16:
                    raise ValueError('Invalid or duplicate WAV format chunk')
                raw = f.read(min(length, 40))
                tag, ch, sr, byte_rate, align, bits = struct.unpack_from('<HHIIHH', raw)
                if tag == 0xfffe:
                    if (length < 40 or struct.unpack_from('<H', raw, 16)[0] < 22
                            or 18 + struct.unpack_from('<H', raw, 16)[0] > length
                            or raw[24:40] != pcm_guid
                            or struct.unpack_from('<H', raw, 18)[0] != bits):
                        raise ValueError('Expected extensible integer PCM')
                elif tag != 1:
                    raise ValueError('Expected integer PCM')
                if (ch != 2 or sr not in (44100, 48000) or bits not in (16, 24)
                        or align != ch * (bits // 8) or byte_rate != sr * align):
                    raise ValueError('Invalid PCM master format')
                fmt = (ch, sr, bits, align)
            elif name == b'data':
                if data_bytes is not None:
                    raise ValueError('Duplicate WAV data chunk')
                data_bytes = length
            f.seek(next_chunk)
        if fmt is None or data_bytes is None:
            raise ValueError('Missing WAV format or data chunk')
        ch, sr, bits, align = fmt
        if data_bytes <= 0 or data_bytes % align:
            raise ValueError('Incomplete PCM frames')
        n = data_bytes // align
    return {'seconds':round(n/sr,3),'sample_rate':sr,'channels':ch,'bit_depth':bits}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--plan',action='store_true'); p.add_argument('--limit',type=int,default=0,help='Maximum NEW takes this invocation; 0=all')
    p.add_argument('--takes',type=int,default=2); p.add_argument('--batch',default='music-001')
    a=p.parse_args()
    if not 1<=a.takes<=8 or a.limit<0 or not __import__('re').fullmatch(r'music-[a-zA-Z0-9-]+',a.batch): p.error('Invalid batch/takes/limit')
    jobs=[]
    for i,(cue,scene,dur,bpm,key,direction) in enumerate(CUES):
        for take in range(1,a.takes+1):
            jobs.append(dict(id=f'{cue}.take-{take:02}',scene=scene,duration=dur,bpm=bpm,key=key,direction=direction+' Original instrumental only; no vocals, no borrowed melodies.',seed=271100+i*100+take))
    print(f'{len(CUES)} cues, {len(jobs)} takes, {sum(j["duration"] for j in jobs)/60:.1f} minutes of target audio',flush=True)
    if a.plan:
        for j in jobs: print(j['id'],j['duration'],j['bpm'],j['seed'])
        return
    if not os.path.ismount('/mnt/z') or not NAS.is_dir(): raise RuntimeError('NAS is not mounted')
    if shutil.disk_usage(NAS).free<10*1024**3 or shutil.disk_usage('/mnt/c').free<25*1024**3: raise RuntimeError('Disk reserve guard')
    # This lock serializes this runner across batches; existing factory/UI/Novel Generator must be idle.
    lock=open(Path.home()/'.nightgrid-music.lock','a')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    if (NAS/'Audio'/'factory-001'/'.audio.lock').exists(): raise RuntimeError('Audio stage lock present; inspect before retrying')
    if not HOME.is_dir(): raise RuntimeError('ACE-Step installation not found')
    if not shutil.which('ffmpeg'): raise RuntimeError('ffmpeg not found')
    with tempfile.TemporaryDirectory(prefix='nightgrid-wav-preflight-') as tmp:
        probe=Path(tmp)/'probe.wav'
        subprocess.run(['ffmpeg','-nostdin','-hide_banner','-loglevel','error','-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-t','0.1','-c:a','pcm_s24le',str(probe)],check=True)
        if audio_info(probe) != {'seconds':0.1,'sample_rate':48000,'channels':2,'bit_depth':24}:
            raise RuntimeError('PCM24 export preflight failed')
        print('PCM24 export preflight passed',flush=True)
    out=NAS/'Music'/a.batch; out.mkdir(parents=True,exist_ok=True)
    os.chdir(HOME); sys.path.insert(0,str(HOME))
    os.environ['HF_HUB_OFFLINE']='1'; os.environ['TRANSFORMERS_OFFLINE']='1'
    used,total=gpu_guard()
    if total-used<8*1024: raise RuntimeError('Less than 8 GiB VRAM free; close ACE-Step UI and other GPU jobs first')
    print('Fingerprinting installed checkpoints...',flush=True)
    provenance=checkpoint_record(); checkpoint=digest(provenance)
    provenance_path=out/'checkpoint.json'
    if provenance_path.exists() and json.loads(provenance_path.read_text())!=provenance: raise RuntimeError('Checkpoint changed; choose a new --batch')
    atomic_json(provenance_path,provenance)
    entries=[]; pending=[]
    for j in jobs:
        name=j['id']; wav=out/(name+'.wav'); meta=out/(name+'.json')
        spec={'job':j,'checkpoint':checkpoint,'steps':8,'shift':3.0,'thinking':True,'instrumental':True,'batch_size':1,'encoding':'pcm_s24le/48000/stereo'}
        fingerprint=digest(spec)
        if meta.exists():
            row=json.loads(meta.read_text(encoding='utf-8'))
            if row.get('fingerprint')!=fingerprint or not wav.is_file() or sha(wav)!=row.get('sha256'): raise RuntimeError('Existing take mismatch: '+name+'; preserve and inspect or use a new batch')
            audio_info(wav); entries.append(row); print('SKIP verified',name,flush=True)
        elif wav.exists(): raise RuntimeError('Uncommitted WAV exists; inspect before resuming: '+name)
        else: pending.append((j,wav,meta,fingerprint))
    def manifest(): atomic_json(out/'manifest.json',{'schema':1,'candidates':entries})
    manifest()
    if not pending: print('Batch complete'); return
    from acestep.handler import AceStepHandler
    from acestep.llm_inference import LLMHandler
    from acestep.inference import GenerationParams, GenerationConfig, generate_music
    dit=AceStepHandler(); lm=LLMHandler()
    msg,ok=dit.initialize_service(project_root=str(HOME),config_path=DIT,device='cuda',offload_to_cpu=True,quantization='int8_weight_only')
    if not ok: raise RuntimeError(str(msg))
    msg,ok=lm.initialize(checkpoint_dir=str(HOME/'checkpoints'),lm_model_path=LM,backend='vllm',device='cuda')
    if not ok: raise RuntimeError(str(msg))
    for j,wav,meta,fingerprint in (pending[:a.limit] if a.limit else pending):
        if not os.path.ismount('/mnt/z'): raise RuntimeError('NAS mount lost')
        if shutil.disk_usage(out).free<10*1024**3 or shutil.disk_usage('/mnt/c').free<25*1024**3: raise RuntimeError('Disk reserve guard')
        gpu_guard(); print('GENERATE',j['id'],flush=True); start=time.monotonic()
        with tempfile.TemporaryDirectory(prefix='nightgrid-music-') as tmp:
            params=GenerationParams(task_type='text2music',caption=j['direction'],lyrics='[Instrumental]',instrumental=True,thinking=True,bpm=j['bpm'],keyscale=j['key'],timesignature='4',duration=j['duration'],seed=j['seed'],inference_steps=8,guidance_scale=1.0,shift=3.0)
            config=GenerationConfig(batch_size=1,use_random_seed=False,seeds=[j['seed']],audio_format='wav')
            result=generate_music(dit,lm,params,config,save_dir=tmp)
            if not result.success or len(result.audios)!=1: raise RuntimeError('Generation failed: '+str(result.status_message))
            item=result.audios[0]; source=Path(item['path']); partial=wav.with_name(wav.stem+'.partial.wav')
            if partial.exists():
                preserved=partial.with_name(partial.stem+f'.previous-{time.time_ns()}.wav')
                os.replace(partial,preserved)
                print('PRESERVED previous scratch:',preserved,flush=True)
            subprocess.run(['ffmpeg','-nostdin','-hide_banner','-loglevel','error','-i',str(source),'-ac','2','-ar','48000','-c:a','pcm_s24le',str(partial)],check=True)
            info=audio_info(partial)
            if abs(info['seconds']-j['duration'])>max(4,j['duration']*.12): raise RuntimeError(f'Unexpected duration for {j["id"]}: {info}')
            row={'id':j['id'],'file':wav.name,'sha256':sha(partial),'model':'ace-step','checkpoint':f'{DIT}+{LM}; sha256:{checkpoint}','scene':j['scene'],'direction':j['direction'],'rights_notes':'Candidate only; exact model and output rights review pending; not for release','reviewed':False,'fingerprint':fingerprint,'requested_seed':j['seed'],'reported_seed':str(item.get('params',{}).get('seed','unknown')),'requested_duration':j['duration'],'audio':info,'elapsed_seconds':round(time.monotonic()-start,2)}
            os.replace(partial,wav); atomic_json(meta,row); entries.append(row); manifest()
            print('SAVED',wav.name,info,flush=True)
        gpu_guard()
    print(f'Verified candidates: {len(entries)}/{len(jobs)}; {out}',flush=True)

if __name__=='__main__':
    try: main()
    except (Exception,KeyboardInterrupt) as exc:
        print(f'STOP: {exc}',file=sys.stderr,flush=True); sys.exit(1)
