"""Integration coverage for visitor credentials, post comments and author replies.
Creates disposable fixtures only; never prints real admin credentials.
"""
from pathlib import Path
from urllib.request import Request, build_opener, HTTPCookieProcessor
from urllib.error import HTTPError
from http.cookiejar import CookieJar
from urllib.parse import urlencode
import json, re, uuid, sqlite3
BASE='http://127.0.0.1:8000'
class Client:
 def __init__(self):
  self.client=build_opener(HTTPCookieProcessor(CookieJar()));self.token=''
 def call(self,path,fields=None,token=None):
  headers={}
  if fields is not None:headers={'Content-Type':'application/x-www-form-urlencoded','X-Community-Token':self.token if token is None else token}
  request=Request(BASE+path,data=urlencode(fields).encode() if fields is not None else None,headers=headers)
  try:
   with self.client.open(request) as r:body=r.read().decode();code=r.status
  except HTTPError as e:code=e.code;body=e.read().decode()
  try:return code,json.loads(body)
  except ValueError:return code,body
 def state(self):
  code,data=self.call('/community/session');assert code==200;self.token=data['token'];return data
admin=Client();visitor=Client();other=Client();anonymous=Client()
slug='community-check-'+uuid.uuid4().hex[:10]
created_names=[]
admin.state()
code,html=admin.call('/admin');assert code==200
studio_token=re.search(r'data-token="([^"]+)"',html)[1]
password=next(line.split('=',1)[1].strip('"') for line in Path('.env').read_text().splitlines() if line.startswith('ADMIN_PASSWORD='))
def studio(path,fields):
 request=Request(BASE+path,data=urlencode(fields).encode(),headers={'Content-Type':'application/x-www-form-urlencoded','X-Studio-Token':studio_token})
 try:
  with admin.client.open(request) as r:return r.status,json.loads(r.read())
 except HTTPError as e:return e.code,json.loads(e.read())
