#!/usr/bin/env ruby
require 'yaml'

class RedisInfoLog
  class RedisCliCommand
    def initialize(h)
      @redis_cli_exe       = h[:redis_cli_exe]
      @redis_cli_auth_file = h[:redis_cli_auth_file]
      @command             = h[:command]
      @with_base_dir       = h[:with_base_dir]
      @host                = h[:host]
      @port                = h[:port]
      @output_strftime     = h[:output_strftime]
    end

    def command_str(output)
      [ [ @redis_cli_exe            ] ,
        [ "-h"             , @host  ] ,
        [ "-p"             , @port  ] ,
        (@redis_cli_auth_file ?
          [ "--auth-file"  , @with_base_dir.path(@redis_cli_auth_file) ] :
          nil                                                            ) ,
        [ @command                  ] ,
        [ ">>"             , output ] ,
        [ "2>&1"                    ] ###
      ].compact.flatten.join(" ")
    end

    def exec_and_log
      t0 = Time.now
      output = @with_base_dir.path(t0.strftime(@output_strftime))
      system(command_str(output))
      t1 = Time.now
      RedisInfoLog.log(output, t0, t1, $?.inspect.sub(/#<Process::Status: (.*?)>/){$1}, "---")
    end
  end

  class WithBaseDir
    def initialize(base_dir)
      @base_dir = base_dir
    end

    def path(file)
      "#{@base_dir}/#{file}"
    end
  end

  def self.log(file, t0, t1, str, prefix = nil)
    File.open(file, "a") { |f|
      f.puts [prefix, (t0 || Time.now).strftime("%Y-%m-%d %H:%M:%S.%3N"), (t1 ? ("%.3f" % (t1 - t0)) : nil), str].compact.join(" ")
    }
  end

  def initialize(h)
    @base_dir            = h[:config]["base_dir"]
    @redis_cli_exe       = h[:config]["redis_cli_exe"]
    @redis_cli_auth_file = h[:config]["redis_cli_auth_file"]
    @command             = h[:config]["command"]
    @loop_exec_interval  = h[:config]["loop_exec_interval"]
    @log_file            = h[:config]["log_file"]
    @servers             = h[:config]["servers"]
    @with_base_dir = WithBaseDir.new(@base_dir)
  end

  def exec
    @servers.each { |k,v|
      RedisCliCommand.new( redis_cli_exe:       @redis_cli_exe       ,
                           redis_cli_auth_file: @redis_cli_auth_file ,
                           command:             @command             ,
                           with_base_dir:       @with_base_dir       ,
                           host:                v["host"]            ,
                           port:                v["port"]            ,
                           output_strftime:     v["output_strftime"] ).exec_and_log()
    }
  end

  def loop_exec
    while true
      t0 = Time.now
      exec
      t1 = Time.now
      RedisInfoLog.log(@with_base_dir.path(@log_file), t0, t1, "pid:#{Process.pid}")
      sleep [@loop_exec_interval - (t1 - t0), 0].max
    end
  end

  def loop_exec_daemon
    Process.daemon
    begin
      loop_exec
    rescue Exception
      RedisInfoLog.log(@with_base_dir.path(@log_file), nil, nil, [$!, $!.backtrace].inspect)
      raise
    end
  end
end


CONFIG_FILE = "config.yml"

RedisInfoLog.new(config: YAML.load_file(CONFIG_FILE)).loop_exec_daemon
