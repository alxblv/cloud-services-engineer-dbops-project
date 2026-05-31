# dbops-project
Исходный репозиторий для выполнения проекта дисциплины "DBOps"

Выдали пользователю testuser, под которым будут выполняться тесты и миграции, все привилегии, как в уроке 4 (Аспекты безопасности в работе с базами данных)

```
postgres=# create database store with owner johndoe;
CREATE DATABASE
postgres=# create role testuser with login password '123';
CREATE ROLE
postgres=# grant all privileges on database store to testuser;
GRANT
```