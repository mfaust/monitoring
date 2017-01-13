TYPE := cm-graphite-client
IMAGE_NAME := docker-${TYPE}

build:
	docker build \
		--rm \
		--tag=$(IMAGE_NAME) .
	@echo Image tag: ${IMAGE_NAME}

run:
	docker run \
		--detach \
		--interactive \
		--tty \
		--env-file ~/src/cm-xlabs/monitoring/environments/customer/env/cm-graphite-client.env \
		--label com.dnsdock.image=${TYPE} \
		--label com.dnsdock.alias=${TYPE} \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/resolv.conf:/etc/resolv.conf:ro \
		--add-host nginx-proxy:192.168.252.101 \
		--network=customer_mon \
		--ip=172.25.0.100 \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env-file ~/src/cm-xlabs/monitoring/environments/customer/env/cm-graphite-client.env \
		--label com.dnsdock.image=${TYPE} \
		--label com.dnsdock.alias=${TYPE} \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/resolv.conf:/etc/resolv.conf:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/logging.rb:/usr/local/lib/logging.rb \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/message-queue.rb:/usr/local/lib/message-queue.rb \
		--add-host nginx-proxy:192.168.252.101 \
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
