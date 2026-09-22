"""Fetch public source snapshots for the six remaining circuits. Run explicitly, offline at runtime."""
from pathlib import Path
import json, time, urllib.request, urllib.parse, xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]; DATA=ROOT/'art/reference_data'
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
def fetch(url):
    for attempt in range(4):
        try:
            return opener.open(urllib.request.Request(url,headers={'User-Agent':'ApexCircuitPrototype/1.0'}),timeout=45).read()
        except Exception:
            if attempt==3: raise
            time.sleep(2+attempt*3)
geo=json.loads((DATA/'f1-circuits.geojson').read_text(encoding='utf-8-sig'))
specs=[('nurburgring','de-1927'),('suzuka','jp-1962'),('imola','it-1953'),('redbull','at-1969')]
extra=[]
for key in ['bathurst','laguna']:
    tree=ET.parse(DATA/(key+'-osm.xml')).getroot()
    if key=='bathurst':
        full=ET.fromstring(fetch('https://api.openstreetmap.org/api/0.6/relation/6942508/full'))
        seen={(n.tag,n.attrib.get('id')) for n in tree}
        for n in full:
            if (n.tag,n.attrib.get('id')) not in seen:tree.append(n)
        ET.ElementTree(tree).write(DATA/(key+'-osm.xml'),encoding='utf-8',xml_declaration=True)
    nodes={n.attrib['id']:[float(n.attrib['lon']),float(n.attrib['lat'])] for n in tree.findall('node')}
    ways={w.attrib['id']:w for w in tree.findall('way')}
    if key=='bathurst':
        rel=next(r for r in tree.findall('relation') if r.attrib['id']=='6942508')
        segments=[[n.attrib['ref'] for n in ways[m.attrib['ref']].findall('nd')] for m in rel.findall('member') if m.attrib['type']=='way' and m.attrib.get('role')=='circuit' and m.attrib['ref'] in ways]
    else:
        segments=[]
        for w in ways.values():
            tags={t.attrib['k']:t.attrib['v'] for t in w.findall('tag')}
            if tags.get('highway')=='raceway' and tags.get('name')!='Pit Lane': segments.append([n.attrib['ref'] for n in w.findall('nd')])
    chain=segments.pop(0)
    while segments:
        for i,seg in enumerate(segments):
            if chain[-1]==seg[0]: chain+=seg[1:];segments.pop(i);break
            if chain[-1]==seg[-1]: chain+=seg[-2::-1];segments.pop(i);break
        else: raise RuntimeError('Disconnected circuit '+key)
    assert chain[0]==chain[-1],key
    coords=[nodes[n] for n in chain]
    # Laguna is one-way in OSM. Bathurst's public-road ways are not directed;
    # place pit straight first and orient toward Hell Corner (north).
    if key=='bathurst':
        i=min(range(len(coords)-1),key=lambda i:(coords[i][0]-149.5777)**2+(coords[i][1]+33.4406)**2)
        coords=coords[i:-1]+coords[:i+1]
        if coords[1][1]<coords[0][1]: coords=coords[::-1]
    extra.append({'type':'Feature','properties':{'id':key,'length':6213 if key=='bathurst' else 3602,'Name':key,'source':'OpenStreetMap / ODbL'},'geometry':{'type':'LineString','coordinates':coords}})
    specs.append((key,key))
(DATA/'extra-circuits.geojson').write_text(json.dumps({'type':'FeatureCollection','features':extra}),encoding='utf-8')
geo['features']+=extra
for key,ident in specs:
    f=next(f for f in geo['features'] if f['properties']['id']==ident); coords=f['geometry']['coordinates']
    if not (DATA/(key+'-osm.xml')).exists():
        west=min(p[0] for p in coords)-.002;east=max(p[0] for p in coords)+.002
        south=min(p[1] for p in coords)-.002;north=max(p[1] for p in coords)+.002
        merged=ET.Element('osm',version='0.6'); seen=set()
        for x0,x1 in [(west,(west+east)/2),((west+east)/2,east)]:
            for y0,y1 in [(south,(south+north)/2),((south+north)/2,north)]:
                part=ET.fromstring(fetch(f'https://api.openstreetmap.org/api/0.6/map?bbox={x0},{y0},{x1},{y1}'))
                for element in part:
                    identity=(element.tag,element.attrib.get('id'))
                    if identity not in seen: merged.append(element);seen.add(identity)
        ET.ElementTree(merged).write(DATA/(key+'-osm.xml'),encoding='utf-8',xml_declaration=True)
    for category in ['elevation','terrain']:
        path=DATA/(key+'-'+category+'.json')
        if path.exists():continue
        if category=='elevation': samples=coords
        else:
            lo=min(p[0] for p in coords)-.004;hi=max(p[0] for p in coords)+.004
            bottom=min(p[1] for p in coords)-.003;top=max(p[1] for p in coords)+.003
            samples=[[lo+(hi-lo)*x/19,bottom+(top-bottom)*z/19] for z in range(20) for x in range(20)]
        results=[]
        for first in range(0,len(samples),95):
            locations='|'.join(f'{p[1]:.6f},{p[0]:.6f}' for p in samples[first:first+95])
            response=json.loads(fetch('https://api.opentopodata.org/v1/srtm30m?locations='+urllib.parse.quote(locations)))
            assert response['status']=='OK'
            assert all(p['elevation'] is not None for p in response['results'])
            results+=response['results'];time.sleep(1.15)
        path.write_text(json.dumps({'source':'OpenTopoData / SRTM30m','grid_size':20,'resolution_metres':30,'results':results}),encoding='utf-8')
    print('SOURCE READY',key,flush=True)
