# AI News Anchor Deployment Strategies

This document outlines deployment strategies for an automated AI News Anchor project, covering execution environments, containerization, and scheduling.

## 1. Local vs. Cloud Execution

### Local PC Execution
- **Pros**:
    - No direct costs for compute time.
    - Full control over the hardware and software environment.
    - Potentially faster development and debugging loop without network latency.
- **Cons**:
    - **Hardware Limitations**: Video generation and GPU-accelerated TTS (Text-to-Speech) are resource-intensive. This requires a powerful CPU, significant RAM (16GB+ recommended), and a modern NVIDIA GPU with sufficient VRAM (8GB+ recommended).
    - **Availability & Reliability**: The application can only run when the local machine is powered on and operational. It is susceptible to local hardware failures, power outages, and network issues.
    - **Maintenance**: You are solely responsible for all hardware/software maintenance, driver updates, and troubleshooting.

### Cloud Execution
- **Pros**:
    - **Scalability & Power**: On-demand access to a wide range of powerful GPU instances (e.g., NVIDIA T4, V100, A100) that can handle heavy workloads.
    - **High Availability**: Cloud providers offer high uptime SLAs, ensuring the application can run 24/7.
    - **Managed Services**: Leverage managed databases, object storage (like S3 or GCS), and networking, reducing operational overhead.
- **Cons**:
    - **Cost**: GPU instances are expensive. Costs are recurring and can range from ~$0.50/hour to several dollars per hour depending on the instance type. Unmanaged usage can lead to high bills.
    - **Complexity**: Steeper learning curve for initial setup, including networking, security configurations, and identity management.

### Cloud Provider Options & Costs
-   **AWS**: Offers EC2 instances like `g4dn` (NVIDIA T4), `p3` (V100), and `g5` (A10G). Spot Instances can reduce costs by up to 90% but can be interrupted, making them suitable for non-critical, fault-tolerant tasks.
-   **GCP**: Google Compute Engine provides VMs with NVIDIA T4, V100, and A100 GPUs attached. Pricing and performance are competitive with AWS.
-   **Azure**: N-series Virtual Machines offer various NVIDIA GPUs.

**Summary**: For a task running one hour daily, a low-end GPU instance might cost between **$20-$50/month**. A more powerful instance running for longer periods could be several hundred dollars per month.

---

## 2. Docker Containerization

Docker is highly recommended for packaging the application with all its dependencies (Python, system libraries, TTS engine).

- **Pros**:
    - **Environment Consistency**: Guarantees the application runs identically across local development, testing, and production environments.
    - **Dependency Isolation**: Simplifies the management of complex dependencies like CUDA, cuDNN, and specific Python/system library versions.
    - **Portability & Scalability**: Containers can be deployed on any host that runs Docker, from a local machine to a cloud VM or a Kubernetes cluster.
- **Cons**:
    - **Image Size**: AI/ML Docker images can be very large (often 5-10GB+), especially when including CUDA runtimes and TTS models.
    - **GPU Configuration**: Requires the host to have the **NVIDIA Container Toolkit** installed to allow Docker containers to access the GPU. This adds an extra setup step.

### VOICEVOX Docker Setup
The official VOICEVOX engine provides a pre-built Docker image (`voicevox/voicevox_engine`) that can serve audio via an API.
- **GPU Support**: To enable GPU acceleration, the host machine needs the NVIDIA driver and NVIDIA Container Toolkit. The container must be run with the `--gpus all` flag.
- **Example command**: `docker run --gpus all -p 50021:50021 voicevox/voicevox_engine`
- **Integration**: Your main Python application would run in a separate container and communicate with the VOICEVOX container over a shared Docker network.

