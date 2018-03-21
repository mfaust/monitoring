# CoreMedia Monitoring Toolbox - Operations Guide

## IOR

**IOR** steht als Abkürzung für "_Interoperable Object Reference, eine Objektreferenz auf ein CORBA-Objekt_"

----

Die Kommunikation im CoreMedia-Umfeld findet bidirektional zwischen allen Contentservern sowie zwischen CAE und RLS statt.

Der "Client" fragt seinen "Server" über eine IOR-URI an und bekommt eine URI zurück, über der die weiter Kommunikation stattfindet.

----

Online-Tool zum parsen einer IOR: [ILU IOR Parser](http://www2.parc.com/istl/projects/ILU/parseIOR/)

Die IOR wird von Content-Servern zur Verfügung gestellt und kann über HTTP abgerufen werden:

 - **CMS** `curl http://${SERVER}:40180/coremedia/ior`
 - **MLS** `curl http://${SERVER}:40280/coremedia/ior`
 - **WFS** `curl http://${SERVER}:40380/workflow/ior`
 - **RLS** `curl http://${SERVER}:42180/coremedia/ior`

----

## Operating

| Fehler  | ToDo      |
| :------ | :-------- |
| IOR steht nicht zur Verfügung | den Service kontrollieren und ggf. neu starten |
