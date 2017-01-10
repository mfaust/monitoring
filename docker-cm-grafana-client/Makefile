TYPE := cm-grafana-client
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
		--env GRAFANA_HOST=nginx-proxy \
		--env GRAFANA_PORT=80 \
		--env GRAFANA_PATH=grafana/ \
		--label com.dnsdock.image=${TYPE} \
		--label com.dnsdock.alias=${TYPE} \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--network=customer_customer \
		--ip=172.25.0.100 \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env GRAFANA_HOST=192.168.252.101 \
		--env GRAFANA_PORT=80 \
		--env GRAFANA_PATH=grafana/ \
		--label com.dnsdock.image=${TYPE} \
		--label com.dnsdock.alias=${TYPE} \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/resolv.conf:/etc/resolv.conf:ro \
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

