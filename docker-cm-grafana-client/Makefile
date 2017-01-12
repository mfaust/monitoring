TYPE := cm-grafana-client
IMAGE_NAME := docker-${TYPE}

build:
	docker build \
		--rm \
		--tag=$(IMAGE_NAME) .
	@echo Image tag: ${IMAGE_NAME}

run:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env-file ~/src/cm-xlabs/monitoring/environments/customer/env/cm-grafana-client.env \
		--label com.dnsdock.image=${TYPE} \
		--label com.dnsdock.alias=${TYPE} \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/resolv.conf:/etc/resolv.conf:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/storage.rb:/usr/local/lib/storage.rb \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/logging.rb:/usr/local/lib/logging.rb \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/mbean.rb:/usr/local/lib/mbean.rb \
		--volume ~/src/cm-xlabs/monitoring/docker-cm-monitoring/rootfs/usr/local/share/templates/grafana:/usr/local/share/templates/grafana \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/data/monitoring:/var/cache/monitoring \
		--network=customer_mon \
		--ip=172.25.0.100 \
		--hostname=${IMAGE_NAME} \
		--name=${IMAGE_NAME} \
		$(IMAGE_NAME) grafana-client.rb

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--env-file ~/src/cm-xlabs/monitoring/environments/customer/env/cm-grafana-client.env \
		--label com.dnsdock.image=${TYPE} \
		--label com.dnsdock.alias=${TYPE} \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/resolv.conf:/etc/resolv.conf:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/storage.rb:/usr/local/lib/storage.rb \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/logging.rb:/usr/local/lib/logging.rb \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/common/mbean.rb:/usr/local/lib/mbean.rb \
		--volume ~/src/cm-xlabs/monitoring/docker-cm-monitoring/rootfs/usr/local/share/templates/grafana:/usr/local/share/templates/grafana \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/data/monitoring:/var/cache/monitoring \
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

