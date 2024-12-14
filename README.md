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
Здесь с помощью параметра _e1server.vm.box_ задан начальный образ, с которого развёртывается машина, и две сети: 
сеть управления и изолированная сеть - параметры _e1server.vm.network_ и _lvirt.management\_network\_{name,address,keep,mac}_.
Для изолированной сети явно задаётся имя сети, IP-адрес и маска. Параметр _libvirt\_\_always\_destroy_ со значением "true" 
не разрешает виртуальным машинам, которые используют виртуальную сеть, но не создавали её, уничтожать эту сеть при уничтожении виртуальной машины (домена).

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
В блоке `provision "shell"` используются те же правила, что и в стандартном _bash_ - знак _#_ в начале строки является комментарием, пустые строки игнорируются. 
Также работают системные  переменные, что позволяет не использовать полные пути к исполняемым командам.

> [!IMPORTANT]
> _vm.provision "file"_ Выполняется с правами пользователя _vagrant_, в то время, как _vm.provision "shell"_ работает с привелегиями суперпользоваттеля. Это необходимо учитывать, планируя послеустановочную настройку системы.

Все виртуальные узлы в данном стенде разворачиваются с помощью команд, правил и описаний в _Vagrant_ файле. 
При этом, установка и настройка прикладного программного обеспечения производится после с помощью _Ansible_, 
за исключением файерволла - установка iptables (nftables) и настройка правил осуществляется на этапе установки.

##### Ejabberd
###### Установка
Установка _Ejabberd_ производится из репозиториев "bookworm-backports". Для этого создаём следующую задачу:
```
- name: eJabberd | Group of servers "ejserver". Install and configure ejabberd. Installing "ejabberd" and "bacula-client" packages on the "ejserver" server group
  hosts: ejserver
  become: true
  tasks:
    - name: APT. Add Backports repository into sources list
      ansible.builtin.apt_repository:
        repo: deb http://deb.debian.org/debian bookworm-backports main contrib non-free
        state: present
    - name: APT. Update the repository cache and install packages "eJabberd", "erlang-p1-pgsql", "python3-psycopg2", "acl", "bacula-client" to latest version using default release bookworm-b>
      ansible.builtin.apt:
        name: ejabberd,erlang-p1-pgsql,python3-psycopg2,acl,bacula-client
        state: present
        default_release: bookworm-backports
        update_cache: yes
    - name: Bacula-client. Copy configuration file. Restart of service
      ansible.builtin.shell: |
        cp /home/vagrant/bacula-fd.conf /etc/bacula/
        systemctl restart bacula-fd.service
      args:
        executable: /bin/bash
```
В которой мы добавили новый репозиторий и установили необходимое ПО, указав в качестве источника "bookworm-backports". 
Помимо _Ejabberd_ в ней так же ставится клиент системы резервного копирования - _Bacula_.

