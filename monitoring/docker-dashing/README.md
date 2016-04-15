# docker-dashing

[Dashing](http://dashing.io/) ist ein einfaches Dashing-Framework (auf Basis von Ruby on Rails), welches über [Widgets](https://github.com/Shopify/dashing/wiki/Additional-Widgets) erweitert werden kann.
Das Dashing-Framework kann von verschiedenen Services Daten einsammeln und visualisieren.

In diesem Dockercontainer stehen bislang folgende Jobs und widgets zur Verfügung:
 - Pingdom
 - Jenkins
 - Icinga2 (work-in-progress)
 - Graphite (experimantal)
 - ChefNodes
 - AWS - CloudFormation / CloudWatch

## Pingdom
Um das Pingdom Widget nutzen zu können, müssen folgende Umgebungsvariablen im Conteiner gesetzt sein:
 - PINGDOM_API
 - PINGDOM_USER
 - PINGDOM_PASS

## Jenkins
Das Jenkins Widget wird über eine eigene yaml Datei im Verzeichniss ``config`` konfiguriert.

## Icinga2
Das Icinga2 Widget wird über eine eigene yaml Datei im Verzeichniss ``config`` konfiguriert.

## Chef
Um das Chef Widget nutzen zu können, muss die Umgebungsvariable CHEF_KNIFE_RB gesetzt werden:
    CHEF_KNIFE_RB=/root/.chef/knife.rb
Damit wird das eigene `~/.chef` Verzeichniss **readonly** in den Container gemappt.

## AWS

