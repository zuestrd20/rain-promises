#!/usr/bin/env python3
"""Original score for 雨停之前的約定. No recordings, samples or soundfonts.
All musical pitches, harmony, and rhythms below are explicitly composed.
Noise is used only for synthesized mechanical/percussive/rain sounds.
Requires Python 3 + numpy + scipy, and ffmpeg (libvorbis encoder).
"""
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile
import hashlib, json, subprocess, math

ROOT=Path(__file__).resolve().parent
SR=44100
RNG=np.random.default_rng(11042026)

def hz(m): return 440.0*2**((m-69)/12)
def stereo(x,pan=0):
    a=(pan+1)*np.pi/4
    return np.column_stack((x*np.cos(a),x*np.sin(a))).astype(np.float32)

def piano(m,dur,vel=1,kind='felt'):
    # Decaying inharmonic partials, with a soft non-sinusoidal felt strike.
    length=dur+2.7
    t=np.arange(round(length*SR),dtype=np.float64)/SR
    f=hz(m); y=np.zeros_like(t)
    for k in range(1,9):
        amp=(1/k**1.75)*(1 if kind=='felt' else .8**(k-1))
        decay=(1.1+dur*.26)/(1+.32*(k-1))*(.85 if m>77 else 1)
        y+=amp*np.sin(2*np.pi*f*k*(1+.00011*k*k)*t)*np.exp(-t/decay)
    if kind=='ep':
        y=.72*y+.26*np.sin(2*np.pi*f*t+1.1*np.sin(2*np.pi*f*2*t)*np.exp(-t/1.1))*np.exp(-t/(1.5+dur*.3))
    env=(1-np.exp(-t/.006))*np.where(t<dur,1,np.exp(-(t-dur)/.24))
    # Quiet hammer: deterministic noise, tightly low-passed and decaying.
    n=signal.lfilter([.12],[1,-.88],RNG.normal(size=len(t)))*np.exp(-t/.018)
    y=(y*env+.024*n)*vel*.27
    return y.astype(np.float32)

def bell(m,dur,vel=1):
    t=np.arange(round((dur+2)*SR))/SR; f=hz(m)
    y=(np.sin(2*np.pi*f*t)*np.exp(-t/1.25)+.26*np.sin(2*np.pi*f*2.003*t)*np.exp(-t/.5)+.07*np.sin(2*np.pi*f*3.99*t)*np.exp(-t/.18))
    y*=np.minimum(t/.008,1)*np.where(t<dur,1,np.exp(-(t-dur)/.4))
    return (y*vel*.18).astype(np.float32)

def pad(notes,dur,vel=1):
    t=np.arange(round((dur+1.7)*SR))/SR
    y=np.zeros((len(t),2))
    for j,m in enumerate(notes):
        f=hz(m)
        for side,detune in enumerate([-.004,.004]):
            y[:,side]+=(np.sin(2*np.pi*f*(1+detune)*t+j*.47)+.18*np.sin(2*np.pi*f*2*(1-detune)*t))* (.9+.1*np.sin(2*np.pi*.23*t+j))
    env=np.minimum(t/.65,1)*np.minimum(np.maximum((dur+1.5-t)/1.5,0),1)
    return (y*env[:,None]*vel*.029).astype(np.float32)

def bass(m,dur,vel=1):
    t=np.arange(round((dur+.2)*SR))/SR; f=hz(m)
    y=(np.sin(2*np.pi*f*t)+.18*np.sin(4*np.pi*f*t)+.05*np.sin(6*np.pi*f*t))
    env=(1-np.exp(-t/.016))*np.exp(-t/(dur*1.2))*np.minimum(np.maximum((dur+.16-t)/.18,0),1)
    return (y*env*vel*.21).astype(np.float32)

def wood(vel=1):
    t=np.arange(round(.16*SR))/SR
    y=(np.sin(2*np.pi*485*t)*np.exp(-t/ .019)+.37*np.sin(2*np.pi*817*t)*np.exp(-t/.009))*(1-np.exp(-t/.0007))
    return (y*vel*.08).astype(np.float32)
