import os
from datetime import timezone
from fastapi import FastAPI,HTTPException
from pymongo import MongoClient
client=MongoClient(os.environ['MONGO_URL'],maxPoolSize=50,serverSelectionTimeoutMS=3000)
parents=client['benchmark']['benchmark_parent']
app=FastAPI()
@app.get('/health')
def health():
    try: client.admin.command('ping')
    except Exception: raise HTTPException(503,'database unavailable')
    return {'status':'ok'}
@app.get('/parent/{id}')
def parent(id:int):
    p=parents.find_one({'_id':id})
    if p is None:raise HTTPException(404,'parent not found')
    return {'id':p['id'],'account_number':p['account_number'],'status':p['status'],'created_at':p['created_at'].replace(tzinfo=timezone.utc),'payload':p['payload']}
