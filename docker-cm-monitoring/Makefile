TYPE := cm-monitoring
IMAGE_NAME := docker-${TYPE}

JOLOKIA_IP := $(docker inspect --format '{{ .NetworkSettings.IPAddress }}' jolokia 2>/dev/null)
GRAPHITE_IP := $(docker inspect --format '{{ .NetworkSettings.IPAddress }}' graphite 2>/dev/null)
GRAFANA_IP := $(docker inspect --format '{{ .NetworkSettings.IPAddress }}' grafana   2>/dev/null)
ICINGA2_IP := $(docker inspect --format '{{ .NetworkSettings.IPAddress }}' icinga2-core   2>/dev/null)


build:
	docker build \
    --rm \
    --tag=$(IMAGE_NAME) \
    .

run:
	docker run \
		--detach \
		--interactive \
		--tty \
		--hostname=${IMAGE_NAME} \
		--name=${USER}-${TYPE} \
		$(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--hostname=${IMAGE_NAME} \
		--name=${USER}-${TYPE} \
		$(IMAGE_NAME)

exec:
	docker exec \
		--interactive \
		--tty \
		${USER}-${TYPE} \
		/bin/sh

stop:
	docker kill \
		${USER}-${TYPE}

