SDR4IoT
=======

This repo holds resources (script, templates…) needed to experiment with wilab. In this README, we'll present the end-to-end procedure to collect BLE advertising packets from wilab.

# jFed

### Presentation
jFed is a tool to use wilab testbed. When installing jFed on Debian/Ubuntu, it comes with 2 tools : jFed-GUI and jFed-CLI. The first one will be used to check that your configuration is valid, and to get some information we'll later need when using jFed-CLI. jFed-CLI will allow us to use scripts to automate tests.

### Get certificate to access labs
See [jFed Getting Started]

### Play (jFed-GUI) --- TODO expand this part
See [Getting Started]
Use jfed-gui to:
- install certificate in /path/to/.jFed (in your home)
- see that you can contact the system
- play with a resource or two
- add a node, start experiment, stop it, then "Export as > Export configuration management settings" to get a zip file of Ansible config.

### Reserve resources
It seems that jfed does not automatically reserve resources, so you'll have
to do it manually (cf. [Reserve nodes]).

### Prepare jFed-CLI configuration
To automate tests, we'll use scripts with jFed-CLI.
- The config file for jFed-CLI is conf/user-example.yml. Check that infos are correct, or update if depending on your config.
- You need to extract the Zip file containing Ansible config you've made previously. Extract the zip file, and copy "id_rsa" and "id_rsa.pub" files to  "templates/ansible/". Execute command "chmod 600 id_rsa".

# Collect BLE advertising packets from wilab

### Install requirements
``` sh
$ pip3 install 'j2cli[yaml]'
$ sudo apt install moreutils
```

### Download jFed CLI tool
Go to https://jfed.ilabt.imec.be/downloads/ and download jfed_cli.tar.gz archive. Extract it, and place the jfed_cli folder in tools/jfed/ folder.

### Download Rtone repos
#### Clone ble_dump
```sh
git clone $(dirname $(git config --get remote.origin.url))/ble-dump.git  <somewhere>
```
#### Download ble_fw
Go to https://infocenter.nordicsemi.com/topic/sdk_nrf5_v16.0.0/ble_sdk_app_beacon.html
Download and extract the directory for BLE examples containing Beacon Transmitter Sample Application example
Add the BLE firmware directory path into your user-exemple yml file

## 1st experiment

Goal : a nrf52 device sends BLE advertising packets, an USRP receives and demodulates them.

You first need to book 2 nodes, 1 apu and 1 server (with an USRP connected). Here we suppose that we have booked apun2 and server15. Then you can enter the following commands :

```sh
cd testbed-controller/

# copy user's conf example
cp conf/user-example.yml conf/me.yml
# tweak it (password, username)
$EDITOR conf/me.yml

cd tools

tmux
# From now, [n] defines commands to be entered in n-th tmux window

[1] ./run.sh -f ../conf/me.yml -f ../conf/all.yml -d -i apun2
[2] ./run.sh -f ../conf/me.yml -f ../conf/all.yml -d -i server15
# Wait for "Ok: ready to execute ansible commands in run/xxx-mobile11/ansible" message

[1] cd run/xxx-apun2/ansible
[1] ../../../setup-nrf52.sh apuN2  #TODO renommer en setup-nrf52-flash-tools.sh
[1] ../../../erase-nrf52-fw.sh -n apuN2 # Pas forcément nécessaire selon l'usage
[1] ../../../setup-nrf52-fw.sh -b apuN2 # TODO renommer en flash-nrf52-fw.sh
# Wait for "Ok: ready to execute ansible commands in run/xxx-server15/ansible" message

[2] cd run/xxx-server15/ansible
[2] ../../../setup-usrp.sh server15 #TODO renommer en flash-server.sh

# Run GnuRadio for BLE demodulation
[2] ../../../setup-gr.sh -s server15 -m mobile11 -p "ble" -e "scenario-0" -e "scene-0" # TODO voir à quoi sert -m mobile11 et s'il faut l'updater
```

# Troubleshooting

#### not enough free ressource (run.sh)
Possible issues are :
- You didn't reserve the node you want to use, or you misspelled it in your command (be careful about cases)
- You've just reserved the node, wait 1 minute

#### OSError: [Errno 28] No space left on device (setup-gr.sh)
You did a lengthy experimentation (>= ~ 5min). When setup-gr.sh tries to generate sigmf archive, there's not enough free space on the server disk. You can show this by using `df -h` command. You can reduce experimentation duration, or download the IQ file and make the sigmf archive locally.


## Extensions

Tools
-----
- [jFed][jfed]: drive experiments. Two versions: GUI or CLI
- omf: ?
- emulab: ?

Requirements
------------
- java (jfed installer does install a specific version)
- python3
- python3-yaml
- jinja2-cli (`pip3 install 'j2cli[yaml]'`)
- ruby
- moreutils (`ts`)

Ressources
==========

Servers you can use for SDR reception :

| Server name | USRP #  |
|----------|------------|
|server9|1|
|server10|2|
|server11|3|
|server12|6|
|server13|4|
|server15|5|

nRF52 devices you can use for BLE advertising : 

| Device  | Platform               | Protocol | MAC Address          |
|------------|-----------------------|-------------|--------------------------|
| apuN2    | nRF52 (Zolertia) | BLE         | F9:A6:1D:5C:0A:B4 |
| apuP22  | nRF52 (Zolertia) | BLE         | C5:7C:7B:2F:2E:59  |
| apuQ2    | nRF52 (Zolertia) | BLE         | E2:1F:7C:DF:86:6E  |


References
==========
- [jFed Reserve nodes](https://inventory.wilab2.ilabt.iminds.be/?viewMode=inventory#)
- [Getting Started](https://doc.ilabt.imec.be/ilabt/virtualwall/getting_started.html)
- [imec iLab.t doc entrypoint](https://doc.ilabt.imec.be/ilabt/index.html)
- [jfed](https://jfed.ilabt.imec.be/downloads/)
- [Ettus doc on UHD and GNUR Radio](https://kb.ettus.com/Building_and_Installing_the_USRP_Open-Source_Toolchain_(UHD_and_GNU_Radio)_on_Linux)
- [Check USRP](https://kb.ettus.com/Verifying_the_Operation_of_the_USRP_Using_UHD_and_GNU_Radio)
- [Robot inteface](https://robotcontrol.wilab2.ilabt.iminds.be/#)