def brush(vel=1):
    t=np.arange(round(.13*SR))/SR
    n=RNG.normal(size=len(t)); n=signal.lfilter([1,-1],[1,-.55],n)
    env=(1-np.exp(-t/.004))*np.exp(-t/.035)
    return (n*env*vel*.009).astype(np.float32)
def kick(vel=1):
    t=np.arange(round(.28*SR))/SR
    phase=2*np.pi*(57*t+26*.025*(1-np.exp(-t/.025)))
    return (np.sin(phase)*(1-np.exp(-t/.003))*np.exp(-t/.073)*vel*.16).astype(np.float32)

D=[62,66,69,73]; Bm=[59,62,66,69]; G=[55,59,62,66]; A=[57,61,64,69]; Fs=[54,57,61,64]; E=[52,55,59,66]
F=[53,57,60,64]; Dm=[50,53,57,64]; Bb=[58,62,65,69]; Gm=[55,58,62,65]; C=[60,64,67,70]; Am=[57,60,64,67]
B=[59,62,66,73]; As=[57,59,64,69]; Fss=[54,59,61,66]
AA=[57,61,64,71]; D2=[62,66,69,73]; EE=[52,56,59,66]; FF=[54,57,61,68]; CC=[61,64,68,71]; BB=[59,62,66,69]
# Each list describes a full bar: (beat offset, beat duration, MIDI note).
city=[[(0, .8,78),(1.5,.4,76),(2,1,73),(3.5,.4,74)],[(.5,.8,73),(1.5,.4,71),(2.5,1.2,69)],[(0,1.3,71),(1.5,.5,74),(2.5,.5,78),(3.5,.4,76)],[(0,1.5,73),(2,.7,71),(3,.8,69)],[(.5,.6,73),(1.5,.5,76),(2.5,1.3,78)],[(0,.8,78),(1,1,74),(2.5,1.2,73)],[(0,1,71),(1.5,.5,69),(2.5,1,67)],[(0,1.2,69),(1.5,.5,73),(2.5,1.2,74)]]
cityB=[[(0,1,79),(1.5,.5,78),(2.5,1,74)],[(.5,.5,76),(1.5,.5,73),(2.5,1,76)],[(0,1.5,78),(2,.5,76),(3,.7,73)],[(.5,.7,74),(1.5,.4,78),(2.5,1,81)],[(0,1,79),(1.5,.5,78),(2.5,1,76)],[(0,1,76),(1.5,.5,73),(3,.8,69)],[(0,1,71),(1.5,.5,74),(2.5,1,78)],[(0,1.4,76),(2,.6,73),(3,.7,69)]]
warm=[[(0,1.2,69),(1.5,.6,72),(2.5,1.2,76)],[(.5,1.2,77),(2,1.5,76)],[(0,1,74),(1.5,.5,72),(2.5,1,70)],[(.5,.5,67),(1.5,.5,70),(2.5,1.2,72)],[(0,1,72),(1.5,.5,76),(2.5,1,79)],[(0,1.4,77),(2,1.4,74)],[(.5,.7,74),(1.5,.5,72),(2.5,1,70)],[(0,1.5,67),(2,.7,69),(3,.7,72)]]
warmB=[[(0,1.5,77),(2,.5,81),(3,.7,79)],[(.5,1,76),(2,1.6,74)],[(0,1,76),(1.5,.5,79),(2.5,1,81)],[(0,1,77),(1.5,.5,76),(2.5,1,74)],[(.5,1,74),(2,1.4,77)],[(0,1.5,76),(2,.5,74),(3,.7,72)],[(0,1,74),(1.5,.5,77),(2.5,1,81)],[(.5,1.2,79),(2,1.5,76)]]
reflection=[[(0,1.7,73),(2.5,1,74)],[(.5,2.2,71)],[(0,1.3,69),(2,1.5,66)],[(.5,1.2,64),(2.5,1,69)],[(0,1.5,67),(2,1.5,66)],[(.5,1.3,62),(2.5,1,66)],[(0,1.2,71),(2,1.5,69)],[(.5,1.5,64),(2.5,1,61)]]
reflectionB=[[(0,1.3,71),(2,1.6,76)],[(.5,1.5,74),(2.5,1,71)],[(0,1.5,73),(2,1.5,69)],[(.5,1,66),(2,1.7,61)]]
ending=[[(0,.7,76),(1,.6,73),(2,1.5,71)],[(0,1.4,69),(2,.7,73),(3,.7,76)],[(.5,.6,78),(1.5,.5,76),(2.5,1.2,73)],[(0,1.5,71),(2,1.5,68)],[(0,1,73),(1.5,.5,76),(2.5,1,80)],[(0,1.5,78),(2,.7,76),(3,.7,73)],[(.5,1,74),(2,1.5,73)],[(0,1.5,71),(2,1.5,69)]]
endingB=[[(0,1.3,81),(1.5,.5,78),(2.5,1,76)],[(0,1.3,80),(2,.6,78),(3,.7,76)],[(.5,.7,78),(1.5,.5,81),(2.5,1,85)],[(0,1.5,83),(2,1.5,80)],[(0,1,81),(1.5,.5,78),(2.5,1,76)],[(.5,1.2,78),(2,1.5,76)],[(0,1.5,74),(2,.6,73),(3,.7,71)],[(0,1,71),(1.5,.5,68),(2.5,1,64)]]

