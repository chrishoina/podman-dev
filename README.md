# podman-dev

<!-- Command used, with the newly updated entrypoint.sh and compose.yaml files (both of which were last updated approximately July 29, 2025): -->

```sh
podman-compose --env-file .env up
```

NOTES:

- I'm not using podman secrets, nor am I exporting anything prior to issuing this command. 
- I've tested with the official oracle db/latest (as of ~July 2025); not Gerald's. So, I'm not sure what his entrypoint.sh script looks like. the `test_database` function could probably be added to his file though. Untested, not sure at all though!!


