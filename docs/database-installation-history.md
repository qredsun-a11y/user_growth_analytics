# 数据库安装历史

## 一、安装时间线

### 第一阶段：安装 MySQL 8.0

```bash
# 安装命令
apt-get install -y mysql-server mysql-client

# 安装的包
- mysql-server-8.0: 8.0.46
- mysql-client-8.0: 8.0.46
- mysql-common: 1:10.11.19+maria~ubu2204
```

**时间**: 2026-09-03 前后

### 第二阶段：移除 MySQL

```bash
# 移除命令
apt-get remove -y mysql-server mysql-common
```

**原因**: Frappe 安装时遇到表创建失败

### 第三阶段：安装 MariaDB

```bash
# 安装命令
apt-get install -y mariadb-server mariadb-client

# 安装的包
- mariadb-server: 10.11.19
- mariadb-client: 10.11.19
- mariadb-server-core: 10.11.19
- mariadb-client-core: 10.11.19
```

**结果**: 成功运行

---

## 二、问题根因分析

### 2.1 MySQL 8.0 的 TEXT 默认值限制

**问题 SQL**:
```sql
CREATE TABLE `tabCustom Field` (
  `description` text NOT NULL DEFAULT '',  -- ❌ 报错
  ...
);
```

**错误信息**:
```
ERROR 1101 (42000): BLOB/TEXT column 'description' can't have a default value
```

### 2.2 Frappe 中的受影响字段

Frappe 框架中大量使用 TEXT 类型并设置默认值：

| DocType | 字段 | 类型 | 默认值 |
|---------|------|------|--------|
| tabDocField | description | TEXT | '' |
| tabCustom Field | desc | TEXT | '' |
| tabProperty Setter | value | TEXT | '' |
| tabSingles | value | LONGTEXT | '' |

### 2.3 MySQL vs MariaDB 行为对比

| 特性 | MySQL 8.0 | MariaDB 10.11 |
|------|-----------|---------------|
| TEXT DEFAULT '' | ❌ 报错 | ✅ 支持 |
| JSON DEFAULT | ❌ 限制多 | ✅ 支持 |
| Frappe 兼容性 | ⚠️ 需要修改源码 | ✅ 原生支持 |

---

## 三、技术背景

### 3.1 为什么 MySQL 有这种限制？

MySQL 的设计哲学：
- TEXT/BLOB 类型是"大对象"，存储方式特殊
- 默认值会在 InnoDB 内部数据字典中存储，可能导致页溢出
- 这是一个保守的设计决策

### 3.2 MariaDB 为什么能解决？

MariaDB 的改进：
- 更灵活的存储引擎实现
- 对 DEFAULT 值的处理更宽松
- 保持与 MySQL 的协议兼容

### 3.3 Frappe 官方的选择

Frappe 框架文档明确推荐：
> "We recommend using MariaDB on Linux systems."

原因：
1. 更好的兼容性（无需修改源码）
2. 更稳定的表现
3. 社区支持更好

---

## 四、验证当前状态

### 4.1 数据库配置

```json
// /home/frappe/bench/sites/site1.local/site_config.json
{
  "db_type": "mariadb",
  "db_name": "_b3068af8ebfe1fd8",
  "db_password": "wzb6kkSOwaoEBr2A"
}
```

### 4.2 已安装的包

```bash
# MariaDB（运行中）
ii  mariadb-server-core              1:10.11.19
ii  mariadb-client                   1:10.11.19

# MySQL（已移除，配置残留）
rc  mysql-server-8.0                 8.0.46
```

### 4.3 连接测试

```bash
# 通过 Frappe 测试
bench --site site1.local console
>>> import frappe
>>> frappe.connect()
>>> frappe.db.sql("SELECT VERSION()")
[('10.11.19-MariaDB',)]
```

---

## 五、经验总结

### 5.1 在 WSL/Ubuntu 上安装 Frappe

**推荐顺序**：
1. 直接安装 MariaDB（不要先装 MySQL）
2. 配置 Frappe site
3. 运行 migrate

**命令**：
```bash
# 正确做法
apt-get install -y mariadb-server mariadb-client
bench new-site site1.local

# 错误做法（会遇到问题）
apt-get install -y mysql-server  # 不要这样做
```

### 5.2 如果已经安装了 MySQL

**迁移步骤**：
```bash
# 1. 停止 MySQL
systemctl stop mysql

# 2. 移除 MySQL（保留数据）
apt-get remove -y mysql-server mysql-client

# 3. 安装 MariaDB
apt-get install -y mariadb-server mariadb-client

# 4. 启动 MariaDB
systemctl start mariadb

# 5. 迁移数据（如果需要）
mysqldump -u root old_db | mariadb -u root new_db
```

### 5.3 关键区别

| 方面 | MySQL 8.0 | MariaDB 10.11 |
|------|-----------|---------------|
| TEXT DEFAULT | ❌ 不支持 | ✅ 支持 |
| Frappe 兼容性 | ⚠️ 需修改 | ✅ 原生 |
| 安装复杂度 | 高 | 低 |
| 推荐度 | 不推荐 | 推荐 |

---

## 六、参考链接

- [Frappe 官方文档 - Database](https://frappeframework.com/docs/user/en/installation)
- [MariaDB  vs MySQL 对比](https://mariadb.com/kb/en/mariadb-vs-mysql-features/)
- [MySQL TEXT 默认值限制](https://dev.mysql.com/doc/refman/8.0/en/blob.html)

---

*文档生成时间：2026-09-05*
