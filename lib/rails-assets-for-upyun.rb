require 'rest-client'
require 'uri'
class RailsAssetsForUpyun
  def self.publish(bucket, username, password, bucket_path="/", localpath='public', upyun_ap="http://v0.api.upyun.com")
    assets_prefix_name = bucket_path[1..-1]
    # http://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
    # sprocket2.x使用manifest-xxx.js , sprocket3.x使用.sprockets-manifest-xx.json
    manifest_paths = Dir[File.join "public", "#{assets_prefix_name}/.sprockets-manifest-*.json"]
    if manifest_paths.length > 1
      puts "#{assets_prefix_name}/.sprockets-manifest-*.json has multi version #{manifest_paths} \n get #{manifest_paths[0]}"
    elsif manifest_paths.length == 0
      puts "has not .sprockets-manifest-*.json file return"
      manifest_paths = Dir[File.join "public", "#{assets_prefix_name}/manifest-*.json"]
      if manifest_paths.length > 1
        puts "#{assets_prefix_name}/manifest-*.json has multi version #{manifest_paths} \n get #{manifest_paths[0]}"
      elsif manifest_paths.length == 0
        puts "has not manifest-*.json file return"
        return false
      end
    end
    
    JSON.parse(File.read(manifest_paths[0]))['assets'].each do |file_name, file|
      file = "#{localpath}/#{assets_prefix_name}/#{file}"
      unless File.file?(file)
        puts "#{file} is not a file"
        next
      end
    # Dir[File.join localpath, "**{,/*/**}/*"].select{|f| File.file? f}.each do |file|
      upload(file, bucket, username, password, assets_prefix_name, localpath, upyun_ap)
    end

    Dir[File.join localpath, "*"].select{|f| File.file? f}.each do |file|
      upload(file, bucket, username, password, assets_prefix_name, localpath, upyun_ap)
    end
  end

  def self.signature(method, uri, date, content_length, password)
    Digest::MD5.hexdigest "#{method}&#{uri}&#{date}&#{content_length}&#{Digest::MD5.hexdigest password}"
  end

  def self.upload(file, bucket, username, password, bucket_path="/", localpath='public', upyun_ap="http://v0.api.upyun.com")
    # public/rujia-wap/maps-f7b45bf124f24075f70001a7ccf8fdac.js
    start_path_num = localpath.to_s.size + bucket_path.to_s.size + 2
    url = URI.encode "/#{bucket}/#{bucket_path}/#{file[start_path_num..-1]}"
    date = Time.now.httpdate
    size = RestClient.head("#{upyun_ap}#{url}", {\
        Authorization: "UpYun #{username}:#{signature 'HEAD', url, date, 0, password}", 
        Date: date}) do |response, request, result, &block|
      case response.code 
      when 200
        response.headers[:x_upyun_file_size].to_i
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
      RestClient.put("#{upyun_ap}#{url}",  file_content,{\
        Authorization: "UpYun #{username}:#{signature 'PUT', url, date, file_size, password}", 
        Date: date,
        mkdir: 'true',
        Content_MD5: Digest::MD5.hexdigest(file_content),
        })
    end
  end
end