###### Общие настройки
Изменим домен по умолчанию, который обслуживает наш сервер. Это параметр _hosts_ в конфигурационном файле /etc/ejabberd/ejabberd.yml:
```
# hosts: Domains served by ejabberd.
# You can define one or several, for example:
# hosts:
#   - "example.net"
#   - "example.com"
#   - "example.org"

hosts:
  - domain.local
```
Ansible playbook:
```
- name: eJabberd | Group of servers "ejserver". Confgure ejservers for domainname and psql1server connect. Granting administrator account rights
  hosts: ejserver
  become: true
  tasks:
    - name: Edit ejabberd.yml for domainname.
      ansible.builtin.shell: |
        sed -i 's/localhost/domain.local/' ejabberd.yml
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```
<a name="admin-rights-point"></a>
Зададим права админа для домена _domain.local_. Ansible playbook: 
```
- name: eJabberd | Group of servers "ejserver". Confgure ejservers for domainname and psql1server connect. Granting administrator account rights
  hosts: ejserver
  become: true
  tasks:
    - name: Edit ejabberd.yml for granting administrator account rights.
      ansible.builtin.shell: |
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
Подробнее о виртуальных доменах в _Ejabberd_ можно ознакомиться [здесь](https://docs.ejabberd.im/admin/configuration/basic/#virtual-hosting).


###### Подключение к СУБД
В нашем проекте основной компонент - _Ejabberd_ устновлен в кластерном исполнении на двух виртуальных машинах. По умолчанию, для своей работы _Ejabberd_ использует базу данных [Mnesia](https://www.erlang.org/doc/apps/mnesia/api-reference.html).
Настройка на работу с [альтернативными СУБД](https://docs.ejabberd.im/admin/configuration/database/#supported-storages) - MySQL, PostgreSQL, MS SQL Server, SQLite, LDAP производится после установки сервиса. Также, начиная с версии 23.10, _Ejabberd_ 
позволяет с помощью параметра _update\_sql\_schema_ автоматически создавать и обновлять таблицы в базе данных SQL при использовании MySQL, PostgreSQL или SQLite.

Для создания базы данных, а так же роли с правами на эту базу подойдут следующие команды:
```
CREATE DATABASE "ejabberd-domain-local"
CREATE USER ejabberd WITH PASSWORD 'P@ssw0rd';
GRANT ALL ON DATABASE "ejabberd-domain-local" TO ejabberd;
```
Создание структуры базы данных:
```
psql -d ejabberd-domain-local -f /usr/share/ejabberd/sql/pg.sql
```

Эти шаги, выполняемые в _Ansible_, в yml-файле будут выглядеть так - создание базы и пользователя:
```
- name: PostgreSQL | Primary Server. Create database "ejabberd_domain_local" and role "ejabberd" on the Primary.
  hosts: psql1server
  become: true
  become_user: postgres
  vars:
    allow_world_readable_tmpfiles: true
  tasks:
    - name: Create a new database with name "ejabberd-domain-local".
      community.postgresql.postgresql_db:
        name: ejabberd-domain-local
        comment: "eJabberd database"
    - name: Connect to eJabberd database, create "ejabberd" user, and grant access to database and all tables.
      community.postgresql.postgresql_user:
        db: ejabberd-domain-local
        name: ejabberd
        password: Inc0gn1t0
        expires: "infinity"
    - name: Connect to eJabberd database, grant privileges on "ejabberd-domain-local" database objects (database) for "ejabberd" role.
      community.postgresql.postgresql_privs:
        database: ejabberd-domain-local
        state: present
        privs: ALL
        type: database
        roles: ejabberd
    - name: Connect to eJabberd database, grant privileges on "ejabberd-domain-local" database objects (schema) for "ejabberd" role.
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
- name: PostgreSQL | Creating tables in the database "ejabberd-domain-local" on the Master. Remote connection
  hosts: e1server
  tasks:
    - name: Connect from e1server to psql1server and run script.
      postgresql_query:
        login_host: 192.168.1.10
        db: ejabberd-domain-local
        login_user: ejabberd
        login_password: Inc0gn1t0
        path_to_script: /usr/share/ejabberd/sql/pg.sql
```
> [!NOTE]
> Обратите внимание, создание базы данных, роли, а также выполнение скрипта, создающего таблицы в данной базе, выполняются только на одном из серверов будущего кластера СУБД. Все данные с этого сервера
> будут скопированы на второй в процессе потоковой репликации, которая будет выполнена позже.

После того, как база данных и роль для работы с ней были созданы, потребуется настроить _Ejabberd_. 
Для этого отредактируем главный конфигурационный файл - /etc/ejabberd/ejabberd.yml, добавив следующие строки:
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
- name: eJabberd | Group of servers "ejserver". Confgure ejservers for domainname and psql1server connect. Granting administrator account rights
  hosts: ejserver
  become: true
  tasks:
    - name: Edit ejabberd.yml for connection to remote db.
      ansible.builtin.shell: |
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
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```

