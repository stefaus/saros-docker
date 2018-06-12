# Saros Docker Testenv

Creates a docker container per eclipse instance and a dockerd xmpp server.

## features
- limit network bandwith and latency (upload 5mbit, 15ms) per client
- starts eclipse with debug enabled and java mission control

## requirements
- linux (tested with mint 18.3 / ubuntu)
- docker
- sudo
- socat # for port forwarding
- iproute2 # for traffic control

### project structure
Saros is complex, so this is a bit hacky.
To use this, it is mandatory to keep a certain folder structure:

```
□ folder somewhere in your filesystem
┣╸eclipse
┣╸jdk
┣╸git (the repository folder)
┃ ┗╸saros (checkout with all needed projects)
┣╸workspaces
┗╸docker (this git repo)
  ┗╸copy configuration.properties to git/saros/de.fu_berlin.inf.dpp/test/stf/de/fu_berlin/inf/dpp/stf/client
```

## usage
`./testenv.sh`

## java remote debug
connect to 192.168.25.100:6006 for alice, 192.168.25.101:6006 for bob, ...

## java mission control
connect to 192.168.25.100:9090 for alice, 192.168.25.101:9090 for bob, ...

## remarks
- saros uses tls 1.0 -> ejabberd is set to this support this unsecure method
- self signed certifcate -> seems to be no problem, and who cares about hostnames...
- some dns server at fu network are blocked -> configre docker accordingly
 
