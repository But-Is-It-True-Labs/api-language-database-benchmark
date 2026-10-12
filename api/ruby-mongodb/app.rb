require 'roda'
require 'mongo'
require 'json'
require 'time'
Mongo::Logger.logger.level=Logger::WARN
DB=Mongo::Client.new(ENV.fetch('MONGO_URL'),database:'benchmark',max_pool_size:50)
class App < Roda
  route do |r|
    response['Content-Type']='application/json'
    r.get 'health' do
      begin
        DB.database.command(ping:1)
        JSON.generate(status:'ok')
      rescue StandardError
        response.status=503
        JSON.generate(status:'database unavailable')
      end
    end
    r.on 'parent' do
      r.get String do |key|
        unless key.match?(/\A[0-9]+\z/)
          response.status=400; next JSON.generate(error:'invalid id')
        end
        p=DB[:benchmark_parent].find(_id:key.to_i).first
        unless p
          response.status=404; next JSON.generate(error:'parent not found')
        end
        JSON.generate(id:p['id'].to_i,account_number:p['account_number'].to_i,status:p['status'],created_at:p['created_at'].utc.iso8601(3),payload:p['payload'])
      end
    end
  end
end
