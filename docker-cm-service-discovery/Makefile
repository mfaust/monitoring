TYPE := cm-service-discover
IMAGE_NAME := docker-${TYPE}

build:
	docker build \
		--rm \
		--quiet \
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
		--env JOLOKIA_HOST=jolokia \
		--env MQ_HOST=beanstalkd \
		--label com.dnsdock.image=cm-service-discover \
		--label com.dnsdock.alias=cm-service-discover \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env JOLOKIA_HOST=jolokia \
		--env MQ_HOST=beanstalkd \
		--label com.dnsdock.image=cm-service-discover \
		--label com.dnsdock.alias=cm-service-discover \
		--label com.dnsdock.ttl=30 \
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

