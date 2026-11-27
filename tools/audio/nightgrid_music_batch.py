#!/usr/bin/env python3
"""NightGrid original music candidate factory; ACE-Step 1.5, no publishing."""
import argparse, fcntl, hashlib, json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path
from music_pcm import pcm_info

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
PROFILES = {
    'legacy': dict(dit=DIT, lm=LM, steps=8, guidance=1.0, lm_backend='vllm',
                   lm_device='cuda', lm_offload=False, dit_offload=False,
                   quantization='int8_weight_only'),
    'studio': dict(dit='acestep-v15-sft', lm='acestep-5Hz-lm-1.7B',
                   steps=50, guidance=7.0, lm_backend='pt', lm_device='cuda',
                   lm_offload=True, dit_offload=True, quantization='int8_weight_only'),
    'studio-4b-cpu': dict(dit='acestep-v15-sft', lm='acestep-5Hz-lm-4B',
                   steps=50, guidance=7.0, lm_backend='pt', lm_device='cpu',
                   lm_offload=False, dit_offload=True, quantization='int8_weight_only'),
}

def available_ram_gib():
    for line in Path('/proc/meminfo').read_text().splitlines():
        if line.startswith('MemAvailable:'):
            return int(line.split()[1]) / 1024**2
    raise RuntimeError('Unable to measure available host RAM')

def check_profile_ram(name):
    if name == 'legacy':
        return
    minimum = 16 if name == 'studio' else 24
    available = available_ram_gib()
    if available < minimum:
        raise RuntimeError(f'{name} requires at least {minimum} GiB available WSL RAM for this pilot; found {available:.1f}')
    print(f'Available WSL RAM: {available:.1f} GiB', flush=True)

def initialize_models(dit, lm, profile, name):
    dit_args = dict(project_root=str(HOME), config_path=profile['dit'],
                    device='cuda', offload_to_cpu=True, quantization=profile['quantization'])
    lm_args = dict(checkpoint_dir=str(HOME/'checkpoints'), lm_model_path=profile['lm'],
                   backend=profile['lm_backend'], device=profile['lm_device'])
    if name != 'legacy':
        dit_args['offload_dit_to_cpu'] = profile['dit_offload']
        lm_args['offload_to_cpu'] = profile['lm_offload']
    msg, ok = dit.initialize_service(**dit_args)
    if not ok:
        raise RuntimeError(str(msg))
    msg, ok = lm.initialize(**lm_args)
    if not ok:
        raise RuntimeError(str(msg))
    if name != 'legacy':
        if getattr(lm, 'device', None) != profile['lm_device']:
            raise RuntimeError('LM device differs from requested studio profile')
        if bool(getattr(lm, 'offload_to_cpu', None)) != profile['lm_offload']:
            raise RuntimeError('LM offload differs from requested studio profile')
        if not getattr(dit, 'offload_to_cpu', False) or not getattr(dit, 'offload_dit_to_cpu', False):
            raise RuntimeError('DiT offload configuration not confirmed')


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

def checkpoint_record(profile=PROFILES['legacy'], name='legacy'):
    files={}
    for model_name in [profile['dit'],profile['lm'],'vae','Qwen3-Embedding-0.6B']:
        folder=HOME/'checkpoints'/model_name
        weights=sorted(folder.rglob('*.safetensors'))
        if not weights: raise RuntimeError('Missing local weights: '+str(folder))
        for path in sorted(folder.rglob('*')):
            if path.is_file() and (path.suffix in ('.safetensors','.pt','.json','.py','.txt','.jinja') or path.name.startswith('LICENSE')):
                files[str(path.relative_to(HOME/'checkpoints'))]=sha(path)
    record = {'source_commit':subprocess.check_output(['git','-C',str(HOME),'rev-parse','HEAD'],text=True).strip(),'dit':profile['dit'],'lm':profile['lm'],'files_sha256':files}
    if name != 'legacy': record['generation_profile'] = dict(profile, name=name)
    return record

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
    info = pcm_info(path)
    info["seconds"] = round(info["seconds"], 3)
    return info

