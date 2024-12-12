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