### Multi-stage Builds for Python Apps
This is a best practice for creating smaller, more secure production images.
1.  **Build Stage**: Use a full-featured base image (e.g., `python:3.10-slim-buster`) to install all dependencies, including compilers and build tools.
2.  **Final Stage**: Start from a minimal base image (e.g., `python:3.10-slim`). Copy only the installed Python packages from the build stage into this new stage, along with your application code. This excludes build-time-only dependencies, significantly reducing the final image size.

---

## 3. Scheduled Execution Options

### On a Dedicated Machine (Local or Cloud VM)
- **cron**:
    - A time-based job scheduler in Unix-like operating systems.
    - **Pros**: Extremely reliable, simple to configure for recurring tasks, and has no cost. It is the industry standard for running jobs on a single server.
    - **Cons**: Requires the machine to be running 24/7. Lacks built-in features for advanced monitoring, logging, and failure notifications without additional tooling.

### Cloud-native & CI/CD Schedulers
- **GitHub Actions**:
    - **Pros**: Excellent for CI/CD and automation directly from your repository. Has a generous free tier for standard runners (2000 minutes/month for private repos).
    - **Cons**: **Free-tier runners do not have GPUs.** To run GPU workloads, you must configure a **self-hosted runner** on your own hardware (local or cloud), which negates the "managed" benefit and re-introduces the need for your own machine. Job execution time is also limited (max 6 hours).

- **Serverless (AWS Lambda / Cloud Functions)**:
    - **Pros**: Highly cost-effective for short, event-driven tasks (pay-per-invocation).
    - **Cons**: Not suitable for this use case. They have strict **execution time limits** (typically 5-15 minutes), limited memory, and while container support exists, GPU access is either unavailable, experimental, or not cost-effective for heavy processing like video generation.

- **VPS / Dedicated Server**:
    - **Pros**: Full control over the environment and guaranteed resources. Can run `cron` without limitations.
    - **Cons**: You are responsible for all setup, security, and maintenance. Often comes at a higher fixed monthly cost compared to on-demand cloud VMs.

---

## 4. Recommended Configurations

### A. Minimal Setup (Personal/Hobbyist Use)
This setup prioritizes simplicity and zero to low cost.
-   **Environment**: A local PC with a modern NVIDIA GPU (e.g., GeForce RTX 30/40 series).
-   **Orchestration**: `docker-compose` to define and run the multi-container application (your Python app + VOICEVOX).
-   **Scheduling**: The native OS scheduler: **cron** on Linux/macOS or **Task Scheduler** on Windows.
-   **Workflow**:
    1.  The scheduler triggers a script that runs `docker-compose up`.
    2.  The Python app fetches data, calls the VOICEVOX API for audio, generates the video, and saves the output to the local disk.
    3.  `docker-compose down` cleans up the containers after the job is done.

### B. Production-Ready Setup
This setup prioritizes reliability, scalability, and automation for a public-facing service.
-   **Environment**: A **Cloud VM** with a GPU (e.g., AWS EC2 `g4dn.xlarge`). Use an Infrastructure as Code tool like **Terraform** to manage and provision this resource reproducibly.
-   **Containerization**:
    -  Application is containerized using Docker with a multi-stage build.
    -  The image is stored in a private registry (e.g., AWS ECR, Google Artifact Registry, Docker Hub).
-   **Orchestration**:
    -  For simple scheduling, **cron** on the cloud VM is sufficient and reliable.
    -  For complex workflows (e.g., multiple steps, dependencies, robust error handling), use a dedicated workflow orchestrator like **Apache Airflow** or **Prefect**.
-   **CI/CD**: A **GitHub Actions** pipeline that automatically tests the code, builds the Docker image, pushes it to the registry, and (optionally) logs into the VM to pull the latest image.
-   **Workflow**:
    1.  `cron` on the VM triggers the application.
    2.  The script pulls the latest Docker image.
    3.  The video is generated and uploaded to a cloud storage service (**AWS S3** or **Google Cloud Storage**).
    4.  (Optional) The application sends a status notification upon success or failure using a service like SNS or a webhook.
