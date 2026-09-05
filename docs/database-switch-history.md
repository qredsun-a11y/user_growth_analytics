# 数据库从 MySQL 切换到 MariaDB 的历史

## 一、安装时间线

根据 apt 历史日志，数据库安装过程如下：

### 阶段 1：首次安装 MySQL (2026-09-03 17:42)
```bash
apt-get install -y mysql-server mysql-client
```
**结果**：安装失败，返回错误码 1

### 阶段 2：尝试移除 MariaDB (2026-09-03 17:42)
```bash
apt remove -y mariadb-*
```
**结果**：失败

### 阶段 3：再次安装 MySQL (2026-09-03 17:43)
```bash
apt install -y mysql-server mysql-client
apt-get install -y mysql-server mysql-client --fix-missing
```
**结果**：仍然失败

### 阶段 4：移除 MySQL (2026-09-04 01:07)
```bash
apt-get remove -y mysql-server mysql-common
```
**结果**：成功移除 MySQL 8.0.46

### 阶段 5：安装 MariaDB (2026-09-04 01:10)
```bash
apt-get install -y mariadb-server mariadb-client
```
**结果**：安装 MariaDB 10.11.19，虽然有错误码但实际成功

---

## 二、问题原因分析

### 2.1 MySQL 8.0 的限制

MySQL 8.0 对 TEXT/BLOB 类型的默认值有更严格的限制：

```sql
-- MySQL 8.0 不支持
CREATE TABLE test (
  data TEXT NOT NULL DEFAULT ''
);

-- 错误信息
ERROR 1101 (42000): BLOB/TEXT column 'data' can't have a default value
```

### 2.2 Frappe 的依赖

Frappe 框架中大量 DocType 使用 TEXT 字段并设置默认值：

| DocType | 字段 | 类型 | 默认值 |
|---------|------|------|--------|
| tabDocField | description | Text | "" |
| tabDocField | options | Small Text | "" |
| tabCustom Field | desc | Text | "" |
| tabProperty Setter | value | Long Text | "" |
| tabSingles | value | Long Text | "" |

### 2.3 "struct_trans_table" 问题

虽然Frappé源码中没有直接叫 `struct_trans_table` 的表，但这个问题通常出现在：

1. **迁移过程中的表创建**：Frappe migrate 会创建大量表
2. **TEXT 字段的默认值**：MySQL 8.0 拒绝为 TEXT 类型设置 DEFAULT
3. **JSON 字段**：MySQL 8.0 对 JSON 默认值也有类似限制

---

## 三、MariaDB 的优势

### 3.1 兼容性改进

MariaDB 10.5+ 改进了对 TEXT 类型默认值的支持：

```sql
-- MariaDB 支持
CREATE TABLE test (
  data TEXT NOT NULL DEFAULT ''
);
-- 成功
```

### 3.2 与 Frappe 的兼容性

Frappe 官方推荐使用 MariaDB：
- 更好的向后兼容性
- 无需修改框架代码
- 更稳定的迁移过程

---

## 四、当前状态

```bash
# 已安装的包
ii  mariadb-server-core    1:10.11.19
ii  mariadb-client         1:10.11.19
rc  mysql-server-8.0       8.0.46 (已移除，配置残留)

# Frappe 配置
db_type: mariadb
db_name: _b3068af8ebfe1fd8
```

---

## 五、经验总结

1. **不要在 Ubuntu 22.04+ 上先安装 MySQL**
   - MySQL 8.0 有严格的 TEXT 默认值限制
   - 会导致 Frappe migrate 失败

2. **直接使用 MariaDB**
   - apt-get install -y mariadb-server mariadb-client
   - 与 Frappe 完美兼容

3. **如果已经安装了 MySQL**
   - 先完全移除：`apt-get remove -y mysql-server mysql-common`
   - 再安装 MariaDB：`apt-get install -y mariadb-server mariadb-client`

---

*记录时间：2026-09-05*
