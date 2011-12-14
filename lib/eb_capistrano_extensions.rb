Capistrano::Configuration.instance(:must_exist).load do
  set :rails_root, "#{File.dirname(__FILE__)}/.."

  desc "Verify that the firewall configuration of the production boxes is correct"
  task :verify_firewall do
    hosts_to_verify = find_servers.map {|server| IPSocket.getaddress(server.host) }
    hosts_to_verify.each do |from_ip|
      hosts_to_verify.each do |to_ip|
        system "ssh root@#{from_ip} 'ufw allow from #{to_ip} to any'"
      end
      system "ssh root@#{from_ip} 'ufw reload'"
    end
  end

  desc "Make sure that MySQL access is granted to everything it should"
  task :verify_mysql_access, :roles => :db do
    require 'escape'
    database_servers = find_servers_for_task(current_task)
    password = Capistrano::CLI.password_prompt("what is the database root password?")
    password = Escape.shell_command([password])
    production_ips = find_servers.map {|server| [server.host, IPSocket.getaddress(server.host)] }
    database_config = YAML::load(File.open("#{rails_root}/config/database.yml"))[rails_env]
    
    database_servers.each do |db_server_ip|
      production_ips.each do |hostname, ip|
        grant_statement = %{grant all on #{database_config['database']}.* to `#{database_config['username']}`@`#{ip}` identified by '#{database_config['password']}';}
        grant_statement = Escape.shell_command(["echo", grant_statement])
        command = Escape.shell_command(["ssh", "root@#{db_server_ip}", grant_statement, "|", "mysql", "-u root -p#{password}"])
        system command
        puts "granted access to #{hostname} for db server #{db_server_ip}"
      end
    end
  end
end
