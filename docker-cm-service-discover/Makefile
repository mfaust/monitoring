TYPE := cm-service-discover
IMAGE_NAME := docker-${TYPE}

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
		--env JOLOKIA_HOST=jolokia \
		--env BEANSTALK_HOST=beanstalkd \
		--label com.dnsdock.image=cm-service-discover \
		--label com.dnsdock.alias=cm-service-discover \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--network=customer_mon \
		--ip=172.25.0.100 \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME) \
    /usr/local/bin/service-discovery.rb

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env JOLOKIA_HOST=jolokia \
		--env BEANSTALK_HOST=beanstalkd \
		--label com.dnsdock.image=cm-service-discover \
		--label com.dnsdock.alias=cm-service-discover \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--network=customer_mon \
		--ip=172.25.0.100 \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME)

exec:
	docker exec \
		--interactive \
		--tty \
		${IMAGE_NAME} \
		/bin/sh

stop:
	docker kill \
		${IMAGE_NAME}

