"""Stage locked public dependency notices; never execute or extract dependency code."""
from pathlib import Path,PurePosixPath
import hashlib,io,json,re,tarfile,urllib.request

def sha(data):return hashlib.sha256(data).hexdigest()
def inputs(root,cache):
    catalog=Path(root)/'release/third-party-notices.json'
    if not catalog.is_file():raise ValueError('Release blocker: reviewed third-party notice catalog is missing')
    spec=json.loads(catalog.read_text(encoding='utf-8'));cache=Path(cache);cache.mkdir(parents=True,exist_ok=True)
    if spec.get('reviewed') is not True:raise ValueError('Release blocker: dependency notice review is incomplete')
    result={}
    for item in spec['entries']:
        expected=item['sha256']
        if not re.fullmatch('[0-9a-f]{64}',expected):raise ValueError('Invalid locked notice hash')
        file=cache/expected
        if file.exists():data=file.read_bytes()
        else:
            if not item['url'].startswith('https://'):raise ValueError('Notice URL must use HTTPS')
            request=urllib.request.Request(item['url'],headers={'User-Agent':'LISRemasteredAccess-release-notices'})
            with urllib.request.urlopen(request,timeout=45) as response:data=response.read(64*1024*1024+1)
            if len(data)>64*1024*1024:raise ValueError('Notice input exceeds size limit')
        if sha(data)!=expected:raise ValueError('Dependency notice checksum mismatch: '+item['name'])
        if not file.exists():file.write_bytes(data)
        prefix='licenses/UE4SS-dependencies/'+item['name']
        if item['kind']=='raw':result[prefix]=data
        elif item['kind']=='crate':
            with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
                for name in item['members']:
                    member=archive.getmember(name)
                    if not member.isfile():raise ValueError('Notice member is not a regular file')
                    rel=PurePosixPath(name)
                    if rel.is_absolute() or '..' in rel.parts:raise ValueError('Unsafe notice member')
                    target=prefix+'/'+str(PurePosixPath(*rel.parts[1:]))
                    if target in result:raise ValueError('Duplicate dependency notice member')
                    result[target]=archive.extractfile(member).read()
        else:raise ValueError('Unknown notice input kind')
    result['licenses/UE4SS-dependencies/catalog.json']=catalog.read_bytes()
    return result
