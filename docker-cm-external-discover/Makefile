TYPE := cm-external-discover
IMAGE_NAME := docker-${TYPE}

build:
	docker \
		build \
		--rm --tag=$(IMAGE_NAME) .
	@echo Image tag: ${IMAGE_NAME}

clean:
	docker rmi \
		${IMAGE_NAME}

run:
	docker run \
		--detach \
		--interactive \
		--tty \
		--env DISCOVERY_HOST=172.31.21.237 \
		--env DISCOVERY_PORT=8080 \
		--env DISCOVERY_PATH=/api/aws \
		--env DISCOVERY_POLL_INTERVAL=10 \
		--env MONITORING_HOST=localhost \
		--env MONITORING_PORT=80 \
		--env MONITORING_API_VERSION=2 \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME) \
		/usr/local/bin/external-discover.rb

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env DISCOVERY_HOST=172.31.21.237 \
		--env DISCOVERY_PORT=8080 \
		--env DISCOVERY_PATH=/api/aws \
		--env DISCOVERY_POLL_INTERVAL=10 \
		--env MONITORING_HOST=localhost \
		--env MONITORING_PORT=80 \
		--env MONITORING_API_VERSION=2 \
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
	docker \
		history ${IMAGE_NAME}
