![Logo](/pictures/logo.png)

#### Автоматическое развёртывание в виртуальной среде с использованием Vagrant, Libvirt, QEMU, KVM и Ansible службы обмена мгновенными сообщениями на базе XMPP-сервера [Ejabberd](https://docs.ejabberd.im/)

> [!NOTE]
> [Ejabberd](https://docs.ejabberd.im/) — это надежная, масштабируемая и расширяемая платформа реального времени с открытым исходным кодом, созданная с использованием Erlang/OTP, которая включает в себя сервер XMPP, брокер MQTT ислужбу SIP.

##### Описание стенда
Для работы будем использовать виртуальный стенд, построенный с использованием среды разработки [Vagrant](https://www.vagrantup.com/), инструментов управления виртуализацией [Libvirt](https://libvirt.org/), 
эмулятора виртуальных машин [Qemu](https://www.qemu.org/), модуля ядра, использующего расширения виртуализации (Intel VT или AMD-V) [KVM](https://linux-kvm.org/page/Main_Page) и инструмента автоматизации [Ansible](https://www.ansible.com/).
Логическая схема стенда выглядит следующим образом:

![Схема сети](/pictures/ejabberd.drawio.png)

Здесь мы примем условно, что фронтэнд, это две ноды _Ejabberd_, которые одним из сетевых интерфейсов доступны извне, в данном случае с хоста виртуализации, сеть - 192.168.121.0/24. 
Второй интерфейс у них находится в сети 192.168.1.0/29, которую мы так же условно, будем считать демилитаризованной зоной. Внутренняя сеть - 192.168.1.8/29 в которой размещены т.н. Backend-серверы,
отделена от демилитаризованной зоны виртуальным хостом _gw1server_ с двумя сетевыми интерфейсами - 192.168.1.1/29 и 192.168.1.9.29, подключенными к этим двум виртуальным сетям и являющимся шлюзом между ними.

##### Первоначальное развёртывание

Для развертывания сети будем использовать _Vagrant_. Блок настроек, включающий в себя аппаратные характеристики машины и её сетевые параметры, за небольшими деталями, одинаков для всех машин. Приведем пример данного блока:
```
Vagrant.configure("2") do |config|
  config.vm.define "Debian12-eJabberd1" do |e1server|
  e1server.vm.box = "/home/max/vagrant/images/debian12"
  e1server.vm.network :private_network,
       :type => 'ip',
       :libvirt__forward_mode => 'veryisolated',
       :libvirt__dhcp_enabled => false,
       :ip => '192.168.1.2',
       :libvirt__netmask => '255.255.255.248',
       :libvirt__network_name => 'vagrant-libvirt-inet1',
       :libvirt__always_destroy => false
  e1server.vm.provider "libvirt" do |lvirt|
      lvirt.memory = "1024"
      lvirt.cpus = "1"
      lvirt.title = "Debian12-e1Server"
      lvirt.description = "Виртуальная машина на базе дистрибутива Debian Linux. e1Server"
      lvirt.management_network_name = "vagrant-libvirt-mgmt"
      lvirt.management_network_address = "192.168.121.0/24"
      lvirt.management_network_keep = "true"
      lvirt.management_network_mac = "52:54:00:27:28:83"
  end
```
Здесь с помощью параметра _e1server.vm.box_ задан начальный образ, с которого развёртывается машина, и две сети: сеть управления и изолированная сеть - параметры _e1server.vm.network_ и _lvirt.management\_network\_{name,address,keep,mac}_.
Для изолированной сети явно задаётся имя сети, IP-адрес и маска. Параметр _libvirt\_\_always\_destroy_ со значением "true" не разрешает виртуальным машинам, которые исользуют сеть, но не создавали её уничтожать её при уничтожении виртуальной машины (домена).

С помощью директив _vm.provision "file"_ на разворачиваемые машины копируются необходимые для дальнейшей работы файлы:
```
  e1server.vm.provision "file", source: "ca/e1server.pem", destination: "~/e1server.pem"
  e1server.vm.provision "file", source: "bacula/e1/bacula-fd.conf", destination: "~/bacula-fd.conf"
```

Следующий блок, начинающийся на _vm.provision "shell"_, предполагает выполнение заданных действий в командной оболочке операционной системы машины:
```
  e1server.vm.provision "shell", inline: <<-SHELL
      brd='*************************************************************'
      echo "$brd"
      echo 'Set Hostname'
      hostnamectl set-hostname e1server
      echo "$brd"
      sed -i 's/debian12/e1server/' /etc/hosts
      sed -i 's/debian12/e1server/' /etc/hosts
      echo '192.168.1.2 e1server.domain.local e1server' >> /etc/hosts
      echo '192.168.1.3 e2server.domain.local e2server' >> /etc/hosts
      echo '192.168.1.10 psql1server.domain.local psql1server' >> /etc/hosts
      echo '192.168.1.11 psql2server.domain.local psql2server' >> /etc/hosts
      echo "$brd"
      echo 'Изменим ttl для работы через раздающий телефон'
      echo "$brd"
      sysctl -w net.ipv4.ip_default_ttl=66
      echo "$brd"
      echo 'Если ранее не были установлены, то установим необходимые  пакеты'
      echo "$brd"
      export DEBIAN_FRONTEND=noninteractive
      apt update
      apt install -y iptables iptables-persistent
      # Политика по умолчанию для цепочки INPUT - DROP
      iptables -P INPUT DROP
      # Политика по умолчанию для цепочки OUTPUT - DROP
      iptables -P OUTPUT DROP
      # Политика по умолчанию для цепочки FORWARD - DROP
      iptables -P FORWARD DROP
      # Базовый набор правил: разрешаем локалхост, запрещаем доступ к адресу сети обратной петли не от локалхоста, разрешаем входящие пакеты со статусом установленного сонединения.
      iptables -A INPUT -i lo -j ACCEPT
      iptables -A INPUT ! -i lo -d 127.0.0.0/8 -j REJECT
      iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
      # Открываем исходящие
      iptables -A OUTPUT -j ACCEPT
      # Разрешим входящие с хоста управления.
      iptables -A INPUT -s 192.168.121.1 -j ACCEPT
      # Также, разрешим входящие для vrrp и e2server
      iptables -A INPUT -s 192.168.1.0/29 -m tcp -m multiport -p tcp --dports 5222,5223,5269,5443,5280,1883,4369,4200:4210 -j ACCEPT
      iptables -A INPUT -s 192.168.1.0/28 -m tcp -m multiport -p tcp --dports 22,9102 -j ACCEPT
      iptables -A INPUT -p vrrp -d 224.0.0.18 -j ACCEPT
      iptables -A INPUT -s 192.168.1.0/29 -m udp -m multiport -p udp --dports 514,3478 -j ACCEPT
      # Откроем ICMP ping
      iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
      netfilter-persistent save
      ip route add 192.168.1.8/29 via 192.168.1.1
      ip route save > /etc/my-routes
      echo 'up ip route restore < /etc/my-routes' >> /etc/network/interfaces
      SHELL
```
Здесь используются те же правила, что и в стандартном _bash_ - знак _#_ в начале строки является комментарием, пустые строки игнорируются. 
Также работают системные  переменные, что позволяет не использовать полные пути к исполняемым командам.

> [!IMPORTANT]
> _vm.provision "file"_ Выполняется с правами пользователя _vagrant_, в то время, как _vm.provision "shell"_ работает с привелегиями суперпользоваттеля. Это необходимо учитывать, планируя послеустановочную настройку системы.

Все виртуальные узлы в данном стенде разворачиваются с помощью описаний в _Vagrant_ файле. При этом, установка и настройка прикладного программного обеспечения производится после с помощью _Ansible_, 
за исключением файерволла - установка iptables (nftables) и настройка правил осуществляется на этапе установки.

##### Ejabberd
###### Подключение к СУБД
В нашем проекте основной компонент - _Ejabberd_ устновлен в кластерном исполнении на двух виртуальных машинах. По умолчанию, для своей работы _Ejabberd_ использует базу данных [Mnesia](https://www.erlang.org/doc/apps/mnesia/api-reference.html).
Настройка на работу с [альтернативными СУБД](https://docs.ejabberd.im/admin/configuration/database/#supported-storages) - MySQL, PostgreSQL, MS SQL Server, SQLite, LDAP производится после установки сервиса. Также, начиная с версии 23.10, _Ejabberd_ 
позволяет с помощью параметра _update\_sql\_schema_ автоматически создавать и обновлять таблицы в базе данных SQL при использовании MySQL, PostgreSQL или SQLite.

Для создания базы данных,а так же роли с правами на эту базу подойдут следующие команды:
```
CREATE DATABASE "ejabberd-domain-local"
CREATE USER ejabberd WITH PASSWORD 'P@ssw0rd';
GRANT ALL ON DATABASE "ejabberd-domain-local" TO ejabberd;
```
Создание структуры базы данных:
```
psql -d ejabberd-domain-local -f /usr/share/ejabberd/sql/pg.sql
```

Эти шаги, выполненяемые в _Ansible_ и описанные в yml-файле. Создание базы и пользователя:
```
- name: PostgreSQL | Primary Server. Create database and role. Создаём базу данных и пользователя с полными правами на неё на Primary экземпляре сервера баз данных.
  hosts: psql1server
  become: true
  become_user: postgres
  vars:
    allow_world_readable_tmpfiles: true
    - name: Create a new database with name "ejabberd-domain-local". Создаём базу данных Jabber-сервера.
      community.postgresql.postgresql_db:
        name: ejabberd-domain-local
        comment: "eJabberd database"
    - name: Connect to eJabberd database, create ejabberd user, and grant access to database and all tables. Создаём пользователя с правами на эту базу данных.
      community.postgresql.postgresql_user:
        db: ejabberd-domain-local
        name: ejabberd
        password: P@ssw0rd
        expires: "infinity"
    - name: Connect to eJabberd database, grant privileges on ejabberd-domain-local database objects (database). Задаём привелегии на базу данных ejabberd-domain-local для пользователя ejabberd.
      community.postgresql.postgresql_privs:
        database: ejabberd-domain-local
        state: present
        privs: ALL
        type: database
        roles: ejabberd
    - name: Connect to eJabberd database, grant privileges on ejabberd-domain-local database objects (schema). Задаём привелегии на объект Schema для пользователя ejabberd.
      community.postgresql.postgresql_privs:
        database: ejabberd-domain-local
        state: present
        privs: CREATE
        type: schema
        objs: public
        roles: ejabberd
```
Создание структуры БД:
```
- name: PostgreSQL | Create tables at database ejabberd-domain-local. Создание таблиц в базе данных ejabberd-domain-local "главного" сервера баз данных. Запуск скрипта производится удалённо.
  hosts: e1server
  tasks:
    - name: Connect from e1server to psql1server and run script
      postgresql_query:
        login_host: 192.168.1.10
        db: ejabberd-domain-local
        login_user: ejabberd
        login_password: Inc0gn1t0
        path_to_script: /usr/share/ejabberd/sql/pg.sql
```
> ![NOTE]
> Обратите внимание, создание баазы данных, роли, а также выполнение скрипта, создающего таблицы в данной базе, выполняются только на одном из серверов будущего кластера СУБД. Все данные с этого сервера
> будут скопированы на второй в процессе потоковой репликации, которая будет выполнена позже.

После того, как база данных и роль для работы с ней были созданы, потребуется настроить _Ejabberd_ для работы с ней. Для этого отредактируем главный конфигурационный файл - /etc/ejabberd/ejabberd.yml, добавив следующие строки:
```
# Database settings
host_config:
  domain.local:
    sql_type: pgsql
    sql_server: 192.168.1.10
    sql_database: ejabberd-domain-local
    sql_username: ejabberd
    sql_password: P@ssw0rd
    auth_method:
      - sql
```

В _Ansible_ задача выглядит так:
```
- name: eJabberd | Confgure ejservers for psql1server connect. Jabber-серверы, настраиваем домен, подключаем к СУБД.
  hosts: ejserver
  become: true
  tasks:
    - name: Edit ejabberd.yml for connection to remote db. Add admin.
      ansible.builtin.shell: |
        sed -i 's/localhost/domain.local/' ejabberd.yml
        echo ''  >> ejabberd.yml
        echo '# Database settings' >> ejabberd.yml
        echo 'host_config:' >> ejabberd.yml
        echo '  domain.local:' >> ejabberd.yml
        echo '    sql_type: pgsql' >> ejabberd.yml
        echo '    sql_server: 192.168.1.10' >> ejabberd.yml
        echo '    sql_database: ejabberd-domain-local' >> ejabberd.yml
        echo '    sql_username: ejabberd' >> ejabberd.yml
        echo '    sql_password: Inc0gn1t0' >> ejabberd.yml
        echo '    auth_method:' >> ejabberd.yml
        echo '      - sql' >> ejabberd.yml
        echo ''  >> ejabberd.yml
        echo '    acl:'  >> ejabberd.yml
        echo '      admin:'  >> ejabberd.yml
        echo '        user: admin@domain.local'  >> ejabberd.yml
        echo ''  >> ejabberd.yml
        echo '    access_rules:'  >> ejabberd.yml
        echo '      configure:'  >> ejabberd.yml
        echo '        allow: admin'  >> ejabberd.yml
        systemctl restart ejabberd.service
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```
