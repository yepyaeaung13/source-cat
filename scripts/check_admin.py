"""Integration check against the running local development server."""
from pathlib import Path
from urllib.request import Request, build_opener, HTTPCookieProcessor
from urllib.error import HTTPError
from http.cookiejar import CookieJar
from urllib.parse import urlencode
import json,re,uuid
base='http://127.0.0.1:8000'
client=build_opener(HTTPCookieProcessor(CookieJar()))
def call(path,fields=None,token=None):
 headers={}
 if fields is not None: headers={'Content-Type':'application/x-www-form-urlencoded','X-Studio-Token':token or ''}
 req=Request(base+path,data=urlencode(fields).encode() if fields is not None else None,headers=headers)
 try:
  with client.open(req) as response:return response.status,response.read().decode()
 except HTTPError as error:return error.code,error.read().decode()
assert call('/admin/content')[0]==401
status,html=call('/admin');assert status==200
token=re.search(r'data-token="([^"]+)"',html)[1]
assert call('/admin/login',{'password':'wrong'},token)[0]==401
password=next(line.split('=',1)[1] for line in Path('.env').read_text().splitlines() if line.startswith('ADMIN_PASSWORD='))
assert call('/admin/login',{'password':password},token)[0]==200
assert call('/admin/content')[0]==200
slug='integration-'+uuid.uuid4().hex[:10]
entry={'id':slug,'original_id':'','kind':'article','title':'Integration article','category':'Testing','excerpt':'Integration excerpt','body':'<p>Integration content</p>','youtube':'','creator':'Test author','thumbnail':'','status':'draft','date':'2026-10-12','minutes':'2 min read'}
try:
 assert call('/admin/save',entry,'bad-token')[0]==403
 assert call('/admin/save',entry,token)[0]==200
 assert call('/posts/'+slug)[0]==404
 assert slug not in call('/')[1]
 assert call('/admin/save',entry,token)[0]==409
 invalid=dict(entry,id='bad/slug');assert call('/admin/save',invalid,token)[0]==422
 invalid=dict(entry,id='bad-youtube',kind='video',youtube='invalid');assert call('/admin/save',invalid,token)[0]==422
 entry.update(original_id=slug,status='published',title='Updated integration article')
 assert call('/admin/save',entry,token)[0]==200
 assert 'Updated integration article' in call('/posts/'+slug)[1]
 assert slug in call('/')[1]
 data=json.loads(call('/admin/content')[1]);assert any(e['id']==slug for e in data)
 entry.update(kind='video',youtube='2WtPyqwTLKM')
 assert call('/admin/save',entry,token)[0]==200
 assert 'data-play="2WtPyqwTLKM"' in call('/posts/'+slug)[1]
 assert call('/admin/delete/'+slug,{},'bad-token')[0]==403
 assert call('/admin/delete/'+slug,{},token)[0]==200
 assert call('/posts/'+slug)[0]==404
 assert call('/admin/logout',{},token)[0]==200
 assert call('/admin/content')[0]==401
 print('PASS: authentication, CSRF, validation, drafts, create/edit/publish, video, delete, logout')
finally:
 # Only removes content created by this check.
 call('/admin/delete/'+slug,{},token)
