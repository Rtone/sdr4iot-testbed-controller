from fabric.api import env, run

#For your convenience, each server has been linked to it's client-Id by means of a role:env.roledefs['server11'] = ['server11.wilab2.ilabt.iminds.be']
env.roledefs['server12'] = ['server12.wilab2.ilabt.iminds.be']

env.roledefs['all'] = ['server11.wilab2.ilabt.iminds.be', 'server12.wilab2.ilabt.iminds.be']

#Use env.hosts instead of roles if you want to execute actions on all hosts instead of being selective:
#env.hosts = [
#	"server11.wilab2.ilabt.iminds.be",
#	"server12.wilab2.ilabt.iminds.be",
#  ]



env.key_filename="./id_rsa"
env.use_ssh_config = True
env.ssh_config_path = './ssh-config'

def pingtest():
    run('ping -c 3 8.8.8.8')

def uptime():
    run('uptime')
