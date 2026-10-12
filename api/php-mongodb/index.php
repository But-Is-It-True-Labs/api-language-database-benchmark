<?php
declare(strict_types=1);
header('Content-Type: application/json');
function answer(int $code,array $body):never {http_response_code($code);echo json_encode($body,JSON_UNESCAPED_SLASHES);exit;}
try { $manager=new MongoDB\Driver\Manager(getenv('MONGO_URL')); }
catch(Throwable $e){answer(503,['error'=>'database unavailable']);}
$path=parse_url($_SERVER['REQUEST_URI'],PHP_URL_PATH);
if($path==='/health'){
  try{$manager->executeCommand('admin',new MongoDB\Driver\Command(['ping'=>1])); answer(200,['status'=>'ok']);}
  catch(Throwable $e){answer(503,['status'=>'database unavailable']);}
}
if(preg_match('~^/parent/([0-9]+)$~',$path,$match)){
  try{
    $query=new MongoDB\Driver\Query(['_id'=>new MongoDB\BSON\Int64($match[1])],['limit'=>1]);
    $cursor=$manager->executeQuery('benchmark.benchmark_parent',$query);
    foreach($cursor as $p){
      $dt=$p->created_at->toDateTime();
      answer(200,['id'=>(int)(string)$p->id,'account_number'=>(int)(string)$p->account_number,'status'=>$p->status,'created_at'=>$dt->format('Y-m-d\TH:i:s.v\Z'),'payload'=>$p->payload]);
    }
    answer(404,['error'=>'parent not found']);
  }catch(Throwable $e){error_log($e->getMessage());answer(500,['error'=>'query failed']);}
}
answer(404,['error'=>'not found']);