CONFIG={
 'city':dict(bpm=84,key='D major',chords=[D,Bm,G,A,Fs,Bm,E,A]+[G,A,Fs,Bm,E,A,G,A]+[D,Bm,G,A,Fs,Bm,E,D],melody=city+cityB+city,title='Window Lights',mood='Light rainy-city movement',form='A (8 bars), B (8), A\u2032 (8)'),
 'warm':dict(bpm=76,key='F major',chords=[F,Dm,Gm,C,Am,Bb,Gm,C]+[Bb,C,Am,Dm,Gm,C,Bb,C]+[F,Dm,Gm,C,Am,Bb,C,F],melody=warm+warmB+warm,title='Two Cups, Still Warm',mood='Tender conversation and café warmth',form='A (8 bars), B (8), A\u2032 (8)'),
 'reflection':dict(bpm=64,key='B minor',chords=[B,G,D,As,E,B,G,Fss]+[E,G,D,Fss]+[B,G,D,As,E,B,Fss,B],melody=reflection+reflectionB+reflection,title='After the Last Train',mood='Quiet rain-night introspection',form='A (8 bars), B (4), A\u2032 (8)'),
 'ending':dict(bpm=92,key='A major',chords=[AA,FF,D2,EE,CC,FF,BB,AA]+[D2,EE,FF,CC,D2,FF,BB,EE]+[AA,FF,D2,EE,CC,FF,EE,AA],melody=ending+endingB+ending,title='The Sky Keeps Its Promise',mood='Hopeful lyrical resolution',form='A (8 bars), B (8), A\u2032 (8)')
}

def add(buf,snd,at,pan=0):
    if snd.ndim==1:snd=stereo(snd,pan)
    at=int(round(at*SR))%len(buf)
    k=min(len(snd),len(buf)-at)
    buf[at:at+k]+=snd[:k]
    if k<len(snd):buf[:len(snd)-k]+=snd[k:]

def ambience_reverb(buf):
    # Circular room tail: previous loop's room decay is already present at t=0.
    wet=np.zeros_like(buf)
    for d,g in [(.071,.13),(.113,.10),(.181,.085),(.277,.067),(.419,.05),(.613,.037),(.829,.025), (1.113,.015)]:
        shifted=np.roll(buf,round(d*SR),axis=0)
        wet[:,0]+=g*shifted[:,1];wet[:,1]+=g*shifted[:,0]
    return buf+wet

