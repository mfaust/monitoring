## Versionschema

**PLANED**

All Containers have a Version LABEL with the following (or upcoming) Schema:

`YYMM-WEEK.Number`

E.g. from a `Dockerfile`

    FROM alpine:latest

    MAINTAINER Bodo Schulz <bodo.schulz@coremedia.com>

    LABEL version="1707-31.3"

### LTS

In an TLS Version, after the `YYMM` Notations follow the `LTS`:
`1707.LTS`

LTS Version will be recreated every 3 Month.

