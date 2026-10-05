#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,hashlib
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly
P=Path(__file__).resolve().parent
manifest=json.loads((P/'manifest.json').read_text())
results=[]
for a in manifest['assets']:
    p=P/a['relative_path'];w=P/a['source_path']
    if not a['loop']:
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(w),'-c:a','libvorbis','-q:a','5',str(p)],check=True)
        a['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
    info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(p)]))['streams'][0]
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-acodec','pcm_f32le','-'])
    z=np.frombuffer(raw,dtype='<f4').reshape(-1,2)
    peak=float(abs(z).max());rms=float(np.sqrt(np.mean(z*z)))
    boundary=float(abs(z[-1]-z[0]).max())
    true_peak=float(abs(resample_poly(z,4,1,axis=0)).max())
    rate,x=wavfile.read(w);x=x.astype(float)/32768
    assert info['sample_rate']=='44100' and info['channels']==2
    assert np.isfinite(z).all() and peak<1 and true_peak<1
    assert len(z)>0 and abs(len(z)/44100-a['duration_seconds'])<.03
    qa={'id':a['id'],'codec':info['codec_name'],'decoded_samples':len(z),'decoded_peak_dbfs':round(20*np.log10(peak),2),'decoded_true_peak_dbfs':round(20*np.log10(true_peak),2),'decoded_rms_dbfs':round(20*np.log10(rms),2),'decoded_boundary_delta':round(boundary,7),'source_boundary_delta':float(abs(x[-1]-x[0]).max()),'no_clipping':True,'runtime_bytes':p.stat().st_size,'stereo_correlation':round(float(np.corrcoef(z.T)[0,1]),4),'loop_metadata_present': 'LOOPSTART' in info.get('tags',{})}
    a['validation']=qa
    results.append(qa)
(P/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(P/'validation.json').write_text(json.dumps({'passed':True,'method':'FFmpeg decode, samples and channels, finite values, clipping/4x true peak, source and decoded loop endpoint delta, size and correlation. Numerical QA only; not listened.','results':results},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(results,indent=2))