assert studio('/admin/login',{'password':password})[0]==200
entry=dict(id=slug,original_id='',kind='article',title='Community integration fixture',category='Testing',excerpt='Test',body='<h2>Rich description</h2><p><strong>Bold</strong> text</p><pre><code>let x = 1</code></pre>',youtube='',creator='Fixture Author',thumbnail='',status='published',date='2026-10-13',minutes='1 min read')
try:
 assert studio('/admin/save',entry)[0]==200
 html=visitor.call('/posts/'+slug)[1];assert 'id="post-comments"' in html and '<strong>Bold</strong>' in html
 for client,kind,secret in [(visitor,'pin','123456'),(other,'pin','654321')]:
  state=client.state();assert re.fullmatch(r'[A-Z][a-z]+ [A-Z][a-z]+',state['suggestion'])
  assert client.call('/community/signup',dict(kind=kind,secret=secret),token='bad')[0]==403
  assert client.call('/community/signup',dict(kind='pin',secret='12'))[0]==422
  assert client.call('/community/signup',dict(kind='password',secret='12345678'))[0]==422
  assert client.call('/community/signup',dict(secret='abcdef'))[0]==422
  code,data=client.call('/community/signup',dict(kind=kind,secret=secret));assert code==200,(code,data)
  created_names.append(data['user']['name']);assert data['user']['name']==state['suggestion']
  assert client.state()['user']['name']==created_names[-1]
 anonymous.state()

 # Bookmarks are private, persistent, idempotent and CSRF protected.
 bookmark='/community/bookmarks/'+slug
 assert anonymous.call('/community/bookmarks')[0]==401
 assert anonymous.call(bookmark,dict(saved='yes'))[0]==401
 assert visitor.call('/community/bookmarks')==(200,[])
 assert visitor.call(bookmark,dict(saved='yes'),token='bad')[0]==403
 assert visitor.call(bookmark,dict(saved='invalid'))[0]==422
 assert visitor.call('/community/bookmarks/missing',dict(saved='yes'))[0]==404
 code,saved=visitor.call(bookmark,dict(saved='yes'));assert code==200 and saved[0]['id']==slug
 assert len(visitor.call(bookmark,dict(saved='yes'))[1])==1
 assert other.call('/community/bookmarks')==(200,[])
 assert slug in visitor.call('/bookmarks')[1]
 assert slug not in other.call('/bookmarks')[1]
 assert slug not in anonymous.call('/bookmarks')[1]
 another_device=Client();another_device.state()
 assert another_device.call('/community/login',dict(name=created_names[0].lower(),secret='123456'))[0]==200
 assert another_device.call('/community/bookmarks')[1][0]['id']==slug
 assert visitor.call(bookmark,dict(saved='no'))==(200,[])
 assert visitor.call(bookmark,dict(saved='no'))==(200,[])
 assert visitor.call(bookmark,dict(saved='yes'))[0]==200
 assert other.call('/community/bookmarks')==(200,[])
 path='/community/posts/'+slug+'/comments'
 assert anonymous.call(path,dict(body='anonymous',parent=''))[0]==401
 assert visitor.call(path,dict(body='bad csrf'),token='bad')[0]==403
 assert visitor.call(path,dict(body=''))[0]==422
 assert visitor.call(path,dict(body='x'*2001))[0]==422
 assert visitor.call('/community/posts/missing/comments',dict(body='not found'))[0]==404
 assert visitor.call(path,dict(body='<script>alert(1)</script> မင်္ဂလာပါ',parent='',role='author',name='Fake Author'))[0]==201
 code,data=visitor.call(path+'/1');assert code==200,(code,data)
 root=data['comments'][0];assert root['role']=='member' and root['can_delete']
 assert other.call('/community/comments/'+root['id']+'/delete',{})[0]==403
 assert other.call(path,dict(body='Other visitor reply',parent=root['id']))[0]==201
 reply=next(c for c in other.call(path+'/1')[1]['comments'] if c['parent'])
 assert visitor.call(path,dict(body='Reply to another visitor',parent=reply['id']))[0]==201
 assert visitor.call(path,dict(body='bad parent',parent='missing'))[0]==422
 assert admin.call(path,dict(body='Thanks for reading!',parent=root['id']))[0]==201
 data=visitor.call(path+'/1')[1];assert data['total']==4
 author=next(c for c in data['comments'] if c['role']=='author');assert author['name']=='Fixture Author'
 assert not next(c for c in anonymous.call(path+'/1')[1]['comments'] if c['id']==root['id'])['can_delete']
 assert visitor.call('/community/comments/'+root['id']+'/delete',{})[0]==200
 data=visitor.call(path+'/1')[1];assert data['total']==3
 assert next(c for c in data['comments'] if c['id']==root['id'])['deleted']
 assert visitor.call('/community/logout',{})[0]==200
 assert visitor.state()['user'] is None
 assert visitor.call('/community/login',dict(name=created_names[0],secret='wrong'))[0]==401
 assert visitor.call('/community/login',dict(name=created_names[0].lower(),secret='123456'))[0]==200
 assert visitor.call('/community/credentials',dict(current_secret='000000',kind='pin',secret='234567'))[0]==401
 assert visitor.call('/community/credentials',dict(current_secret='123456',secret='234567'))[0]==200
 assert visitor.call('/community/logout',{})[0]==200
 assert visitor.call('/community/login',dict(name=created_names[0].lower(),secret='123456'))[0]==401
 assert visitor.call('/community/login',dict(name=created_names[0],secret='234567'))[0]==200
 # New roots are paged ten at a time; replies travel with their root.
 for i in range(6):assert other.call(path,dict(body=f'Pagination {i}',parent=''))[0]==201
 for i in range(5):assert visitor.call(path,dict(body=f'Pagination visitor {i}',parent=''))[0]==201
 first=visitor.call(path+'/1')[1];second=visitor.call(path+'/2')[1]
 assert first['roots']==12 and len([c for c in first['comments'] if not c['parent']])==10
 assert len([c for c in second['comments'] if not c['parent']])==2
 # Credentials are salted and hashed; repeated failures are throttled.
 db_path=next(line.split('=',1)[1].strip('\"') for line in Path('.env').read_text().splitlines() if line.startswith('DB_DATABASE='))
 with sqlite3.connect(db_path) as db:
  rows=db.execute('SELECT salt,password_hash FROM community_users WHERE name IN (?,?)',created_names).fetchall()
  assert len(rows)==2 and rows[0][0]!=rows[1][0]
  assert all(len(row[1])==64 and row[1] not in ('123456','234567','654321') for row in rows)
 for i in range(10):
  code,data=anonymous.call('/community/login',dict(name=created_names[1],secret='000000'));assert code==401,(i,code,data)
 assert anonymous.call('/community/login',dict(name=created_names[1],secret='654321'))[0]==429
 # Drafts do not expose comments or saved content.
 entry.update(original_id=slug,status='draft');assert studio('/admin/save',entry)[0]==200
 assert visitor.call(path+'/1')[0]==404
 assert visitor.call(path,dict(body='private'))[0]==404
 assert visitor.call('/community/bookmarks')==(200,[])
 assert slug not in visitor.call('/bookmarks')[1]
 assert visitor.call(bookmark,dict(saved='yes'))[0]==404
 entry.update(status='published');assert studio('/admin/save',entry)[0]==200
 assert visitor.call('/community/bookmarks')[1][0]['id']==slug
 assert studio('/admin/delete/'+slug,{})[0]==200
 assert visitor.call(path+'/1')[0]==404
 assert visitor.call('/community/bookmarks')==(200,[])
 print('PASS: generated accounts, PIN-only credentials and hashing, CSRF, login/logout, credential changes, comments, nested replies, author identity, permissions, pagination, draft privacy, private bookmarks, persistence, saved-post page')
finally:
 studio('/admin/delete/'+slug,{})
 # Remove only the accounts made by this check and their test sessions.
 db_path=next(line.split('=',1)[1].strip('"') for line in Path('.env').read_text().splitlines() if line.startswith('DB_DATABASE='))
 with sqlite3.connect(db_path) as db:
  for name in created_names:
   db.execute('DELETE FROM community_bookmarks WHERE user_id IN (SELECT id FROM community_users WHERE name = ?)', (name,))
   db.execute('DELETE FROM community_users WHERE name = ?', (name,))
   db.execute('DELETE FROM community_login_attempts WHERE name = ? COLLATE NOCASE', (name,))
