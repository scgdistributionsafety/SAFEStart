# รวมหน้าเว็บจริง + ฐานข้อมูลในเบราว์เซอร์ เป็นเดโม (dist/index.html)
import os,subprocess
D=os.path.dirname(os.path.abspath(__file__));W=os.path.join(D,'..')
subprocess.run('NODE_PATH=/tmp/w/node_modules /tmp/w/node_modules/.bin/esbuild entry.mjs --bundle --format=iife --minify --loader:.sql=text --outfile=dist/demo-db.js --log-level=warning --define:import.meta.url=\'"https://x/"\'',shell=True,cwd=D,check=True)
R=lambda p:open(p,encoding='utf8').read()
css=R('/tmp/w/node_modules/leaflet/dist/leaflet.css')+R(W+'/style.css')+'\n.demo-pill{position:fixed;right:12px;bottom:calc(env(safe-area-inset-bottom) + 84px);z-index:80;display:grid;justify-items:end;gap:6px}body:has(.sheet-bg) .demo-pill{display:none}@media (min-width:700px){.demo-pill{bottom:16px}}'
js='\n'.join(R(W+'/'+f) for f in ['ui.js','data.js','views_c.js','views_s.js','main.js'])+'\n'+R(D+'/demo_ui.js')
html=f'''<title>SafeStart Demo</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Anuphan:wght@500;600;700&family=IBM+Plex+Sans+Thai:wght@400;500;600&family=IBM+Plex+Mono:wght@500;600&display=swap">
<style>{css}</style><div id="root"></div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react/18.3.1/umd/react.production.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.3.1/umd/react-dom.production.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/htm@3.1.1/dist/htm.umd.js"></script>
<script src="demo-db.js"></script>
<script>{js}</script>'''
open(D+'/dist/index.html','w',encoding='utf8').write(html);print('ok',len(html))
