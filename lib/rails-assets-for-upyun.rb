require 'rest-client'
require 'uri'
class RailsAssetsForUpyun
  def self.publish(bucket, username, password, custom_host=nil, bucket_path="/", localpath='public', upyun_ap="http://v0.api.upyun.com")
    # http://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
    _upyun_head_host = custom_host || upyun_ap
    puts "head host: #{_upyun_head_host}"
    Dir[File.join localpath, "**{,/*/**}/*"].select{|f| File.file? f}.each do |file|
      
      head_url = URI.encode "#{"/#{bucket}" if custom_host.nil?}#{bucket_path}#{file[localpath.to_s.size + 1 .. -1]}"
      url = URI.encode "/#{bucket}#{bucket_path}#{file[localpath.to_s.size + 1 .. -1]}"
      puts "encode head_url: #{head_url}"
      date = Time.now.httpdate
      size = RestClient.head("#{_upyun_head_host}#{head_url}", {\
          Authorization: "UpYun #{username}:#{signature 'HEAD', url, date, 0, password}", 
          Date: date}) do |response, request, result, &block|
        case response.code 
        when 200
          if custom_host.nil?
            response.headers[:x_upyun_file_size].to_i
          else
            response.headers[:content_length].to_i
          end
        when 404
          "non-exists"
        else
          response.return!(request, result, &block)
        end
      end
      if size == (file_size = File.size file)
        puts "skipping #{file}.."
      else
        file_content = File.read(file)
        puts "uploading #{size} => #{file_size} #{file}.."
        puts "uploading url: #{url}"
        RestClient.put("#{upyun_ap}#{url}",  file_content,{\
          Authorization: "UpYun #{username}:#{signature 'PUT', url, date, file_size, password}", 
          Date: date,
          mkdir: 'true',
          Content_MD5: Digest::MD5.hexdigest(file_content),
          })
      end
    end
  end
  def self.signature(method, uri, date, content_length, password)
    Digest::MD5.hexdigest "#{method}&#{uri}&#{date}&#{content_length}&#{Digest::MD5.hexdigest password}"
  end
end
