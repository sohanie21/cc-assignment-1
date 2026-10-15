# Evidence index

All required evidence is captured as text files in this folder.

- `b1-sizes.txt` contains the A, B, and C image sizes and `docker history` output.
- `b2-cache.txt` contains the rebuild after changing one line of `app.py`.
- `b3-cache.txt` contains the deliberately poor cache-order rebuild using `Dockerfile.bad`.
- `c1-acr.txt` proves that image tags `1.0` and final deployed tag `1.1` are present in ACR, with registry manifest digests.
- `c2-aci.txt` contains the final ACI status, public IP, FQDN, image tag `1.1`, and `Succeeded` provisioning state.
- `c3-request.txt` contains successful responses through the public IP with the ACI host header and through the public FQDN.
- `c4-secure-var.txt` shows `secureValue` and `value` as `null` in the control-plane response for `GREETING`.

No credentials or registry passwords are stored in this folder. The ACI was deployed in
Germany West Central because that region was allowed by the subscription policy. The ACR
was kept in France Central, where ACR creation was allowed.
