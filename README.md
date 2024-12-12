#### Автоматическое развёртывание в виртуальной среде с использованием Vagrant, Libvirt, QEMU, KVM и Ansible службы обмена мгновенными сообщениями на базе XMPP-сервера [Ejabberd](https://docs.ejabberd.im/)

![Logo](/pictures/logo.png)

> [!NOTE]
> [Ejabberd](https://docs.ejabberd.im/) — это надежная, масштабируемая и расширяемая платформа реального времени с открытым исходным кодом, созданная с использованием Erlang/OTP, которая включает в себя сервер XMPP, брокер MQTT ислужбу SIP.

##### Описание стенда
Для работы будем использовать виртуальный стенд, построенный с использованием среды разработки [Vagrant](https://www.vagrantup.com/), инструментов управления виртуализацией [Libvirt](https://libvirt.org/), 
эмулятора виртуальных машин [Qemu][https://www.qemu.org/], модуля ядра, использующего расширения виртуализации (Intel VT или AMD-V) [KVM](https://linux-kvm.org/page/Main_Page) и инструмента автоматизации [Ansible](https://www.ansible.com/)
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
