import Fastify from 'fastify';
import {MongoClient,Long} from 'mongodb';
const client=new MongoClient(process.env.MONGO_URL,{maxPoolSize:50});
await client.connect();
const parents=client.db('benchmark').collection('benchmark_parent');
const app=Fastify({logger:false});
app.get('/health',async(_r,reply)=>{try{await client.db('admin').command({ping:1});return{status:'ok'}}catch{return reply.code(503).send({status:'database unavailable'})}});
app.get('/parent/:id',async(req,reply)=>{
 const id=Number(req.params.id);if(!Number.isSafeInteger(id))return reply.code(400).send({error:'invalid id'});
 const p=await parents.findOne({_id:Long.fromNumber(id)});if(!p)return reply.code(404).send({error:'parent not found'});
 return {id:Number(p.id?.toNumber ? p.id.toNumber() : p.id),account_number:Number(p.account_number?.toNumber ? p.account_number.toNumber() : p.account_number),status:p.status,created_at:p.created_at.toISOString(),payload:p.payload};
});
await app.listen({host:'0.0.0.0',port:8080});
