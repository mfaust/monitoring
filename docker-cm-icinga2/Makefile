
TYPE := cm-icinga2
IMAGE_NAME := docker-${TYPE}

.PHONY: build clean run  shell exec stop package-info history

default: build

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
		$(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--volume /etc/localtime:/etc/localtime:ro \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
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
	docker history \
		${IMAGE_NAME}

