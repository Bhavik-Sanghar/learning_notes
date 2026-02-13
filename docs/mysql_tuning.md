# MySQL 8.0 Configuration Justification (Heavy Workload)

> Target: OLTP-heavy platform with frequent enrollment/progress writes and high read concurrency.

## 1) Example `my.cnf` baseline

```ini
[mysqld]
# Core
bind-address = 0.0.0.0
port = 3306
skip_name_resolve = ON
max_connections = 1000
thread_cache_size = 256

# InnoDB memory + durability
innodb_buffer_pool_size = 8G
innodb_buffer_pool_instances = 8
innodb_log_file_size = 1G
innodb_log_buffer_size = 128M
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 8
innodb_write_io_threads = 8

# Temp/sort and table cache
tmp_table_size = 128M
max_heap_table_size = 128M
table_open_cache = 8000
table_definition_cache = 4000
open_files_limit = 65535

# Binary logging / replication safety
server_id = 101
log_bin = mysql-bin
binlog_format = ROW
sync_binlog = 1
expire_logs_days = 7

# Slow query observability
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 0.5
log_queries_not_using_indexes = OFF

# Per-connection caps (avoid runaway memory)
sort_buffer_size = 2M
join_buffer_size = 2M
read_buffer_size = 1M
read_rnd_buffer_size = 2M
```

## 2) Why these settings

- `innodb_buffer_pool_size`: Keeps hot tables/indexes in memory for read-heavy lesson/progress/exam lookups.
- `innodb_log_file_size` + `innodb_log_buffer_size`: Helps sustained write bursts from logs and attempts.
- `innodb_flush_log_at_trx_commit=1` + `sync_binlog=1`: Maximum durability for enrollment/payment/certificate integrity.
- `skip_name_resolve`: Removes DNS latency from frequent connections.
- `table_open_cache` and `thread_cache_size`: Reduce connection and metadata overhead under concurrency.
- Conservative per-connection buffers protect server memory when `max_connections` is high.

## 3) Environment-specific tuning guidance

- Start with 50–60% RAM for buffer pool on dedicated DB hosts.
- Increase `innodb_io_capacity` only when storage can sustain it.
- For non-critical staging load tests, you may temporarily relax durability (`innodb_flush_log_at_trx_commit=2`, `sync_binlog=0`) to measure throughput ceiling.

## 4) Installation notes (Ubuntu example)

```bash
sudo apt update
sudo apt install -y mysql-server
sudo systemctl enable --now mysql
mysql -uroot -p -e "SELECT VERSION();"
```

Apply config, then:

```bash
sudo systemctl restart mysql
mysql -uroot -p -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
```

