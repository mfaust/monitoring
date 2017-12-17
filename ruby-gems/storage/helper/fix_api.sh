#!/bin/bash

grep -rl "@memcache\." rootfs/* | xargs \
  sed -i \
    -e 's|self.cacheKey|self.cache_key(|g' \

# memcache.rb
# def initialize( params = {} )
# def self.cacheKey( params = {} )
# def get( key )
# def set( key, value )
# def self.delete( key )


grep -rl "@database\." rootfs/* | xargs \
  sed -i \
    -e 's|@database.toJson(|@database.toJson(|g' \
    -e 's|@database.dnsData(|@database.dns_data(|g' \
    -e 's|@database.createDNS(|@database.create_dns(|g' \
    -e 's|@database.removeDNS(|@database.remove_dns(|g' \
    -e 's|@database.setStatus(|@database.set_status(|g' \
    -e 's|@database.createConfig(|@database.create_config(|g' \
    -e 's|@database.writeConfig(|@database.write_config(|g' \
    -e 's|@database.removeConfig(|@database.remove_config(|g' \
    -e 's|@database.createDiscovery(|@database.create_discovery(|g' \
    -e 's|@database.writeDiscovery(|@database.write_discovery(|g' \
    -e 's|@database.discoveryData(|@database.discovery_data(|g' \
    -e 's|@database.createMeasurements(|@database.create_measurements(|g' \
    -e 's|@database.writeMeasurements(|@database.write_measurements(|g' \
    -e 's|@database.parsedResponse(|@database.parsed_response(|g'

grep -rl "@redis\." rootfs/* | xargs \
  sed -i \
    -e 's|@redis.checkDatabase(|@redis.check_database(|g' \
    -e 's|@redis.cacheKey(|@redis.cache_key(|g' \
    -e 's|@redis.createDNS(|@redis.create_dns(|g' \
    -e 's|@redis.removeDNS(|@redis.remove_dns(|g' \
    -e 's|@redis.dnsData(|@redis.dns_data(|g' \
    -e 's|@redis.setStatus(|@redis.set_status(|g' \
    -e 's|@redis.createConfig(|@redis.create_config(|g' \
    -e 's|@redis.writeConfig(|@redis.write_config(|g' \
    -e 's|@redis.removeConfig(|@redis.remove_config(|g' \
    -e 's|@redis.createDiscovery(|@redis.create_discovery(|g' \
    -e 's|@redis.writeDiscovery(|@redis.write_discovery(|g' \
    -e 's|@redis.discoveryData(|@redis.discovery_data(|g' \
    -e 's|@redis.createMeasurements(|@redis.create_measurements(|g' \
    -e 's|@redis.writeMeasurements(|@redis.write_measurements(|g' \
    -e 's|@redis.parsedResponse(|@redis.parsed_response(|g' \
    -e 's|@redis.addNode(|@redis.add_node(|g' \
    -e 's|@redis.removeNode(|@redis.remove_node(|g'

grep -rl "Storage::.*\.cacheKey" rootfs/* | xargs \
  sed -i \
    -e 's|cacheKey(|cache_key(|g'
