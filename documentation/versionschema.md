## Versionschema

All Containers have a Version LABEL with the following (or upcoming) Schema:

`YY.MM.Number`

E.g. from a `Dockerfile`

    FROM alpine:latest

    MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

    LABEL version="17.04.03"

### LTS

In an TLS Version, was the `Number` replased with `LTS`:
`17.05.LTS`

LTS Version will be recreated every 3 Month.

