# An Apache based SAML authentication proxy

A simple way of putting SAML authentication in front of applications.

It uses [mod_auth_mellon](https://github.com/UNINETT/mod_auth_mellon), to create a Service Provider (SP).

## Running

```
docker run --rm -ti -d --name saml_frontend -e SP_HOSTNAME=sp.nordu.test -e APPSERVERS="backend.norud.test:8443" -v $(pwd)/data:/opt/data -p 80:80 -p 443:445 apache-saml-frontend 
```

This should start the apache frontend, and generate a SP certificate in the `data/certs` directory.

This docker image defaults to using idp.nordu.net as the trusted IDP.

If your backends are running in another docker container on the same host you can add them to the same network, or use the simplistic links.

## Environment options

- `SP_HOSTNAME` - the hostname of the SP
- `APPSERVERS` - A space seperated list of backend servers
- `DISABLE_SUBJECT_CONFIRMATION` - Sets `MellonSubjectConfirmationDataAddressCheck` to off. Useful for running locally, and might be required when running in docker...
- `SSL_CERT` and `SSL_KEY` - can be used to change the default path for the ssl certificates. Default is `/opt/data/certs/${SP_HOSTNAME}.crt` and `/opt/data/certs/${SP_HOSTNAME}.key`. If the files are not present it will use snake oil certificates.
- `SP_CERT` and `SP_KEY` - can be used to change the default path for the sp certificates. Default is `/opt/data/certs/sp.crt` and `/opt/data/certs/sp.key`. SP certificates will be automatically generated at the specified paths if not present.
- `SP_LOCATION` - defaults to the root location `/`
- `SP_DISCOVERY_URL` - Used to set the discovery url, for when you accept multiple IDPs. An example could be `https://md.nordu.net/role/idp.ds`
- `REMOTE_USER_VAR` - set the variable to use for the REMOTE_USER. Defaults to `EPPN`
- `REMOTE_USER_NAME` - the name of the variable. Defaults to `REMOTE_USER`.
- `HEADER_PREFIX` - add a prefix to  all default headers.
- `ACCESS_LOG_OFF` - disable the access log, and only log the error log to std out.

## Trusting IDPs

In the data dir you can add a folder called metadata. The docker image will add all `.xml` files to the mellon configuration.

You can add signing certs as well to check if the metadata is properly signed. Just add the certificate in pem-format named `<IDP_FILE_NAME>.crt` e.g. `idp.nrodu.net.xml.crt`.

If you add more than one IDP you need to set the `SP_DISCOVERY_URL`.

## Adding certificates

Your SP should have proper SSL certificates when running in production. You can add them to the `data/certs` directory. 

You probably want to add the chaining files as well (bundle files). Just concatenate them starting with your certificated, and going up the chain. Normally you should be able to use:

```
cat SSL_CERT.pem BUNDLE.pem > SP_HOSTNAME.crt 
```

## SP metadata

The SP metadata can be downloaded from `<SP_HOSTNAME><SP_LOCATION>/mellon/metadata`.