def cue_palette(name):
    if name == 'legacy':
        return CUES
    if name != 'neon-grunge-v1':
        raise ValueError('Unknown music palette')
    catalog = json.loads(Path(__file__).with_name('neon_grunge_palette.json').read_text(encoding='utf-8'))
    directions = catalog.get('directions')
    if (catalog.get('schema') != 1 or catalog.get('id') != name
            or not isinstance(directions, dict)
            or set(directions) != {row[0] for row in CUES}
            or any(not isinstance(value, str) or not value.strip() for value in directions.values())):
        raise ValueError('Invalid or incomplete neon-grunge cue palette')
    return [(*row[:-1], directions[row[0]]) for row in CUES]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--plan',action='store_true'); p.add_argument('--limit',type=int,default=0,help='Maximum NEW takes this invocation; 0=all')
    p.add_argument('--takes',type=int,default=2); p.add_argument('--batch',default='music-001')
    p.add_argument('--palette', choices=['legacy','neon-grunge-v1'], default='legacy')
    p.add_argument('--profile', choices=list(PROFILES), default='legacy')
    a=p.parse_args()
    profile=PROFILES[a.profile]
    if not 1<=a.takes<=8 or a.limit<0 or not __import__('re').fullmatch(r'music-[a-zA-Z0-9-]+',a.batch): p.error('Invalid batch/takes/limit')
    if a.palette == 'neon-grunge-v1' and not a.batch.startswith('music-neon-grunge-'):
        p.error('Neon-grunge requires a separate --batch music-neon-grunge-001 (or another music-neon-grunge-* name)')
    if a.palette == 'legacy' and a.batch.startswith('music-neon-grunge-'):
        p.error('Neon-grunge batch names require --palette neon-grunge-v1')
    if a.profile != 'legacy' and (a.palette != 'neon-grunge-v1' or not a.batch.startswith('music-neon-grunge-'+a.profile+'-')):
        p.error('Studio profiles require --palette neon-grunge-v1 and a separate music-neon-grunge-'+a.profile+'-* batch')
    if a.profile == 'legacy' and a.batch.startswith('music-neon-grunge-studio-'):
        p.error('Studio batch requires its explicit matching --profile')
    if a.profile == 'studio' and a.batch.startswith('music-neon-grunge-studio-4b-cpu-'):
        p.error('4B batch requires --profile studio-4b-cpu')
    cues=cue_palette(a.palette)
    jobs=[]
    for i,(cue,scene,dur,bpm,key,direction) in enumerate(cues):
        for take in range(1,a.takes+1):
            jobs.append(dict(id=f'{cue}.take-{take:02}',scene=scene,duration=dur,bpm=bpm,key=key,direction=direction+' Original instrumental only; no vocals, no borrowed melodies.',seed=271100+i*100+take))
    print(f'{len(CUES)} cues, {len(jobs)} takes, {sum(j["duration"] for j in jobs)/60:.1f} minutes of target audio',flush=True)
    if a.plan:
        if a.palette != 'legacy': print('Palette:', a.palette, 'Batch:', a.batch)
        if a.profile != 'legacy': print('Profile:', a.profile, json.dumps(profile, sort_keys=True))
        for j in jobs:
            print(j['id'],j['duration'],j['bpm'],j['seed'])
            if a.palette != 'legacy': print('  '+j['direction'])
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
    check_profile_ram(a.profile)
    print('Fingerprinting installed checkpoints...',flush=True)
    provenance=checkpoint_record(profile, a.profile); checkpoint=digest(provenance)
    provenance_path=out/'checkpoint.json'
    if provenance_path.exists() and json.loads(provenance_path.read_text())!=provenance: raise RuntimeError('Checkpoint changed; choose a new --batch')
    atomic_json(provenance_path,provenance)
    entries=[]; pending=[]
    for j in jobs:
        name=j['id']; wav=out/(name+'.wav'); meta=out/(name+'.json')
        spec={'job':j,'checkpoint':checkpoint,'steps':profile['steps'],'shift':3.0,'thinking':True,'instrumental':True,'batch_size':1,'encoding':'pcm_s24le/48000/stereo'}
        if a.profile != 'legacy': spec['generation_profile'] = dict(profile, name=a.profile)
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
    initialize_models(dit, lm, profile, a.profile)
    for j,wav,meta,fingerprint in (pending[:a.limit] if a.limit else pending):
        if not os.path.ismount('/mnt/z'): raise RuntimeError('NAS mount lost')
        if shutil.disk_usage(out).free<10*1024**3 or shutil.disk_usage('/mnt/c').free<25*1024**3: raise RuntimeError('Disk reserve guard')
        gpu_guard(); print('GENERATE',j['id'],flush=True); start=time.monotonic()
        with tempfile.TemporaryDirectory(prefix='nightgrid-music-') as tmp:
            params=GenerationParams(task_type='text2music',caption=j['direction'],lyrics='[Instrumental]',instrumental=True,thinking=True,bpm=j['bpm'],keyscale=j['key'],timesignature='4',duration=j['duration'],seed=j['seed'],inference_steps=profile['steps'],guidance_scale=profile['guidance'],shift=3.0)
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
            row={'id':j['id'],'file':wav.name,'sha256':sha(partial),'model':'ace-step','checkpoint':f'{profile["dit"]}+{profile["lm"]}; sha256:{checkpoint}','scene':j['scene'],'direction':j['direction'],'rights_notes':'Candidate only; exact model and output rights review pending; not for release','reviewed':False,'fingerprint':fingerprint,'requested_seed':j['seed'],'reported_seed':str(item.get('params',{}).get('seed','unknown')),'requested_duration':j['duration'],'audio':info,'elapsed_seconds':round(time.monotonic()-start,2)}
            if a.profile != 'legacy': row['generation_profile'] = dict(profile, name=a.profile)
            os.replace(partial,wav); atomic_json(meta,row); entries.append(row); manifest()
            print('SAVED',wav.name,info,flush=True)
        gpu_guard()
    print(f'Verified candidates: {len(entries)}/{len(jobs)}; {out}',flush=True)

if __name__=='__main__':
    try: main()
    except (Exception,KeyboardInterrupt) as exc:
        print(f'STOP: {exc}',file=sys.stderr,flush=True); sys.exit(1)
