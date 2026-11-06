\# DevOps Project: Microservices CI/CD on AWS



Three Flask microservices containerised with Docker, provisioned on AWS with Terraform, deployed automatically by a Jenkins pipeline to EC2 via Amazon ECR, and monitored with Prometheus and Grafana.



\## Architecture





Developer ──push──> GitHub (develop → PR → main)

&#x20;                       │  (Jenkins polls every 2 min)

&#x20;                       ▼

&#x20;                Jenkins (Docker, local)

&#x20;    Checkout → Build → Test → Push to ECR → Deploy → Health check

&#x20;                       │                        │

&#x20;                       ▼                        ▼ (SSH + deploy.sh)

&#x20;                Amazon ECR (3 repos)  ──pull──> EC2 (t3.small, ap-south-1)

&#x20;                                                ├─ nginx :80 (only public port)

&#x20;                                                ├─ user-service :5001

&#x20;                                                ├─ product-service :5002

&#x20;                                                ├─ order-service :5003 → calls user + product

&#x20;                                                └─ Prometheus, Node Exporter,

&#x20;                                                   Blackbox Exporter, Grafana

&#x20;                                                   (bound to 127.0.0.1, SSH tunnel only)





\## Tech stack



| Area | Tools |

|---|---|

| Application | Python 3.12, Flask |

| Containers | Docker, Docker Compose, Nginx reverse proxy |

| Infrastructure as Code | Terraform (AWS provider \~> 5.0) |

| Cloud | AWS EC2, ECR, IAM, Security Groups |

| CI/CD | Jenkins (declarative pipeline), GitHub |

| Monitoring | Prometheus, Node Exporter, Blackbox Exporter, Grafana |



\## Repository structure





user-service/ product-service/ order-service/   Flask apps + Dockerfiles

nginx/default.conf                               Reverse proxy routes

docker-compose.yml                               Local environment

deploy/docker-compose.prod.yml                   Production stack (pulls from ECR)

deploy/deploy.sh                                 Runs on EC2: login, pull, up, keep previous version

monitoring/                                      Prometheus + Grafana config

terraform/                                       EC2, ECR, security group, IAM role

jenkins/Dockerfile                               Jenkins image with Docker CLI + AWS CLI

Jenkinsfile                                      CI/CD pipeline





\## 1. Run locally



bash

docker compose up -d --build

docker compose ps            # all 4 containers healthy

curl http://localhost/api/users

curl http://localhost/api/products

curl http://localhost/api/orders





Only Nginx publishes a port (80). Services reach each other by name on the app-net network. Healthchecks plus depends\_on: service\_healthy make order-service wait for its dependencies.



\## 2. Provision AWS with Terraform



bash

cd terraform

\# terraform.tfvars (git-ignored):  my\_ip = "<your public IP>"

terraform init

terraform validate

terraform plan        # 8 resources

terraform apply





Creates one EC2 instance (Amazon Linux 2023, Docker installed via user\_data), three ECR repositories, a security group and an IAM instance profile.



\## 3. CI/CD pipeline



Jenkins runs in Docker locally and polls main every 2 minutes.



| Stage | What it does |

|---|---|

| Checkout | Pulls code, sets image tag v1.0.<build>-<git sha> |

| Build | Builds all three images |

| Test | Starts each image and imports the app to catch errors |

| Push to ECR | Logs in with the aws-creds Jenkins credential and pushes |

| Deploy to EC2 | Copies compose, nginx and monitoring files over SSH and runs deploy.sh |

| Health Check | Calls http://<EC2>/api/orders until it responds, else fails the build |



Branching: work on develop, merge to main through a pull request, Jenkins deploys main.



\## 4. Monitoring



\- \*Prometheus targets:\* node, prometheus, and service-health (Blackbox probes of all four /health endpoints)

\- \*Grafana:\* "Node Exporter Full" dashboard (ID 1860) plus a "Service Availability" panel using probe\_success (1 = UP)

\- Access through an SSH tunnel:

&#x20; ssh -i <key>.pem -L 3001:localhost:3000 -L 9090:localhost:9090 ec2-user@<EC2\_IP>



\## 5. Rollback



deploy.sh saves the previous .env as .env.previous on every deploy. To roll back on the server:



bash

cd /opt/app

sed -i 's/IMAGE\_TAG=.\*/IMAGE\_TAG=<previous tag>/' .env

docker compose -f docker-compose.prod.yml up -d

docker compose -f docker-compose.prod.yml restart nginx





Demonstrated: rolled back from v1.0.20-119a93c to v1.0.16-aabb06c and forward again with no downtime to the API. ECR tags are \*immutable\*, so an old tag always points to the exact same image.



\## 6. Troubleshooting log (real incidents)



| Symptom | Cause | Fix |

|---|---|---|

| Container exited on start | \_\_name\_\_ typed as \_name\_ | Corrected the code and rebuilt |

| Builds #3–#14 failed: WorkflowScript: 82 expecting '(' | A closing ''' was lost in the Jenkinsfile deploy stage | Restored the Jenkinsfile and merged the fix; #15 passed |

| Monitoring containers never created | Compose edit only partly saved | Replaced the full production compose file |

| 502 Bad Gateway after deploy | Nginx cached old container IPs | Restart nginx at the end of every deploy |

| Builds green but old version running | up -d line accidentally replaced in deploy.sh | Restored pull → up -d → restart nginx |

| App containers stuck in "Created" | Two pipeline runs deployed at once | Removed stale container, re-ran up -d, added disableConcurrentBuilds() |

| SSH blocked next day | Home IP changed | Updated terraform.tfvars and re-applied (security group only) |



\## 7. Security decisions



\- SSH allowed only from my IP (/32); only port 80 is public

\- EC2 pulls from ECR with an \*IAM role\*, so no AWS keys are stored on the server

\- Secrets live in the Jenkins credential store, never in Git; .pem, \*.tfstate and terraform.tfvars are git-ignored

\- Containers run as a non-root user; IMDSv2 enforced; ECR scan-on-push enabled

\- Prometheus and Grafana bound to 127.0.0.1 and reached only through an SSH tunnel

\- Limitations (learning setup): Jenkins runs as root with the Docker socket, and the Terraform IAM user has AdministratorAccess. In production these would be locked down.



\## 8. Cleanup



bash

cd terraform

terraform destroy





Then delete the IAM access key used for this project.



\## Screenshots



See docs/screenshots/: Compose healthy, Terraform apply, Jenkins pipeline, Prometheus targets, Grafana dashboards, failed and recovered builds, rollback.

