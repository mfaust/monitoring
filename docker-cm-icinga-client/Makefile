TYPE := cm-icinga-client
IMAGE_NAME := docker-${TYPE}

.PHONY: build clean shell run exec

build:
	docker build \
		--rm \
		--tag=$(IMAGE_NAME) .
	@echo Image tag: ${IMAGE_NAME}

clean:
	docker rmi \
		${IMAGE_NAME}

run:
	docker run \
		--detach \
		--interactive \
		--tty \
		--volume /etc/localtime:/etc/localtime:ro \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME) \
		icinga-client.rb

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--volume /etc/localtime:/etc/localtime:ro \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		--env ICINGA_CERT_SERVICE='{ "ba": { "user":"admin", "password":"admin" },"api": { "port": "5665", "user":"root", "password":"icinga" },"server": "cm-icinga2-master","port": 4567,"path": "/"}' \
		--entrypoint '' \
		$(IMAGE_NAME) \
		/bin/sh

exec:
	docker exec \
		--interactive \
		--tty \
		${IMAGE_NAME} \
		/bin/sh

stop:
	docker kill \
		${IMAGE_NAME}

package-info:
	docker run \
		--rm \
		--interactive \
		--tty \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME) \
		apk -v info | sort

history:
	docker \
		history ${IMAGE_NAME}
