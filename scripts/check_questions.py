"""Public questions, account-only writes, reply isolation and safe rendering."""
from pathlib import Path
from urllib.request import Request, build_opener, HTTPCookieProcessor
from urllib.error import HTTPError
from http.cookiejar import CookieJar
from urllib.parse import urlencode
import json, sqlite3
BASE='http://127.0.0.1:8000'
class Client:
 def __init__(self):self.client=build_opener(HTTPCookieProcessor(CookieJar()));self.token=''
 def call(self,path,fields=None,token=None):
  headers={} if fields is None else {'Content-Type':'application/x-www-form-urlencoded','X-Community-Token':self.token if token is None else token}
  try:
   with self.client.open(Request(BASE+path,data=None if fields is None else urlencode(fields).encode(),headers=headers)) as r:code,body=r.status,r.read().decode()
  except HTTPError as e:code,body=e.code,e.read().decode()
  try:return code,json.loads(body)
  except ValueError:return code,body
 def state(self):
  code,data=self.call('/community/session');assert code==200;self.token=data['token'];return data
names=[];ids=[]
a,b,guest=Client(),Client(),Client()
try:
 for c in [a,b]:
  c.state();code,data=c.call('/community/signup',{'secret':'123456'});assert code==200;names.append(data['user']['name']);c.state()
 guest.state()
 fields={'title':'How do I learn Gleam?','topic':'Gleam','body':'မြန်မာ developer question\n<script>alert(1)</script>\nlet x = 1'}
 assert guest.call('/community/questions',fields)[0]==401
 assert a.call('/community/questions',fields,token='bad')[0]==403
 assert a.call('/community/questions',dict(fields,body='short'))[0]==422
 for c in [a,b]:
  code,data=c.call('/community/questions',fields);assert code==201,(code,data);ids.append(data['url'].split('/')[-1])
 q=ids[0];path=f'/community/questions/{q}/comments'
 code,html=guest.call('/community/thread/'+q);assert code==200 and '&lt;script&gt;' in html and '<script>alert(1)</script>' not in html
 assert guest.call('/community')[0]==200
 assert guest.call(path,{'body':'guest reply'})[0]==401
 assert b.call(path,{'body':'Try the official tutorial!','parent':''},token='bad')[0]==403
 assert b.call(path,{'body':'Try the official tutorial!','parent':''})[0]==201
 data=guest.call(path+'/1')[1];root=data['comments'][0];assert root['name']==names[1] and root['role']=='member' and not root['can_delete']
 assert a.call(path,{'body':'Thanks, that helps.','parent':root['id']})[0]==201
 data=guest.call(path+'/1')[1];assert data['total']==2 and data['roots']==1;assert data['comments'][1]['role']=='author'
 assert b.call('/community/questions/'+ids[1]+'/comments',{'body':'wrong thread','parent':root['id']})[0]==422
 assert a.call('/community/comments/'+root['id']+'/delete',{})[0]==403
 assert b.call('/community/comments/'+root['id']+'/delete',{})[0]==200
 data=guest.call(path+'/1')[1];assert data['comments'][0]['deleted'] and data['comments'][1]['body']=='Thanks, that helps.'
 assert guest.call('/community/questions/missing/comments/1')[0]==404
 assert guest.call(path+'/0')[0]==422
 # Another device sees the same persisted question and replies without signing in.
 assert Client().call(path+'/1')[1]['total']==1
 print('Community questions checks passed: public reads, authenticated writes, CSRF, author replies, thread isolation, deletion permissions and escaped content.')
finally:
 with sqlite3.connect('src/database/main/data.db') as db:
  for q in ids:
   db.execute('DELETE FROM community_comments WHERE post_id=?',('question:'+q,));db.execute('DELETE FROM community_questions WHERE id=?',(q,))
  for name in names:
   db.execute('DELETE FROM community_login_attempts WHERE name=?',(name.lower(),));db.execute('DELETE FROM community_users WHERE name=?',(name,))
