# Assignment 1 — Containerise and deploy

**Name:** Sohan Chatani
**Campus:** Segovia

## What this is

This project packages the supplied Flask API into a reproducible Docker image and deploys
it to Azure Container Registry and Azure Container Instances. The API returns a greeting
and hostname, increments a file-backed counter, and exposes a health endpoint.

## Build and run it locally

From the repository root:

```bash
docker build -t cc-a1:latest .
docker run --rm -d --name cc-a1 -p 8000:8000 -v cc-a1-data:/data cc-a1:latest
curl http://localhost:8000/
curl http://localhost:8000/count
curl http://localhost:8000/healthz
docker exec cc-a1 id
```

The root request returns JSON containing the greeting and hostname. The count request
returns a JSON count, and the health request returns `{"status":"ok"}`. The `id` command
shows the non-root `appuser`.

To show the named volume surviving a restart:

```bash
curl http://localhost:8000/count

docker run --rm -d --name cc-a1 -p 8000:8000 -v cc-a1-data:/data cc-a1:latest
curl http://localhost:8000/count
docker rm -f cc-a1
```

## Configuration

| Variable | Default | What it does |
|:--|:--|:--|
| `GREETING` | `Hello from the container` | Controls the greeting returned by `/`. |
| `DATA_DIR` | `/data` | Directory containing the persisted counter file. |
| `PORT` | `8000` | Port used by the Flask server. |

## Part B — layers and cache

### B1 — image size

| Build | Base | Stages | Size |
|:--|:--|--:|--:|
| A — single-stage, full base | `python:3.12` | 1 | 1.62GB |
| B — single-stage, slim base | `python:3.12-slim` | 1 | 223MB |
| C — `Dockerfile` | `python:3.12-slim` | 2 | 217MB |

| Step | Saves | What left the image |
|:--|--:|:--|
| A → B | about 1.40GB | The full Debian/Python image's compiler, development packages, utilities, and other build-oriented OS layers. |
| B → C | about 6MB | The multi-stage final image omits the builder's pip installation environment and keeps only the runtime site-packages needed by Flask. |

The A → B change did more work for this small application. `docker history` shows the
full image contains very large development and tooling layers, including a 679MB build
tool layer and a 208MB VCS/tooling layer. The slim image removes those base-image layers.
The B → C difference is small because Flask has only a small dependency set and the slim
runtime already contains most of what this application needs. For an application with
large native dependencies, such as a data-science service containing compilers and large
scientific libraries, B → C would save much more because the builder would contain the
compiler toolchain and temporary build artifacts while the final image would need only the
runtime libraries.

Evidence is in `evidence/b1-sizes.txt`.

### B2 — changing one line of source

I changed the default `GREETING` value in `app.py` from `Hello from the container` to
`Hello from the rebuilt container`. The rebuild output is in `evidence/b2-cache.txt`.
The base image, builder `WORKDIR`, `COPY requirements.txt`, pip-install layer, runtime
user/data-directory layer, and site-packages copy were cached. Only the final `COPY app.py`
step rebuilt, because `app.py` is copied after the stable dependency layers in the
Dockerfile. Docker therefore did not need to reinstall dependencies.

### B3 — making the cache worse

`Dockerfile.bad` copies `app.py` before `requirements.txt` and runs pip installation
after both copies:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY app.py .
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```

The output is in `evidence/b3-cache.txt`. Because the changing application source is now
before dependency installation, changing one line invalidates the later pip-install layer
and forces dependencies to be installed again. The rule broken is to put stable, expensive
instructions before frequently changing source files.

## Part C — Azure

The final deployment used the subscription's allowed-region policy: the resource group is
in Belgium Central, the ACR is in France Central, and ACI is in Germany West Central. The
final deployment uses the AMD64 image tag `1.1`, because the original image built on the
Apple Silicon laptop was ARM64 and was unsuitable for the ACI runtime.

The important commands were:

```bash
az group create --name rg-cc-a1-sohan --location belgiumcentral
az acr create --resource-group rg-cc-a1-sohan --name ccassignment1sohan2026c --location francecentral --sku Basic --admin-enabled true
az acr login --name ccassignment1sohan2026c
docker build --platform linux/amd64 -t cc-a1:amd64 .
docker tag cc-a1:amd64 ccassignment1sohan2026c.azurecr.io/cc-a1:1.1
docker push ccassignment1sohan2026c.azurecr.io/cc-a1:1.1

acr_password=$(az acr credential show --name ccassignment1sohan2026c --query "passwords[0].value" --output tsv)
az container create --resource-group rg-cc-a1-sohan --name cc-a1-aci --location germanywestcentral --os-type Linux --cpu 1 --memory 1.5 --image ccassignment1sohan2026c.azurecr.io/cc-a1:1.1 --dns-name-label cc-a1-sohan-20261015 --ports 8000 --registry-login-server ccassignment1sohan2026c.azurecr.io --registry-username ccassignment1sohan2026c --registry-password "$acr_password" --secure-environment-variables GREETING="secure assignment greeting"
```

The secure environment variable was `GREETING`. In `evidence/c4-secure-var.txt`, Azure's
control-plane response shows both `secureValue` and `value` as `null`, so the actual value
is not readable through `az container show`. The ACI public request and deployment details
are in `evidence/c2-aci.txt` and `evidence/c3-request.txt`.

## Before this went to production

I would replace Flask's development server with a production WSGI server, add proper
readiness and liveness probes, and move the counter to durable managed storage because the
ACI filesystem is ephemeral. I would also use a managed identity or short-lived registry
credentials instead of enabling ACR admin credentials, and add centralized logging and
monitoring before exposing the service publicly.

## AI use

GitHub Copilot was used to explain the assignment, draft and review Dockerfile commands,
interpret Docker cache and Azure errors, and help structure the README and evidence index.
All commands were run and checked in the local terminal, and the final Azure evidence was
captured from the user's subscription.

## Sources

- The supplied Assignment 1 brief and starter README.
- Docker documentation for multi-stage builds, image layers, volumes, and cache ordering.
- Azure CLI documentation and the course Session 4 deployment material for ACR and ACI.
