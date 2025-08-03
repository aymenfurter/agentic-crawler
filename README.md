<div align="center">

> **Warning:** This project is provided as a demonstration. Please ensure you have appropriate permissions to crawl any websites and comply with their terms of service.

# Agentic Web Crawler with MCP & Fabric

<p align="center">
  <img src="https://img.shields.io/badge/Azure-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white" alt="Azure"/>
  <img src="https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white" alt="OpenAI"/>
  <img src="https://img.shields.io/badge/Microsoft_Fabric-0078D4?style=for-the-badge&logo=microsoft&logoColor=white" alt="Microsoft Fabric"/>
  <img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License"/>
</p>

<h3>Two-phase AI-powered solution: (1) Web crawling using Azure OpenAI Service's Responses API via Playwright-MCP to extract and store data in Microsoft Fabric, then (2) Natural language analytics using Azure AI Foundry's AI Agent service to query the stored data.</h3>

</div>

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Usage](#usage)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

---

## Architecture Overview

<div align="center">
  <img src="assets/architecture.png" alt="Architecture Diagram" width="800"/>
</div>

<br>

The solution consists of two main phases with three technical components:

<div align="center">

> **Important:** This is a structured data extraction and analytics solution, not a RAG (Retrieval-Augmented Generation) approach. The system extracts, transforms, and stores data in a queryable format rather than using vector embeddings for semantic search.

### **Phase 1: Data Crawling & Storage**
- **Azure OpenAI Service's Responses API** with MCP support connects to the Playwright MCP server
- **Playwright MCP server** (hosted on Azure Container Apps) provides browser automation to LLMs
- **Microsoft Fabric notebook** orchestrates the crawling process and stores extracted data

### **Phase 2: Natural Language Analytics**
- **Azure AI Foundry's AI Agent service** agent layer connecting to the Fabric Data Agent
- **Microsoft Fabric Data Agent** generates SQL queries from natural language questions
- **Microsoft Fabric Data Warehouse** stores the extracted structured data as the foundation for analytics queries

### **Supporting Infrastructure**
- **Azure API Management (APIM)** secures access to the MCP server
- **Azure Key Vault** stores credentials securely
- **Pydantic models** validate extracted data structure

</div>

---

## Prerequisites

Before you begin, ensure you have:

### **Azure Services**

- Azure subscription with the following services:
  - Azure OpenAI Service
  - Microsoft Fabric workspace (F2 or higher capacity)
  - Azure Key Vault
  - Azure AI Foundry project

- The following components are provisioned during setup:
  - Azure API Management instance
  - Azure Container Apps environment for Playwright MCP server

---

## Setup Instructions

### 1. Deploy the MCP Server Infrastructure

The deployment scripts will set up the secure browser infrastructure:

```bash
cd mcp-server-deployment
./deploy.sh
```

### 2. Configure Azure Key Vault

Store your credentials securely:

1. **Create a Key Vault** (if not exists)
2. **Add the following secrets:**
   ```
   mcp-key: Your APIM subscription key
   openai-key: Your Azure OpenAI API key
   ```

### 3. Set Up Microsoft Fabric Data Agent

To enable natural language querying of your data:

#### **Enable Fabric Data Agent capabilities:**

1. Navigate to your Fabric tenant settings
2. Enable the following settings:
   - "Fabric data agent tenant settings"
   - "Copilot tenant switch"
   - "Cross-geo processing for AI"
   - "Cross-geo storing for AI"

#### **Create a Data Agent in Fabric (After you ran the notebook):**

1. In your Fabric workspace, click **New** → **Data Agent**
2. Configure access to your data source
3. Note the **Artifact ID** and **Workspace ID** from the published endpoint (derive from URL in the User Interface)

### 4. Connect Fabric Data Agent to Azure AI Foundry

#### **In Azure AI Foundry Portal:**

1. Navigate to your AI Foundry project
2. Go to **Agents** → Create new agent
3. Under **Knowledge**, click **Add** → **Microsoft Fabric**
4. Create a new connection using:
   - Workspace ID from your Fabric Data Agent
   - Artifact ID from your Fabric Data Agent
   - Mark both as secrets

#### **Configure the agent:**

- Select your deployment model (e.g., `gpt-4o-mini`)
- Enable the Fabric tool for your agent

---

## Usage

### Phase 1: Data Crawling and Storage

1. **Open the notebook** `blog-data-ingestion.ipynb` in Microsoft Fabric
2. **Update the configuration variables:**
   - Key Vault URI
   - Azure OpenAI endpoint and deployment name
   - MCP server URL (from deployment output)

3. **Run the notebook cells sequentially:**

#### **The crawling pipeline will:**

- Use Azure OpenAI's Responses API to connect to the MCP server
- Navigate to target websites via the Playwright MCP server
- Extract all blog post URLs and visit each page
- Extract structured data using LLM capabilities
- Store the processed data in a table in Microsoft Fabric

<div align="center">

### Notebook Execution in Progress

<img src="assets/fabric-data-table.png" alt="Blog Data Ingestion Pipeline" width="700"/>
</div>

### Phase 2: Natural Language Analytics

Once data is crawled and stored in Fabric:

1. **Set up the Fabric Data Agent** (as described in setup instructions)
2. **Connect it to Azure AI Foundry's AI Agent service**
3. **Ask analytics questions** in natural language about your stored data

#### **Example analytics queries:**

```
"How many blog entries were written in 2024?"
"What are the most recent blog posts about AI?"
"Show me all posts that mention Azure OpenAI"
"Which technologies are most frequently discussed?"
"What's the average reading duration in minutes of blog posts by month?"
```

<div align="center">

### AI Foundry Agent in Action

<img src="assets/ai-foundry-agent-response.png" alt="AI Foundry Agent Response" width="700"/>
</div>

---

## Security Considerations

This implementation includes basic security measures:

<div align="center">

| Security Feature | Implementation |
|-----------------|----------------|
| **Authentication** | API Management with subscription key |
| **Network Security** | IP whitelisting between APIM and Container Apps |
| **Credential Storage** | Azure Key Vault for secrets |
| **Identity Management** | User identity passthrough for data access |

</div>

> **Note:** This is a demo implementation. For production use, consider additional security requirements apply.

---

## Additional Resources

<div align="center">

- [Microsoft Fabric Data Agent Documentation](https://learn.microsoft.com/en-us/fabric/data-science/concept-data-agent)
- [Azure AI Foundry Fabric Tool Guide](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/tools/fabric?pivots=portal)
- [Azure OpenAI Responses API Documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/responses?tabs=python-secure)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)