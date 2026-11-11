"""Render existing Markdown, checking structure rather than visual appearance."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote
import argparse,os,re,shutil,subprocess

DOCUMENTS=('README.md','CHANGELOG.md','THIRD-PARTY-LICENSES.md')
class CheckHTML(HTMLParser):
    def __init__(self):
        super().__init__();self.ids=set();self.hrefs=[];self.rows=0;self.headers=0
        self.main=0;self.nav=0;self.language=False;self.errors=[];self.level=0
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:
            if a['id'] in self.ids:self.errors.append('duplicate id '+a['id'])
            self.ids.add(a['id'])
        if 'href' in a:self.hrefs.append(a['href'])
        if tag=='html':self.language=a.get('lang')=='en'
        if tag=='main':self.main+=1
        if tag=='nav':self.nav+=1
        if tag=='tr':self.rows+=1
        if tag=='th':
            self.headers+=1
            if a.get('scope')!='col':self.errors.append('table header lacks scope=col')
        if tag in ('script','iframe'):self.errors.append('active content '+tag)
        if tag=='link' or (tag in ('img','audio','video') and a.get('src','').startswith(('http:','https:','//'))):
            self.errors.append('external asset')
        if re.fullmatch('h[1-6]',tag):
            level=int(tag[1])
            if level>self.level+1:self.errors.append('skipped heading level')
            self.level=level

def validate_html(text,markdown,files):
    p=CheckHTML();p.feed(text)
    if not(p.language and p.main==1 and p.nav and '#main' in p.hrefs):p.errors.append('missing language/main/contents/skip link')
    for href in p.hrefs:
        if href.startswith('#') and unquote(href[1:]) not in p.ids:p.errors.append('broken anchor '+href)
        if re.fullmatch(r'[A-Z-]+\.html',href) and href not in files:p.errors.append('missing document '+href)
    fenced=False;expected=0
    for line in markdown.splitlines():
        if line.strip().startswith('```'):fenced=not fenced
        if not fenced and line.startswith('|') and not re.fullmatch(r'[| :\-]+',line):expected+=1
    if p.rows!=expected:p.errors.append(f'table rows lost: expected{expected}, got{p.rows}')
    if p.errors:raise ValueError('; '.join(p.errors))
    return {'table_rows':p.rows,'column_headers':p.headers}

def find_pandoc(explicit=None):
    candidates=[explicit,shutil.which('pandoc'),str(Path(os.environ.get('ProgramFiles','C:/Program Files'))/'Pandoc/pandoc.exe'),
                str(Path(os.environ.get('LOCALAPPDATA',''))/'Pandoc/pandoc.exe')]
    for p in candidates:
        if p and Path(p).is_file():return str(p)
    raise ValueError('Pandoc required to build the accessible player documents; pass --pandoc if needed')

def build(root,out,pandoc=None):
    root=Path(root);out=Path(out);out.mkdir(parents=True,exist_ok=True);exe=find_pandoc(pandoc)
    result={};names={Path(n).with_suffix('.html').name for n in DOCUMENTS}
    for n in DOCUMENTS:
        text=(root/n).read_text(encoding='utf-8')
        if re.search(r'<https?://|(?m:^\s*https?://)',text):raise ValueError('Bare link in '+n)
        target=out/Path(n).with_suffix('.html').name
        title=text.splitlines()[0].lstrip('# ').strip()
        subprocess.run([exe,str(root/n),'--from=gfm','--to=html5','--standalone','--toc',
            '--template',str(root/'scripts/docs/template.html'),'--lua-filter',str(root/'scripts/docs/accessibility.lua'),
            '--metadata','title='+title,'--output',str(target)],check=True,
            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),capture_output=True,timeout=60)
        result[n]=validate_html(target.read_text(encoding='utf-8'),text,names)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--pandoc')
    args=p.parse_args();print(build(Path(__file__).resolve().parents[1],args.output,args.pandoc))
