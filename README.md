#### Автоматическое развёртывание в виртуальной среде с использованием Vagrant, Libvirt, QEMU, KVM и Ansible службы обмена мгновенными сообщениями на базе XMPP-сервера [Ejabberd](https://docs.ejabberd.im/)
> [!NOTE]
> [Ejabberd](https://docs.ejabberd.im/) — это надежная, масштабируемая и расширяемая платформа реального времени с открытым исходным кодом, созданная с использованием Erlang/OTP, которая включает в себя сервер XMPP, брокер MQTT ислужбу SIP.
##### Описание стенда
Для работы будем использовать виртуальный стенд, построенный с использованием среды разработки [Vagrant](https://www.vagrantup.com/), инструментов управления виртуализацией [Libvirt](https://libvirt.org/), 
эмулятора виртуальных машин [Qemu][https://www.qemu.org/], модуля ядра, использующего расширения виртуализации (Intel VT или AMD-V) [KVM](https://linux-kvm.org/page/Main_Page) и инструмента автоматизации [Ansible](https://www.ansible.com/)
Схема стенда выглядит следующим образом:
![Схема сети](ejabberd.drawio.png)

##### Первоначальное развёртывание

