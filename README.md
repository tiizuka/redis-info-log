redis-info-log
==============

Periodically save Redis INFO output from servers

config.yml sample
```yaml
base_dir:            /path/to/this/dir
redis_cli_exe:       /path/to/bin/redis-cli
redis_cli_auth_file: ./auth
command:             info
loop_exec_interval:  60
log_file:            log/redis_info_log.log

servers:
  server01:
    host:             127.0.0.1
    port:             6379
    output_strftime:  log/server01.%Y-%m-%d
  server02:
    host:             127.0.0.1
    port:             6380
    output_strftime:  log/server02.%Y-%m-%d
  server03:
    host:             127.0.0.1
    port:             6381
    output_strftime:  log/server03.%Y-%m-%d
```
