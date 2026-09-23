# MetaThief_MU (Security Impossible CTF 2026 - Monash University, cloud)

MetaThief presents a web service designed to fetch and display preview contents from user-supplied URLs. The challenge description hints at an AWS cloud deployment, indicating that server-side request processing could expose internal cloud infrastructure.

## Identifying the SSRF Primitive

The web application exposes an endpoint `/fetch?url=` that accepts an HTTP URL, performs an outbound `GET` request from the backend server, and returns the response body directly to the client.

Because the endpoint performs no destination filtering, IP blocklisting, or scheme validation, it provides an unconstrained Server-Side Request Forgery (SSRF) primitive.

In cloud environments such as Amazon Web Services (AWS), EC2 instances query the link-local metadata address `169.254.169.254` (the Instance Metadata Service, or IMDS) to retrieve network configuration, identity credentials, and instance bootstrap data.

## Exploring the Metadata Service

We start by querying the standard IMDSv1 paths through the SSRF proxy:

```bash
curl -s "http://$TARGET:$PORT/fetch?url=http://169.254.169.254/latest/meta-data/"
```

The service responds with the standard directory listing (`ami-id`, `hostname`, `iam/`, `public-keys/`, etc.).

Next, we inspect the IAM security credentials path:

```bash
curl -s "http://$TARGET:$PORT/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
```

Querying the listed role returns an AccessKeyId, SecretAccessKey, and Token. However, testing these credentials with the AWS CLI reveals they are expired decoy keys designed to mislead automated scanners.

## Retrieving Cloud-Init User-Data

Beyond `/meta-data/`, the IMDS exposes `/latest/user-data`. When an EC2 instance launches, AWS executes the user-data script (cloud-init) to configure software, provision environment variables, and bootstrap services. Developers frequently leave configuration secrets and flags inside user-data scripts.

We target `/latest/user-data` via the SSRF endpoint:

```bash
curl -s "http://$TARGET:$PORT/fetch?url=http://169.254.169.254/latest/user-data"
```

The server returns the initial bash bootstrap script:

```bash
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y python3-pip
export FLAG="sictf{dda98075907f6ff9aa3c246fa41e5e6c}"
python3 -m app.server &
```

The user-data script contains the flag in plaintext as an exported environment variable.

Solve: `solve/solve.sh`

Flag: `sictf{dda98075907f6ff9aa3c246fa41e5e6c}`
