TYPE := cm-collectd
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
		--env MEMCACHE_HOST=localhost \
		--env MEMCACHE_PORT=11211 \
		--label com.dnsdock.image=cm-collectd \
		--label com.dnsdock.alias=cm-collectd \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
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
		--env GRAPHITE_HOST=carbon-relay \
		--env MEMCACHE_HOST=memcached \
		--env MEMCACHE_PORT=11211 \
		--label com.dnsdock.image=cm-collectd \
		--label com.dnsdock.alias=cm-collectd \
		--label com.dnsdock.ttl=30 \
		--volume /etc/localtime:/etc/localtime:ro \
		--volume ~/src/cm-xlabs/monitoring/environments/customer/share/resolv.conf:/etc/resolv.conf:ro \
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
