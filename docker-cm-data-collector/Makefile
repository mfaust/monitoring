TYPE := cm-data-collector
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
		--env MEMCACHE_HOST=localhost \
		--env MEMCACHE_PORT=11211 \
		--env JOLOKIA_HOST=jolokia \
		--env MQ_HOST=beanstalkd \
		--env POLL_INTERVAL=10 \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME) \
		/usr/local/bin/external-discover.rb

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env MEMCACHE_HOST=localhost \
		--env MEMCACHE_PORT=11211 \
		--env JOLOKIA_HOST=jolokia \
		--env MQ_HOST=beanstalkd \
		--env POLL_INTERVAL=10 \
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
	docker \
		history ${IMAGE_NAME}