###### Управление пользователями
[Ранее](#admin-rights-point) мы уже назначили администратора для домена __domain.local__. Теперь заведем соответствующую учётную запись, а вместе с ней и обычного пользователя.
```
- name: eJabberd | e1server. Create users - administrator and regular. Configuring the e1server server certificate
  hosts: e1server
  become: true
  tasks:
    - name: Add users. Edit ejabberd.yml
      ansible.builtin.shell: |
        ejabberdctl register admin domain.local Inc0gn1t0
        ejabberdctl register max domain.local P@$$w0rd
      args:
        executable: /bin/bash
```
###### Настройка безопасного подключения
Настроим TLS-шифрование для подключений к нашим серверам. Создадим свой локальный Удостоверяющий Центр для выпуска серверных сертификатов, 
которым будет доверять клиентское ПО - браузер или xmpp-клиент. 

Для этих целей отлично подойдет __XCA__ - [приложение](https://hohnstaedt.de/xca/), предназначеное для создания 
и управления сертификатами X.509, запросами сертификатов, закрытыми ключами RSA, DSA и EC, смарт-картами и CRL.

![Certification Authority](/pictures/ca.png)

Выпустим в нём корневой сертификат нашего УЦ, на котором подпишем сертификаты для сетевых служб. Корневой сертификат потребуется установить в используемые браузеры или, в случае с Windows, 
в специальное хранилище ***Доверенные корневые центры сертификации*** оснастки ***Сертификаты***.

В свойствах выпускаемых сертификатов заполним расширение ***Альтернативное имя субъекта*** так, чтобы оно содержало как доменные имена сервера, 
на котором будет использоваться данный сертификат, так и его IP-адреса.

![Certificate](/pictures/cert.png)

Предварительно созданные сертификаты загружаются в домашние каталоги пользователя _Vagrant_ соответствующих виртуальных серверов с помощью директивы `vm.provision "file"`. 
Пример для сервера e1server:
```
  e1server.vm.provision "file", source: "ca/e1server.pem", destination: "~/e1server.pem"
```
После этого, в задаче _Ansible playbook_ производится настройка сервиса _ejabberd_:
```
- name: eJabberd | e1server. Create users - administrator and regular. Configuring the e1server server certificate
  hosts: e1server
  become: true
  tasks:
    - name: Configuring the e1server server certificate
      ansible.builtin.shell: |
        cp /home/vagrant/e1server.pem .
        chown root:ejabberd e1server.pem
        chmod 640 e1server.pem
        sed -i 's/ejabberd.pem/e1server.pem/' ejabberd.yml
        systemctl restart ejabberd.service
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
- name: eJabberd | e2server. Configuring the e2server server certificate
  hosts: e2server
  become: true
  tasks:
    - name: Edit ejabberd.yml
      ansible.builtin.shell: |
        cp /home/vagrant/e2server.pem .
        chown root:ejabberd e2server.pem
        chmod 640 e2server.pem
        sed -i 's/ejabberd.pem/e2server.pem/' ejabberd.yml
        systemctl restart ejabberd.service
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```

###### Создание кластера
В предыдущем абзаце мы вносили изменения в конфигурационный файл _Ejabberd_, при этом все изменения синхронно применялись на обоих виртуальных серверах, 
включенных в группу хостов [ejserver] inventory-файла _Ansible_:
```
[ejserver]
e1server ansible_host=192.168.121.10 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-eJabberd1/libvirt/private_key
e2server ansible_host=192.168.121.11 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-eJabberd2/libvirt/private_key
```
Таким образом, файлы конфигурации на обоих серверах имеют одинаковые настройки. Теперь создадим кластер из этих двух серверов. 
Нам потребуется на каждом сервере изменить имя ноды со значения по умолчанию "ejabberd@localhost" на "ejabberd@hostname". 
Это необходимо для того, чтобы обеспечить уникальность имён узлов в кластере.

Инструкция по переименованию имени узла находится [здесь](https://docs.ejabberd.im/admin/guide/managing/#change-computer-hostname).

Соответствующая задача в _ansible playbook_ выглядит следующим образом:
```
- name: eJabberd | Group of servers "ejserver". Confgure Erlang. Pre-configuration for creating a cluster
  hosts: ejserver
  become: true
  tasks:
    - name: Change default Erlang node. Change default nodename for use a %HOSTNAME. ejabberd@localhost -> ejabberd@hostname. Specify the acceptable range of ports
      ansible.builtin.shell: |
        OLDNODE=ejabberd@localhost
        NEWNODE=ejabberd@$HOSTNAME
        OLDFILE=/var/lib/ejabberd/oldfiles/old.backup
        NEWFILE=/var/lib/ejabberd/new.backup
        mkdir /var/lib/ejabberd/oldfiles
        chown -R ejabbed:ejabberd /var/lib/ejabberd/oldfiles
        ejabberdctl --node $OLDNODE backup $OLDFILE
        ejabberdctl --node $OLDNODE stop
        mv /var/lib/ejabberd/*.* /var/lib/ejabberd/oldfiles/
        sed -i "s/#ERLANG_NODE=ejabberd@localhost/ERLANG_NODE=$NEWNODE/" /etc/default/ejabberd
        ejabberdctl start
        ejabberdctl mnesia_change_nodename $OLDNODE $NEWNODE $OLDFILE $NEWFILE
        ejabberdctl install_fallback $NEWFILE
        ejabberdctl stop
        ejabberdctl start
        echo 'HWSTFERDACTZHIEXBZGN' > /var/lib/ejabberd/.erlang.cookie
      args:
        executable: /bin/bash
```

После того, как имена узлов кластера были изменены, в системе сохраняются запущенными процессы, связанные со старыми _Erlang_-нодами:
```
State   Recv-Q Send-Q Local Address:Port Peer Address:Port Process                                                                    
LISTEN  0      128          0.0.0.0:4200      0.0.0.0:*     users:(("beam.smp",pid=4833,fd=17))   
LISTEN  0      4096               *:4369            *:*     users:(("epmd",pid=4820,fd=3),("systemd",pid=1,fd=54))   
LISTEN  0      1000               *:1883            *:*     users:(("beam.smp",pid=4833,fd=31))   
LISTEN  0      128                *:5443            *:*     users:(("beam.smp",pid=4833,fd=28))   
LISTEN  0      128                *:5223            *:*     users:(("beam.smp",pid=4833,fd=26))   
LISTEN  0      128                *:5222            *:*     users:(("beam.smp",pid=4833,fd=25))
LISTEN  0      128                *:5269            *:*     users:(("beam.smp",pid=4833,fd=27))
LISTEN  0      128                *:5280            *:*     users:(("beam.smp",pid=4833,fd=29))
```
При перезапуске главного процесса _ejabberd.service_, настройки для этих работающих процессов применены не будут и мы получим ошибку при попопытке создать кластер.
Поэтому потребуется завершить все процессы _beam.smp_, что приведёт к остановке процесса _ejabberd.service_, остановить сервис _epmd_, 
после чего запустить _ejabberd.service_. Пример соответствующей задчи для _Ansible_:
```
- name: eJabberd | Group of servers "ejserver". Confgure Erlang. Pre-configuration for creating a cluster
  hosts: ejserver
  become: true
  tasks:
    - name: Reboot after change nofename. Перезагружаем сервисы для применения изменений.
      ansible.builtin.shell: |
        pkill -9 beam.smp
        systemctl stop epmd.service
        sleep 5
        systemctl start ejabberd.service
        sleep 5
      args:
        executable: /bin/bash
```
Также, для обеспечения возможности синхронизации узлов кластера при работающем файерволле на хостах, изменим порты, используемые _Erlang_ 
с динамического на выделенный диапазон 4200-4210 (не забудем добавить соответствующие разрешающие правила в iptables):
```
- name: eJabberd | Group of servers "ejserver". Confgure Erlang. Pre-configuration for creating a cluster
  hosts: ejserver
  become: true
  tasks:
    - name: Specify the acceptable range of ports.
      ansible.builtin.shell: |
        sed -i "s/#FIREWALL_WINDOW=/FIREWALL_WINDOW=4200-4210/" /etc/default/ejabberd
        systemctl restart ejabberd.service
        systemctl restart epmd.service
      args:
        executable: /bin/bash
```

Теперь создадим кластер:
```
- name: eJabberd | Create a cluster
  hosts: e2server
  become: true
  tasks:
    - name: Join ejabberd@e2server to cluster ejabberd@e1server
      ansible.builtin.shell: |
        ejabberdctl --no-timeout join_cluster 'ejabberd@e1server'
      args:
        executable: /bin/bash
```

Чтобы добавление узла в кластер прошло успешно, необходимо обеспечить разрешение имён нод на DNS-службе или в файлах _hosts_ всех узлов кластера, 
после чего можно проверить их доступность между собой:
```
root@e1server:~# ejabberdctl ping ejabberd@e2server
pong
```

##### PostgreSQL
###### Настройка файла _pg_hba.conf_
Предоставим пользователю _ejabberd_ права на удалённый доступ к базе данных _ejabberd\_domain\_local_, а пользователю _replica\_role_ доступ к кластеру для потоковой репликации. 
Для этого нужно привести файл _pg_hba.conf_ для _Master_ ноды к виду:
```
# Database administrative login by Unix domain socket
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
# IPv4 local connections:
# IPv6 local connections:
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all     peer
local   all     postgres        peer
local   all     all     peer
host    replication     replica_role    192.168.1.11/32 scram-sha-256
host    replication     all     127.0.0.1/32    scram-sha-256
host    replication     all     ::1/128 scram-sha-256
host    ejabberd-domain-local   ejabberd        192.168.1.2/32  scram-sha-256
host    ejabberd-domain-local   ejabberd        192.168.1.3/32  scram-sha-256
host    all     all     127.0.0.1/32    scram-sha-256
host    all     all     ::1/128 scram-sha-256
```

А для _Replica_:
```
# Database administrative login by Unix domain socket
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
# IPv4 local connections:
# IPv6 local connections:
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all     peer
local   all     postgres        peer
local   all     all     peer
host    replication     replica_role    192.168.1.10/32 scram-sha-256
host    replication     all     127.0.0.1/32    scram-sha-256
host    replication     all     ::1/128 scram-sha-256
host    ejabberd-domain-local   ejabberd        192.168.1.2/32  scram-sha-256
host    ejabberd-domain-local   ejabberd        192.168.1.3/32  scram-sha-256
host    all     all     127.0.0.1/32    scram-sha-256
host    all     all     ::1/128 scram-sha-256
```
Задача в _Ansible playbook_ - редактирование_pg\_hba.conf_ для предоставления доступа пользователю _ejabberd_ и настройки сетевого интерфейса, на котором работает _PostgreSQL_. 
Выполняется на обеих нодах:
```
    - name: Edit pg_hba configuration file. Add e1server access. Открываем удалённый доступ с первой ноды Jabber-сервера к базе ejabberd-domain-local для пользователя ejabberd.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: ejabberd
        source: 192.168.1.2
        databases: ejabberd-domain-local
        method: scram-sha-256
        create: true
    - name: Edit pg_hba configuration file. Add e2server access. Открываем удалённый доступ со второй ноды Jabber-сервера к базе ejabberd-domain-local для пользователя ejabberd.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: ejabberd
        source: 192.168.1.3
        databases: ejabberd-domain-local
        method: scram-sha-256
        create: true
    - name: Edit postgresql.conf for enable all interfaces. Разрешаем входящие подключения к порту 5432 на всех интерфейсах.
      ansible.builtin.shell: |
        echo "listen_addresses = '*'" >> postgresql.conf
        cp /home/vagrant/bacula-fd.conf /etc/bacula/
        systemctl restart postgresql
        systemctl restart bacula-fd.service
      args:
        executable: /bin/bash
        chdir: /etc/postgresql/15/main/
```

Задача в _Ansible playbook_ - редактирование_pg\_hba.conf_ для предоставления доступа пользователю _replica_role_ для выполнения репликации. Выполняется на _Master_:
```
    - name: Edit pg_hba configuration file. Access for Replica from psql2server. Разрешаем удалённое подключение пользователю replica_role для получения wal принимающим сервером.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: replica_role
        source: 192.168.1.11
        databases: replication
        method: scram-sha-256
```
Задача в _Ansible playbook_ - редактирование_pg\_hba.conf_ для предоставления доступа пользователю _replica_role_ для выполнения репликации. Выполняется на _Replica_:
```
    - name: Edit pg_hba configuration file. Access for Replica from psql1server. Разрешаем удалённое подключение пользователю replica_role для получения wal принимающим сервером.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: replica_role
        source: 192.168.1.10
        databases: replication
        method: scram-sha-256
```
