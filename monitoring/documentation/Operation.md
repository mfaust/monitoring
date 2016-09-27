Operating
=========

Als Annahme gilt:
 - Heap Memory : die Coremedia Applikationen sind mit 2GiB konfiguriert worden
 - Blob Cache : die Coremedia Applikationen sind mit 10GiB konfiguriert worden


## Heap Memory

| green | yellow | red |
|:---:|:---:|:---:|
| < 80% used | 80:95 | > 95% used |

## Blob Cache

| green | yellow | red |
|:---:|:---:|:---:|
| < 80% used | 80:95 | > 95% used |

## CAE Feeder

CAE Feeder sollten Projektspezifisch überwacht werden. Die Schwellwerte sind hier von der Anzahl und der Abhängigkeitstiefe der jeweiligen Elemente abhängig.
Daher sind die folgenden Werte eher ein initialer Richtwert.

| green | yellow | red |
|:---:|:---:|:---:|
| < 200 | 200:500 | > 500 |

Die Feeder müssen einen Healthstatus von 'HEALTHY' liefern, sonst ist deren Funktionalität nicht gegeben.

### HeartBeat

| green | yellow | red |
|:---:|:---:|:---:|
| < 10 ms | 10 ms:60 s | > 60 s |



## Sequenznumbers

Die Differenz der Sequenzen zwischen MLS und RLS sollte nicht zu groß werden.

| green | yellow | red |
|:---:|:---:|:---:|
| < 100 | 100:300 | > 300 |


## CapConnection

Eine CapConnection wird von Clients genutzt, die eine Verbindung zu einem Content-Server aufbauen.

| green | yellow | red |
|:---:|:---:|:---:|
| open |    | closed |