def render_music(name,c):
    beat=60/c['bpm'];bar=4*beat; nbar=len(c['chords'])
    out=np.zeros((round(nbar*bar*SR),2),dtype=np.float32)
    for b,(ch,mel) in enumerate(zip(c['chords'],c['melody'])):
        start=b*bar;middle=8<=b<(12 if name=='reflection' else 16)
        ret=b>=nbar-8
        gain=1.04 if middle else (.94 if ret else .85)
        add(out,pad(ch,bar,.60 if name=='reflection' else .40),start)
        root=ch[0]-24 if ch[0]>58 else ch[0]-12
        add(out,bass(root,beat*2.5,.65 if name=='reflection' else .8),start, -.03)
        if name!='reflection':add(out,bass(root+7,beat*.8,.50),start+2.5*beat,.02)
        if name=='city':
            for i,p in enumerate([0,.75,1.5,2.5,3.25]):
                nn=[ch[1],ch[2],ch[3]][i%3]
                add(out,piano(nn,beat*.55,.46*gain,'ep'),start+p*beat,-.32)
            for p in [0,2]:add(out,kick(.55),start+p*beat)
            for p in [1,3]:add(out,wood(.54),start+p*beat,.3)
            for i,p in enumerate(np.arange(.5,4,.5)):add(out,brush(.5 if i%2 else .8),start+p*beat,-.4)
        elif name=='warm':
            for i,p in enumerate([0,.5,1.5,2,2.75,3.5]):
                add(out,piano(ch[[0,2,1,3,2,1][i]]+12,beat*.75,.38*gain),start+p*beat,-.34 if i%2==0 else .28)
            for p in [1,3]:add(out,brush(.55),start+p*beat,.4)
            if b%2==1:add(out,wood(.27),start+3*beat,-.2)
        elif name=='reflection':
            for i,p in enumerate([0,1.25,2.75]):add(out,piano(ch[[0,2,3][i]],beat*1.2,.57),start+p*beat,-.3+i*.25)
            if middle:add(out,bell(ch[2]+12,beat*2,.25),start+2*beat,.44)
        else:
            for i,p in enumerate(np.arange(0,4,.5)):
                add(out,piano(ch[[0,2,1,3,2,1,3,2][i]]+12,beat*.7,.34*gain),start+p*beat,-.30+i%2*.5)
            for p in [0,2]:add(out,kick(.38),start+p*beat)
            for p in [1,3]:add(out,wood(.30),start+p*beat,.25)
            for p in [1.5,2.5,3.5]:add(out,brush(.40),start+p*beat,-.3)
        for j,(p,length,m) in enumerate(mel):
            # Strong theme with an answering upper layer added in B / reprise.
            vel=gain*(.82 if name=='reflection' else .71)*(1-.07*(j%3))
            add(out,piano(m,length*beat,vel,'ep' if name=='city' else 'felt'),start+p*beat,.12)
            if (middle or ret) and j==0 and name!='reflection':
                add(out,bell(m+12,beat*1.5,.18 if name!='ending' else .25),start+(p+.06)*beat,-.45)
        if ret and b%2==0:
            add(out,piano(ch[1]+12,beat*1.4,.18,'ep'),start+3*beat,.45)
    out=ambience_reverb(out)
    return out

