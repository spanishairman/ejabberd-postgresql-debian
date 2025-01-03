#### Введение
В настоящее время происходит бурное развитие технологий и средств обмена мгновенными сообщениями, за самыми популярными из которых, 
как правило, стоят мегакорпорации, пример - _WhatsUp_ (***Meta***) или _Viber_ (***Rakuten***).

Зачастую, компании принимают решение использовать тот или иной мессенджер в качестве стандарта де-факто для оперативного решения рабочих вопросов и связи со своими сотрудниками. 
Начинается бесконтрольный процесс появления рабочих чатов. Нередко, к части из них администрация подключает сторонних ботов, выдавая им таким образом доступ ко всей переписке внутри данного чата.

Спецслужбы различных стран, под предлогами благих намерений, начинают давить на владельцев крупных мессенджеров, с целью получить доступ к переписке всех их пользователей.
Как пример, [задержание](https://ru.wikipedia.org/wiki/%D0%94%D0%B5%D0%BB%D0%BE_%D0%9F%D0%B0%D0%B2%D0%BB%D0%B0_%D0%94%D1%83%D1%80%D0%BE%D0%B2%D0%B0) основателя популярного мессенджера _Telegram_ - Павла Дурова 
в Париже 24 августа 2024 года, ранее - попытки блокирования _Telegram_ в России, блокировка _Viber_ со стороны *РКН* в декабре 2024 года.

Все эти факторы могут приводить и приводят к многочисленным компрометациям, мошенническим схемам, утечкам персональных данных и коммерческой тайны, а также к репутационным потерям.

Протокол [_XMPP_](https://xmpp.org/about/technology-overview/) позволяет использовать один из тысяч бесплатных серверов в сети интернет если вы обычный пользователь или поднять свой сервер, в случае необходимости 
служебных коммуникаций. Такой сервер, благодаря децентрализованности системы и особенности архитектуры _XMPP_, может быть как доступным в любой точке земного шара, так и изолированным от внешнего мира в соответствии 
с корпоративными стандартами, принятыми в организации. Структура сети _XMPP_ похожа на электронную почту, в результате каждый может запустить свой собственный сервер _XMPP_, что позволяет отдельным лицам и организациям 
контролировать свой коммуникационный опыт.

Защита с использованием ***SASL*** и ***TLS*** встроена в основные  [спецификации](https://xmpp.org/rfcs/) _XMPP_. Кроме того, сообщество разработчиков _XMPP_ активно работает над сквозным шифрованием, чтобы еще больше поднять планку безопасности.

В нашей работе мы рассмотрим разворачивание стенда с отказоустойчивой реализацией сервиса _XMPP_, готового обслуживать какой-либо офис или организацию.

![Logo](/pictures/logo.png)

#### Автоматическое развёртывание в виртуальной среде с использованием Vagrant, Libvirt, QEMU, KVM и Ansible службы обмена мгновенными сообщениями на базе XMPP-сервера [Ejabberd](https://docs.ejabberd.im/)

> [!NOTE]
> [Ejabberd](https://docs.ejabberd.im/) — это надежная, масштабируемая и расширяемая платформа реального времени с открытым исходным кодом, созданная с использованием Erlang/OTP, 
> которая включает в себя сервер [XMPP](https://xmpp.org/), брокер [MQTT](https://mqtt.org/) ислужбу [SIP](https://en.wikipedia.org/wiki/Session_Initiation_Protocol).

##### Описание стенда
Для работы будем использовать виртуальную сеть с набором сервисов, построенную с использованием среды разработки [Vagrant](https://www.vagrantup.com/), инструментов управления виртуализацией [Libvirt](https://libvirt.org/), 
эмулятора виртуальных машин [Qemu](https://www.qemu.org/), модуля ядра, использующего расширения виртуализации (Intel VT или AMD-V) [KVM](https://linux-kvm.org/page/Main_Page) и инструмента автоматизации [Ansible](https://www.ansible.com/).
Логическая схема стенда выглядит следующим образом:

![Схема сети](/pictures/ejabberd.drawio.png)

Здесь мы примем условно, что фронтэнд, это две ноды _Ejabberd_, которые одним из сетевых интерфейсов доступны извне, в данном случае с хоста виртуализации - сеть __192.168.121.0/24__. 
Второй интерфейс у них находится в сети __192.168.1.0/29__, которую мы также условно, будем считать демилитаризованной зоной. Внутренняя сеть - __192.168.1.8/29__, в которой размещены т.н. ***Backend***-серверы,
отделена от демилитаризованной зоны виртуальным хостом ***gw1server*** с двумя сетевыми интерфейсами с адресами __192.168.1.1/29__ и __192.168.1.9.29__, 
подключенными к этим двум виртуальным сетям и являющимся шлюзом между ними.

##### Первоначальное развёртывание

![Vagrant](/pictures/vagrant.png) Для развёртывания сети будем использовать _Vagrant_. Блок настроек, включающий в себя аппаратные характеристики машины и её сетевые параметры, за небольшими деталями, 
одинаков для всех машин. Приведем пример данного блока:

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
Для изолированной сети явно задаётся имя сети, IP-адрес и маска. Параметр _libvirt\_\_always\_destroy_ со значением _"true"_ 
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
Также работают системные переменные, что позволяет не использовать полные пути к исполняемым командам.

> [!IMPORTANT]
> _vm.provision "file"_ Выполняется с правами пользователя _vagrant_, в то время, как _vm.provision "shell"_ работает с привилегиями суперпользоваттеля. 
> Это необходимо учитывать, планируя послеустановочную настройку системы.

Все виртуальные узлы в данном стенде разворачиваются с помощью команд, правил и описаний в _Vagrant_ файле. 
При этом, установка и настройка прикладного программного обеспечения производится после с помощью _Ansible_, 
за исключением файерволла - установка iptables (nftables) и настройка правил осуществляется на этапе установки.

##### Ejabberd
###### Установка
![Ejabberd](/pictures/ejabberd.png) Установка _Ejabberd_ производится из репозиториев _"bookworm-backports"_. Для этого создаём следующую задачу:

```
- name: eJabberd | Group of servers "ejserver". Install and configure ejabberd. Installing "ejabberd" packages on the "ejserver" server group
  hosts: ejserver
  become: true
  tasks:
    - name: APT. Add Backports repository into sources list
      ansible.builtin.apt_repository:
        repo: deb http://deb.debian.org/debian bookworm-backports main contrib non-free
        state: present
    - name: APT. Update the repository cache and install packages "eJabberd", "erlang-p1-pgsql", "python3-psycopg2", "acl" to latest version using default release bookworm-backport
      ansible.builtin.apt:
        name: ejabberd,erlang-p1-pgsql,python3-psycopg2,acl
        state: present
        default_release: bookworm-backports
        update_cache: yes
```

В которой мы добавили новый репозиторий и установили необходимое ПО, указав в качестве источника _"bookworm-backports"_. 

###### Общие настройки
Изменим домен по умолчанию, который обслуживает наш сервер. Это параметр _hosts_ в конфигурационном файле _/etc/ejabberd/ejabberd.yml_:
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
Зададим права админа для домена _domain.local_. Ansible _playbook_: 

```
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
В нашем проекте основной компонент - _Ejabberd_ устновлен в кластерном исполнении на двух виртуальных машинах. По умолчанию, для своей работы _Ejabberd_ 
использует базу данных [Mnesia](https://www.erlang.org/doc/apps/mnesia/api-reference.html).
Настройка на работу с [альтернативными СУБД](https://docs.ejabberd.im/admin/configuration/database/#supported-storages) - _MySQL_, _PostgreSQL_, _MS SQL Server_, _SQLite_, _LDAP_ 
производится после установки сервиса. Также, начиная с версии __23.10__, _Ejabberd_ 
позволяет с помощью параметра _update\_sql\_schema_ автоматически создавать и обновлять таблицы в базе данных _SQL_ при использовании _MySQL_, _PostgreSQL_ или _SQLite_.

Для создания базы данных, а также роли с правами на эту базу подойдут следующие команды:

```
CREATE DATABASE "ejabberd-domain-local"
CREATE USER ejabberd WITH PASSWORD 'P@ssw0rd';
GRANT ALL ON DATABASE "ejabberd-domain-local" TO ejabberd;
```

Создание структуры базы данных:

```
psql -d ejabberd-domain-local -f /usr/share/ejabberd/sql/pg.sql
```

Эти шаги, выполняемые в _Ansible_, в yml-файле будут выглядеть так:

  - создание базы и пользователя:

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
        password: P@ssw0rd
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

  - создание структуры БД:

```
- name: PostgreSQL | Creating tables in the database "ejabberd-domain-local" on the Master. Remote connection
  hosts: e1server
  tasks:
    - name: Connect from e1server to psql1server and run script.
      postgresql_query:
        login_host: 192.168.1.10
        db: ejabberd-domain-local
        login_user: ejabberd
        login_password: P@ssw0rd
        path_to_script: /usr/share/ejabberd/sql/pg.sql
```

> [!NOTE]
> Обратите внимание, создание базы данных, роли, а также выполнение скрипта, создающего таблицы в данной базе, выполняются только на одном из серверов будущего кластера СУБД. Все данные с этого сервера
> будут скопированы на второй в процессе потоковой репликации, которая будет выполнена позже.

После того, как база данных и роль для работы с ней были созданы, потребуется настроить _Ejabberd_. 
Для этого отредактируем главный конфигурационный файл - _/etc/ejabberd/ejabberd.yml_, добавив следующие строки:

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
        echo '    sql_password: P@ssw0rd' >> ejabberd.yml
        echo '    auth_method:' >> ejabberd.yml
        echo '      - sql' >> ejabberd.yml
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```

###### Управление пользователями
[Ранее](#admin-rights-point) мы уже назначили администратора для домена ***domain.local***. Теперь заведём соответствующую учётную запись, а вместе с ней и обычного пользователя.

```
- name: eJabberd | e1server. Create users - administrator and regular. Configuring the e1server server certificate
  hosts: e1server
  become: true
  tasks:
    - name: Add users. Edit ejabberd.yml
      ansible.builtin.shell: |
        ejabberdctl register admin domain.local P@ssw0rd
        ejabberdctl register max domain.local P@$$w0rd
      args:
        executable: /bin/bash
```

###### Настройка безопасного подключения
![XCA](/pictures/xca.png)Настроим _TLS_-шифрование для подключений к нашим серверам. Создадим свой локальный Удостоверяющий Центр для выпуска серверных сертификатов, 
которым будет доверять клиентское ПО - браузер или _xmpp_-клиент. 

Для этих целей отлично подойдет _XCA_ - [приложение](https://hohnstaedt.de/xca/), предназначеное для создания 
и управления сертификатами _X.509_, запросами сертификатов, закрытыми ключами _RSA_, _DSA_ и _EC_, смарт-картами и _CRL_.

![Certification Authority](/pictures/ca.png)

Выпустим в нём корневой сертификат нашего УЦ, с помощью которого подпишем сертификаты для сетевых служб. Корневой сертификат потребуется установить в 
используемые браузеры или, в случае с _Windows_, в специальное хранилище ***Доверенные корневые центры сертификации*** оснастки ***Сертификаты***.

В свойствах выпускаемых сертификатов заполним расширение ***Альтернативное имя субъекта*** так, чтобы оно содержало как доменные имена сервера, 
на котором будет использоваться данный сертификат, так и его _IP_-адреса.

![Certificate](/pictures/cert.png)

Предварительно созданные сертификаты загружаются в домашние каталоги пользователя _Vagrant_ соответствующих виртуальных серверов с помощью директивы `vm.provision "file"`. 
Пример для сервера ***e1server***:

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
включенных в группу хостов ***ejserver*** inventory-файла _Ansible_:

```
[ejserver]
e1server ansible_host=192.168.121.10 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-eJabberd1/libvirt/private_key
e2server ansible_host=192.168.121.11 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-eJabberd2/libvirt/private_key

```
Таким образом, файлы конфигурации на обоих серверах имеют одинаковые настройки. Теперь создадим кластер из этих двух серверов. 
Нам потребуется на каждом сервере изменить имя ноды со значения по умолчанию ***"ejabberd@localhost"*** на ***"ejabberd@hostname"***. 
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
При перезапуске главного процесса ***ejabberd.service***, настройки для этих работающих процессов применены не будут и мы получим ошибку при попытке создать кластер.
Поэтому потребуется завершить все процессы ***beam.smp***, что приведёт к остановке процесса ***ejabberd.service***, остановить сервис ***epmd***, 
после чего запустить ***ejabberd.service***. Пример соответствующей задчи для _Ansible_:

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
с динамического на выделенный диапазон __4200-4210__ (не забудем добавить соответствующие разрешающие правила в _iptables_):

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

Чтобы добавление узла в кластер прошло успешно, необходимо обеспечить разрешение имён нод на _DNS_-службе или в файлах _hosts_ всех узлов кластера, 
после чего можно проверить их доступность между собой:

```
root@e1server:~# ejabberdctl ping ejabberd@e2server
pong
```

##### PostgreSQL
###### Настройка файла _pg_hba.conf_
![Postgresql](/pictures/psql.png)Предоставим пользователю _ejabberd_ права на удалённый доступ к базе данных _ejabberd\_domain\_local_, а пользователю _replica\_role_ доступ к кластеру для потоковой репликации. 
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

Задача в _Ansible playbook_ - редактирование _pg\_hba.conf_ для предоставления доступа пользователю _ejabberd_ и настройки сетевого интерфейса, на котором работает _PostgreSQL_. 
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

###### Настройка потоковой репликации
Для запуска сервера ***psql2server*** в режиме _Replica_ служит следующая задача в _Ansible Playbook_ (выполняется на сервера ***psql2server***):
```
- name: PostgreSQL | Secondary Server. Configuration a Replica server and start replication.
  hosts: psql2server
  become: true
  tasks:
    - name: Config. Bash. Stop postgresql service, remove work directory. Set PGPASSWORD variable, start replication.
      ansible.builtin.shell: |
        systemctl stop postgresql
        rm -rf /var/lib/postgresql/15/main
        PGPASSWORD=P@ssw0rd
        export PGPASSWORD
        pg_basebackup -h 192.168.1.10 -U replica_role -X stream -R -P -D /var/lib/postgresql/15/main
        chown -R postgres: /var/lib/postgresql/15/main
        systemctl start postgresql
      args:
        executable: /bin/bash
```

##### Bacula
![Bacula](/pictures/bacula.png) В качестве системы резервного копирования для долговременного хранения копий баз данных и конфигураций приложений будем использовать [Bacula](https://www.bacula.org/).
На сервере резервных копий будут храниться копии каталогов _/etc_ серверов _e1server_и _e2server_, резервные копии базы _ejabberd-domain-local_, снятые с сервера ***psql2server*** (_Replica_),
а также архивы рабочих каталогов _Grafana_ и _Prometheus_ сервера ***mon1server***.

> [!NOTE]
> На этом же сервере - ***bk1server***, в каталогах ***/srv/share/upload/psql{1,2}server/{backup,archive}/***, 
предоставляемых для монтирования по протоколу _nfs_ серверам ***psql1server*** и ***psql2server***, 
> сохраняются копии _PostgreSQL_-кластера соответствующих серверов, а также их журналы _WAL_.

Основные настройки _Bacula_ относятся к демону _Director_ и хранятся в конфигурационном файле _/etc/bacula/bacula-dir.conf_. Рассмотрим их подробнее.

###### Jobs

```
# My jobs and jobdefs

JobDefs {
  Name = "My-JobDef-Tpl"
  Type = Backup
  Storage = bk1server-sd
  Messages = Standard
  SpoolAttributes = yes
  Priority = 10
  Write Bootstrap = "/var/lib/bacula/%c.bsr"
}

Job {
  Name = "e1-fs-Job"
  FileSet = "My-fs-FS"
  Pool = e1-fs-Full
  Full Backup Pool = e1-fs-Full                  # write Full Backups into "Full" Pool         (#05)
  Differential Backup Pool = e1-fs-Diff
  Incremental Backup Pool = e1-fs-Incr           # write Incr Backups into "Incremental" Pool  (#11)
  Schedule = "e1-fs-Sdl"
  JobDefs = "My-JobDef-Tpl"
  Client = "e1server-fd"
}

Job {
  Name = "e2-fs-Job"
  FileSet = "My-fs-FS"
  Pool = e2-fs-Full
  Full Backup Pool = e2-fs-Full                  # write Full Backups into "Full" Pool         (#05)
  Differential Backup Pool = e2-fs-Diff
  Incremental Backup Pool = e2-fs-Incr           # write Incr Backups into "Incremental" Pool  (#11)
  Schedule = "e2-fs-Sdl"
  JobDefs = "My-JobDef-Tpl"
  Client = "e2server-fd"
}

Job {
  Name = "MyRestoreFiles"
  Type = Restore
  Client=bk1server-fd
  Storage = bk1server-sd
# The FileSet and Pool directives are not used by Restore Jobs  but must not be removed
  FileSet="Full Set"
  Pool = File
  Messages = Standard
  Where = /bacula-restores
}

Job {
  Name = "psql2-dump-Job"
  FileSet = "My-psql-FS"
  Pool = psql2-dump-Full
  Full Backup Pool = psql2-dump-Full                  # write Full Backups into "Full" Pool         (#05)
  Differential Backup Pool = psql2-dump-Diff
  Incremental Backup Pool = psql2-dump-Incr           # write Incr Backups into "Incremental" Pool  (#11)
  Schedule = "psql2-dump-Sdl"
  JobDefs = "My-JobDef-Tpl"
  Client = "psql2server-fd"
  ClientRunBeforeJob = "/etc/bacula/scripts/bacula-before-dump.sh" # скрипт выполняющийся до задачи
  ClientRunAfterJob = "/etc/bacula/scripts/bacula-after-dump.sh" # скрипт выполняющийся после задачи
}

Job {
  Name = "mon1-grfn-Job"
  FileSet = "My-grfn-FS"
  Pool = mon1-grfn-Full
  Full Backup Pool = mon1-grfn-Full                  # write Full Backups into "Full" Pool         (#05)
  Differential Backup Pool = mon1-grfn-Diff
  Incremental Backup Pool = mon1-grfn-Incr           # write Incr Backups into "Incremental" Pool  (#11)
  Schedule = "mon1-grfn-Sdl"
  JobDefs = "My-JobDef-Tpl"
  Client = "mon1server-fd"
}

```

В данном блоке описан шаблон для задач _My-JobDef-Tpl_, в котором собраны общие для нескольких задач параметры, задача для восстановления - _MyRestoreFiles_ и остальные задачи, 
которые описывают параметры резервного копирования для разных наборов файлов, пулов томов, расписаний и пр. 
Подробное описание настройки и работы с _Bacula_ можно найти [здесь](https://github.com/spanishairman/bacula-debian).

###### Filesets

Наборы архивируемых файлов описываются в соответствующем блоке настроек. Здесь у нас набор _My-fs-FS_, который содержит каталог _/etc_, _My-psql-FS_ - в этом наборе 
содержится описание каталога /bacula-backup/ и _My-grfn-FS_ содержит _/var/lib/grafana_ - рабочий каталог _Grafana_ и _/var/lib/prometheus_ - рабочий каталог _Prometheus_. 

> [!NOTE]
> В каталог _/bacula-backup/_ попадает резервная копия базы данных _ejabberd-domain-local_, которая создаётся с помощью скрипта _/etc/bacula/scripts/bacula-before-dump.sh_, 
> запускаемого непосредственно перед выполнением задачи резервного копирования. Таким образом, сначала выполняется скрипт, создающий дамп базы данных в каталоге /bacula-backup/,
> затем содержимое этого каталога архивируется на сервер резервных копий

Содержимое скрипта _/etc/bacula/scripts/bacula-before-dump.sh_ для сервера _psql2server_:

```
#!/bin/bash
# Пример pg_dump со сжатием:
# sudo -u postgres pg_dump -d ejabberd | gzip > /media/backup/dump/ejabberd.sql.gz
# Мы делаем без сжатия, так как сжимать файлы будет bacula
postgreshome="/var/lib/postgresql"
cd $postgreshome
sudo -u postgres pg_dump -d ejabberd-domain-local > /bacula-backup/ejabberd.sql
```

```
# My-filesets

FileSet {
  Name = "My-fs-FS"
  Enable VSS = yes
  Include {
    Options {
      Signature = SHA1
      Compression = LZO
      No Atime = yes
      Sparse = yes
      Checkfilechanges = yes
      IgnoreCase = no
    }
    File = "/etc"
  # File = "/var"
  }
}

FileSet {
  Name = "My-psql-FS"
  Enable VSS = yes
  Include {
    Options {
      Signature = SHA1
      Compression = GZIP
      No Atime = yes
      Sparse = yes
      Checkfilechanges = yes
      IgnoreCase = no
    }
    File = "/bacula-backup"
  }
}

FileSet {
  Name = "My-grfn-FS"
  Enable VSS = yes
  Include {
    Options {
      Signature = SHA1
      Compression = LZO
      No Atime = yes
      Sparse = yes
      Checkfilechanges = yes
      IgnoreCase = no
    }
    File = "/var/lib/grafana"
    File = "/var/lib/prometheus"
  }
}

```

###### Schedules
Зададим расписания для выполнения заданий резервного копирования каталога _/etc_ клиентских машин ***e1server*** и ***e2server***:
  - Полная копия - 1 число каждого месяца в час ночи;
  - разностная копия - 15 числа каждого месяца в час ночи;
  - инкрементные копии - со 2 по 14 и с 16 по 31 число каждого месяца в час ночи.

Для машины ***psql2server*** расписания для задач резервного копирования каталога _/bacula-backup_ выглядят так:
  - Полная копия - ежедневно в час ночи;
  - разностная копия - ежедневно в час дня;
  - инкрементные копии ежедневно каждый час кроме часа ночи и часа дня.

Для сервера мониторинга ***mon1server***, также как и для _Replica_ сервера с базами данных:
  - Полная копия - ежедневно в час ночи; 
  - разностная копия - ежедневно в час дня;
  - инкрементные копии ежедневно каждый час кроме часа ночи и часа дня.

В соответствующем блоке настроек - _Schedules_ расписания выглядят так:

```
# My Schedules

Schedule {
  Enabled = yes
  Name = "e1-fs-Sdl"
  Run = Level=Full on 1 at 01:00
  Run = Level=Differential on 15 at 01:00
  Run = Level=Incremental on 2-14 at 01:00
  Run = Level=Incremental on 16-31 at 01:00
}

Schedule {
  Enabled = yes
  Name = "e2-fs-Sdl"
  Run = Level=Full Pool=e2-fs-Full on 1 at 01:00
  Run = Level=Differential on 15 at 01:00
  Run = Level=Incremental on 2-14 at 01:00
  Run = Level=Incremental on 16-31 at 01:00
}

Schedule {
  Enabled = yes
  Name = "psql2-dump-Sdl"
  Run = Level=Full Pool=psql2-dump-Full at 01:00
  Run = Level=Differential at 13:00
  Run = Level=Incremental 2-12
  Run = Level=Incremental 14-23
  Run = Level=Incremental at 00:00
}

Schedule {
  Enabled = yes
  Name = "mon1-grfn-Sdl"
  Run = Level=Full Pool=mon1-grfn-Full at 01:00
  Run = Level=Differential at 13:00
  Run = Level=Incremental 2-12
  Run = Level=Incremental 14-23
  Run = Level=Incremental at 00:00
}
```

###### Clients
Описание клиентов сервера в конфигурационном файле  _/etc/bacula/bacula-dir.conf_:

```
# Client (File Services) to backup
Client {
  Name = e1server-fd
  Address = 192.168.1.2
  FDPort = 9102
  Catalog = MyCatalog
  Password = "DYrPl1SQnGYgUHDy809bU6ejZyo-N97m4"          # password for FileDaemon
  File Retention = 365 days           # 60 days
  Job Retention = 12 months           # six months
  AutoPrune = yes                     # Prune expired Jobs/Files
}

# Client (File Services) to backup
Client {
  Name = e2server-fd
  Address = 192.168.1.3
  FDPort = 9102
  Catalog = MyCatalog
  Password = "tyWfHO1Bp3joollMSdXggFoeBoMTPZF8G"          # password for FileDaemon
  File Retention = 365 days           # 60 days
  Job Retention = 12 months           # six months
  AutoPrune = yes                     # Prune expired Jobs/Files
}

# Client (File Services) to backup
Client {
  Name = psql1server-fd
  Address = 192.168.1.10
  FDPort = 9102
  Catalog = MyCatalog
  Password = "psXJhsM7F9pX4ikzuymM7JzeLFbaRiuuJt"          # password for FileDaemon
  File Retention = 365 days           # 60 days
  Job Retention = 12 months           # six months
  AutoPrune = yes                     # Prune expired Jobs/Files
}

# Client (File Services) to backup
Client {
  Name = psql2server-fd
  Address = 192.168.1.11
  FDPort = 9102
  Catalog = MyCatalog
  Password = "XoPVaXygpP3EuWKypKqvLXKJAEr7haMTrK"          # password for FileDaemon
  File Retention = 365 days           # 60 days
  Job Retention = 12 months           # six months
  AutoPrune = yes                     # Prune expired Jobs/Files
}

# Client (File Services) to backup
Client {
  Name = mon1server-fd
  Address = 192.168.1.13
  FDPort = 9102
  Catalog = MyCatalog
  Password = "HPihbJqsYFXHcU7MNdaTNkEjxfhReUWgpW"          # password for FileDaemon
  File Retention = 365 days           # 60 days
  Job Retention = 12 months           # six months
  AutoPrune = yes                     # Prune expired Jobs/Files
}
```

###### Storage

Здесь настраиваются параметры, с которыми _Director_ подключается к демону _Storage_.

```
# My-storage

Storage {
  Name = bk1server-sd
# Do not use "localhost" here
  Address = 192.168.1.12                # N.B. Use a fully qualified name here
  SDPort = 9103
  Password = "tX-mbxkAlCKyMGRTf33pWEuzlVZRB7OaJ"
  Device = FileStorage
  Media Type = File
  Maximum Concurrent Jobs = 10        # run up to 10 jobs a the same time
}
```

_Storage_ может размещаться как на одном хосте с _Director_ так и на выделенном сервере или кластере серверов (что предпочтительнее).

###### Pools

Пулы томов содержат тома с резервными копиями. Пулы предназначены для хранения различных типов томов, более гибкого управления резервными копиями и томами, а также их переработкой.

Для клиента ***e1server*** набор пулов томов выглядит так:

```
# File Pool definition eJabberd1-fs
Pool {
  Name = e1-fs-Full
  Pool Type = Backup
  Recycle = yes                        # Bacula can automatically recycle Volumes
  AutoPrune = yes                      # Prune expired volumes
  Recycle Oldest Volume = yes          # Prune the oldest volume in the Pool, and if all files were pruned, recycle this volume and use it.
  Volume Retention = 29  days          # How long should the Full Backups be kept?
  Maximum Volume Bytes = 1G            # Limit Volume size to something reasonable
  Maximum Volume Jobs = 30             # 30 Jobs = One Vol
  Maximum Volumes = 3                  # Limit number of Volumes in Pool
  Label Format = "e1-fs-Full-"         # Volumes will be labeled "Full-<volume-id>"
}
Pool {
  Name = e1-fs-Diff
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 29  days
  Maximum Volume Bytes = 1G
  Maximum Volume Jobs = 30
  Maximum Volumes = 3
  Label Format = "e1-fs-Diff-"
}
Pool {
  Name = e1-fs-Incr
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 7   days
  Maximum Volume Bytes = 1G
  Maximum Volume Jobs = 14
  Maximum Volumes = 3
  Label Format = "e1-fs-Incr-"
}
```

Для клиента ***e2server*** - так:

```
# File Pool definition eJabberd2-fs
Pool {
  Name = e2-fs-Full
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 29  days
  Maximum Volume Bytes = 1G
  Maximum Volume Jobs = 30
  Maximum Volumes = 3
  Label Format = "e2-fs-Full-"
}
Pool {
  Name = e2-fs-Diff
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 29  days
  Maximum Volume Bytes = 1G
  Maximum Volume Jobs = 30
  Maximum Volumes = 3
  Label Format = "e2-fs-Diff-"
}
Pool {
  Name = e2-fs-Incr
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 7   days
  Maximum Volume Bytes = 1G
  Maximum Volume Jobs = 14
  Maximum Volumes = 3
  Label Format = "e2-fs-Incr-"
}
```

Для клиента ***psql2server*** - так:

```
# File Pool definition psql2-dump
Pool {
  Name = psql2-dump-Full
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 21  days
  Maximum Volume Bytes = 2G
  Maximum Volume Jobs = 7
  Maximum Volumes = 4
  Label Format = "psql2-dump-Full-"
}
Pool {
  Name = psql2-dump-Diff
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 21  days
  Maximum Volume Bytes = 2G
  Maximum Volume Jobs = 7
  Maximum Volumes = 4
  Label Format = "psql2-dump-Diff-"
}
Pool {
  Name = psql2-dump-Incr
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 1   days
  Maximum Volume Bytes = 1G
  Maximum Volume Jobs = 22
  Maximum Volumes = 2
  Label Format = "psql2-dump-Incr-"
}
```

Для ***mon1server***:

```
# File Pool definition mon1-fs
Pool {
  Name = mon1-grfn-Full
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 21  days
  Maximum Volume Bytes = 2G
  Maximum Volume Jobs = 7
  Maximum Volumes = 4
  Label Format = "mon1-grfn-Full-"
}
Pool {
  Name = mon1-grfn-Diff
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 21  days
  Maximum Volume Bytes = 2G
  Maximum Volume Jobs = 7
  Maximum Volumes = 4
  Label Format = "mon1-grfn-Diff-"
}
Pool {
  Name = mon1-grfn-Incr
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Recycle Oldest Volume = yes
  Volume Retention = 1   days
  Maximum Volume Bytes = 1G
  Maximum Volume Jobs = 22
  Maximum Volumes = 2
  Label Format = "mon1-grfn-Incr-"
}
```

Подробное описание параметров для пулов томов я уже делал [здесь](https://github.com/spanishairman/bacula-debian), сейчас же опишу, как работает цикл хранения резервных копий базы данных
_ejabberd-domain-local_ на примере вышеуказанных пулов и расписаний.

Так как полная копия для базы данных _ejabberd-domain-local_ создается один раз в день и пишется на пул _psql2-dump-Full_, то мы будем заполнять один том в течение недели, 
пока количество резервных копий в томе не достигнет максимального значения (параметр _Maximum Volume Jobs = 7_). 

> [!NOTE]
> Под единицей измерения в данном случае подразумевается _Задача_ (__Job__), независимо от того, сколько резервных копий файлов она создаёт.

Следующая задача запишет новую копию в новый том, и далее задачи резервного копирования будут писать в него, пока количество задач снова не достигнет значения 7. 

Далее, когда будут использованы все четыре тома в пуле (параметр _Maximum Volumes = 4_), _Bacula_, так как свободных томов не осталась, начнёт искать использованный том, 
у которого истёк срок хранения, заданный параметром _Volume Retention = 21  days_ (отсчитывается от времени последней записи в том). 

> [!NOTE]
> Даже если параметр _Volume Retention_ для тома уже истёк, _Bacula_ не станет перезаписывать его новыми данными, пока у неё есть возможность использовать
> свободные тома в пуле. Т.е. перезапись данных в томе происходит в самом крайнем случае.

Это будет самый первый том, а так как для него задан параметр _Recycle = yes_, то данные на нём будут перезаписаны. Более того, благодаря опции _AutoPrune = yes_, 
перезаписываемый том будет усечён до нулевого размера.

Что же произойдёт, если на момент исчерпания новых свободных томов в пуле, окажется более одного тома с истёкшим сроком хранения, заданным параметром _Volume Retention_?
Здесь, благодаря заданной опции _Recycle Oldest Volume = yes_, будет перезаписан том, хранящий самые старые записи.

Хранение резервных копий в остальных томах можно посчитать точно также, используя вышеуказанный пример.

##### Nfs
На сервере ***bk1server*** также экспортируются каталоги для хранения резервных копий _PostgreSQL_ кластеров и их журналов _WAL_. 
Установка и настройка сервера _NFS_ осуществляется в следующем _Ansible Playbook_:

```
- name: bacula | Install and configure nfs and bacula-server. Установка nfs and bacula на группу серверов bkserver. Настройка конфигурационных файлов.
  hosts: bkserver
  become: true
  tasks:
    - name: Install packages "bacula" and "nfs" to latest version
      ansible.builtin.apt:
        name: nfs-common,nfs-kernel-server,bacula
        state: present
        update_cache: true
    - name: Configure and start nfs-server and bacula-dir, bacula-sd, bacula-catalog
      ansible.builtin.shell: |
        mkdir -p /srv/share/upload/psql{1,2}server/{archive,backup}
        chmod -R o+w /srv/share/upload
        echo '/srv/share/upload 192.168.1.10/32(rw,sync,root_squash,no_subtree_check)' >> /etc/exports
        echo '/srv/share/upload 192.168.1.11/32(rw,sync,root_squash,no_subtree_check)' >> /etc/exports
        exportfs -r
```

В данном случае мы разрешили хостам с ip-адресами __192.168.1.10__ и __192.168.1.11__ монтировать каталог _/srv/share/upload_ в режиме записи и с трансляцией _UID_ 
удалённого прользователя _root_ в _nobody_.

На клиентской стороне монтирование каталогов _NFS-сервера_ происходит благодаря записи в _Playbook_ для _Primary_:

```
- name: PostgreSQL | Primary Server. Creating a directory for archiving. Settngs for replication and archiving
  hosts: psql1server
  become: true
  tasks:
    - name: Bash. Create a directory for nfs-mounting and archiving
      ansible.builtin.shell: |
        test ! -d /mnt/nfs && mkdir -p $_
        echo "192.168.1.12:/srv/share/upload/ /mnt/nfs nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
        systemctl daemon-reload
        systemctl restart remote-fs.target
      args:
        executable: /bin/bash
```

и для _Replica_:

```
- name: PostgreSQL | Secondary Server. Configuration a Replica server and start replication.
  hosts: psql2server
  become: true
  tasks:
    - name: Bash. Create nfs dir. Configure bacula-client
      ansible.builtin.shell: |
        test ! -d /mnt/nfs && mkdir -p $_
        echo "192.168.1.12:/srv/share/upload/ /mnt/nfs nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
        systemctl daemon-reload
        systemctl restart remote-fs.target
      args:
        executable: /bin/bash
```

##### Prometheus
![Prometheus](/pictures/prometheus.png) Для сбора метрик с узлов сети будем ипользовать [Prometheus](https://prometheus.io/) - набор инструментов с открытым исходным кодом для мониторинга и оповещения.

_Prometheus_ состоит из двух компонентов - сервера и экспортера. Сервер собирает метрики от экспортеров и хранит их в собственной базе данных _"/var/lib/prometheus/metrics2"_.
Экспортер предоставляет метрики серверу или, например, _Grafana_ и т. д. Поскольку _prometheus_ находится в репозитории _Debian_, установить его просто с помощью команды:

```
# apt install prometheus prometheus-node-exporter
```

_Ansible Playbook_ для разворачивания _Prometheus_ на клиентах и сервере:

```
---
- name: Prometheus-node-exporter | Install prometheus-node-exporter
  hosts: prometheuses
  become: true
  tasks:
    - name: APT. Update the repository cache and install packages "prometheus-node-exporter" to latest version
      ansible.builtin.apt:  
        name: prometheus-node-exporter
        state: present
        update_cache: yes
- name: Prometheus-postgres-exporter | Install and copy files
  hosts: psqlserver
  become: true
  tasks:
    - name: APT. Update the repository cache and install packages "prometheus-postgres-exporter" to latest version
      ansible.builtin.apt:  
        name: prometheus-postgres-exporter
        state: present
        update_cache: yes
    - name: prometheus-postgres-exporter. Copy configuration file
      ansible.builtin.shell: |
        cp prometheus-post.sql /usr/share/doc/prometheus-postgres-exporter/prometheus-post.sql
        cp prometheus-postgres-exporter /etc/default/prometheus-postgres-exporter
      args:
        executable: /bin/bash
        chdir: /home/vagrant/

- name: Prometheus-postgres-exporter | Execute SQL commands to create the user prometheus and GRANTs
  hosts: psql1server
  become: true
  become_user: postgres
  tasks:
    - name: Prometheus-postgres-exporter. Run script.
      postgresql_query:
        db: postgres
        path_to_script: /usr/share/doc/prometheus-postgres-exporter/prometheus-post.sql

- name: Prometheus-postgres-exporter | Restart Service
  hosts: psqlserver
  become: true
  tasks:
    - name: prometheus-postgres-exporter. Restart service
      ansible.builtin.shell: |
        sleep 5
        systemctl restart prometheus-postgres-exporter.service
      args:
        executable: /bin/bash
- name: Prometheus | mon1server. Install Prometheus. Add jobs for prometheus-postgres-exporter
  hosts: monserver
  become: true
  tasks:
    - name: APT. Add Backports repository into sources list
      ansible.builtin.apt_repository:
        repo: deb http://deb.debian.org/debian bookworm-backports main contrib non-free
        state: present
    - name: APT. Update the repository cache and install packages "prometheus", "adduser", "libfontconfig1", "musl" to latest version using default release bookworm-backport
      ansible.builtin.apt:  
        name: prometheus,adduser,libfontconfig1,musl
        state: present
        default_release: bookworm-backports
        update_cache: yes
    - name: Prometheus. Add Jobs to prometheus.yml
      ansible.builtin.shell: |
        echo '' >> prometheus.yml
        echo '  - job_name: psql1server' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.10:9187']' >> prometheus.yml
        echo '' >> prometheus.yml
        echo '  - job_name: psql2server' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.11:9187']' >> prometheus.yml
        echo '' >> prometheus.yml
        echo '  - job_name: psql1serverex' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.10:9100']' >> prometheus.yml
        echo '' >> prometheus.yml
        echo '  - job_name: psql2serverex' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.11:9100']' >> prometheus.yml
        echo '' >> prometheus.yml
        echo '  - job_name: e1serverex' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.2:9100']' >> prometheus.yml
        echo '' >> prometheus.yml
        echo '  - job_name: e2serverex' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.3:9100']' >> prometheus.yml
        echo '' >> prometheus.yml
        echo '  - job_name: gw1serverex' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.9:9100']' >> prometheus.yml
        echo '' >> prometheus.yml
        echo '  - job_name: bk1serverex' >> prometheus.yml
        echo '    static_configs:' >> prometheus.yml
        echo '      - targets: ['192.168.1.12:9100']' >> prometheus.yml
        echo '' >> prometheus.yml
        systemctl restart prometheus.service
      args:
        executable: /bin/bash
        chdir: /etc/prometheus/
```

В нашем примере мы установили сервер _prometheus_ на виртуальную машину ***mon1server***, а экспортеры _prometheus-node-exporter_ на следующие машины: 
  - ***e1server***, 
  - ***e2server***,
  - ***psql1server***, 
  - ***psql2server***,
  - ***gw1server***, 
  - ***bk1server***.

> [!NOTE]
> Обратите внимание, что для добавления указанных машин в качестве целевых, в задаче _"APT. Update the repository cache and install packages "prometheus-node-exporter" to latest version"_
> используется группа хостов с именем ***prometheuses***, которая, в свою очередь, содержит вложенные группы хостов - ***ejserver***, ***psqlserver***, ***gwserver*** и ***bkserver***. 
> Для описания группы хостов, содержащих вложенные группы, необходимо через двоеточие после имени группы указывать ключ _children_. В нашем случае файл инвентаризации хостов выглядит так:

```
[ejserver]
e1server ansible_host=192.168.121.10 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-eJabberd1/libvirt/private_key
e2server ansible_host=192.168.121.11 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-eJabberd2/libvirt/private_key

[psqlserver]
psql1server ansible_host=192.168.121.12 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-psql1/libvirt/private_key
psql2server ansible_host=192.168.121.13 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-psql2/libvirt/private_key

[gwserver]
gw1server ansible_host=192.168.121.14 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-gw1/libvirt/private_key

[bkserver]
bk1server ansible_host=192.168.121.15 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-bk1/libvirt/private_key

[monserver]
mon1server ansible_host=192.168.121.16 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-mon1/libvirt/private_key

[baculas:children]
ejserver
psqlserver
monserver

[baculas-script]
psql2server ansible_host=192.168.121.13 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-psql2/libvirt/private_key
mon1server ansible_host=192.168.121.16 ansible_port=22 ansible_private_key_file=/home/max/vagrant/vg3/.vagrant/machines/Debian12-mon1/libvirt/private_key

[prometheuses:children]
ejserver
psqlserver
gwserver
bkserver
```
##### Grafana

![Grafana](/pictures/grafana-logo.png) С помощью [Grafana](https://grafana.com/grafana/) можно выводить на монитор наглядные результаты сбора метрик со стороны _Prometheus_. Пример вывода информации в _Grafana_:

![Grafana](/pictures/grafana.png)

На [странице](https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/) руководства по установке _Grafana_ на операционные системы _Debian_ или _Ubuntu_ предлагается два пути:
  - импортировать GPG-ключ и добавить репозиторий _Grafana_;
  - скачать установочный пакет со [страницы](https://grafana.com/grafana/download) загрузки и установить его локально.

Воспользуемся вторым способом. _Ansible Playbook_ для установки и настройки _Grafana_:

```
---
- name: Grafana | Install Grafana
  hosts: monserver
  become: true
  tasks:
    - name: Grafana. Install. Enable and start of service
      ansible.builtin.shell: |
        dpkg -i grafana_11.4.0_amd64.deb
        systemctl daemon-reload
        systemctl enable grafana-server
        systemctl start grafana-server
      args:
        executable: /bin/bash
        chdir: /home/vagrant/
- name: Grafana | Configure Grafana
  hosts: monserver
  become: true
  tasks:
    - name: Grafana. Configure. Enable and start of service
      ansible.builtin.shell: |
        cp /home/vagrant/mon1server.pem /etc/grafana/mon1server.pem
        chown grafana:grafana /etc/grafana/mon1server.pem
        sed -i "s/;protocol = http/protocol = https/" /etc/grafana/grafana.ini
        sed -i "s/;domain = localhost/domain = grafana.domain.local/" /etc/grafana/grafana.ini
        sed -i "s/;cert_file =/cert_file = \\/etc\\/grafana\\/mon1server.pem/" /etc/grafana/grafana.ini
        sed -i "s/;cert_key =/cert_key = \\/etc\\/grafana\\/mon1server.pem/" /etc/grafana/grafana.ini
        systemctl restart grafana-server.service
      args:
        executable: /bin/bash
```

Проверим, что _Grafana_ запустилась:

```
root@mon1server:~# ss -ntlp
State    Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process                                                         
LISTEN   0       128           0.0.0.0:22         0.0.0.0:*      users:(("sshd",pid=506,fd=3))                                  
LISTEN   0       50       192.168.1.13:9102       0.0.0.0:*      users:(("bacula-fd",pid=2420,fd=3))                            
LISTEN   0       4096                *:3000             *:*      users:(("grafana",pid=5687,fd=10))                             
LISTEN   0       4096                *:9090             *:*      users:(("prometheus",pid=5342,fd=7))                           
LISTEN   0       4096                *:9100             *:*      users:(("prometheus-node",pid=4789,fd=3))                      
LISTEN   0       128              [::]:22            [::]:*      users:(("sshd",pid=506,fd=4))
```

Дальнейшие шаги по настройке и добавлению панелей производятся уже в веб-интерфейсе установленного сервиса, доступном по адресу https://имя_хоста:3000

#### Нештатные ситуации
![popai](/pictures/popai.png) Как уже говорилось ранее, демон _Ejabberd_ и СУБД _Postgresql_ у нас настроены для работы в режиме кластера из двух пар серверов, поэтому в нашем стенде 
изначально поддерживается стабильная работа в случае сбоя. Рассмотрим добавление нового узла, на случай выхода из строя одного из серверов, таким образом, 
чтобы в случае нештатной ситуации сохранился отказоустойчивый режим работы.

Для этих целей в нашем стенде предусмотрена дополнительная виртуальная машина, которая не включена в вышеприведённую схему. Описание машины в Vagrantfile:
```
  config.vm.define "Debian12-r1" do |r1server|
  r1server.vm.box = "/home/max/vagrant/images/debian12"
  r1server.vm.network :private_network,
       :type => 'ip',
       :libvirt__forward_mode => 'veryisolated',
       :libvirt__dhcp_enabled => false,
       :ip => '192.168.1.4',
       :libvirt__netmask => '255.255.255.248',
       :libvirt__network_name => 'vagrant-libvirt-inet1',
       :libvirt__always_destroy => false
  r1server.vm.network :private_network,
       :type => 'ip',
       :libvirt__forward_mode => 'veryisolated',
       :libvirt__dhcp_enabled => false,
       :ip => '192.168.1.17',
       :libvirt__netmask => '255.255.255.248',
       :libvirt__network_name => 'vagrant-libvirt-srv1',
       :libvirt__always_destroy => false
  r1server.vm.provider "libvirt" do |lvirt|
      lvirt.memory = "1024"
      lvirt.cpus = "1"
      lvirt.title = "Debian12-r1Server"
      lvirt.description = "Виртуальная машина на базе дистрибутива Debian Linux. r1Server"
      lvirt.management_network_name = "vagrant-libvirt-mgmt"
      lvirt.management_network_address = "192.168.121.0/24"
      lvirt.management_network_keep = "true"
      lvirt.management_network_mac = "52:54:00:27:28:90"
  end
  r1server.vm.provision "file", source: "ca/e3server.pem", destination: "~/e3server.pem"
  r1server.vm.provision "shell", inline: <<-SHELL
      brd='*************************************************************'
      echo "$brd"
      echo 'Set Hostname'
      hostnamectl set-hostname r1server
      echo "$brd"
      sed -i 's/debian12/r1server/' /etc/hosts
      sed -i 's/debian12/r1server/' /etc/hosts
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
      # Разрешим транзит трафика.
      iptables -A FORWARD -j ACCEPT
      # Открываем исходящие
      iptables -A OUTPUT -j ACCEPT
      # Разрешим входящие с хоста управления.
      iptables -A INPUT -s 192.168.121.1 -m tcp -p tcp --dport 22 -j ACCEPT
      # Также, разрешим входящие для виртуальных хостов по ssh и для серверов баз данных во всём диапазоне tcp
      iptables -A INPUT -s 192.168.1.0/28 -m multiport -m tcp -p tcp --dports 22,9100 -j ACCEPT
      # Откроем ICMP ping
      iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
      netfilter-persistent save
      echo "net.ipv4.conf.all.forwarding = 1" >> /etc/sysctl.conf
      sysctl -p
      SHELL
  end
```
Здесь мы видим, что данная машина имеет три сетевых интерфейса: один для упрвления машиной с хоста виртуализации и два в изолированных сетях - _"vagrant-libvirt-inet1"_ и _vagrant-libvirt-srv1_. 
В зависимости от роли резервного сервера, лишний сетевой интерфейс будет отключен при выполнении yml-сценария восстановления.

##### Ejabberd
![popai-ej](/pictures/popai-ej.png) Рассмотрим ситуацию, когда у нас становится недоступным один из узлов сервиса _Jabber_. _Ansible_ _yml_-файл с сценарием для восстановления кластера находится [здесь](/files/rescue.yml). 

Рассмотрим его подробно. Для начала настроим сетевые параметры и зададим имя хоста, а также зададим правила межсетевого экранирования:

```
- name: Rescue | r1server. Change ip-address for ens6. Add rule. Install and configure ejabberd
  hosts: r1server
  become: true
  tasks:
    - name: r1server. Down iface. Set new ip-address. Up iface
      ansible.builtin.shell: |
        ifdown ens6
        ifdown ens7
        sed -i '/iface ens6/{n;s/address 192\.168\.1\..*/address 192.168.1.4/}' /etc/network/interfaces
        ifup ens6
        hostnamectl set-hostname e3server
        sed -i 's/r1server/e3server/' /etc/hosts
        sed -i 's/r1server/e3server/' /etc/hosts
        echo '192.168.1.4 e3server.domain.local e1server' >> /etc/hosts
        iptables -A INPUT -s 192.168.121.1 -m tcp -p tcp --dport 5280 -j ACCEPT
        iptables -A INPUT -s 192.168.1.0/29 -m tcp -m multiport -p tcp --dports 5222,5223,5269,5443,5280,1883,4369,4200:4210 -j ACCEPT
        iptables -A INPUT -s 192.168.1.0/28 -m tcp -m multiport -p tcp --dports 22,9100,9102 -j ACCEPT
        iptables -A INPUT -p vrrp -d 224.0.0.18 -j ACCEPT
        netfilter-persistent save
        ip route add 192.168.1.8/29 via 192.168.1.1
        ip route save > /etc/my-routes
        echo 'up ip route restore < /etc/my-routes' >> /etc/network/interfaces
      args:
        executable: /bin/bash
```

Далее, настраиваем репозитории и устанавливаем необходимые пакеты:

```
- name: Rescue | r1server. Install and configure ejabberd
  hosts: r1server
  become: true
  tasks:
    - name: APT. Add Backports repository into sources list
      ansible.builtin.apt_repository:
        repo: deb http://deb.debian.org/debian bookworm-backports main contrib non-free
        state: present
    - name: APT. Update the repository cache and install packages "eJabberd", "erlang-p1-pgsql", "python3-psycopg2", "acl" to latest version using default release bookworm-backport
      ansible.builtin.apt:
        name: ejabberd,erlang-p1-pgsql,python3-psycopg2,acl
        state: present
        default_release: bookworm-backports
        update_cache: yes
```

На серверах кластера СУБД редоставим доступ для пользователя `ejabberd` к базе данных `ejabberd-domain-local` для подключения с нашего нового сервера:

```
- name: PostgreSQL | Group of servers "psqlserver".
  hosts: psqlserver
  become: true
  tasks:
    - name: Config. Edit pg_hba configuration file. Add e3server access. Открываем доступ с третьей ноды Jabber-сервера к базе ejabberd-domain-local для пользователя ejabberd.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: ejabberd
        source: 192.168.1.4
        databases: ejabberd-domain-local
        method: scram-sha-256
        create: true
    - name: Config. Bash. Restart postgresql.service
      ansible.builtin.shell: |
        systemctl restart postgresql
      args:   
        executable: /bin/bash
```

Приведём параметры главного конфигурационного файла _ejabberd_ к такому же виду, как и на остальных серверах кластера:

```
- name: Rescue | r1server. Confgure for domainname and psql1server connect. Granting administrator account rights
  hosts: r1server
  become: true
  tasks:
    - name: Edit ejabberd.yml for domainname.
      ansible.builtin.shell: |
        sed -i 's/localhost/domain.local/' ejabberd.yml
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
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
    - name: Edit ejabberd.yml for granting administrator account rights.
      ansible.builtin.shell: |
        echo ''  >> ejabberd.yml
        echo '    acl:' >> ejabberd.yml
        echo '      admin:' >> ejabberd.yml
        echo '        user: admin@domain.local' >> ejabberd.yml
        echo ''  >> ejabberd.yml
        echo '    access_rules:' >> ejabberd.yml
        echo '      configure:' >> ejabberd.yml
        echo '        allow: admin' >> ejabberd.yml
        systemctl restart ejabberd.service
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```

Настроим параметры для _TLS_, для чего укажем путь к сертификату и закрытому ключу:

```
- name: Rescue | r1server. Configuring the e3server server certificate
  hosts: r1server
  become: true
  tasks:
    - name: Edit ejabberd.yml
      ansible.builtin.shell: |
        cp /home/vagrant/e3server.pem .
        chown root:ejabberd e3server.pem
        chmod 640 e3server.pem
        sed -i 's/ejabberd.pem/e3server.pem/' ejabberd.yml
        systemctl restart ejabberd.service
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```

Подготовим наш хост для добавления его в кластер _Ejabberd_:

```
- name: eJabberd | Server "r1server". Confgure Erlang. Pre-configuration for creating a cluster
  hosts: r1server
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
    - name: Specify the acceptable range of ports.
      ansible.builtin.shell: |
        sed -i "s/#FIREWALL_WINDOW=/FIREWALL_WINDOW=4200-4210/" /etc/default/ejabberd
      args:
        executable: /bin/bash
    - name: Reboot after change nodename.
      ansible.builtin.shell: |
        pkill -9 beam.smp
        systemctl stop epmd.service
        sleep 5
        systemctl start ejabberd.service
        sleep 5
      args:
        executable: /bin/bash
```

Добавим его в кластер, используя одну из доступных нод:

```
- name: eJabberd | Add host to a cluster
  hosts: r1server
  become: true
  tasks:
    - name: Join ejabberd@e3server to cluster ejabberd@e1server or ejabberd@e2server
      ansible.builtin.shell: |
        ejabberdctl ping ejabberd@e1server | grep "pong" && ejabberdctl --no-timeout join_cluster 'ejabberd@e1server' || ejabberdctl --no-timeout join_cluster 'ejabberd@e2server' 
      args:
        executable: /bin/bash
```

Настроим сетевой интерфейс из сети управления так, чтобы он мог участвовать в существующей конфигурации балансировщика _keepalived_:

```
- name: keepalived | Install and configure keepalived. Установка Keepalived на сервер r1server. Настройка главного конфигурационного файла.
  hosts: r1server
  become: true
  tasks:
    - name: Install package "keepalived" to latest version
      ansible.builtin.apt:
        name: keepalived
        state: present
        update_cache: yes
    - name: Configure and start virtual ip
      ansible.builtin.shell: |
        echo 'global_defs {' > /etc/keepalived/keepalived.conf
        echo '   notification_email {' >> /etc/keepalived/keepalived.conf
        echo '     admin@example.net' >> /etc/keepalived/keepalived.conf
        echo '   }' >> /etc/keepalived/keepalived.conf
        echo '   notification_email_from kladmin@example.net' >> /etc/keepalived/keepalived.conf
        echo '   smtp_server 127.0.0.1' >> /etc/keepalived/keepalived.conf
        echo '   smtp_connect_timeout 30' >> /etc/keepalived/keepalived.conf
        echo "   router_id $HOSTNAME" >> /etc/keepalived/keepalived.conf
        echo '#  vrrp_skip_check_adv_addr' >> /etc/keepalived/keepalived.conf
        echo '#  vrrp_strict' >> /etc/keepalived/keepalived.conf
        echo '#  vrrp_garp_interval 0' >> /etc/keepalived/keepalived.conf
        echo '#  vrrp_gna_interval 0' >> /etc/keepalived/keepalived.conf
        echo '}' >> /etc/keepalived/keepalived.conf
        echo ' ' >> /etc/keepalived/keepalived.conf
        echo 'vrrp_track_process track_beam.smp {' >> /etc/keepalived/keepalived.conf
        echo '    process beam.smp' >> /etc/keepalived/keepalived.conf
        echo '    weight 10' >> /etc/keepalived/keepalived.conf
        echo '    delay 1' >> /etc/keepalived/keepalived.conf
        echo '}' >> /etc/keepalived/keepalived.conf
        echo 'vrrp_instance VI_1 {' >> /etc/keepalived/keepalived.conf
        echo '    garp_master_delay 5' >> /etc/keepalived/keepalived.conf
        echo '    garp_master_repeat 5' >> /etc/keepalived/keepalived.conf
        echo '    garp_lower_prio_delay 5' >> /etc/keepalived/keepalived.conf
        echo '    garp_lower_prio_repeat 5' >> /etc/keepalived/keepalived.conf
        echo '    garp_master_refresh 60' >> /etc/keepalived/keepalived.conf
        echo '    garp_master_refresh_repeat 2' >> /etc/keepalived/keepalived.conf
        echo '    state BACKUP' >> /etc/keepalived/keepalived.conf
        echo '    nopreempt' >> /etc/keepalived/keepalived.conf
        echo '    interface ens5' >> /etc/keepalived/keepalived.conf
        echo '#   smtp_alert' >> /etc/keepalived/keepalived.conf
        echo '    virtual_router_id 51' >> /etc/keepalived/keepalived.conf
        echo '    priority 99' >> /etc/keepalived/keepalived.conf
        echo '    advert_int 5' >> /etc/keepalived/keepalived.conf
        echo '    authentication {' >> /etc/keepalived/keepalived.conf
        echo '        auth_type PASS' >> /etc/keepalived/keepalived.conf
        echo '        auth_pass P@sswd' >> /etc/keepalived/keepalived.conf
        echo '    }' >> /etc/keepalived/keepalived.conf
        echo '    virtual_ipaddress {' >> /etc/keepalived/keepalived.conf
        echo '        192.168.121.9 label keepalived_addr' >> /etc/keepalived/keepalived.conf
        echo '    }' >> /etc/keepalived/keepalived.conf
        echo '    track_process {' >> /etc/keepalived/keepalived.conf
        echo '        track_beam.smp' >> /etc/keepalived/keepalived.conf
        echo '    }' >> /etc/keepalived/keepalived.conf
        echo '}' >> /etc/keepalived/keepalived.conf
      args:
        executable: /bin/bash
        chdir: /etc/keepalived/
```

Здесь указывается такой же _virtual\_router\_id_, как на остальных хостах и устанавливается самый низкий приоритет ноды - *99*. 
У _e1server_ и _e2server_ - *101* и *100*, соответственно.

Перезапускаем _keepalived_ с новыми параметрами:
```
- name: Keepalived | Перезапуск Keepalived
  hosts: r1server
  become: true
  tasks:
    - name: Перезапуск Keepalived
      ansible.builtin.shell: systemctl restart keepalived
      args:
        executable: /bin/bash
```

##### Postgresql
###### Replica

![popai-psql](/pictures/popai-psql.png) Рассмотрим случай, когда нужно включить в работу резервный сервер, вместо вышедшего из строя экземпляра кластера в роли _Replica_. В отличие от предыдущего примера, когда
дополнительная нода _ejabberd@e3server_ включалась в работу в дополнение к двум существующим экземплярам _ejabberd@e1server_ и _ejabberd@e2server_ 
со своим уникальным ip-адресом и именем хоста, здесь мы будем вводить в эксплуатацию сервер с ip-адресом и именем, совпадающими с вышедшим из строя экземпляром.
Т.е. если у нас вышел из строя сервер с именем _psql2server_ и ip-адресом __192.168.1.11__, то резервный сервер с исходным именем _r1server_ и ip-адресом
__192.168.1.17__ присвоит себе имя и адрес замещаемого хоста.

_Ansible_ _yml_-файл с сценарием для восстановления кластера находится [здесь](/files/rescue-psql2.yml). Рассмотрим его подробно. 
Для начала настроим сетевые параметры и зададим имя хоста, а также зададим правила межсетевого экранирования:

```
- name: Rescue | r1server. Change ip-address for ens7. Add rule. Install and configure ejabberd
  hosts: r1server
  become: true
  tasks:
    - name: r1server. Down iface. Set new ip-address. Up iface
      ansible.builtin.shell: |
        ifdown ens6
        ifdown ens7
        sed -i '/iface ens7/{n;s/address 192\.168\.1\..*/address 192.168.1.11/}' /etc/network/interfaces
        ifup ens7
        hostnamectl set-hostname psql2server
        sed -i 's/r1server/psql2server/' /etc/hosts
        sed -i 's/r1server/psql2server/' /etc/hosts
        echo '192.168.1.11 psql2server.domain.local psql2server' >> /etc/hosts
        iptables -A INPUT -s 192.168.1.0/28 -m tcp -m multiport -p tcp --dports 5432,9100,9102,9187 -j ACCEPT
        netfilter-persistent save
        ip route add 192.168.1.0/29 via 192.168.1.9
        ip route save > /etc/my-routes
        echo 'up ip route restore < /etc/my-routes' >> /etc/network/interfaces
      args:
        executable: /bin/bash
```

Далее, настраиваем репозитории, устанавливаем необходимые пакеты и настраиваем СУБД:

```
- name: Rescue | r1server. Install and configure postgresql
  hosts: r1server
  become: true
  tasks:
    - name: APT. Add Backports repository into sources list
      ansible.builtin.apt_repository:
        repo: deb http://deb.debian.org/debian bookworm-backports main contrib non-free
        state: present
    - name: APT. Update the repository cache and install packages "postgresqql", "python3-psycopg2", "acl", "nfs-common", "prometheus-node-exporter", "prometheus-postgres-exporter" to latest version using default release bookworm-backport
      ansible.builtin.apt:
        name: postgresql,python3-psycopg2,acl,nfs-common,prometheus-node-exporter,prometheus-postgres-exporter
        state: present
        default_release: bookworm-backports
        update_cache: true
    - name: Config. Edit pg_hba configuration file. Add e1server access. Открываем доступ с первой ноды Jabber-сервера к базе ejabberd-domain-local для пользователя ejabberd.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: ejabberd
        source: 192.168.1.2
        databases: ejabberd-domain-local
        method: scram-sha-256
        create: true
    - name: Config. Edit pg_hba configuration file. Add e2server access. Открываем доступ со второй ноды Jabber-сервера к базе ejabberd-domain-local для пользователя ejabberd.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: ejabberd
        source: 192.168.1.3
        databases: ejabberd-domain-local
        method: scram-sha-256
        create: true
    - name: Config. Bash. Edit postgresql.conf for enable all interfaces. Разрешаем входящие подключения к порту 5432 на всех интерфейсах.
      ansible.builtin.shell: |
        echo "listen_addresses = '*'" >> postgresql.conf
        systemctl restart postgresql
      args:
        executable: /bin/bash
        chdir: /etc/postgresql/15/main/
    - name: prometheus-postgres-exporter. Copy configuration file
      ansible.builtin.shell: |
        cp prometheus-postgres-exporter /etc/default/prometheus-postgres-exporter
      args:
        executable: /bin/bash
        chdir: /home/vagrant/
    - name: prometheus-postgres-exporter. Restart service
      ansible.builtin.shell: |
        sleep 5
        systemctl restart prometheus-postgres-exporter.service
      args:
        executable: /bin/bash
```

Приводим к нужному виду конфигурационные файлы и запускаем репликацию

```
- name: Rescue | r1server as Secondary Server. Configuration a Replica server and start replication.
  hosts: r1server
  become: true
  tasks:
    - name: Config. Edit pg_hba configuration file. Access for Replica from psql1server. Разрешаем удалённое подключение пользователю replica_role для получения wal принимающим сервером.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: replica_role
        source: 192.168.1.10
        databases: replication
        method: scram-sha-256
        create: true
    - name: Bash. Create nfs dir.
      ansible.builtin.shell: |
        test ! -d /mnt/nfs && mkdir -p $_
        echo "192.168.1.12:/srv/share/upload/ /mnt/nfs nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
        systemctl daemon-reload
        systemctl restart remote-fs.target
      args:
        executable: /bin/bash
    - name: Config. Bash. Edit postgresql.conf configuration file.
      ansible.builtin.shell: |
        sed -i 's/#wal_level = replica/wal_level = replica/' postgresql.conf
        sed -i 's/#max_wal_senders = 10/#max_wal_senders = 10/' postgresql.conf
        sed -i 's/#max_replication_slots = 10/max_replication_slots = 10/' postgresql.conf
        sed -i 's/#wal_keep_size = 0/wal_keep_size = 100/' postgresql.conf
        sed -i 's/#max_slot_wal_keep_size = -1/max_slot_wal_keep_size = -1/' postgresql.conf
        sed -i 's/#wal_sender_timeout = 60s/wal_sender_timeout = 60s/' postgresql.conf
        sed -i 's/#track_commit_timestamp = off/track_commit_timestamp = off/' postgresql.conf
        sed -i 's/#archive_mode = off/archive_mode = on/' postgresql.conf
        echo '# Archive and restore commsnfs' >> postgresql.conf
        echo "archive_command = 'test ! -f /mnt/nfs/psql2server/archive/%f && cp %p /mnt/nfs/psql2server/archive/%f'" >> postgresql.conf
        echo "restore_command = 'cp /mnt/nfs/psql2server/archive/%f %p'" >> postgresql.conf
      args:
        executable: /bin/bash
        chdir: /etc/postgresql/15/main/
    - name: Config. Bash. Stop postgresql service, remove work directory. Set PGPASSWORD variable, start replication.
      ansible.builtin.shell: |
        systemctl stop postgresql
        rm -rf /var/lib/postgresql/15/main
        PGPASSWORD=Inc0gn1t0
        export PGPASSWORD
        pg_basebackup -h 192.168.1.10 -U replica_role -X stream -R -P -D /var/lib/postgresql/15/main
        chown -R postgres: /var/lib/postgresql/15/main
        systemctl start postgresql
      args:
        executable: /bin/bash
```

Настраиваем клиент _Bacula_:

```
- name: Rescue | r1server. Install and configure "bacula-client". Installing "bacula-client" packages on the r1server
  hosts:
    r1server
  become: true
  tasks:
    - name: APT. Update the repository cache and install packages "bacula-client" to latest version using default release bookworm-backport
      ansible.builtin.apt:
        name: bacula-client
        state: present
        update_cache: yes
    - name: Bacula-client. Copy configuration file. Restart of service
      ansible.builtin.shell: |
        cp /home/vagrant/bacula-fd2.conf /etc/bacula/bacula-fd.conf
        systemctl restart bacula-fd.service
      args:
        executable: /bin/bash
    - name: Bash. Create a directory for archiving tasks
      ansible.builtin.shell: |
        mkdir -p /bacula-backup
        chown -R postgres:postgres /bacula-backup
        cp /home/vagrant/bacula-{before,after}-dump.sh /etc/bacula/scripts/
        chown bacula:bacula /etc/bacula/scripts/bacula-{before,after}-dump.sh
        chmod u+x /etc/bacula/scripts/bacula-{before,after}-dump.sh
        systemctl restart bacula-fd.service
      args:
        executable: /bin/bash
```

После всех этих действий новый сервер становится на замену вышедшей из строя реплики. С него снимаются резервные копии, на сервер _Grafana_ выводятся метрики, собираемые экспортерами _prometheus-node-exporter_, _prometheus-postgres-exporter_

###### Master

План для восстановления работы кластера в случае выхода из строя сервера с ролью _Master_ заключается в следующем: 
  - перевести текущий _Replica_-сервер из режима _readonly_ в _Master_; 
  - перенастроить серверы _Ejabberd_ - _e1server_ и _e2server_ на работу с новым _Master_-сервером - _psql2server_; 
  - настроить резервный сервер _r1server_ для работы в качестве _Replica_ вместо вышедшего из эксплуатации _psql1server_.

_Ansible_ _yml_-файл с сценарием для восстановления кластера находится [здесь](/files/rescue-psql1.yml). Рассмотрим его подробно.
Для начала настроим сетевые параметры и зададим имя хоста, а также зададим правила межсетевого экранирования:

```
- name: Rescue | r1server. Change ip-address for ens7. Add rule. Install and configure ejabberd
  hosts: r1server
  become: true
  tasks:
    - name: r1server. Down iface. Set new ip-address. Up iface
      ansible.builtin.shell: |
        ifdown ens6
        ifdown ens7
        sed -i '/iface ens7/{n;s/address 192\.168\.1\..*/address 192.168.1.10/}' /etc/network/interfaces
        ifup ens7
        hostnamectl set-hostname psql1server
        sed -i 's/r1server/psql1server/' /etc/hosts
        sed -i 's/r1server/psql1server/' /etc/hosts
        echo '192.168.1.10 psql1server.domain.local psql1server' >> /etc/hosts
        iptables -A INPUT -s 192.168.1.0/28 -m tcp -m multiport -p tcp --dports 5432,9100,9102,9187 -j ACCEPT
        netfilter-persistent save
        ip route add 192.168.1.0/29 via 192.168.1.9
        ip route save > /etc/my-routes
        echo 'up ip route restore < /etc/my-routes' >> /etc/network/interfaces
      args:
        executable: /bin/bash
```

Далее, настраиваем репозитории, устанавливаем необходимые пакеты и настраиваем СУБД:

```
- name: Rescue | r1server. Install and configure postgresql
  hosts: r1server
  become: true
  tasks:
    - name: APT. Add Backports repository into sources list
      ansible.builtin.apt_repository:
        repo: deb http://deb.debian.org/debian bookworm-backports main contrib non-free
        state: present
    - name: APT. Update the repository cache and install packages "postgresqql", "python3-psycopg2", "acl", "nfs-common", "prometheus-node-exporter", "prometheus-postgres-exporter" to latest version using default release bookworm-backport
      ansible.builtin.apt:
        name: postgresql,python3-psycopg2,acl,nfs-common,prometheus-node-exporter,prometheus-postgres-exporter
        state: present
        default_release: bookworm-backports
        update_cache: true
    - name: Config. Edit pg_hba configuration file. Add e1server access. Открываем доступ с первой ноды Jabber-сервера к базе ejabberd-domain-local для пользователя ejabberd.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: ejabberd
        source: 192.168.1.2
        databases: ejabberd-domain-local
        method: scram-sha-256
        create: true
    - name: Config. Edit pg_hba configuration file. Add e2server access. Открываем доступ со второй ноды Jabber-сервера к базе ejabberd-domain-local для пользователя ejabberd.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: ejabberd
        source: 192.168.1.3
        databases: ejabberd-domain-local
        method: scram-sha-256
        create: true
    - name: Config. Bash. Edit postgresql.conf for enable all interfaces. Разрешаем входящие подключения к порту 5432 на всех интерфейсах.
      ansible.builtin.shell: |
        echo "listen_addresses = '*'" >> postgresql.conf
        systemctl restart postgresql
      args:
        executable: /bin/bash
        chdir: /etc/postgresql/15/main/
    - name: prometheus-postgres-exporter. Copy configuration file
      ansible.builtin.shell: |
        cp prometheus-postgres-exporter /etc/default/prometheus-postgres-exporter
      args:
        executable: /bin/bash
        chdir: /home/vagrant/
    - name: prometheus-postgres-exporter. Restart service
      ansible.builtin.shell: |
        sleep 5
        systemctl restart prometheus-postgres-exporter.service
      args:
        executable: /bin/bash
```

Переводим текущий сервер _Replica_ в режим _Master_:

```
- name: Rescue | Start psql2server as Primary Server.
  hosts: psql2server
  become: true
  tasks:
    - name: Bash. Up psql2server to Master.
      ansible.builtin.shell: |
        pg_ctlcluster 15 main promote
        systemctl restart postgresql.service
      args:
        executable: /bin/bash
        chdir: /var/lib/postgresql/15/
```

Перенастраиваем оба сервера _Ejabberd_ для работы с новым _Master_ сервером _Postgresql_:

```
- name: Rescue | ejserver. Reconfigure ejabberd for a new Postgresql Master.
  hosts: ejserver
  become: true
  tasks:
    - name: Bash. Up psql2server to Master.
      ansible.builtin.shell: |
        sed -i 's/sql_server: 192.168.1.10/sql_server: 192.168.1.11/' ejabberd.yml
        systemctl restart ejabberd.service
      args:
        executable: /bin/bash
        chdir: /etc/ejabberd/
```

Настраиваем новый сервер _Replica_:

```
- name: Rescue | r1server as Secondary Server. Configuration a Replica server and start replication.
  hosts: r1server
  become: true
  tasks:
    - name: Config. Edit pg_hba configuration file. Access for Replica from psql1server. Разрешаем удалённое подключение пользователю replica_role для получения wal принимающим сервером.
      postgresql_pg_hba:
        dest: /etc/postgresql/15/main/pg_hba.conf
        contype: host
        users: replica_role
        source: 192.168.1.11
        databases: replication
        method: scram-sha-256
        create: true
    - name: Bash. Create nfs dir.
      ansible.builtin.shell: |
        test ! -d /mnt/nfs && mkdir -p $_
        echo "192.168.1.12:/srv/share/upload/ /mnt/nfs nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
        systemctl daemon-reload
        systemctl restart remote-fs.target
      args:
        executable: /bin/bash
    - name: Config. Bash. Edit postgresql.conf configuration file.
      ansible.builtin.shell: |
        sed -i 's/#wal_level = replica/wal_level = replica/' postgresql.conf
        sed -i 's/#max_wal_senders = 10/#max_wal_senders = 10/' postgresql.conf
        sed -i 's/#max_replication_slots = 10/max_replication_slots = 10/' postgresql.conf
        sed -i 's/#wal_keep_size = 0/wal_keep_size = 100/' postgresql.conf
        sed -i 's/#max_slot_wal_keep_size = -1/max_slot_wal_keep_size = -1/' postgresql.conf
        sed -i 's/#wal_sender_timeout = 60s/wal_sender_timeout = 60s/' postgresql.conf
        sed -i 's/#track_commit_timestamp = off/track_commit_timestamp = off/' postgresql.conf
        sed -i 's/#archive_mode = off/archive_mode = on/' postgresql.conf
        echo '# Archive and restore commsnfs' >> postgresql.conf
        echo "archive_command = 'test ! -f /mnt/nfs/psql2server/archive/%f && cp %p /mnt/nfs/psql2server/archive/%f'" >> postgresql.conf
        echo "restore_command = 'cp /mnt/nfs/psql2server/archive/%f %p'" >> postgresql.conf
      args:
        executable: /bin/bash
        chdir: /etc/postgresql/15/main/
    - name: Config. Bash. Stop postgresql service, remove work directory. Set PGPASSWORD variable, start replication.
      ansible.builtin.shell: |
        systemctl stop postgresql
        rm -rf /var/lib/postgresql/15/main
        PGPASSWORD=Inc0gn1t0
        export PGPASSWORD
        pg_basebackup -h 192.168.1.11 -U replica_role -X stream -R -P -D /var/lib/postgresql/15/main
        chown -R postgres: /var/lib/postgresql/15/main
        systemctl start postgresql
      args:
        executable: /bin/bash
```

Устанавливаем и настраиваем на новом сервере _Replica_ клиент системы резервного копирования _Bacula_:

```
- name: Rescue | r1server. Install and configure "bacula-client". Installing "bacula-client" packages on the r1server
  hosts:
    r1server
  become: true
  tasks:
    - name: APT. Update the repository cache and install packages "bacula-client" to latest version using default release bookworm-backport
      ansible.builtin.apt:
        name: bacula-client
        state: present
        update_cache: yes
    - name: Bacula-client. Copy configuration file. Restart of service
      ansible.builtin.shell: |
        cp /home/vagrant/bacula-fd1.conf /etc/bacula/bacula-fd.conf
        systemctl restart bacula-fd.service
      args:
        executable: /bin/bash
    - name: Bash. Create a directory for archiving tasks
      ansible.builtin.shell: |
        mkdir -p /bacula-backup
        chown -R postgres:postgres /bacula-backup
        cp /home/vagrant/bacula-{before,after}-dump.sh /etc/bacula/scripts/
        chown bacula:bacula /etc/bacula/scripts/bacula-{before,after}-dump.sh
        chmod u+x /etc/bacula/scripts/bacula-{before,after}-dump.sh
        systemctl restart bacula-fd.service
      args:
        executable: /bin/bash
```

После всех выполненых настроек, мы получаем работающую систему, где сервер СУБД _psql2server_, ранее выполняющий роль ведомого, стал главным,
на месте бывшего _Master_-сервера поднят резервный хост, но уже в роли _Replica_, а ноды _Ejabberd_ настроены на работу с новым _Master_-сервером.
