"""Project original geographic centre lines to metre-scale east/up/south coordinates.
SRTM heights are terrain samples, NOT survey-quality track elevation.
No arbitrary length scaling, fictional sine elevation, or latitude mirroring.
"""
import json, math, xml.etree.ElementTree as ET
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'art/reference_data'
geo=json.loads((DATA/'f1-circuits.geojson').read_text(encoding='utf-8-sig'))
geo['features']+=json.loads((DATA/'extra-circuits.geojson').read_text(encoding='utf-8-sig'))['features']
tracks={}
for key,ident,name,region,width in [('monza','it-1922','蒙扎','意大利 · 蒙扎公园',12),('spa','be-1925','斯帕','比利时 · 阿登森林',14),('silverstone','gb-1948','银石','英国 · 北安普敦郡',15),('nurburgring','de-1927','纽博格林 GP','德国 · 艾费尔山区',13),('suzuka','jp-1962','铃鹿','日本 · 三重县',13),('imola','it-1953','伊莫拉','意大利 · 艾米利亚',12),('redbull','at-1969','红牛环','奥地利 · 施皮尔贝格',13),('bathurst','bathurst','巴瑟斯特','澳大利亚 · 全景山',11),('laguna','laguna','拉古纳·塞卡','美国 · 加利福尼亚',12)]:
    feature=next(f for f in geo['features'] if f['properties']['id']==ident)
    coords=feature['geometry']['coordinates'][:-1]
    elevations=json.loads((DATA/(key+'-elevation.json')).read_text(encoding='utf-8-sig'))['results'][:-1]
    assert len(coords)==len(elevations)
    lat=sum(p[1] for p in coords)/len(coords);lon=sum(p[0] for p in coords)/len(coords)
    heights=[p['elevation'] for p in elevations]
    assert all(h is not None for h in heights)
    low=min(heights)
    points=[[(p[0]-lon)*111320*math.cos(math.radians(lat)),heights[i]-low,-(p[1]-lat)*111320] for i,p in enumerate(coords)]
    def project(latitude,longitude,height=0):
        return [(longitude-lon)*111320*math.cos(math.radians(lat)),height,-(latitude-lat)*111320]
    osm=ET.parse(DATA/(key+'-osm.xml')).getroot()
    nodes={n.attrib['id']:project(float(n.attrib['lat']),float(n.attrib['lon'])) for n in osm.findall('node')}
    features=[]
    def nearest(p):
        return min(points,key=lambda q:(q[0]-p[0])**2+(q[2]-p[2])**2)
    start_name={'monza':'Palazzina Box','spa':'Stand F1','silverstone':'Silverstone Wing'}.get(key,'__none__')
    start_target=None
    for way in osm.findall('way'):
        tags={t.attrib['k']:t.attrib['v'] for t in way.findall('tag')}
        kind='building' if 'building' in tags else 'forest' if tags.get('natural')=='wood' or tags.get('landuse')=='forest' else 'pitlane' if tags.get('raceway')=='pit_lane' or tags.get('name')=='Pit Lane' else 'water' if tags.get('natural')=='water' else 'barrier' if tags.get('barrier') in ['guard_rail','fence','wall'] else ''
        if not kind:continue
        polygon=[nodes[n.attrib['ref']] for n in way.findall('nd') if n.attrib['ref'] in nodes]
        if len(polygon)<3:continue
        center=[sum(p[c] for p in polygon)/len(polygon) for c in range(3)]
        closest=nearest(center)
        distance=math.hypot(center[0]-closest[0],center[2]-closest[2])
        if kind=='building' and distance>260:continue
        if tags.get('name')==start_name:start_target=center
        height=float(tags.get('height','0').replace(' m','')) if tags.get('height','0').replace(' m','').replace('.','',1).isdigit() else 0
        stand=tags.get('building')=='grandstand' or tags.get('leisure')=='grandstand'
        area=abs(sum(polygon[i][0]*polygon[(i+1)%len(polygon)][2]-polygon[(i+1)%len(polygon)][0]*polygon[i][2] for i in range(len(polygon))))/2
        fallback_height=8 if stand else min(7,max(2.5,math.sqrt(area)*.30))
        raised=tags.get('level')=='1' or tags.get('layer')=='1' or tags.get('bridge')=='yes'
        features.append({'osm_id':way.attrib['id'],'kind':kind,'name':tags.get('name',''),'grandstand':stand,'height':height or fallback_height,'height_measured':bool(height),'barrier_type':tags.get('barrier',''),'min_height':float(tags.get('min_height',5.5 if raised else 0)),'points':polygon})
    ways={w.attrib['id']:w for w in osm.findall('way')}
    for relation in osm.findall('relation'):
        tags={t.attrib['k']:t.attrib['v'] for t in relation.findall('tag')}
        if tags.get('natural')!='wood' and tags.get('landuse')!='forest':continue
        for member in relation.findall('member'):
            if member.attrib.get('role')!='outer' or member.attrib.get('ref') not in ways:continue
            way=ways[member.attrib['ref']]
            polygon=[nodes[n.attrib['ref']] for n in way.findall('nd') if n.attrib['ref'] in nodes]
            if len(polygon)>3:
                features.append({'osm_id':'relation_'+relation.attrib['id'],'kind':'forest','name':'','grandstand':False,'height':0,'height_measured':False,'points':polygon})
    # Densify long straights BEFORE corner cutting so sharp turns are not erased.
    dense=[]
    for i,a in enumerate(points):
        b=points[(i+1)%len(points)]
        n=max(1,math.ceil(math.dist(a,b)/12))
        for j in range(n):dense.append([round(a[c]+(b[c]-a[c])*j/n,4) for c in range(3)])
    if key == 'silverstone':
        # OSM start node belongs to Hamilton Straight (not the old national pits).
        start_target=nodes.get('13036050130',start_target)
    if start_target:
        start_index=min(range(len(dense)),key=lambda i:(dense[i][0]-start_target[0])**2+(dense[i][2]-start_target[2])**2)
        dense=dense[start_index:]+dense[:start_index]
    length=sum(math.dist(p,points[(i+1)%len(points)]) for i,p in enumerate(points))
    tracks[key]={'name':name,'region':region,'distance':f"{feature['properties']['length']/1000:.3f} KM",'corners':{'monza':'11 弯','spa':'19 弯','silverstone':'18 弯','nurburgring':'16 弯','suzuka':'18 弯','imola':'19 弯','redbull':'10 弯','bathurst':'23 弯','laguna':'11 弯'}[key],
        'nominal_width_m':width,'points':dense,'source_length_m':round(length,3),'published_length_m':feature['properties']['length'],
        'elevation_range_m':round(max(heights)-low,2),'source_origin_lat_lon':[lat,lon],
        'accuracy':'Geographic centreline + 30m SRTM terrain; nominal road width. Buildings are stylized approximations.'}
    terrain=json.loads((DATA/(key+'-terrain.json')).read_text(encoding='utf-8-sig'))
    tracks[key]['terrain']=[project(p['location']['lat'],p['location']['lng'],p['elevation']-low) for p in terrain['results']]
    tracks[key]['terrain_grid_size']=terrain['grid_size']
    tracks[key]['features']=features
    tracks[key]['start_reference']='Closest centreline point to mapped main pit building; approximate start/finish position.'
    coarse=np.asarray(tracks[key]['terrain']).reshape(20,20,3)
    x0,x1=coarse[0,0,0],coarse[0,-1,0]
    z0,z1=coarse[-1,0,2],coarse[0,0,2]
    columns=math.ceil((x1-x0)/24)+1;rows=math.ceil((z1-z0)/24)+1
    xs=np.linspace(x0,x1,columns);zs=np.linspace(z0,z1,rows)
    xx,zz=np.meshgrid(xs,zs);query=np.column_stack([xx.ravel(),zz.ravel()])
    road=np.asarray(dense)
    road_distance=[];road_height=[]
    for first in range(0,len(query),512):
        q=query[first:first+512]
        d=((q[:,None,:]-road[None,:,[0,2]])**2).sum(axis=2)
        nearest_indices=d.argmin(axis=1)
        road_distance.extend(np.sqrt(d[np.arange(len(q)),nearest_indices]))
        road_height.extend(road[nearest_indices,1])
    dense_terrain=[]
    for i,(x,z) in enumerate(query):
        u=(x-x0)/(x1-x0)*19;v=(z1-z)/(z1-z0)*19
        ix=min(18,int(u));iz=min(18,int(v));fx=u-ix;fz=v-iz
        h=(coarse[iz,ix,1]*(1-fx)+coarse[iz,ix+1,1]*fx)*(1-fz)+(coarse[iz+1,ix,1]*(1-fx)+coarse[iz+1,ix+1,1]*fx)*fz
        blend=max(0,min(1,(road_distance[i]-38)/42))
        h=min(h,road_height[i]-1.8)*(1-blend)+h*blend
        dense_terrain.append([round(x,2),round(h,2),round(z,2),round(road_distance[i],2)])
    tracks[key]['terrain_mesh']={'columns':columns,'rows':rows,'points':dense_terrain}
    print(key,'metres=',round(length,1),'height range=',round(max(heights)-low,1),'samples=',len(dense))
(ROOT/'godot/assets/circuits').mkdir(exist_ok=True,parents=True)
(ROOT/'godot/assets/circuits/real_circuits.json').write_text(json.dumps(tracks,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
