# OpenAI API Key Permissions and Security (2025-2026)

This document provides a detailed overview of the OpenAI API key permission system, security best practices, and the process for creating and managing scoped API keys.

## 1. OpenAI API Key Permission System

OpenAI has transitioned to a more granular and secure system for managing API access through **Projects** and **scoped API keys**. This allows for precise control over an API key's capabilities.

### Permissions Granularity

API key permissions are not granted on a per-model basis, but rather on a per-endpoint-group level. When creating a key, you can assign one of three permission levels:

1.  **All**: Grants unrestricted access to all API endpoints within the project. This is the most permissive level.
2.  **Read Only**: Allows the key to list and read metadata and objects (e.g., list fine-tuning jobs, retrieve a file's metadata) but prohibits any write or generative operations.
3.  **Restricted**: This is the recommended and most secure option. It allows you to specify `None`, `Read`, or `Write` access for individual API endpoint groups.

### Key Types: Project vs. Legacy User

-   **Project API Keys (Recommended)**: These are the current standard. Keys are created within a specific **Project**. Their access is confined to that project only, promoting better organization and security. If a project key is compromised, the blast radius is limited to that single project.
-   **Legacy User API Keys (Phasing Out)**: These older keys are tied directly to a user account and grant access to *all* projects and organizations the user belongs to. OpenAI strongly encourages migrating away from these legacy keys due to their broad scope and associated security risks.

---

## 2. Permissions Required for Each API

To apply the principle of least privilege, you should grant a key `Write` access only to the specific endpoint groups it needs to function.

| API / Feature | Endpoint Group(s) | Required Permission | Description |
| :--- | :--- | :--- | :--- |
| **Chat Completions** | `v1/chat/completions` | `Write` | To create chat completions with models like GPT-4o, GPT-4 Turbo, and GPT-4o-mini. |
| **Image Generation** | `v1/images/generations` | `Write` | To generate images with DALL-E 3. |
| **Audio (Transcription)** | `v1/audio/transcriptions` | `Write` | To transcribe audio files using the Whisper API. |
| **Audio (Text-to-Speech)** | `v1/audio/speech` | `Write` | To generate speech from text using the TTS API. |
| **Embeddings API** | `v1/embeddings` | `Write` | To create embeddings from text. |
| **Fine-tuning API** | `v1/fine_tuning/jobs` | `Write` | To create, manage, and view fine-tuning jobs. Requires `Read` to list jobs. |
| **Assistants API** | `v1/assistants`<br>`v1/threads` | `Write` | To create and manage Assistants, Threads, and Messages. Requires `Read` to list/retrieve them. |
| **Files API** | `v1/files` | `Write` | To upload files for use with APIs like Assistants or Fine-tuning. `Read` is needed to list/retrieve files. |
| **Batch API** | `v1/batches` | `Write` | To create and manage asynchronous batch processing jobs. |
| **Model Listing** | `v1/models` | `Read` | To list available models. Often required by libraries to validate a model name. |

---

## 3. Security Best Practices

Adhering to security best practices is critical for protecting your account and data.

-   **Principle of Least Privilege**: Always create `Restricted` API keys with the minimum permissions required for the application's functionality. For an application that only uses the Chat Completions API, grant `Write` access *only* to the `v1/chat/completions` endpoint.
-   **Key Rotation**: Regularly rotate your API keys (e.g., every 60-90 days). If a key is ever exposed, immediately revoke it and generate a new one.
-   **Environment Variable Management**:
    -   **NEVER** hardcode API keys directly into your source code.
    -   **NEVER** commit API keys to version control (e.g., Git). Use a `.gitignore` file to exclude configuration files.
    -   Store keys in environment variables (`OPENAI_API_KEY`) and load them into your application at runtime.
-   **Production vs. Development Keys**:
    -   Use separate Projects and API keys for your `development`, `staging`, and `production` environments.
    -   Development keys can have broader permissions, but production keys must be strictly locked down to only the necessary scopes.
-   **Backend Storage and Secret Management**:
    -   **NEVER** expose an API key on the client-side (in a browser or mobile app). All API calls should be routed through a secure backend server where the key is stored.
    -   In production, use a dedicated secret management service like AWS Secrets Manager, Azure Key Vault, or HashiCorp Vault to store API keys securely.
-   **Monitoring**: Regularly monitor your API usage and costs in the OpenAI dashboard to detect any unusual or unauthorized activity.

---

## 4. API Key Creation Process

### How to Create a New Restricted API Key

1.  Navigate to the OpenAI Platform: [platform.openai.com](https://platform.openai.com).
2.  Select the **Project** you want to create the key for from the dropdown menu in the top-left.
3.  Click on **API keys** in the left-hand navigation menu.
4.  Click the **+ Create new secret key** button.
5.  A modal window will appear. Provide a descriptive **Name** for your key (e.g., "Prod-WebApp-ChatOnly").
6.  Select the **Restricted** permission option.
7.  A list of all API endpoint groups will appear. Set the permission level for each group. For a key that only needs to generate chat responses, set `v1/chat/completions` to `Write` and all others to `None`.
8.  Click **Create secret key**.
9.  **Immediately copy the key and store it in a secure location.** OpenAI will only show you the full key once. You will not be able to retrieve it again.

### How to Restrict an Existing Key

You can modify the permissions of an existing API key at any time.

1.  Go to the **API keys** section for your project.
2.  Find the key you wish to modify in the list.
3.  Click the **Edit** (pencil) icon next to the key.
4.  Adjust the permission levels for each endpoint group as needed.
5.  Click **Save**. The changes will take effect almost immediately.