ASSETS=[]
def export(id,a,loop,mood,bpm=None,key=None,extra=None):
    a=np.asarray(a,dtype=np.float32)
    if a.ndim==1:a=stereo(a)
    # Only subsonic DC removal. Circular filtering avoids new loop transients.
    a-=a.mean(axis=0)
    target=.60 if id.startswith('music') else (.40 if id=='ambience_rain' else .46)
    a*=target/max(np.max(np.abs(a)),1e-9)
    if loop:
        # 2 ms endpoint projection makes the exact sample boundary continuous.
        k=88;mid=(a[0]+a[-1])/2
        a[:k]+=(mid-a[0])[None,:]*np.linspace(1,0,k)[:,None]
        a[-k:]+=(mid-a[-1])[None,:]*np.linspace(0,1,k)[:,None]
    else:
        k=min(220,len(a)//4);a[:k]*=np.linspace(0,1,k)[:,None];a[-k:]*=np.linspace(1,0,k)[:,None]
    wav=ROOT/'source'/f'{id}.wav';ogg=ROOT/'runtime'/f'{id}.ogg'
    wavfile.write(wav,SR,(np.clip(a,-1,1)*32767).astype(np.int16))
    loop_tags=['-metadata','LOOPSTART=0','-metadata',f'LOOPEND={len(a)}'] if loop else []
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5','-metadata','ARTIST=Original procedural score for Before the Rain Ends']+loop_tags+[str(ogg)],check=True)
    rms=float(np.sqrt(np.mean(a*a)));peak=float(np.max(np.abs(a)))
    x=dict(id=id,mood=mood,bpm=bpm,key=key,duration_seconds=round(len(a)/SR,6),loop=loop,relative_path=f'runtime/{id}.ogg',source_path=f'source/{id}.wav',sha256=hashlib.sha256(ogg.read_bytes()).hexdigest(),source_sha256=hashlib.sha256(wav.read_bytes()).hexdigest(),sample_rate=SR,channels=2,source_bits_per_sample=16,peak_dbfs=round(20*np.log10(peak),2),rms_dbfs=round(20*np.log10(rms),2),boundary_delta=float(np.max(np.abs(a[-1]-a[0]))),listened=False)
    if extra:x.update(extra)
    ASSETS.append(x);print(id,x['duration_seconds'],x['peak_dbfs'],x['rms_dbfs'],flush=True)

def rain():
    dur=32;n=SR*dur;a=np.zeros((n,2))
    # FFT-domain filtering is periodic, so the rain loop has no filter reset.
    freqs=np.fft.rfftfreq(n,1/SR)
    response=(freqs/(freqs+170)) / np.sqrt(1+(freqs/3900)**4)
    for s in range(2):
        noise=RNG.normal(size=n)
        a[:,s]=np.fft.irfft(np.fft.rfft(noise)*response,n)*.095
    for i in range(180):
        t=np.arange(round(.12*SR))/SR
        nse=RNG.normal(size=len(t));nse=signal.lfilter([.15],[1,-.7],nse)
        drop=nse*np.minimum(t/.002,1)*np.exp(-t/.020)*RNG.uniform(.035,.085)
        add(a,drop,RNG.uniform(0,dur),RNG.uniform(-.9,.9))
    # Slow periodic intensity, same value and slope at either edge.
    env=.87+.06*np.cos(2*np.pi*np.arange(n)/n)+.07*np.cos(6*np.pi*np.arange(n)/n)
    return a*env[:,None]

def sfx():
    t=np.arange(round(.48*SR))/SR
    n=RNG.normal(size=len(t));hp=signal.lfilter([1,-1],[1,-.2],n)
    paper=hp*(np.sin(np.pi*np.minimum(t/.44,1))**1.5)*(.30+.7*np.sin(2*np.pi*13*t)**2)*.045
    export('sfx_page',paper,False,'Soft paper turn')
    n=round(.35*SR);cam=np.zeros((n,2))
    for at,lev,p in [(0,.7,-.08),(.046,.52,.08),(.095,.17,-.1)]:add(cam,wood(lev),at,p)
    t=np.arange(round(.14*SR))/SR
    whirr=np.sin(2*np.pi*(390*t-100*t*t))*np.exp(-t/.04)*.012
    add(cam,whirr,.10,.08)
    export('sfx_camera',cam,False,'Quiet mechanical camera shutter, not an explosive impulse')
    export('sfx_ui',wood(.65),False,'Short rounded wooden UI confirmation')

if __name__=='__main__':
    for name,c in CONFIG.items():export('music_'+name,render_music(name,c),True,c['mood'],c['bpm'],c['key'],{'title':c['title'],'form':c['form'],'bars':len(c['chords'])})
    export('ambience_rain',rain(),True,'Gentle steady stereo rain')
    sfx()
    manifest={'project':'雨停之前的約定','version':1,'authoring':'Original explicitly composed notes and procedural synthesis; no third-party recordings, samples or soundfonts','listening_status':'Not auditioned by a human or audio-perception tool; numerical validation only. Audition in-game before release.','runtime_import':'In Godot, enable Loop on music and ambience Ogg import; leave off for SFX. Vorbis LOOP tags included as supplemental metadata.','assets':ASSETS}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
